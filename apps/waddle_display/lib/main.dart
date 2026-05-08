import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'alerts/alert_repository.dart';
import 'alerts/alert_overlay_host.dart';
import 'alerts/alert_severity_icons_kv.dart';
import 'alerts/drift_alert_repository.dart';
import 'api/deployment_api_key_source.dart';
import 'api/local_rest_server.dart';
import 'api/network_addressing.dart';
import 'blob/blob_store.dart';
import 'blob/filesystem_blob_store.dart';
import 'bootstrap/app_fatal_error_recovery.dart';
import 'clock.dart';
import 'config/dev_dotenv_secrets.dart';
import 'config/provider_config_resolver.dart';
import 'curator/default_dashboard_curator.dart';
import 'curator/drift_curator_read_port.dart';
import 'curator/gated_dashboard_curator.dart';
import 'debug/app_debug_log.dart';
import 'display/dashboard_data_bound_shell.dart';
import 'display/dashboard_viewport_scope.dart';
import 'display/display_viewport.dart';
import 'display/screen_rotator.dart';
import 'data/data_write_context.dart';
import 'data/engine/data_collection_engine.dart';
import 'data/providers/google_calendar/google_calendar_data_provider.dart';
import 'data/providers/bing_image_of_day/bing_image_of_day_data_provider.dart';
import 'data/providers/flickr_media/flickr_media_data_provider.dart';
import 'data/providers/joke/joke_data_provider.dart';
import 'data/providers/onedrive_media/onedrive_media_data_provider.dart';
import 'data/providers/outlook_calendar/outlook_calendar_data_provider.dart';
import 'data/providers/pexels/pexels_data_provider.dart';
import 'data/providers/rss_news/rss_news_data_provider.dart';
import 'data/providers/stock_quote/stock_quote_data_provider.dart';
import 'data/providers/trivia/trivia_data_provider.dart';
import 'data/providers/nws_weather_gov/nws_weather_gov_alerts_data_provider.dart';
import 'data/providers/opentdb_trivia/opentdb_trivia_data_provider.dart';
import 'data/providers/weather/weather_data_provider.dart';
import 'data/stub_data_provider.dart';
import 'marquee_cycle_gate.dart';
import 'persistence/database.dart';
import 'persistence/tables.dart';
import 'secrets/flutter_secure_secret_store.dart';
import 'data/seed/initial_seed.dart';
import 'sleeper.dart';
import 'theme/display_theme.dart';
import 'theme/tv_overscan.dart';
import 'ticker/memory_ticker_curated_repository.dart';
import 'ticker/ticker_marquee.dart';
import 'window/linux_window_chrome_controller.dart';
import 'window/noop_window_chrome_controller.dart';
import 'window/startup_window_policy.dart';
import 'window/window_chrome_controller.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
    installGlobalFatalErrorHandlers();
    unawaited(_waddleBootstrap());
  }, onZoneFatalError);
}

Future<void> _waddleBootstrap() async {
  try {
    AppDebugLog.startup('Waddle View bootstrap');
    await loadDevDotenvFromFilesystem();
    final support = await getApplicationSupportDirectory();
    AppDebugLog.startup('app support directory: ${support.path}');
    final keyFile = File(p.join(support.path, 'waddle_api.key'));
    var createdDeploymentKey = false;
    if (!await keyFile.exists()) {
      final rnd = Random.secure();
      final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await keyFile.writeAsString('$hex\n', flush: true);
      createdDeploymentKey = true;
    }
    final mediaDir = Directory(p.join(support.path, 'media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    final db = AppDatabase(createQueryExecutor());
    await ensureInitialSeed(db);
    if (createdDeploymentKey) {
      await db.into(db.configKeyValues).insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(
              key: kAdminBootstrapDoneKvKey,
              value: '0',
            ),
          );
    } else {
      final existing = await (db.select(db.configKeyValues)
            ..where((t) => t.key.equals(kAdminBootstrapDoneKvKey)))
          .getSingleOrNull();
      if (existing == null) {
        await db.into(db.configKeyValues).insertOnConflictUpdate(
              ConfigKeyValuesCompanion.insert(
                key: kAdminBootstrapDoneKvKey,
                value: '1',
              ),
            );
      }
    }
    AppDebugLog.startup('SQLite ready (seed applied if first run)');

    final secrets = FlutterSecureSecretStore();
    await applyJokesTokenFromDevDotenv(secrets);
    await applyGoogleTokensFromDevDotenv(secrets);
    await applyMicrosoftGraphTokensFromDevDotenv(secrets);
    final resolver = ProviderConfigResolver(db, secrets);
    final blobs = FileSystemBlobStore(mediaDir);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: blobs,
      secrets: secrets,
      resolve: resolver.resolve,
    );
    const clock = SystemClock();
    final tickerCurated = MemoryTickerCuratedRepository();
    final marqueeCycleGate = MarqueeCycleGate();
    final dashboardCuratorInner = DefaultDashboardCurator(
      read: DriftCuratorReadPort(db),
      tickerStore: tickerCurated,
      clock: clock,
    );
    await dashboardCuratorInner.refresh();
    marqueeCycleGate.onCurationWrittenExpectMarqueeLoop();
    AppDebugLog.startup('initial curator refresh done');
    final dashboardCurator = GatedDashboardCurator(
      inner: dashboardCuratorInner,
      marqueeGate: marqueeCycleGate,
    );
    final engine = DataCollectionEngine(
      providers: [
        StubDataProvider(),
        RssNewsDataProvider(),
        JokeDataProvider(),
        TriviaDataProvider(),
        OpenTdbTriviaDataProvider(),
        WeatherDataProvider(),
        NwsWeatherGovAlertsDataProvider(),
        PexelsDataProvider(),
        GoogleCalendarDataProvider(),
        OutlookCalendarDataProvider(),
        OneDriveMediaDataProvider(),
        FlickrMediaDataProvider(),
        BingImageOfDayDataProvider(),
        StockQuoteDataProvider(),
      ],
      context: ctx,
      sleeper: SystemSleeper(),
      idleBetweenCycles: kDebugMode
          ? const Duration(seconds: 5)
          : const Duration(seconds: 30),
      onCycleComplete: dashboardCurator.refresh,
    );
    unawaited(engine.start());

    final alerts = DriftAlertRepository(db);
    final keys = FileDeploymentApiKeySource(keyFile);
    final httpConfig = await resolveHttpBindConfig();
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      keys: keys,
      ticker: tickerCurated,
      secrets: secrets,
      onConfigChanged: dashboardCurator.refresh,
      keyFile: keyFile,
      setupScreenId: 'admin_setup',
    );
    final server = await LocalRestServer.bind(
      handler: handler,
      address: httpConfig.address,
      port: httpConfig.port,
      displayHost: httpConfig.displayHost,
    );
    AppDebugLog.startup('REST listening at ${server.baseUrl}');

    final windowPolicy = StartupWindowPolicy(
      isLinux: !kIsWeb && Platform.isLinux,
      isDebug: kDebugMode,
      allowFullscreen: true,
    );
    final WindowChromeController chrome =
        !kIsWeb && Platform.isLinux
            ? LinuxWindowChromeController()
            : NoOpWindowChromeController();
    await chrome.initialize();
    await chrome.applyStartupPolicy(windowPolicy);

    AppDebugLog.startup('entering runApp');
    runApp(
      WaddleRoot(
        db: db,
        blobs: blobs,
        alerts: alerts,
        server: server,
        setupPasswordFile: keyFile,
        engine: engine,
        tickerCurated: tickerCurated,
        marqueeCycleGate: marqueeCycleGate,
      ),
    );
  } catch (e, st) {
    onZoneFatalError(e, st);
  }
}

class WaddleRoot extends StatelessWidget {
  const WaddleRoot({
    super.key,
    required this.db,
    required this.blobs,
    required this.alerts,
    required this.server,
    required this.setupPasswordFile,
    required this.engine,
    required this.tickerCurated,
    required this.marqueeCycleGate,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final DriftAlertRepository alerts;
  final LocalRestServer server;
  final File setupPasswordFile;
  final DataCollectionEngine engine;
  final MemoryTickerCuratedRepository tickerCurated;
  final MarqueeCycleGate marqueeCycleGate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConfigKeyValue>>(
      stream: db.select(db.configKeyValues).watch(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <ConfigKeyValue>[];
        final kv = {for (final r in rows) r.key: r.value};
        final theme = DisplayTheme.buildFromKvValue(kv[kDisplayThemeIdKvKey]);
        return MaterialApp(
          title: 'Waddle View',
          theme: theme,
          builder: (context, child) =>
              child ?? const SizedBox.shrink(),
          home: WaddleHome(
            db: db,
            blobs: blobs,
            alerts: alerts,
            server: server,
            setupPasswordFile: setupPasswordFile,
            engine: engine,
            tickerCurated: tickerCurated,
            marqueeCycleGate: marqueeCycleGate,
            dashboardKv: kv,
          ),
        );
      },
    );
  }
}

class WaddleHome extends StatefulWidget {
  const WaddleHome({
    super.key,
    required this.db,
    required this.blobs,
    required this.alerts,
    required this.server,
    required this.setupPasswordFile,
    required this.engine,
    required this.tickerCurated,
    required this.marqueeCycleGate,
    required this.dashboardKv,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final AlertRepository alerts;
  final LocalRestServer server;
  final File setupPasswordFile;
  final DataCollectionEngine engine;
  final MemoryTickerCuratedRepository tickerCurated;
  final MarqueeCycleGate marqueeCycleGate;
  final Map<String, String> dashboardKv;

  @override
  State<WaddleHome> createState() => _WaddleHomeState();
}

class _WaddleHomeState extends State<WaddleHome> {
  final TickerMarqueeNavigationController _tickerNavigationController =
      TickerMarqueeNavigationController();

  @override
  void dispose() {
    AppDebugLog.startup('dispose: stopping engine, closing REST and DB');
    widget.tickerCurated.dispose();
    widget.marqueeCycleGate.dispose();
    widget.engine.stop();
    _tickerNavigationController.dispose();
    unawaited(widget.server.close());
    unawaited(widget.db.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final baseScaler = mq.textScaler;
    final screenKv = linearFactorForDisplayTextScaleKvValue(
      widget.dashboardKv[kDisplayTextScaleScreenKvKey],
    );
    final tickerKv = linearFactorForDisplayTextScaleKvValue(
      widget.dashboardKv[kDisplayTextScaleTickerKvKey],
    );
    final screenScaler = DisplayTextScaler(
      baseScaler,
      screenKv * DisplayTheme.textScale,
    );
    final tickerScaler = DisplayTextScaler(
      baseScaler,
      tickerKv * DisplayTheme.textScale,
    );
    return Scaffold(
      body: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _tickerNavigationController.navigateBackward();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _tickerNavigationController.navigateForward();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MediaQuery(
          data: mq.copyWith(textScaler: screenScaler),
          child: AlertOverlayHost(
            repository: widget.alerts,
            clock: const SystemClock(),
            severityIconsKv: widget.dashboardKv[kAlertSeverityIconsKvKey],
            child: DashboardDataBoundShell(
              overscan: const TvOverscanInsets(),
              viewportConfig: const DisplayViewportConfig(),
              body: ScreenRotator(
                db: widget.db,
                blobs: widget.blobs,
                localRestBaseUrl: widget.server.baseUrl,
                adminBaseUrl: widget.server.displayBaseUrl,
                setupPasswordFile: widget.setupPasswordFile,
              ),
              ticker: MediaQuery(
                data: mq.copyWith(textScaler: tickerScaler),
                child: _KvAwareMarquee(
                  db: widget.db,
                  repository: widget.tickerCurated,
                  marqueeCycleGate: widget.marqueeCycleGate,
                  navigationController: _tickerNavigationController,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [TickerMarquee] scroll speed from `curator.ticker.newsPixelsPerSecond` in [ConfigKeyValue].
class _KvAwareMarquee extends StatelessWidget {
  const _KvAwareMarquee({
    required this.db,
    required this.repository,
    required this.marqueeCycleGate,
    required this.navigationController,
  });

  final AppDatabase db;
  final MemoryTickerCuratedRepository repository;
  final MarqueeCycleGate marqueeCycleGate;
  final TickerMarqueeNavigationController navigationController;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConfigKeyValue>>(
      stream: db.select(db.configKeyValues).watch(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <ConfigKeyValue>[];
        final m = {for (final r in rows) r.key: r.value};
        final px =
            double.tryParse(
              m['curator.ticker.newsPixelsPerSecond']?.trim() ?? '',
            ) ??
            80;
        return Builder(
          builder: (context) {
            final s = DashboardViewportScope.scaleOf(context);
            return TickerMarquee(
              repository: repository,
              pixelsPerSecond: px * s,
              cycleGate: marqueeCycleGate,
              navigationController: navigationController,
            );
          },
        );
      },
    );
  }
}

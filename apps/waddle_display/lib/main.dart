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
import 'api/display_instance_id_source.dart';
import 'api/local_rest_server.dart';
import 'package:waddle_shared/auth/adoption_repository.dart';
import 'package:waddle_shared/auth/cors_origin_repository.dart';
import 'api/network_addressing.dart';
import 'bootstrap/app_fatal_error_recovery.dart';
import 'clock.dart';
import 'config/dev_dotenv_secrets.dart';
import 'config/display_timezone.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/blob/filesystem_blob_store.dart';
import 'package:waddle_shared/collect/data_collection_engine.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/collect/stub_data_provider.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/curation/reject_rescan.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/flutter_secure_secret_store.dart';
import 'package:waddle_shared/seed/initial_seed.dart';
import 'package:waddle_data_providers/waddle_data_providers.dart';
import 'curator/default_dashboard_curator.dart';
import 'curator/drift_curator_read_port.dart';
import 'curator/gated_dashboard_curator.dart';
import 'debug/app_debug_log.dart';
import 'debug/debug_console_disk_logger.dart';
import 'debug/display_collect_diagnostics.dart';
import 'debug/operator_telemetry_hub.dart';
import 'display/display_navigation_bus.dart';
import 'display/dashboard_data_bound_shell.dart';
import 'display/dashboard_viewport_scope.dart';
import 'display/display_viewport.dart';
import 'display/overlay/celebration_overlay_host.dart';
import 'display/screen_rotator.dart';
import 'display/viewer_invite_runtime.dart';
import 'marquee_cycle_gate.dart';
import 'persistence/flutter_query_executor.dart';
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
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (kDebugMode) {
        await DebugConsoleDiskLogger.install();
      }
      ensureDisplayTimeZonesInitialized();
      MediaKit.ensureInitialized();
      installGlobalFatalErrorHandlers();
      await _waddleBootstrap();
    },
    onZoneFatalError,
    zoneSpecification:
        kDebugMode ? DebugConsoleDiskLogger.debugZoneSpecification() : null,
  );
}

Future<void> _waddleBootstrap() async {
  try {
    AppDebugLog.startup('Waddle View bootstrap');
    await loadDevDotenvFromFilesystem();
    final support = await getApplicationSupportDirectory();
    AppDebugLog.startup('app support directory: ${support.path}');
    final legacyKeyFile = File(p.join(support.path, 'waddle_api.key'));
    final instanceIdFile = File(p.join(support.path, 'waddle_instance.id'));
    if (!await instanceIdFile.exists()) {
      if (await legacyKeyFile.exists()) {
        await legacyKeyFile.rename(instanceIdFile.path);
      } else {
        final rnd = Random.secure();
        final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
        final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        await instanceIdFile.writeAsString('$hex\n', flush: true);
      }
    }
    final mediaDir = Directory(p.join(support.path, 'media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    final db = AppDatabase(createQueryExecutor());
    await ensureInitialSeed(db);
    // Rescan content against the current reject list on startup so any rows
    // added by a previous-running provider before the operator extended the
    // list are caught before the curator picks them.
    unawaited(_rescanRejectListOnStartup(db));
    final instanceId = await FileDisplayInstanceIdSource(instanceIdFile).load();
    final adoption = instanceId != null && instanceId.isNotEmpty
        ? AdoptionRepository(db, instanceId: instanceId)
        : null;
    final corsOrigins = CorsOriginRepository(db);
    AppDebugLog.startup('SQLite ready (seed applied if first run)');

    final secrets = FlutterSecureSecretStore();
    final envMap = mergeBootstrapEnv();
    await corsOrigins.seedEnvOrigins(
      parseCorsAllowedOrigins(envMap['WADDLE_HTTP_CORS_ORIGINS']),
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    final resolver = ProviderConfigResolver(db, envMap);
    final blobs = FileSystemBlobStore(mediaDir);
    final telemetryHub = OperatorTelemetryHub();
    final collectDiag = defaultDisplayCollectDiagnostics(telemetryHub: telemetryHub);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: blobs,
      secrets: secrets,
      resolve: resolver.resolve,
      env: envMap,
      diagnostics: collectDiag,
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
        const StubDataProvider(),
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
      diagnostics: collectDiag,
    );
    unawaited(engine.start());

    final alerts = DriftAlertRepository(db);
    final httpConfig = await resolveHttpBindConfig(environment: envMap);
    final navigationBus = DisplayNavigationBus();
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      adoption: adoption,
      corsOrigins: corsOrigins,
      ticker: tickerCurated,
      blobs: blobs,
      onConfigChanged: dashboardCurator.refresh,
      env: envMap,
      telemetryHub: telemetryHub,
      navigationBus: navigationBus,
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
        instanceIdFile: instanceIdFile,
        engine: engine,
        tickerCurated: tickerCurated,
        marqueeCycleGate: marqueeCycleGate,
        telemetryHub: telemetryHub,
        navigationBus: navigationBus,
        viewerInviteRuntime: ViewerInviteRuntime(
          controllerPublicUrl: (envMap['WADDLE_CONTROLLER_PUBLIC_URL'] ?? '').trim(),
          viewerRegistrationSecret:
              (envMap['WADDLE_VIEWER_REGISTRATION_SECRET'] ?? '').trim(),
        ),
      ),
    );
  } catch (e, st) {
    onZoneFatalError(e, st);
  }
}

class WaddleRoot extends StatefulWidget {
  const WaddleRoot({
    super.key,
    required this.db,
    required this.blobs,
    required this.alerts,
    required this.server,
    required this.instanceIdFile,
    required this.engine,
    required this.tickerCurated,
    required this.marqueeCycleGate,
    required this.telemetryHub,
    required this.navigationBus,
    required this.viewerInviteRuntime,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final DriftAlertRepository alerts;
  final LocalRestServer server;
  final File instanceIdFile;
  final DataCollectionEngine engine;
  final MemoryTickerCuratedRepository tickerCurated;
  final MarqueeCycleGate marqueeCycleGate;
  final OperatorTelemetryHub telemetryHub;
  final DisplayNavigationBus navigationBus;
  final ViewerInviteRuntime viewerInviteRuntime;

  @override
  State<WaddleRoot> createState() => _WaddleRootState();
}

class _WaddleRootState extends State<WaddleRoot> {
  /// One Drift stream for the lifetime of the app. A fresh `.watch()` on every
  /// [build] (or on every parent rebuild) makes [StreamBuilder] tear down and
  /// resubscribe repeatedly and can leak native resources (Linux: EMFILE /
  /// GLib GWakeup pipe exhaustion on long-running kiosks).
  late final Stream<List<ConfigKeyValue>> _configKvStream =
      widget.db.select(widget.db.configKeyValues).watch();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConfigKeyValue>>(
      stream: _configKvStream,
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
            db: widget.db,
            blobs: widget.blobs,
            alerts: widget.alerts,
            server: widget.server,
            instanceIdFile: widget.instanceIdFile,
            engine: widget.engine,
            tickerCurated: widget.tickerCurated,
            marqueeCycleGate: widget.marqueeCycleGate,
            telemetryHub: widget.telemetryHub,
            navigationBus: widget.navigationBus,
            dashboardKv: kv,
            viewerInviteRuntime: widget.viewerInviteRuntime,
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
    required this.instanceIdFile,
    required this.engine,
    required this.tickerCurated,
    required this.marqueeCycleGate,
    required this.telemetryHub,
    required this.navigationBus,
    required this.dashboardKv,
    required this.viewerInviteRuntime,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final AlertRepository alerts;
  final LocalRestServer server;
  final File instanceIdFile;
  final DataCollectionEngine engine;
  final MemoryTickerCuratedRepository tickerCurated;
  final MarqueeCycleGate marqueeCycleGate;
  final OperatorTelemetryHub telemetryHub;
  final DisplayNavigationBus navigationBus;
  final Map<String, String> dashboardKv;
  final ViewerInviteRuntime viewerInviteRuntime;

  @override
  State<WaddleHome> createState() => _WaddleHomeState();
}

class _WaddleHomeState extends State<WaddleHome> {
  final TickerMarqueeNavigationController _tickerNavigationController =
      TickerMarqueeNavigationController();

  @override
  void dispose() {
    if (kDebugMode) {
      unawaited(DebugConsoleDiskLogger.close());
    }
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
              child: CelebrationOverlayHost(
                db: widget.db,
                clock: const SystemClock(),
                dashboardKv: widget.dashboardKv,
                child: DashboardDataBoundShell(
                  overscan: const TvOverscanInsets(),
                  viewportConfig: const DisplayViewportConfig(),
                  body: ScreenRotator(
                    db: widget.db,
                    blobs: widget.blobs,
                    localRestBaseUrl: widget.server.baseUrl,
                    adminBaseUrl: widget.server.displayBaseUrl,
                    instanceIdFile: widget.instanceIdFile,
                    viewerInviteRuntime: widget.viewerInviteRuntime,
                    telemetryHub: widget.telemetryHub,
                    navigationBus: widget.navigationBus,
                  ),
                  ticker: MediaQuery(
                    data: mq.copyWith(textScaler: tickerScaler),
                    child: Builder(
                      builder: (context) {
                        final s = DashboardViewportScope.scaleOf(context);
                        final px =
                            double.tryParse(
                              widget.dashboardKv['curator.ticker.newsPixelsPerSecond']
                                      ?.trim() ??
                                  '',
                            ) ??
                            80;
                        return TickerMarquee(
                          repository: widget.tickerCurated,
                          pixelsPerSecond: px * s,
                          cycleGate: widget.marqueeCycleGate,
                          navigationController: _tickerNavigationController,
                          telemetryHub: widget.telemetryHub,
                          navigationBus: widget.navigationBus,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ),
      ),
    );
  }
}

Future<void> _rescanRejectListOnStartup(AppDatabase db) async {
  try {
    final result = await rescanContentForBlockTerms(db);
    if (result.totalMarked > 0) {
      AppDebugLog.startup(
        'reject rescan: marked ${result.totalMarked} row(s) '
        '(rss=${result.rssArticlesMarked}, '
        'jokes=${result.jokesMarked}, '
        'trivia=${result.triviaQuestionsMarked}, '
        'photos=${result.photosMarked}, '
        'videos=${result.videosMarked})',
      );
    }
  } catch (e, st) {
    AppDebugLog.startup('reject rescan failed: $e\n$st');
  }
}


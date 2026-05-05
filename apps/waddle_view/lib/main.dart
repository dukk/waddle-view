import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'alerts/alert_repository.dart';
import 'alerts/alert_overlay_host.dart';
import 'alerts/drift_alert_repository.dart';
import 'api/deployment_api_key_source.dart';
import 'api/local_rest_server.dart';
import 'api/network_addressing.dart';
import 'blob/blob_store.dart';
import 'blob/filesystem_blob_store.dart';
import 'clock.dart';
import 'config/dev_dotenv_secrets.dart';
import 'config/provider_config_resolver.dart';
import 'curator/default_dashboard_curator.dart';
import 'curator/drift_curator_read_port.dart';
import 'curator/gated_dashboard_curator.dart';
import 'debug/app_debug_log.dart';
import 'dashboard/dashboard_data_bound_shell.dart';
import 'dashboard/screen_rotator.dart';
import 'data/data_write_context.dart';
import 'data/engine/data_collection_engine.dart';
import 'data/providers/joke_data_provider.dart';
import 'data/providers/rss_news_data_provider.dart';
import 'data/providers/trivia_data_provider.dart';
import 'data/providers/weather_data_provider.dart';
import 'data/providers/category_icon_service.dart';
import 'data/stub_data_provider.dart';
import 'marquee_cycle_gate.dart';
import 'persistence/database.dart';
import 'secrets/flutter_secure_secret_store.dart';
import 'seed/initial_seed.dart';
import 'sleeper.dart';
import 'theme/display_theme.dart';
import 'theme/tv_overscan.dart';
import 'ticker/memory_ticker_curated_repository.dart';
import 'ticker/ticker_marquee.dart';
import 'window/linux_window_chrome_controller.dart';
import 'window/noop_window_chrome_controller.dart';
import 'window/startup_window_policy.dart';
import 'window/window_chrome_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    await db.into(db.dashboardKv).insertOnConflictUpdate(
          DashboardKvCompanion.insert(
            key: kAdminBootstrapDoneKvKey,
            value: '0',
          ),
        );
  } else {
    final existing = await (db.select(db.dashboardKv)
          ..where((t) => t.key.equals(kAdminBootstrapDoneKvKey)))
        .getSingleOrNull();
    if (existing == null) {
      await db.into(db.dashboardKv).insertOnConflictUpdate(
            DashboardKvCompanion.insert(
              key: kAdminBootstrapDoneKvKey,
              value: '1',
            ),
          );
    }
  }
  AppDebugLog.startup('SQLite ready (seed applied if first run)');

  final secrets = FlutterSecureSecretStore();
  await applyJokesTokenFromDevDotenv(secrets);
  final resolver = ProviderConfigResolver(db, secrets);
  final blobs = FileSystemBlobStore(mediaDir);
  final ctx = DataWriteContextImpl(
    db: db,
    blobs: blobs,
    secrets: secrets,
    resolve: resolver.resolve,
  );
  const clock = SystemClock();
  final iconPreloadClient = http.Client();
  await preloadSeedCategoryIcons(
    ctx: ctx,
    httpClient: iconPreloadClient,
    perTypeLimit: 3,
  );
  iconPreloadClient.close();
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
      WeatherDataProvider(),
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
    return MaterialApp(
      title: 'Waddle View',
      theme: DisplayTheme.build(),
      builder: (context, child) {
        final data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(
            textScaler: DisplayTheme.wrapTextScaler(data.textScaler),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: WaddleHome(
        db: db,
        blobs: blobs,
        alerts: alerts,
        server: server,
        setupPasswordFile: setupPasswordFile,
        engine: engine,
        tickerCurated: tickerCurated,
        marqueeCycleGate: marqueeCycleGate,
      ),
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
  });

  final AppDatabase db;
  final BlobStore blobs;
  final AlertRepository alerts;
  final LocalRestServer server;
  final File setupPasswordFile;
  final DataCollectionEngine engine;
  final MemoryTickerCuratedRepository tickerCurated;
  final MarqueeCycleGate marqueeCycleGate;

  @override
  State<WaddleHome> createState() => _WaddleHomeState();
}

class _WaddleHomeState extends State<WaddleHome> {
  @override
  void dispose() {
    AppDebugLog.startup('dispose: stopping engine, closing REST and DB');
    widget.tickerCurated.dispose();
    widget.marqueeCycleGate.dispose();
    widget.engine.stop();
    unawaited(widget.server.close());
    unawaited(widget.db.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AlertOverlayHost(
        repository: widget.alerts,
        clock: const SystemClock(),
        child: DashboardDataBoundShell(
          overscan: const TvOverscanInsets(),
          body: ScreenRotator(
            db: widget.db,
            blobs: widget.blobs,
            localRestBaseUrl: widget.server.baseUrl,
            adminBaseUrl: widget.server.displayBaseUrl,
            setupPasswordFile: widget.setupPasswordFile,
          ),
          ticker: _KvAwareMarquee(
            db: widget.db,
            repository: widget.tickerCurated,
            marqueeCycleGate: widget.marqueeCycleGate,
          ),
        ),
      ),
    );
  }
}

/// [TickerMarquee] scroll speed from `curator.ticker.newsPixelsPerSecond` in [DashboardKvData].
class _KvAwareMarquee extends StatelessWidget {
  const _KvAwareMarquee({
    required this.db,
    required this.repository,
    required this.marqueeCycleGate,
  });

  final AppDatabase db;
  final MemoryTickerCuratedRepository repository;
  final MarqueeCycleGate marqueeCycleGate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DashboardKvData>>(
      stream: db.select(db.dashboardKv).watch(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <DashboardKvData>[];
        final m = {for (final r in rows) r.key: r.value};
        final px =
            double.tryParse(
              m['curator.ticker.newsPixelsPerSecond']?.trim() ?? '',
            ) ??
            80;
        return TickerMarquee(
          repository: repository,
          pixelsPerSecond: px,
          cycleGate: marqueeCycleGate,
        );
      },
    );
  }
}

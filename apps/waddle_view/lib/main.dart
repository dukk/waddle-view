import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'alerts/alert_repository.dart';
import 'alerts/alert_overlay_host.dart';
import 'alerts/drift_alert_repository.dart';
import 'api/deployment_api_key_source.dart';
import 'api/local_rest_server.dart';
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
  if (!await keyFile.exists()) {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await keyFile.writeAsString('$hex\n', flush: true);
  }
  final mediaDir = Directory(p.join(support.path, 'media'));
  if (!await mediaDir.exists()) {
    await mediaDir.create(recursive: true);
  }

  final db = AppDatabase(createQueryExecutor());
  await ensureInitialSeed(db);
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
  final clock = SystemClock();
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
  final handler = buildRootHandler(
    db: db,
    alerts: alerts,
    keys: keys,
    ticker: tickerCurated,
  );
  final server = await LocalRestServer.bind(
    handler: handler,
    address: InternetAddress.loopbackIPv4,
    port: 8787,
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
      alerts: alerts,
      server: server,
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
    required this.alerts,
    required this.server,
    required this.engine,
    required this.tickerCurated,
    required this.marqueeCycleGate,
  });

  final AppDatabase db;
  final DriftAlertRepository alerts;
  final LocalRestServer server;
  final DataCollectionEngine engine;
  final MemoryTickerCuratedRepository tickerCurated;
  final MarqueeCycleGate marqueeCycleGate;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waddle View',
      theme: DisplayTheme.build(),
      home: WaddleHome(
        db: db,
        alerts: alerts,
        server: server,
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
    required this.alerts,
    required this.server,
    required this.engine,
    required this.tickerCurated,
    required this.marqueeCycleGate,
  });

  final AppDatabase db;
  final AlertRepository alerts;
  final LocalRestServer server;
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
        clock: SystemClock(),
        child: DashboardDataBoundShell(
          overscan: const TvOverscanInsets(),
          body: Stack(
            fit: StackFit.expand,
            children: [
              ScreenRotator(db: widget.db),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'API ${widget.server.baseUrl}\nUse header X-Api-Key from waddle_api.key',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white54,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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

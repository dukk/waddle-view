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
import 'config/provider_config_resolver.dart';
import 'dashboard/dashboard_shell.dart';
import 'dashboard/dashboard_slot_descriptor.dart';
import 'dashboard/drift_dashboard_data_access.dart';
import 'data/data_write_context.dart';
import 'data/engine/data_collection_engine.dart';
import 'data/stub_data_provider.dart';
import 'persistence/database.dart';
import 'secrets/flutter_secure_secret_store.dart';
import 'seed/initial_seed.dart';
import 'sleeper.dart';
import 'theme/tv_overscan.dart';
import 'theme/tv_theme.dart';
import 'ticker/drift_ticker_schedule_repository.dart';
import 'ticker/ticker_condition_evaluator.dart';
import 'ticker/ticker_rotation_controller.dart';
import 'ticker/ticker_strip.dart';
import 'window/linux_window_chrome_controller.dart';
import 'window/noop_window_chrome_controller.dart';
import 'window/startup_window_policy.dart';
import 'window/window_chrome_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final support = await getApplicationSupportDirectory();
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

  final secrets = FlutterSecureSecretStore();
  final resolver = ProviderConfigResolver(db, secrets);
  final blobs = FileSystemBlobStore(mediaDir);
  final ctx = DataWriteContextImpl(
    db: db,
    blobs: blobs,
    secrets: secrets,
    resolve: resolver.resolve,
  );
  final engine = DataCollectionEngine(
    providers: [StubDataProvider()],
    context: ctx,
    sleeper: SystemSleeper(),
    idleBetweenCycles: kDebugMode
        ? const Duration(seconds: 5)
        : const Duration(seconds: 30),
  );
  unawaited(engine.start());

  final alerts = DriftAlertRepository(db);
  final keys = FileDeploymentApiKeySource(keyFile);
  final handler = buildRootHandler(db: db, alerts: alerts, keys: keys);
  final server = await LocalRestServer.bind(
    handler: handler,
    address: InternetAddress.loopbackIPv4,
    port: 8787,
  );

  final data = DriftDashboardDataAccess(db);
  final tickerRepo = DriftTickerScheduleRepository(db);
  final tickerController = TickerRotationController(
    repository: tickerRepo,
    evaluator: const TickerConditionEvaluator(),
    clock: SystemClock(),
    sleeper: SystemSleeper(),
  );
  unawaited(tickerController.start());

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

  runApp(
    WaddleRoot(
      db: db,
      data: data,
      alerts: alerts,
      server: server,
      engine: engine,
      tickerController: tickerController,
    ),
  );
}

class WaddleRoot extends StatelessWidget {
  const WaddleRoot({
    super.key,
    required this.db,
    required this.data,
    required this.alerts,
    required this.server,
    required this.engine,
    required this.tickerController,
  });

  final AppDatabase db;
  final DriftDashboardDataAccess data;
  final DriftAlertRepository alerts;
  final LocalRestServer server;
  final DataCollectionEngine engine;
  final TickerRotationController tickerController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waddle View',
      theme: TvTheme.build(),
      home: WaddleHome(
        db: db,
        data: data,
        alerts: alerts,
        server: server,
        engine: engine,
        tickerController: tickerController,
      ),
    );
  }
}

class WaddleHome extends StatefulWidget {
  const WaddleHome({
    super.key,
    required this.db,
    required this.data,
    required this.alerts,
    required this.server,
    required this.engine,
    required this.tickerController,
  });

  final AppDatabase db;
  final DriftDashboardDataAccess data;
  final AlertRepository alerts;
  final LocalRestServer server;
  final DataCollectionEngine engine;
  final TickerRotationController tickerController;

  @override
  State<WaddleHome> createState() => _WaddleHomeState();
}

class _WaddleHomeState extends State<WaddleHome> {
  @override
  void dispose() {
    widget.engine.stop();
    widget.tickerController.dispose();
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
        child: DashboardShell(
          overscan: const TvOverscanInsets(),
          slots: const [
            DashboardSlotDescriptor(id: 'main', label: 'Main'),
          ],
          header: StreamBuilder<String?>(
            stream: widget.data.watchHeaderTitle(),
            builder: (context, snap) {
              return Text(
                snap.data ?? 'Waddle View',
                style: Theme.of(context).textTheme.headlineMedium,
              );
            },
          ),
          body: Center(
            child: Text(
              'API ${widget.server.baseUrl}\nUse header X-Api-Key from waddle_api.key',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          ticker: TickerStrip(controller: widget.tickerController),
        ),
      ),
    );
  }
}

import '../clock.dart';
import 'package:waddle_shared/persistence/database.dart';

abstract class AlertRepository {
  Future<int> insertAlert({
    required String title,
    required String body,
    String? qrPayload,
    String severity,
    int priority,
    int? expiresAtMs,
  });

  Future<void> dismiss(int id);

  Stream<DashboardAlert?> watchActive(Clock clock);
}

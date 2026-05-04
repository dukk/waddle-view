/// Read models for dashboard tiles — backed by Drift streams in production.
abstract class DashboardDataAccess {
  Stream<String?> watchHeaderTitle();

  Stream<String?> watchSlotSubtitle(String slotId);
}

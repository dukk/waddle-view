/// Selects and shapes persisted facts into presentation stores (ticker, etc.).
abstract class DashboardCurator {
  Future<void> refresh();
}

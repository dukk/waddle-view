/// Mutable allow-lists updated when the active curator selection changes.
class CuratorMembershipFilter {
  /// Null until the first [ActiveCuratorService] resolve (then a possibly empty set).
  Set<String>? tickerTapeIds;
  Set<String> overlayIds = {};
}

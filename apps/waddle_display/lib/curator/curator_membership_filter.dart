/// Mutable allow-lists updated when the active curator selection changes.
class CuratorMembershipFilter {
  /// When false, ticker curation is skipped and the display shell hides the strip.
  bool tickerCurationEnabled = true;

  /// Null until the first [ActiveCuratorService] resolve (then a possibly empty set).
  Set<String>? tickerTapeIds;
  Set<String> overlayIds = {};
}

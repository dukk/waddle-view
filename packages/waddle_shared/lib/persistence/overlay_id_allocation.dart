import 'catalog_id_allocation.dart';

export 'catalog_id_allocation.dart' show allocateOverlayIdFromName;

/// Slugify an operator-facing overlay name into a stable row id fragment.
String slugifyOverlayName(String name) =>
    slugifyCatalogName(name, digitPrefix: 'o_');

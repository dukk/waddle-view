import 'curator_runtime_state.dart';

class CuratorStatePredicateCatalogEntry {
  const CuratorStatePredicateCatalogEntry({
    required this.id,
    required this.label,
    required this.description,
    required this.implemented,
  });

  final String id;
  final String label;
  final String description;
  final bool implemented;
}

const String kCuratorPredicateDisplayNotAdopted = 'display.not_adopted';
const String kCuratorPredicateDisplayAdopted = 'display.adopted';
const String kCuratorPredicateInternetDown = 'connectivity.internet_down';
const String kCuratorPredicateServerDown = 'connectivity.server_down';
const String kCuratorPredicateMotionDetected = 'room.motion_detected';
const String kCuratorPredicateMotionAbsent = 'room.motion_absent';
const String kCuratorPredicateBeaconPresent = 'beacon.present';

const List<CuratorStatePredicateCatalogEntry> kCuratorStatePredicateCatalog = [
  CuratorStatePredicateCatalogEntry(
    id: kCuratorPredicateDisplayNotAdopted,
    label: 'Display not adopted',
    description: 'No API clients in api_clients (setup / pairing mode).',
    implemented: true,
  ),
  CuratorStatePredicateCatalogEntry(
    id: kCuratorPredicateDisplayAdopted,
    label: 'Display adopted',
    description: 'At least one row in api_clients.',
    implemented: true,
  ),
  CuratorStatePredicateCatalogEntry(
    id: kCuratorPredicateInternetDown,
    label: 'Internet unreachable',
    description: 'From runtime_signals (connectivity.internet_reachable).',
    implemented: true,
  ),
  CuratorStatePredicateCatalogEntry(
    id: kCuratorPredicateServerDown,
    label: 'Display server unreachable',
    description: 'From runtime_signals (connectivity.server_reachable).',
    implemented: true,
  ),
  CuratorStatePredicateCatalogEntry(
    id: kCuratorPredicateMotionDetected,
    label: 'Motion detected',
    description: 'From runtime_signals (room.motion_detected).',
    implemented: true,
  ),
  CuratorStatePredicateCatalogEntry(
    id: kCuratorPredicateMotionAbsent,
    label: 'No motion',
    description: 'Inverse of room.motion_detected runtime signal.',
    implemented: true,
  ),
  CuratorStatePredicateCatalogEntry(
    id: kCuratorPredicateBeaconPresent,
    label: 'Beacon detected',
    description: 'From runtime_signals (beacon.present).',
    implemented: true,
  ),
];

bool evaluateCuratorStatePredicate(String predicateId, CuratorRuntimeState state) {
  switch (predicateId) {
    case kCuratorPredicateDisplayNotAdopted:
      return !state.displayAdopted;
    case kCuratorPredicateDisplayAdopted:
      return state.displayAdopted;
    case kCuratorPredicateInternetDown:
      return !state.internetReachable;
    case kCuratorPredicateServerDown:
      return !state.displayServerReachable;
    case kCuratorPredicateMotionDetected:
      return state.motionDetected;
    case kCuratorPredicateMotionAbsent:
      return !state.motionDetected;
    case kCuratorPredicateBeaconPresent:
      return state.beaconDetected;
    default:
      return false;
  }
}

bool isKnownCuratorStatePredicate(String? id) {
  if (id == null || id.trim().isEmpty) {
    return true;
  }
  return kCuratorStatePredicateCatalog.any((e) => e.id == id.trim());
}

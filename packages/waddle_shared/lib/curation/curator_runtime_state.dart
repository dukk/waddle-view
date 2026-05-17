/// Live display inputs for [CuratorStatePredicates] (built by the display app).
class CuratorRuntimeState {
  const CuratorRuntimeState({
    required this.displayAdopted,
    this.internetReachable = true,
    this.displayServerReachable = true,
    this.motionDetected = false,
    this.beaconDetected = false,
  });

  final bool displayAdopted;
  final bool internetReachable;
  final bool displayServerReachable;
  final bool motionDetected;
  final bool beaconDetected;
}

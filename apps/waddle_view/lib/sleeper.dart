/// Injectable sleep for async pacing (engine loop, tests).
abstract class Sleeper {
  Future<void> sleep(Duration d);
}

class SystemSleeper implements Sleeper {
  @override
  Future<void> sleep(Duration d) => Future<void>.delayed(d);
}

class FakeSleeper implements Sleeper {
  final List<Duration> recorded = [];

  @override
  Future<void> sleep(Duration d) async {
    recorded.add(d);
  }
}

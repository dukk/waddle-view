/// Injectable clock for time-dependent logic and tests.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

class FakeClock implements Clock {
  FakeClock(this.fixed);

  DateTime fixed;

  @override
  DateTime now() => fixed;
}

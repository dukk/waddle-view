import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/display_navigation_bus.dart';

void main() {
  test('enqueue ignores invalid direction', () {
    final bus = DisplayNavigationBus();
    bus.enqueueScreenNav(0);
    bus.enqueueTickerNav(2);
    expect(bus.dequeueScreenNav(), isNull);
    expect(bus.dequeueTickerNav(), isNull);
  });

  test('enqueue and dequeue FIFO', () {
    final bus = DisplayNavigationBus();
    bus.enqueueScreenNav(-1);
    bus.enqueueScreenNav(1);
    expect(bus.dequeueScreenNav(), -1);
    expect(bus.dequeueScreenNav(), 1);
    expect(bus.dequeueScreenNav(), isNull);
  });
}

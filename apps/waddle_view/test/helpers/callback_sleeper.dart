import 'package:waddle_view/sleeper.dart';

class CallbackSleeper implements Sleeper {
  CallbackSleeper(this.onSleep);
  final void Function() onSleep;

  @override
  Future<void> sleep(Duration d) async {
    onSleep();
  }
}

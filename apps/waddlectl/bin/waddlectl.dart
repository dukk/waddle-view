import 'dart:io';

import 'package:waddlectl/run_app.dart';

Future<void> main(List<String> args) async {
  exit(await runWaddlectl(args));
}

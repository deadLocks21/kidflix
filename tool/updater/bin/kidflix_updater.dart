import 'dart:io';

import 'package:kidflix_updater/cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await runCli(args);
}

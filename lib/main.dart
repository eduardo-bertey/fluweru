import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pr_app/src/rust/frb_generated.dart';

import 'gui/engine_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await RustLib.init();
  runApp(const PrApp());
}

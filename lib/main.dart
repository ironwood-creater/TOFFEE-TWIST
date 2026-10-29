import 'package:flutter/material.dart';

import 'app.dart';
import 'services/services.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await lockPortrait();
  await Services.init();
  runApp(const ToffeeTwistApp());
}

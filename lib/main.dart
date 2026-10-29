import 'package:flutter/material.dart';

import 'app.dart';
import 'services/services.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await lockPortrait();
  await Services.init();
  runApp(const ToffeeTwistApp());
  // Ask for ad consent (if needed) and connect to Google Play after the
  // first frame, so the game shows up immediately.
  WidgetsBinding.instance.addPostFrameCallback((_) => Services.startStoreAndAds());
}

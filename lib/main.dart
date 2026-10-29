import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/services.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Show the fonts' licenses on the "Open-source licenses" page.
  LicenseRegistry.addLicense(() async* {
    for (final (font, file) in [('Baloo 2', 'Baloo2-OFL.txt'), ('Nunito', 'Nunito-OFL.txt')]) {
      yield LicenseEntryWithLineBreaks([font], await rootBundle.loadString('assets/fonts/$file'));
    }
  });
  await lockPortrait();
  await Services.init();
  runApp(const ToffeeTwistApp());
  // Ask for ad consent (if needed) and connect to Google Play after the
  // first frame, so the game shows up immediately.
  WidgetsBinding.instance.addPostFrameCallback((_) => Services.startStoreAndAds());
}

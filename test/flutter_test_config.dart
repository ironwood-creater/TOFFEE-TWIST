import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the game's real fonts before widget tests, so text has its real size
/// (by default tests draw every letter as a wide square block).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('assets/fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Baloo2', ['Baloo2-SemiBold.ttf', 'Baloo2-Bold.ttf', 'Baloo2-ExtraBold.ttf']);
  await load('Nunito', ['Nunito-Regular.ttf', 'Nunito-SemiBold.ttf', 'Nunito-Bold.ttf', 'Nunito-ExtraBold.ttf']);
  await testMain();
}

// Renders all sweets to a PNG for a quick visual check:
//   flutter test tool/preview/art_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:toffeetwist/game/logic/types.dart';
import 'package:toffeetwist/game/render/sweet_art.dart';

void main() {
  test('render art sheet', () async {
    const cell = 120.0;
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    c.drawRect(const ui.Rect.fromLTWH(0, 0, cell * 8, cell * 5), ui.Paint()..color = const ui.Color(0xFFFFF1D6));
    final specials = [Special.none, Special.stripedH, Special.stripedV, Special.box];
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 6; col++) {
        SweetArt.paintPiece(c, ui.Rect.fromLTWH(col * cell + 6, row * cell + 6, cell - 12, cell - 12),
            color: col, special: specials[row], armed: row == 3 && col == 5);
      }
    }
    SweetArt.paintPiece(c, ui.Rect.fromLTWH(6 * cell + 6, 6, cell - 12, cell - 12), color: -1, special: Special.swirl);
    SweetArt.paintPiece(c, ui.Rect.fromLTWH(6 * cell + 6, cell + 6, cell - 12, cell - 12), color: -1, nut: true);
    SweetArt.paintLogoToffee(c, ui.Rect.fromLTWH(6 * cell, 2 * cell, cell * 2, cell * 2));
    for (var k = 0; k < 3; k++) {
      SweetArt.paintCaramel(c, ui.Rect.fromLTWH(k * cell, 4 * cell, cell, cell), k == 0 ? 1 : 2);
      SweetArt.paintCrate(c, ui.Rect.fromLTWH((3 + k) * cell, 4 * cell, cell, cell), k + 1);
    }
    final img = await rec.endRecording().toImage((cell * 8).toInt(), (cell * 5).toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final out = Platform.environment['ART_OUT'] ?? 'build/art_preview.png';
    File(out)..createSync(recursive: true)..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

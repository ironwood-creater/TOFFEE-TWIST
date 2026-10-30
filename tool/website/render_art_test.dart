// Renders the game's sweets, special pieces and blockers for the website.
//   flutter test tool/website/render_art_test.dart
// Output: website/assets/art/*.png (transparent, 192 x 192)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toffeetwist/game/logic/types.dart';
import 'package:toffeetwist/game/render/sweet_art.dart';
import 'package:toffeetwist/theme.dart';

import '../branding/brand_kit.dart';

void main() {
  test('render website art', () async {
    const px = 192;
    const dir = 'website/assets/art';
    Rect inner(Size s) => Rect.fromLTWH(s.width * 0.04, s.height * 0.04, s.width * 0.92, s.height * 0.92);

    for (final sweet in Sweet.values) {
      await savePng('$dir/${sweet.name}.png', px, px,
          (c, s) => SweetArt.paintPiece(c, inner(s), color: sweet.index));
    }
    await savePng('$dir/striped.png', px, px,
        (c, s) => SweetArt.paintPiece(c, inner(s), color: Sweet.toffee.index, special: Special.stripedH));
    await savePng('$dir/box.png', px, px,
        (c, s) => SweetArt.paintPiece(c, inner(s), color: Sweet.macaron.index, special: Special.box));
    await savePng('$dir/swirl.png', px, px,
        (c, s) => SweetArt.paintPiece(c, inner(s), color: -1, special: Special.swirl));
    await savePng('$dir/nut.png', px, px, (c, s) => SweetArt.paintPiece(c, inner(s), color: -1, nut: true));

    // Blockers sit on a board tile, like in the game.
    void tile(Canvas c, Size s) => c.drawRRect(
          RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(s.width * 0.16)),
          Paint()..color = AppColors.tileLight,
        );
    await savePng('$dir/caramel.png', px, px, (c, s) {
      tile(c, s);
      SweetArt.paintCaramel(c, Offset.zero & s, 2);
      SweetArt.paintPiece(c, inner(s).deflate(s.width * 0.08), color: Sweet.cupcake.index);
    });
    await savePng('$dir/crate.png', px, px, (c, s) {
      tile(c, s);
      SweetArt.paintCrate(c, Offset.zero & s, 3);
    });
  });
}

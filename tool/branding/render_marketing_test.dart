// Renders the logo files and promotional banners.
//   flutter test tool/branding/render_marketing_test.dart
// Needs the raw screenshots in store_assets/raw/ (tool/store/capture_screenshots.js).
// Output: store_assets/logo/*.png and store_assets/banners/*.png
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toffeetwist/game/logic/types.dart';

import 'brand_kit.dart';

const _sweetsAround = <(double, double, double, int, Special)>[
  (0.06, 0.16, 0.20, 1, Special.none),
  (0.17, 0.83, 0.17, 2, Special.stripedH),
  (0.05, 0.56, 0.15, 4, Special.none),
  (0.24, 0.20, 0.13, 3, Special.none),
  (0.93, 0.16, 0.19, 5, Special.none),
  (0.84, 0.85, 0.17, 4, Special.box),
  (0.95, 0.57, 0.15, 2, Special.none),
  (0.76, 0.22, 0.13, -1, Special.swirl),
];

void main() {
  setUpAll(loadFonts);

  test('render logos and banners', () async {
    final shots = <String, dynamic>{};
    for (final name in ['1_home', '2_map', '3_combo', '4_board', '5_blockers', '6_win', '9_swirl_combo']) {
      shots[name] = await loadImage('store_assets/raw/$name.png');
    }

    // ---------------------------------------------------------------- logos
    await savePng('store_assets/logo/logo_vertical_transparent.png', 1800, 1450,
        (c, s) => logoLockup(c, const Offset(900, 780), 1600));
    await savePng('store_assets/logo/logo_horizontal_transparent.png', 2150, 800, (c, s) {
      toffee(c, const Offset(380, 400), 700);
      outlinedText(c, 'Toffee Twist', const Offset(1400, 335), 190);
      pill(c, 'Sweet Match 3', const Offset(1400, 560), 70);
    });
    await savePng('store_assets/logo/logo_on_background.png', 1600, 1600, (c, s) {
      warmBackground(c, s);
      logoLockup(c, const Offset(800, 850), 1400);
    });
    File('branding/icon_full.png').copySync('store_assets/logo/app_icon_1024.png');

    // -------------------------------------------------------------- banners
    Directory('store_assets/banners').createSync(recursive: true);
    File('store_assets/feature_graphic.png').copySync('store_assets/banners/feature_graphic_1024x500.png');

    // Link preview / social share (Facebook, X, WhatsApp...): 1200 x 628.
    await savePng('store_assets/banners/social_share_1200x628.png', 1200, 628, (c, s) {
      warmBackground(c, s);
      scatterSweets(c, s, const [
        (0.05, 0.12, 0.17, 1, Special.none),
        (0.04, 0.86, 0.15, 3, Special.none),
        (0.50, 0.90, 0.12, -1, Special.swirl),
      ]);
      logoLockup(c, const Offset(330, 300), 520);
      outlinedText(c, 'Swap. Match. Twist!', const Offset(330, 560), 46);
      phoneMockup(c, shots['5_blockers'], const Offset(1010, 325), 500, angle: 0.09);
      phoneMockup(c, shots['3_combo'], const Offset(785, 318), 520, angle: -0.07);
    });

    // Square social post: 1080 x 1080.
    await savePng('store_assets/banners/square_post_1080x1080.png', 1080, 1080, (c, s) {
      warmBackground(c, s);
      scatterSweets(c, s, const [
        (0.09, 0.10, 0.14, 1, Special.none),
        (0.91, 0.10, 0.14, 2, Special.none),
        (0.08, 0.50, 0.11, 4, Special.stripedV),
        (0.92, 0.50, 0.11, 3, Special.none),
      ]);
      logoLockup(c, const Offset(540, 372), 740);
      phoneMockup(c, shots['5_blockers'], const Offset(285, 860), 400, angle: -0.13);
      phoneMockup(c, shots['6_win'], const Offset(795, 860), 400, angle: 0.13);
      phoneMockup(c, shots['9_swirl_combo'], const Offset(540, 840), 440);
    });

    // Landscape promo (YouTube video cover, website hero, tablets): 1920 x 1080.
    await savePng('store_assets/banners/landscape_promo_1920x1080.png', 1920, 1080, (c, s) {
      warmBackground(c, s);
      scatterSweets(c, s, const [
        (0.05, 0.12, 0.13, 1, Special.none),
        (0.04, 0.88, 0.12, 2, Special.stripedH),
        (0.40, 0.08, 0.10, 3, Special.none),
        (0.42, 0.92, 0.10, -1, Special.swirl),
      ]);
      logoLockup(c, const Offset(500, 490), 800);
      outlinedText(c, '500 sweet levels to twist!', const Offset(500, 880), 58);
      phoneMockup(c, shots['2_map'], const Offset(1690, 560), 700, angle: 0.08);
      phoneMockup(c, shots['1_home'], const Offset(1170, 560), 700, angle: -0.08);
      phoneMockup(c, shots['3_combo'], const Offset(1430, 545), 760);
    });

    // Profile header (X / Twitter style): 1500 x 500. Keep the centre clear.
    await savePng('store_assets/banners/header_1500x500.png', 1500, 500, (c, s) {
      warmBackground(c, s);
      scatterSweets(c, s, const [
        (0.07, 0.25, 0.30, 1, Special.none),
        (0.19, 0.76, 0.26, 2, Special.none),
        (0.81, 0.24, 0.27, 3, Special.none),
        (0.93, 0.74, 0.30, 5, Special.none),
        (0.96, 0.18, 0.18, -1, Special.swirl),
        (0.04, 0.80, 0.18, 4, Special.box),
      ]);
      toffee(c, const Offset(480, 245), 290);
      outlinedText(c, 'Toffee Twist', const Offset(860, 215), 118);
      pill(c, 'Sweet Match 3', const Offset(860, 345), 44);
    });

    // Vertical story (Instagram / TikTok / WhatsApp status): 1080 x 1920.
    await savePng('store_assets/banners/story_1080x1920.png', 1080, 1920, (c, s) {
      warmBackground(c, s);
      scatterSweets(c, s, _sweetsAround, seed: 9);
      logoLockup(c, const Offset(540, 520), 880);
      phoneMockup(c, shots['9_swirl_combo'], const Offset(540, 1365), 880, angle: -0.03);
    });
  });
}

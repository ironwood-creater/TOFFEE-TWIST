// Renders the app icon, splash and store graphics from the game's own art.
//   flutter test tool/branding/render_branding_test.dart
// Output: branding/*.png and store_assets/*.png
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toffeetwist/game/logic/types.dart';
import 'package:toffeetwist/game/render/sweet_art.dart';

Future<void> loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('assets/fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Baloo2', ['Baloo2-ExtraBold.ttf']);
  await load('Nunito', ['Nunito-ExtraBold.ttf']);
}

Future<void> savePng(String path, int w, int h, void Function(Canvas c, Size s) paint) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  paint(c, Size(w.toDouble(), h.toDouble()));
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}

void warmBackground(Canvas c, Size s, {bool dots = true}) {
  final r = Offset.zero & s;
  c.drawRect(
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        s.center(Offset.zero),
        s.longestSide * 0.75,
        const [Color(0xFFFFF1CF), Color(0xFFF8C66E), Color(0xFFE39A2F)],
        const [0, 0.55, 1],
      ),
  );
  if (!dots) return;
  final p = Paint()..color = const Color(0x2EFFFFFF);
  final step = s.shortestSide / 9;
  var row = 0;
  for (var y = step / 3; y < s.height; y += step, row++) {
    for (var x = row.isEven ? step / 3 : step * 0.83; x < s.width; x += step) {
      c.drawCircle(Offset(x, y), step * 0.12, p);
    }
  }
}

void toffee(Canvas c, Offset center, double size, {bool shadow = true}) =>
    SweetArt.paintLogoToffee(c, Rect.fromCenter(center: center, width: size, height: size), shadow: shadow);

void outlinedText(Canvas c, String text, Offset center, double size,
    {List<Color> fill = const [Color(0xFFFFF4C2), Color(0xFFFFCB3C), Color(0xFFE39A0C)]}) {
  TextPainter tp(Paint fg) => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: 'Baloo2', fontWeight: FontWeight.w800, fontSize: size, height: 1, foreground: fg),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
  final stroke = tp(Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = size * 0.16
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFF3B1F12));
  final off = center - Offset(stroke.width / 2, stroke.height / 2);
  stroke.paint(c, off);
  final stops = [for (var i = 0; i < fill.length; i++) i / (fill.length - 1)];
  final shader = ui.Gradient.linear(Offset(0, off.dy), Offset(0, off.dy + stroke.height), fill, stops);
  tp(Paint()..shader = shader).paint(c, off);
}

void main() {
  setUpAll(loadFonts);

  test('render branding', () async {
    // Adaptive icon foreground: toffee inside the 66% safe zone, transparent.
    await savePng('branding/icon_foreground.png', 1024, 1024, (c, s) {
      toffee(c, s.center(Offset.zero), s.width * 0.54);
    });
    // Adaptive icon background.
    await savePng('branding/icon_background.png', 1024, 1024, (c, s) => warmBackground(c, s));
    // Monochrome (themed icons on Android 13+): white silhouette.
    await savePng('branding/icon_monochrome.png', 1024, 1024, (c, s) {
      c.saveLayer(Offset.zero & s, Paint());
      toffee(c, s.center(Offset.zero), s.width * 0.54, shadow: false);
      c.drawRect(Offset.zero & s, Paint()
        ..blendMode = BlendMode.srcIn
        ..color = Colors.white);
      c.restore();
    });
    // Full icon (legacy launchers, Play Store 512x512 icon).
    Future<void> fullIcon(String path, int px) => savePng(path, px, px, (c, s) {
          warmBackground(c, s);
          toffee(c, s.center(Offset.zero), s.width * 0.86);
        });
    await fullIcon('branding/icon_full.png', 1024);
    await fullIcon('store_assets/icon_512.png', 512);
    // Splash images.
    await savePng('branding/splash.png', 768, 768, (c, s) => toffee(c, s.center(Offset.zero), s.width * 0.95));
    await savePng('branding/splash_android12.png', 1152, 1152,
        (c, s) => toffee(c, s.center(Offset.zero), s.width * 0.6));

    // Feature graphic 1024 x 500.
    await savePng('store_assets/feature_graphic.png', 1024, 500, (c, s) {
      warmBackground(c, s);
      final rnd = math.Random(4);
      final spots = <(double, double, double, int, Special)>[
        (90, 110, 120, 1, Special.none),
        (185, 430, 100, 2, Special.stripedH),
        (70, 300, 95, 4, Special.none),
        (250, 120, 90, 3, Special.none),
        (930, 100, 115, 5, Special.none),
        (850, 435, 105, 4, Special.box),
        (965, 290, 95, 2, Special.none),
        (770, 130, 85, -1, Special.swirl),
      ];
      for (final (x, y, size, color, sp) in spots) {
        c.save();
        c.translate(x, y);
        c.rotate((rnd.nextDouble() - 0.5) * 0.5);
        SweetArt.paintPiece(c, Rect.fromCenter(center: Offset.zero, width: size, height: size),
            color: color, special: sp);
        c.restore();
      }
      toffee(c, const Offset(512, 150), 230);
      outlinedText(c, 'Toffee Twist', const Offset(512, 318), 118);
      // "Sweet Match 3" pill
      final pill = RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(512, 430), width: 360, height: 64), const Radius.circular(32));
      c.drawRRect(pill, Paint()..color = const Color(0xFFF26FA6));
      c.drawRRect(pill, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFF3B1F12));
      outlinedText(c, 'Sweet Match 3', const Offset(512, 433), 44, fill: const [Colors.white, Colors.white]);
    });
  });
}

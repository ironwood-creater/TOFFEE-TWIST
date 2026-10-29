// Shared drawing helpers for the branding and marketing renderers.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Rounded "Sweet Match 3" style pill with outlined text.
void pill(Canvas c, String text, Offset center, double fontSize,
    {Color color = const Color(0xFFF26FA6), double padX = 0.9}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: 'Baloo2', fontWeight: FontWeight.w800, fontSize: fontSize, height: 1),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final w = tp.width + fontSize * padX * 2;
  final h = fontSize * 1.45;
  final r = RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: w, height: h), Radius.circular(h / 2));
  c.drawRRect(r.shift(Offset(0, fontSize * 0.08)), Paint()..color = const Color(0x55000000));
  c.drawRRect(r, Paint()..color = color);
  c.drawRRect(
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = fontSize * 0.11
      ..color = const Color(0xFF3B1F12),
  );
  outlinedText(c, text, center + Offset(0, fontSize * 0.04), fontSize, fill: const [Colors.white, Colors.white]);
}

/// Sweets scattered at fixed spots: (x, y, size, color, special) as fractions
/// of the canvas size (x, y) and of its shorter side (size).
void scatterSweets(Canvas c, Size s, List<(double, double, double, int, Special)> spots, {int seed = 4}) {
  final rnd = math.Random(seed);
  for (final (x, y, size, color, sp) in spots) {
    final px = size * s.shortestSide;
    c.save();
    c.translate(x * s.width, y * s.height);
    c.rotate((rnd.nextDouble() - 0.5) * 0.5);
    SweetArt.paintPiece(c, Rect.fromCenter(center: Offset.zero, width: px, height: px), color: color, special: sp);
    c.restore();
  }
}

Future<ui.Image> loadImage(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

/// A simple phone frame (chocolate brown) showing [screen], centred at
/// [center], [height] tall, rotated by [angle] radians.
void phoneMockup(Canvas c, ui.Image screen, Offset center, double height, {double angle = 0}) {
  final aspect = screen.width / screen.height;
  final h = height;
  final w = h * aspect;
  final bezel = h * 0.025;
  c.save();
  c.translate(center.dx, center.dy);
  c.rotate(angle);
  final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w + bezel * 2, height: h + bezel * 2), Radius.circular(h * 0.06));
  c.drawRRect(
    body.shift(Offset(h * 0.012, h * 0.025)),
    Paint()
      ..color = const Color(0x66000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.02),
  );
  c.drawRRect(body, Paint()..color = const Color(0xFF2B160C));
  c.drawRRect(
    body.deflate(h * 0.004),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.006
      ..color = const Color(0xFF6B3A1E),
  );
  final screenRect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(screenRect, Radius.circular(h * 0.045)));
  c.drawImageRect(
    screen,
    Rect.fromLTWH(0, 0, screen.width.toDouble(), screen.height.toDouble()),
    screenRect,
    Paint()..filterQuality = FilterQuality.high,
  );
  c.restore();
  c.restore();
}

/// The full logo: toffee, "Toffee Twist" and the "Sweet Match 3" pill,
/// fitted into a box of width [w] centred at [center] (top of the toffee at
/// center.dy - w * 0.42).
void logoLockup(Canvas c, Offset center, double w) {
  toffee(c, center + Offset(0, -w * 0.20), w * 0.50);
  outlinedText(c, 'Toffee Twist', center + Offset(0, w * 0.12), w * 0.17);
  pill(c, 'Sweet Match 3', center + Offset(0, w * 0.29), w * 0.062);
}

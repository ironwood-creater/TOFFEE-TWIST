import 'dart:math' as math;
import 'dart:ui';

import '../logic/types.dart';

/// Draws every piece of the game with plain shapes, paths and gradients
/// (no image files). Everything is drawn in a 100 x 100 box and scaled.
///
/// Each sweet has a different SHAPE and COLOR so colorblind players can
/// tell them apart:
/// toffee = wrapped bar, cupcake = cup + frosting, donut = ring,
/// macaron = wide sandwich, lollipop = spiral circle on a stick,
/// chocolate = square with a grid.
abstract final class SweetArt {
  static const Color outline = Color(0xFF4A2A12);

  /// Main color of each sweet (for particles, goal icons ...).
  static const List<Color> baseColors = [
    Color(0xFFE59A2F), // toffee: golden brown
    Color(0xFFF26FA6), // cupcake: pink
    Color(0xFF3D8FE8), // donut: blue
    Color(0xFF4CC992), // macaron: mint green
    Color(0xFFA65BE0), // lollipop: purple
    Color(0xFF6B3A1E), // chocolate: dark brown
  ];

  /// Lighter variant (sparkles, glows).
  static const List<Color> lightColors = [
    Color(0xFFFFE08A),
    Color(0xFFFFC2DC),
    Color(0xFFA9D6FF),
    Color(0xFFB8F5D6),
    Color(0xFFE4C2FF),
    Color(0xFFC08A5C),
  ];

  /// Paints a piece into [rect].
  static void paintPiece(
    Canvas canvas,
    Rect rect, {
    required int color,
    Special special = Special.none,
    bool nut = false,
    bool armed = false,
  }) {
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / 100, rect.height / 100);
    if (nut) {
      _shadow(canvas);
      _nut(canvas);
    } else if (special == Special.swirl) {
      _shadow(canvas);
      _swirl(canvas);
    } else if (special == Special.box) {
      _boxBack(canvas, armed);
      canvas.save();
      canvas.translate(50, 52);
      canvas.scale(0.74);
      canvas.translate(-50, -50);
      paintSweet(canvas, color);
      canvas.restore();
      _boxFront(canvas, armed);
    } else {
      _shadow(canvas);
      paintSweet(canvas, color);
      if (special == Special.stripedH || special == Special.stripedV) {
        _stripes(canvas, color, horizontal: special == Special.stripedH);
      }
    }
    canvas.restore();
  }

  /// Paints only the sweet (in the current 100x100 space).
  static void paintSweet(Canvas c, int color) {
    switch (color) {
      case 0:
        _toffee(c);
      case 1:
        _cupcake(c);
      case 2:
        _donut(c);
      case 3:
        _macaron(c);
      case 4:
        _lollipop(c);
      default:
        _chocolate(c);
    }
  }

  // ---------------------------------------------------------------------------

  static Paint _fill(Color top, Color bottom, {double y0 = 10, double y1 = 90}) =>
      Paint()
        ..shader = Gradient.linear(Offset(0, y0), Offset(0, y1), [top, bottom]);

  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.2
    ..strokeJoin = StrokeJoin.round
    ..color = outline;

  static Paint _line(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..color = color;

  static void _shadow(Canvas c) {
    c.drawOval(
      const Rect.fromLTRB(22, 84, 78, 96),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  static void _shine(Canvas c, Rect r, [double alpha = 0.6]) {
    c.drawOval(r, Paint()..color = Color.fromRGBO(255, 255, 255, alpha));
  }

  // --- Toffee: golden-brown wrapped toffee with twisted ends -----------------
  static void _toffee(Canvas c) {
    final wrap = _fill(const Color(0xFFFFE597), const Color(0xFFE09A2A), y0: 26, y1: 74);
    final left = Path()
      ..moveTo(30, 43)
      ..lineTo(9, 25)
      ..quadraticBezierTo(2, 50, 9, 75)
      ..lineTo(30, 57)
      ..close();
    final right = Path()
      ..moveTo(70, 43)
      ..lineTo(91, 25)
      ..quadraticBezierTo(98, 50, 91, 75)
      ..lineTo(70, 57)
      ..close();
    for (final p in [left, right]) {
      c.drawPath(p, wrap);
      c.drawPath(p, _stroke);
    }
    final pleat = _line(const Color(0xAA9C5A0E), 2.2);
    for (final (x0, x1, sign) in [(28.0, 10.0, 1.0), (72.0, 90.0, -1.0)]) {
      c.drawLine(Offset(x0, 46), Offset(x1, 33), pleat);
      c.drawLine(Offset(x0, 54), Offset(x1, 67), pleat);
      c.drawLine(Offset(x0 - 2 * sign, 50), Offset(x1 - 3 * sign, 50), pleat);
    }
    final knot = _fill(const Color(0xFFF0B550), const Color(0xFFB8701A), y0: 40, y1: 60);
    for (final x in [29.0, 71.0]) {
      final r = Rect.fromCenter(center: Offset(x, 50), width: 9, height: 19);
      c.drawOval(r, knot);
      c.drawOval(r, _stroke);
    }
    final body = RRect.fromLTRBR(27, 29, 73, 71, const Radius.circular(15));
    c.drawRRect(body, _fill(const Color(0xFFF7BE55), const Color(0xFFB0611A), y0: 29, y1: 71));
    // Twist lines across the body.
    final twist = _line(const Color(0x66FFF3C4), 3);
    c.drawLine(const Offset(40, 33), const Offset(34, 67), twist);
    c.drawLine(const Offset(56, 33), const Offset(50, 67), twist);
    c.drawRRect(body, _stroke);
    _shine(c, const Rect.fromLTRB(33, 33, 56, 42));
  }

  // --- Cupcake: pink cup (trapezoid) with a round frosting top ---------------
  static void _cupcake(Canvas c) {
    final cup = Path()
      ..moveTo(21, 55)
      ..lineTo(79, 55)
      ..lineTo(70, 91)
      ..lineTo(30, 91)
      ..close();
    c.drawPath(cup, _fill(const Color(0xFFEB5A90), const Color(0xFFB4235A), y0: 55, y1: 91));
    final ridge = _line(const Color(0x66FFFFFF), 2.4);
    for (final x in [32.0, 41.0, 50.0, 59.0, 68.0]) {
      final xb = 50 + (x - 50) * 0.7;
      c.drawLine(Offset(x, 58), Offset(xb, 88), ridge);
    }
    c.drawPath(cup, _stroke);

    final frost = Path()
      ..moveTo(15, 56)
      ..cubicTo(8, 42, 20, 30, 31, 32)
      ..cubicTo(33, 14, 66, 10, 69, 30)
      ..cubicTo(82, 29, 93, 43, 85, 56)
      ..quadraticBezierTo(77, 65, 68, 58)
      ..quadraticBezierTo(59, 66, 50, 58)
      ..quadraticBezierTo(41, 66, 32, 58)
      ..quadraticBezierTo(23, 65, 15, 56)
      ..close();
    c.drawPath(frost, _fill(const Color(0xFFFFC4DD), const Color(0xFFF0629F), y0: 14, y1: 64));
    final swirl = Path()
      ..moveTo(24, 47)
      ..cubicTo(38, 36, 58, 52, 76, 42);
    c.drawPath(swirl, _line(const Color(0x88FFFFFF), 3.2));
    c.drawPath(frost, _stroke);
    // Sprinkles.
    const dots = [
      (35.0, 25.0, Color(0xFFFFFFFF)),
      (55.0, 21.0, Color(0xFFFFE066)),
      (64.0, 37.0, Color(0xFF8EE8C0)),
      (44.0, 38.0, Color(0xFFFFFFFF)),
      (26.0, 40.0, Color(0xFFFFE066)),
      (75.0, 49.0, Color(0xFFFFFFFF)),
    ];
    for (final (x, y, col) in dots) {
      c.drawCircle(Offset(x, y), 2.4, Paint()..color = col);
    }
    _shine(c, const Rect.fromLTRB(38, 19, 52, 27), 0.55);
  }

  // --- Donut: blue glazed ring with sprinkles --------------------------------
  static void _donut(Canvas c) {
    const center = Offset(50, 51);
    final dough = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: center, radius: 41))
      ..addOval(Rect.fromCircle(center: center, radius: 13));
    c.drawPath(dough, _fill(const Color(0xFFF2C27F), const Color(0xFFC07A33), y0: 10, y1: 92));
    final glaze = Path()..fillType = PathFillType.evenOdd;
    const n = 64;
    for (var i = 0; i <= n; i++) {
      final a = i / n * math.pi * 2;
      final r = 35 + 3.2 * math.sin(a * 7) + 1.5 * math.sin(a * 3 + 1);
      final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? glaze.moveTo(p.dx, p.dy) : glaze.lineTo(p.dx, p.dy);
    }
    glaze.close();
    glaze.addOval(Rect.fromCircle(center: center, radius: 17));
    c.drawPath(
      glaze,
      Paint()
        ..shader = Gradient.radial(const Offset(38, 36), 52,
            [const Color(0xFF9AD3FF), const Color(0xFF3D8FE8), const Color(0xFF1A5DB8)], [0, 0.45, 1]),
    );
    c.drawPath(glaze, _line(const Color(0x8813408A), 1.6));
    const sprinkles = [
      (0.3, 26.0, Color(0xFFFFFFFF)),
      (1.1, 27.0, Color(0xFFFFE066)),
      (1.9, 26.0, Color(0xFFFF8AC0)),
      (2.6, 27.0, Color(0xFFFFFFFF)),
      (3.4, 26.0, Color(0xFFFFE066)),
      (4.1, 27.0, Color(0xFFFF8AC0)),
      (4.9, 26.0, Color(0xFFFFFFFF)),
      (5.6, 27.0, Color(0xFFFFE066)),
    ];
    for (final (a, r, col) in sprinkles) {
      final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(a * 2.3);
      c.drawRRect(RRect.fromLTRBR(-4.5, -1.6, 4.5, 1.6, const Radius.circular(1.6)),
          Paint()..color = col);
      c.restore();
    }
    c.drawPath(dough, _stroke);
    c.drawArc(Rect.fromCircle(center: center, radius: 29), 3.5, 0.9, false,
        _line(const Color(0x99FFFFFF), 4.5));
  }

  // --- Macaron: mint green oval sandwich --------------------------------------
  static void _macaron(Canvas c) {
    final shell = _fill(const Color(0xFFB4F5D2), const Color(0xFF34B47A), y0: 18, y1: 84);
    const bottom = Rect.fromLTRB(13, 55, 87, 84);
    c.drawOval(bottom, shell);
    c.drawOval(bottom, _stroke);
    // Ruffled "feet".
    final feet = Paint()..color = const Color(0xFF5ACB97);
    for (var x = 17.0; x <= 83; x += 6.6) {
      c.drawCircle(Offset(x, 57), 3.3, feet);
      c.drawCircle(Offset(x, 49), 3.3, feet);
    }
    final cream = RRect.fromLTRBR(15, 46, 85, 60, const Radius.circular(7));
    c.drawRRect(cream, Paint()..color = const Color(0xFFFFF6DE));
    c.drawRRect(cream, _stroke);
    const top = Rect.fromLTRB(10, 17, 90, 51);
    c.drawOval(top, shell);
    c.drawOval(top, _stroke);
    _shine(c, const Rect.fromLTRB(24, 22, 54, 32), 0.55);
  }

  // --- Lollipop: purple spiral circle on a stick ------------------------------
  static void _lollipop(Canvas c) {
    final stick = RRect.fromLTRBR(45.5, 66, 54.5, 97, const Radius.circular(4));
    c.drawRRect(stick, Paint()..color = const Color(0xFFFFF8EC));
    c.drawRRect(stick, _stroke);
    const center = Offset(50, 41);
    final circle = Rect.fromCircle(center: center, radius: 34);
    c.drawOval(
      circle,
      Paint()
        ..shader = Gradient.radial(const Offset(40, 30), 48,
            [const Color(0xFFE2B5FF), const Color(0xFFA65BE0), const Color(0xFF6A23AD)], [0, 0.5, 1]),
    );
    c.save();
    c.clipPath(Path()..addOval(circle));
    final spiral = Path();
    for (var i = 0; i <= 120; i++) {
      final t = i / 120;
      final a = t * math.pi * 5.2;
      final r = 2 + t * 34;
      final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? spiral.moveTo(p.dx, p.dy) : spiral.lineTo(p.dx, p.dy);
    }
    c.drawPath(spiral, _line(const Color(0xDDF6E6FF), 5.5));
    c.restore();
    c.drawOval(circle, _stroke);
    _shine(c, const Rect.fromLTRB(28, 17, 46, 27), 0.6);
  }

  // --- Chocolate: dark brown square with grid lines ---------------------------
  static void _chocolate(Canvas c) {
    final body = RRect.fromLTRBR(15, 15, 85, 85, const Radius.circular(11));
    c.drawRRect(body, _fill(const Color(0xFF8E522B), const Color(0xFF45220D), y0: 15, y1: 85));
    const step = 70 / 3;
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        final r = Rect.fromLTWH(15 + i * step + 3.5, 15 + j * step + 3.5, step - 7, step - 7);
        c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)),
            _fill(const Color(0xFF9A5C33), const Color(0xFF5E3015), y0: r.top, y1: r.bottom));
        c.drawLine(r.topLeft + const Offset(1, 1), r.topRight + const Offset(-1, 1),
            _line(const Color(0x55FFE2C0), 1.6));
      }
    }
    final groove = _line(const Color(0xFF2E1405), 2.4);
    for (var k = 1; k < 3; k++) {
      c.drawLine(Offset(15 + k * step, 18), Offset(15 + k * step, 82), groove);
      c.drawLine(Offset(18, 15 + k * step), Offset(82, 15 + k * step), groove);
    }
    c.drawRRect(body, _stroke);
    c.drawLine(const Offset(22, 21), const Offset(38, 21), _line(const Color(0x77FFFFFF), 3));
  }

  // --- Specials ---------------------------------------------------------------

  static void _stripes(Canvas c, int color, {required bool horizontal}) {
    c.save();
    c.clipRRect(RRect.fromLTRBR(12, 14, 88, 88, const Radius.circular(30)));
    final band = Paint()..color = const Color(0xE6FFFFFF);
    final edge = _line(SweetArt.baseColors[color].withValues(alpha: 0.9), 1.6);
    for (final k in [-17.0, 0.0, 17.0]) {
      final r = horizontal
          ? Rect.fromLTRB(0, 47 + k, 100, 54 + k)
          : Rect.fromLTRB(47 + k, 0, 54 + k, 100);
      c.drawRect(r, band);
      c.drawRect(r, edge);
    }
    c.restore();
    // Arrows show which way the stripes will clear.
    final arrow = Paint()..color = const Color(0xFFFFFFFF);
    final arrowLine = _line(outline, 2);
    for (final dir in [-1.0, 1.0]) {
      final path = Path();
      if (horizontal) {
        final x = 50 + dir * 47;
        path
          ..moveTo(x, 50)
          ..lineTo(x - dir * 9, 42)
          ..lineTo(x - dir * 9, 58)
          ..close();
      } else {
        final y = 50 + dir * 47;
        path
          ..moveTo(50, y)
          ..lineTo(42, y - dir * 9)
          ..lineTo(58, y - dir * 9)
          ..close();
      }
      c.drawPath(path, arrow);
      c.drawPath(path, arrowLine);
    }
  }

  static void _boxBack(Canvas c, bool armed) {
    if (armed) {
      c.drawCircle(
        const Offset(50, 50),
        48,
        Paint()
          ..color = const Color(0xAAFF8A00)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
    final box = RRect.fromLTRBR(7, 9, 93, 93, const Radius.circular(16));
    c.drawRRect(box, Paint()..color = const Color(0x55FFE08A));
    c.drawRRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFFD99A0E),
    );
  }

  static void _boxFront(Canvas c, bool armed) {
    final ribbon = Paint()..color = armed ? const Color(0xCCFF7A00) : const Color(0xCCF5B800);
    final edge = _line(const Color(0xFF9C6A00), 1.6);
    const v = Rect.fromLTRB(46.5, 9, 53.5, 93);
    const h = Rect.fromLTRB(7, 48.5, 93, 55.5);
    for (final r in [v, h]) {
      c.drawRect(r, ribbon);
      c.drawRect(r, edge);
    }
    // Bow on top.
    final bowFill = Paint()..color = armed ? const Color(0xFFFF8F1F) : const Color(0xFFFFC928);
    for (final dx in [-1.0, 1.0]) {
      final loop = Rect.fromCenter(center: Offset(50 + dx * 10, 8), width: 18, height: 12);
      c.drawOval(loop, bowFill);
      c.drawOval(loop, edge);
    }
    c.drawCircle(const Offset(50, 9), 4.5, bowFill);
    c.drawCircle(const Offset(50, 9), 4.5, edge);
    final box = RRect.fromLTRBR(7, 9, 93, 93, const Radius.circular(16));
    c.drawRRect(box, _line(const Color(0x66FFFFFF), 2));
    c.drawLine(const Offset(16, 18), const Offset(30, 18), _line(const Color(0x99FFFFFF), 3));
  }

  static void _swirl(Canvas c) {
    const center = Offset(50, 50);
    final disc = Rect.fromCircle(center: center, radius: 39);
    c.drawOval(
      disc,
      Paint()
        ..shader = Gradient.radial(const Offset(40, 38), 50,
            [const Color(0xFFFFF6C8), const Color(0xFFF2B53A), const Color(0xFFB0660E)], [0, 0.55, 1]),
    );
    c.save();
    c.clipPath(Path()..addOval(disc));
    for (var arm = 0; arm < 6; arm++) {
      final path = Path();
      for (var i = 0; i <= 40; i++) {
        final t = i / 40;
        final a = arm * math.pi / 3 + t * math.pi * 1.6;
        final r = 3 + t * 40;
        final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      c.drawPath(path, _line(baseColors[arm == 5 ? 0 : arm + 1].withValues(alpha: 0.95), 6.5));
    }
    c.restore();
    c.drawCircle(center, 8, Paint()..color = const Color(0xFFFFF6D0));
    c.drawOval(disc, _stroke);
    for (final (x, y, s) in [(20.0, 18.0, 7.0), (83.0, 26.0, 5.0), (78.0, 84.0, 6.0)]) {
      _sparkle(c, Offset(x, y), s);
    }
  }

  static void _sparkle(Canvas c, Offset p, double s) {
    final path = Path()
      ..moveTo(p.dx, p.dy - s)
      ..quadraticBezierTo(p.dx, p.dy, p.dx + s, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s)
      ..quadraticBezierTo(p.dx, p.dy, p.dx - s, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s)
      ..close();
    c.drawPath(path, Paint()..color = const Color(0xFFFFFFFF));
  }

  static void _nut(Canvas c) {
    final body = Path()
      ..moveTo(50, 93)
      ..cubicTo(17, 89, 12, 52, 26, 38)
      ..lineTo(74, 38)
      ..cubicTo(88, 52, 83, 89, 50, 93)
      ..close();
    c.drawPath(
      body,
      _fill(const Color(0xFFFFEC9A), const Color(0xFFC8860E), y0: 38, y1: 93),
    );
    c.drawPath(body, _stroke);
    final cap = Path()
      ..moveTo(19, 42)
      ..cubicTo(16, 14, 84, 14, 81, 42)
      ..quadraticBezierTo(50, 51, 19, 42)
      ..close();
    c.drawPath(cap, _fill(const Color(0xFFA4723F), const Color(0xFF6B4320), y0: 18, y1: 48));
    c.save();
    c.clipPath(cap);
    final hatch = _line(const Color(0x553A2008), 1.6);
    for (var x = 4.0; x < 100; x += 8) {
      c.drawLine(Offset(x, 14), Offset(x + 18, 50), hatch);
      c.drawLine(Offset(x + 18, 14), Offset(x, 50), hatch);
    }
    c.restore();
    c.drawPath(cap, _stroke);
    final stem = RRect.fromLTRBR(46, 6, 54, 21, const Radius.circular(3));
    c.drawRRect(stem, Paint()..color = const Color(0xFF6B4320));
    c.drawRRect(stem, _stroke);
    _shine(c, const Rect.fromLTRB(30, 52, 42, 72), 0.6);
    _sparkle(c, const Offset(70, 60), 6);
  }

  // --- Board blockers ---------------------------------------------------------

  /// Caramel tile under a piece (1 or 2 layers).
  static void paintCaramel(Canvas canvas, Rect r, int layers) {
    if (layers <= 0) return;
    final rr = RRect.fromRectAndRadius(r.deflate(r.width * 0.03), Radius.circular(r.width * 0.16));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = Gradient.linear(
          r.topLeft,
          r.bottomRight,
          layers >= 2
              ? [const Color(0xFFC46A12), const Color(0xFF8E4508)]
              : [const Color(0xFFF2AE4E), const Color(0xFFD68420)],
        ),
    );
    // Drizzle lines + gloss.
    final drizzle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r.width * 0.045
      ..strokeCap = StrokeCap.round
      ..color = layers >= 2 ? const Color(0x88FFD08A) : const Color(0x66FFF0C8);
    final path = Path()
      ..moveTo(r.left + r.width * 0.15, r.top + r.height * 0.3)
      ..quadraticBezierTo(r.center.dx, r.top + r.height * 0.15, r.right - r.width * 0.15,
          r.top + r.height * 0.35);
    canvas.drawPath(path, drizzle);
    if (layers >= 2) {
      final p2 = Path()
        ..moveTo(r.left + r.width * 0.15, r.bottom - r.height * 0.28)
        ..quadraticBezierTo(r.center.dx, r.bottom - r.height * 0.12, r.right - r.width * 0.15,
            r.bottom - r.height * 0.32);
      canvas.drawPath(p2, drizzle);
    }
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.width * 0.035
        ..color = const Color(0xFF8A4A10),
    );
  }

  /// Wooden crate with 1-3 hit points.
  static void paintCrate(Canvas canvas, Rect r, int hp) {
    if (hp <= 0) return;
    final rr = RRect.fromRectAndRadius(r.deflate(r.width * 0.04), Radius.circular(r.width * 0.1));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = Gradient.linear(r.topCenter, r.bottomCenter,
            [const Color(0xFFDCA261), const Color(0xFFA8692E)]),
    );
    final w = r.width;
    final plank = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..color = const Color(0xFF7A4518);
    for (final f in [0.36, 0.64]) {
      canvas.drawLine(Offset(r.left + w * 0.08, r.top + w * f),
          Offset(r.right - w * 0.08, r.top + w * f), plank);
    }
    final brace = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8C5220);
    canvas.drawLine(r.topLeft + Offset(w * 0.2, w * 0.2), r.bottomRight - Offset(w * 0.2, w * 0.2),
        brace);
    if (hp >= 2) {
      canvas.drawLine(r.topRight + Offset(-w * 0.2, w * 0.2),
          r.bottomLeft + Offset(w * 0.2, -w * 0.2), brace);
    }
    if (hp >= 3) {
      final band = Paint()..color = const Color(0xFF9AA3AD);
      for (final f in [0.16, 0.84]) {
        canvas.drawRect(
            Rect.fromLTWH(r.left + w * 0.06, r.top + w * f - w * 0.045, w * 0.88, w * 0.09), band);
      }
      final rivet = Paint()..color = const Color(0xFF5E666E);
      for (final fx in [0.16, 0.5, 0.84]) {
        for (final fy in [0.16, 0.84]) {
          canvas.drawCircle(Offset(r.left + w * fx, r.top + w * fy), w * 0.025, rivet);
        }
      }
    }
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045
        ..color = const Color(0xFF5C3210),
    );
  }

  /// A golden twisted toffee used for the logo, app icon and splash.
  static void paintLogoToffee(Canvas canvas, Rect rect) {
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / 100, rect.height / 100);
    canvas.translate(50, 50);
    canvas.rotate(-0.35);
    canvas.translate(-50, -50);
    _shadow(canvas);
    _toffee(canvas);
    _sparkle(canvas, const Offset(80, 20), 7);
    _sparkle(canvas, const Offset(18, 80), 5);
    canvas.restore();
  }
}

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../../theme.dart';

/// Short visual effects drawn above the pieces: striped beams, explosion
/// rings, swirl rays, flashes and floating texts.
class FxLayer extends Component {
  FxLayer() : super(priority: 40);

  final List<_Fx> _items = [];

  bool get isEmpty => _items.isEmpty;

  void beam(Rect area, Color color, {required bool horizontal, double delay = 0}) =>
      _items.add(_BeamFx(area, color, horizontal, delay));

  void ring(Offset center, double radius, Color color, {double delay = 0, double duration = 0.4}) =>
      _items.add(_RingFx(center, radius, color, delay, duration));

  void rays(Offset from, List<Offset> to, Color color) => _items.add(_RaysFx(from, to, color));

  void flash(Rect area, {Color color = const Color(0xFFFFFFFF)}) => _items.add(_FlashFx(area, color));

  void glow(Rect cell, Color color) => _items.add(_GlowFx(cell, color));

  /// Small "+120" score text.
  void scoreText(Offset at, String text, {double size = 18, double delay = 0}) =>
      _items.add(_TextFx(at, text, size, const Color(0xFFFFFFFF), 0.8, 42, delay));

  /// Big centered banner word ("Great!", "Shuffle!").
  void banner(Offset at, String text, {double size = 44, Color color = AppColors.goldLight}) =>
      _items.add(_TextFx(at, text, size, color, 1.1, 30, 0, banner: true));

  @override
  void update(double dt) {
    for (final fx in _items) {
      if (fx.delay > 0) {
        fx.delay -= dt;
      } else {
        fx.t += dt;
      }
    }
    _items.removeWhere((fx) => fx.t >= fx.duration);
  }

  @override
  void render(Canvas canvas) {
    for (final fx in _items) {
      if (fx.delay > 0) continue;
      fx.draw(canvas, (fx.t / fx.duration).clamp(0.0, 1.0));
    }
  }
}

abstract class _Fx {
  _Fx(this.duration, [this.delay = 0]);
  final double duration;
  double delay;
  double t = 0;
  void draw(Canvas c, double k);
}

class _BeamFx extends _Fx {
  _BeamFx(this.area, this.color, this.horizontal, double delay) : super(0.42, delay);
  final Rect area;
  final Color color;
  final bool horizontal;
  final Paint _p = Paint();

  @override
  void draw(Canvas c, double k) {
    final grow = math.min(1.0, k * 4);
    final thick = (horizontal ? area.height : area.width) * (1 - k) * 0.9;
    final center = area.center;
    final len = (horizontal ? area.width : area.height) * grow;
    final r = horizontal
        ? Rect.fromCenter(center: center, width: len, height: thick)
        : Rect.fromCenter(center: center, width: thick, height: len);
    _p
      ..color = color.withValues(alpha: 0.85 * (1 - k))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    c.drawRRect(RRect.fromRectAndRadius(r.inflate(8), Radius.circular(thick)), _p);
    _p
      ..color = const Color(0xFFFFE08A).withValues(alpha: 0.9 * (1 - k))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    c.drawRRect(RRect.fromRectAndRadius(r.deflate(thick * 0.12), Radius.circular(thick)), _p);
    _p
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 1 - k)
      ..maskFilter = null;
    final core = horizontal
        ? Rect.fromCenter(center: center, width: len, height: thick * 0.35)
        : Rect.fromCenter(center: center, width: thick * 0.35, height: len);
    c.drawRRect(RRect.fromRectAndRadius(core, Radius.circular(thick)), _p);
  }
}

class _RingFx extends _Fx {
  _RingFx(this.center, this.radius, this.color, double delay, double duration)
      : super(duration, delay);
  final Offset center;
  final double radius;
  final Color color;
  final Paint _p = Paint()..style = PaintingStyle.stroke;

  @override
  void draw(Canvas c, double k) {
    final e = Curves.easeOut.transform(k);
    _p
      ..strokeWidth = radius * 0.25 * (1 - k) + 1
      ..color = color.withValues(alpha: 1 - k);
    c.drawCircle(center, radius * (0.2 + 0.8 * e), _p);
    final fill = Paint()..color = const Color(0xFFFFF3C4).withValues(alpha: 0.5 * (1 - e));
    c.drawCircle(center, radius * 0.9 * e, fill);
  }
}

class _RaysFx extends _Fx {
  _RaysFx(this.from, this.to, this.color) : super(0.55);
  final Offset from;
  final List<Offset> to;
  final Color color;
  final Paint _p = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  @override
  void draw(Canvas c, double k) {
    final grow = math.min(1.0, k * 3);
    _p
      ..strokeWidth = 5 * (1 - k) + 1
      ..color = color.withValues(alpha: 1 - k);
    final core = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 1 - k);
    for (final t in to) {
      final end = Offset.lerp(from, t, grow)!;
      c.drawLine(from, end, _p);
      c.drawLine(from, end, core);
    }
  }
}

class _FlashFx extends _Fx {
  _FlashFx(this.area, this.color) : super(0.5);
  final Rect area;
  final Color color;

  @override
  void draw(Canvas c, double k) {
    c.drawRect(area.inflate(20), Paint()..color = color.withValues(alpha: 0.75 * (1 - k)));
  }
}

class _GlowFx extends _Fx {
  _GlowFx(this.cell, this.color) : super(0.25);
  final Rect cell;
  final Color color;

  @override
  void draw(Canvas c, double k) {
    c.drawRRect(
      RRect.fromRectAndRadius(cell.deflate(2), Radius.circular(cell.width * 0.25)),
      Paint()
        ..color = color.withValues(alpha: 0.6 * (1 - k))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }
}

class _TextFx extends _Fx {
  _TextFx(this.at, String text, double size, Color color, double duration, this.rise, double delay,
      {this.banner = false})
      : super(duration, delay) {
    _painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AppText.heading,
          fontWeight: FontWeight.w800,
          fontSize: size,
          color: color,
          shadows: const [
            Shadow(color: Color(0xFF6B3A10), offset: Offset(0, 2.5), blurRadius: 0),
            Shadow(color: Color(0x88000000), offset: Offset(0, 3), blurRadius: 6),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  final Offset at;
  final double rise;
  final bool banner;
  late final TextPainter _painter;

  @override
  void draw(Canvas c, double k) {
    final alpha = k < 0.7 ? 1.0 : 1 - (k - 0.7) / 0.3;
    final scale = banner ? (k < 0.2 ? 0.4 + 0.6 * Curves.easeOutBack.transform(k / 0.2) : 1.0) : 1.0;
    c.save();
    c.translate(at.dx, at.dy - rise * Curves.easeOut.transform(k));
    c.scale(scale);
    c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)));
    _painter.paint(c, Offset(-_painter.width / 2, -_painter.height / 2));
    c.restore();
    c.restore();
  }
}

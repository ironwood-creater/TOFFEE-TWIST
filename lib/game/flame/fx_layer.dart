import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../../theme.dart';

/// Short visual effects drawn above the pieces: striped beams, explosion
/// rings, swirl rays, flashes and floating texts.
class FxLayer extends Component {
  FxLayer({this.pixelRatio = 1}) : super(priority: 40);

  /// Screen pixels per logical pixel (texts are rendered once at this size).
  final double pixelRatio;
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
      _items.add(_TextFx(at, text, size, const Color(0xFFFFFFFF), 0.8, 42, delay, pixelRatio));

  /// Big centered banner word ("Great!", "Shuffle!").
  void banner(Offset at, String text, {double size = 44, Color color = AppColors.goldLight}) =>
      _items.add(_TextFx(at, text, size, color, 1.1, 30, 0, pixelRatio, banner: true));

  @override
  void update(double dt) {
    for (final fx in _items) {
      if (fx.delay > 0) {
        fx.delay -= dt;
      } else {
        fx.t += dt;
      }
    }
    _items.removeWhere((fx) {
      if (fx.t < fx.duration) return false;
      fx.dispose();
      return true;
    });
  }

  @override
  void onRemove() {
    for (final fx in _items) {
      fx.dispose();
    }
    _items.clear();
    super.onRemove();
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
  void dispose() {}
}

class _BeamFx extends _Fx {
  _BeamFx(this.area, this.color, this.horizontal, double delay) : super(0.42, delay);
  final Rect area;
  final Color color;
  final bool horizontal;
  final Paint _p = Paint();

  // Soft edges come from a gradient across the beam instead of blur filters,
  // which are slow on phones when they cover a whole row or column.
  @override
  void draw(Canvas c, double k) {
    final grow = math.min(1.0, k * 4);
    final thick = (horizontal ? area.height : area.width) * (1 - k) * 0.9;
    final center = area.center;
    final len = (horizontal ? area.width : area.height) * grow;
    final glowThick = thick * 2 + 36;
    final glow = horizontal
        ? Rect.fromCenter(center: center, width: len + 16, height: glowThick)
        : Rect.fromCenter(center: center, width: glowThick, height: len + 16);
    final edge = color.withValues(alpha: 0);
    final strong = color.withValues(alpha: 0.9 * (1 - k));
    _p.shader = ui.Gradient.linear(
      horizontal ? glow.topCenter : glow.centerLeft,
      horizontal ? glow.bottomCenter : glow.centerRight,
      [edge, color.withValues(alpha: 0.45 * (1 - k)), strong, strong, color.withValues(alpha: 0.45 * (1 - k)), edge],
      const [0, 0.22, 0.4, 0.6, 0.78, 1],
    );
    c.drawRect(glow, _p);
    _p.shader = null;
    final r = horizontal
        ? Rect.fromCenter(center: center, width: len, height: thick)
        : Rect.fromCenter(center: center, width: thick, height: len);
    _p.color = const Color(0xFFFFE08A).withValues(alpha: 0.9 * (1 - k));
    c.drawRRect(RRect.fromRectAndRadius(r.deflate(thick * 0.12), Radius.circular(thick)), _p);
    _p.color = const Color(0xFFFFFFFF).withValues(alpha: 1 - k);
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
  final Paint _fill = Paint();

  @override
  void draw(Canvas c, double k) {
    final e = Curves.easeOut.transform(k);
    _p
      ..strokeWidth = radius * 0.25 * (1 - k) + 1
      ..color = color.withValues(alpha: 1 - k);
    c.drawCircle(center, radius * (0.2 + 0.8 * e), _p);
    _fill.color = const Color(0xFFFFF3C4).withValues(alpha: 0.5 * (1 - e));
    c.drawCircle(center, radius * 0.9 * e, _fill);
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
  final Paint _core = Paint()
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;

  @override
  void draw(Canvas c, double k) {
    final grow = math.min(1.0, k * 3);
    _p
      ..strokeWidth = 5 * (1 - k) + 1
      ..color = color.withValues(alpha: 1 - k);
    final core = _core..color = const Color(0xFFFFFFFF).withValues(alpha: 1 - k);
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
  final Paint _p = Paint();

  @override
  void draw(Canvas c, double k) {
    c.drawRect(area.inflate(20), _p..color = color.withValues(alpha: 0.75 * (1 - k)));
  }
}

class _GlowFx extends _Fx {
  _GlowFx(this.cell, this.color) : super(0.25);
  final Rect cell;
  final Color color;
  final Paint _p = Paint();

  // Two soft layers instead of a blur filter (cheaper with many cells).
  @override
  void draw(Canvas c, double k) {
    final radius = Radius.circular(cell.width * 0.25);
    _p.color = color.withValues(alpha: 0.3 * (1 - k));
    c.drawRRect(RRect.fromRectAndRadius(cell.inflate(1), radius), _p);
    _p.color = color.withValues(alpha: 0.45 * (1 - k));
    c.drawRRect(RRect.fromRectAndRadius(cell.deflate(4), radius), _p);
  }
}

/// Floating text. The text (with its shadows) is drawn once into an image;
/// every frame only draws that image, faded and moved.
class _TextFx extends _Fx {
  _TextFx(this.at, String text, double size, Color color, double duration, this.rise, double delay,
      double pixelRatio,
      {this.banner = false})
      : super(duration, delay) {
    final painter = TextPainter(
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
    // Room for the shadows around the letters.
    const pad = 10.0;
    _w = painter.width + pad * 2;
    _h = painter.height + pad * 2;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(pixelRatio);
    painter.paint(c, const Offset(pad, pad));
    painter.dispose();
    final picture = rec.endRecording();
    _image = picture.toImageSync((_w * pixelRatio).ceil(), (_h * pixelRatio).ceil());
    picture.dispose();
    _src = Rect.fromLTWH(0, 0, _image.width.toDouble(), _image.height.toDouble());
  }

  final Offset at;
  final double rise;
  final bool banner;
  late final ui.Image _image;
  late final Rect _src;
  late final double _w;
  late final double _h;
  final Paint _p = Paint()..filterQuality = FilterQuality.medium;

  @override
  void draw(Canvas c, double k) {
    final alpha = k < 0.7 ? 1.0 : 1 - (k - 0.7) / 0.3;
    final scale = banner ? (k < 0.2 ? 0.4 + 0.6 * Curves.easeOutBack.transform(k / 0.2) : 1.0) : 1.0;
    final cx = at.dx;
    final cy = at.dy - rise * Curves.easeOut.transform(k);
    final w = _w * scale;
    final h = _h * scale;
    _p.color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0));
    c.drawImageRect(_image, _src, Rect.fromLTWH(cx - w / 2, cy - h / 2, w, h), _p);
  }

  @override
  void dispose() => _image.dispose();
}

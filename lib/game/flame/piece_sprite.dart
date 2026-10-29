import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../logic/types.dart';

class _Anim {
  _Anim(this.duration, this.apply, this.curve, this.delay);
  final double duration;
  final void Function(double k) apply;
  final Curve curve;
  double delay;
  double t = 0;
  final done = Completer<void>();
}

/// One piece on the screen. Moves with small tween animations that can be
/// awaited (`await sprite.moveTo(...)`).
class PieceSprite extends PositionComponent {
  PieceSprite(this.piece, this.image, double tile)
      : super(size: Vector2.all(tile), anchor: Anchor.center, priority: 1);

  Piece piece;
  ui.Image image;

  double opacity = 1;
  double scaleK = 1;
  double squashX = 1;
  double squashY = 1;
  bool selected = false;
  bool hinting = false;
  double _clock = 0;
  final List<_Anim> _anims = [];

  static final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;
  static final Paint _glowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

  Future<void> tween(
    double duration,
    void Function(double k) apply, {
    double delay = 0,
    Curve curve = Curves.easeInOut,
  }) {
    final a = _Anim(math.max(duration, 0.001), apply, curve, delay);
    _anims.add(a);
    return a.done.future;
  }

  Future<void> moveTo(Vector2 target, double duration,
      {double delay = 0, Curve curve = Curves.easeInOut}) {
    final from = position.clone();
    final to = target.clone();
    return tween(duration, (k) {
      position.setValues(from.x + (to.x - from.x) * k, from.y + (to.y - from.y) * k);
    }, delay: delay, curve: curve);
  }

  /// Grows a little, then shrinks away.
  Future<void> pop({double delay = 0}) => tween(0.24, (k) {
        scaleK = k < 0.3 ? 1 + k / 0.3 * 0.22 : 1.22 * (1 - (k - 0.3) / 0.7);
        opacity = k < 0.5 ? 1 : 1 - (k - 0.5) / 0.5;
      }, delay: delay, curve: Curves.linear);

  /// Pops in from nothing (new special pieces).
  Future<void> appear({double delay = 0}) {
    scaleK = 0;
    return tween(0.26, (k) => scaleK = k, delay: delay, curve: Curves.easeOutBack);
  }

  /// Little squash when landing after a fall.
  Future<void> land() => tween(0.14, (k) {
        final s = math.sin(k * math.pi);
        squashX = 1 + 0.10 * s;
        squashY = 1 - 0.12 * s;
      }, curve: Curves.linear);

  /// Follows waypoints: the piece is at `points[i]` at time `times[i]`
  /// (seconds from now). With [fadeSegment] >= 0 the piece is invisible before
  /// that segment and fades in during it (new pieces dropping in).
  Future<void> followPath(List<Vector2> points, List<double> times, {int fadeSegment = -1}) {
    final total = times.last;
    final fadeIn = fadeSegment >= 0;
    if (fadeIn) opacity = 0;
    position.setFrom(points.first);
    return tween(total, (k) {
      final t = k * total;
      var i = 0;
      while (i < times.length - 2 && t > times[i + 1]) {
        i++;
      }
      final t0 = times[i];
      final t1 = times[i + 1];
      final f = t1 > t0 ? ((t - t0) / (t1 - t0)).clamp(0.0, 1.0) : 1.0;
      final a = points[i];
      final b = points[i + 1];
      position.setValues(a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f);
      if (fadeIn) opacity = i < fadeSegment ? 0 : (i == fadeSegment ? f : 1);
    }, curve: Curves.linear);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
    if (_anims.isEmpty) return;
    for (final a in List.of(_anims)) {
      if (a.delay > 0) {
        a.delay -= dt;
        if (a.delay > 0) continue;
        a.t += -a.delay;
        a.delay = 0;
      } else {
        a.t += dt;
      }
      final k = (a.t / a.duration).clamp(0.0, 1.0);
      a.apply(a.curve.transform(k));
      if (k >= 1) {
        _anims.remove(a);
        a.done.complete();
      }
    }
  }

  @override
  void onRemove() {
    for (final a in _anims) {
      if (!a.done.isCompleted) a.done.complete();
    }
    _anims.clear();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    if (opacity <= 0.01 || scaleK <= 0.01) return;
    final w = size.x;
    final c = Offset(w / 2, size.y / 2);
    var s = scaleK;
    if (hinting) s *= 1 + 0.08 * math.sin(_clock * 6).abs();
    if (selected || hinting) {
      _glowPaint.color = selected ? const Color(0xAAFFFFFF) : const Color(0x99FFD54F);
      canvas.drawCircle(c, w * 0.47, _glowPaint);
    }
    if (piece.armed) {
      final pulse = 0.5 + 0.5 * math.sin(_clock * 10);
      _glowPaint.color = Color.fromRGBO(255, 140, 0, 0.35 + 0.35 * pulse);
      canvas.drawCircle(c, w * (0.46 + 0.05 * pulse), _glowPaint);
    }
    final dw = w * s * squashX;
    final dh = w * s * squashY;
    final bottom = c.dy + w * s / 2;
    final dst = Rect.fromLTWH(c.dx - dw / 2, bottom - dh, dw, dh);
    _imagePaint.color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      _imagePaint,
    );
  }
}

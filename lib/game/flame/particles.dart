import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

/// A pooled particle system: all particles live in fixed-size typed arrays
/// that are reused, so bursts never allocate objects (smooth 60 fps).
class ParticleLayer extends Component {
  ParticleLayer() : super(priority: 50);

  static const int capacity = 900;

  final _x = Float32List(capacity);
  final _y = Float32List(capacity);
  final _vx = Float32List(capacity);
  final _vy = Float32List(capacity);
  final _g = Float32List(capacity);
  final _life = Float32List(capacity);
  final _maxLife = Float32List(capacity);
  final _size = Float32List(capacity);
  final _rot = Float32List(capacity);
  final _color = Uint32List(capacity);
  final _shape = Uint8List(capacity);
  int _count = 0;
  final _rand = math.Random();
  final Paint _paint = Paint();

  int get activeCount => _count;

  static const int circle = 0;
  static const int crumb = 1;
  static const int sparkle = 2;

  /// Shoots [count] particles out of [at].
  void burst(
    Vector2 at,
    Color color, {
    int count = 10,
    double speed = 170,
    double size = 5,
    double life = 0.55,
    int shape = circle,
    double gravity = 520,
    double upward = 60,
  }) {
    for (var n = 0; n < count; n++) {
      if (_count >= capacity) return;
      final i = _count++;
      final a = _rand.nextDouble() * math.pi * 2;
      final v = speed * (0.35 + _rand.nextDouble() * 0.65);
      _x[i] = at.x;
      _y[i] = at.y;
      _vx[i] = math.cos(a) * v;
      _vy[i] = math.sin(a) * v - upward;
      _g[i] = gravity;
      final l = life * (0.6 + _rand.nextDouble() * 0.5);
      _life[i] = l;
      _maxLife[i] = l;
      _size[i] = size * (0.6 + _rand.nextDouble() * 0.7);
      _rot[i] = _rand.nextDouble() * math.pi;
      _color[i] = color.toARGB32();
      _shape[i] = shape;
    }
  }

  @override
  void update(double dt) {
    var i = 0;
    while (i < _count) {
      final l = _life[i] - dt;
      if (l <= 0) {
        _count--;
        _copy(_count, i);
        continue;
      }
      _life[i] = l;
      _vy[i] += _g[i] * dt;
      _vx[i] *= 0.985;
      _x[i] += _vx[i] * dt;
      _y[i] += _vy[i] * dt;
      _rot[i] += dt * 5;
      i++;
    }
  }

  void _copy(int from, int to) {
    _x[to] = _x[from];
    _y[to] = _y[from];
    _vx[to] = _vx[from];
    _vy[to] = _vy[from];
    _g[to] = _g[from];
    _life[to] = _life[from];
    _maxLife[to] = _maxLife[from];
    _size[to] = _size[from];
    _rot[to] = _rot[from];
    _color[to] = _color[from];
    _shape[to] = _shape[from];
  }

  @override
  void render(Canvas canvas) {
    for (var i = 0; i < _count; i++) {
      final k = _life[i] / _maxLife[i];
      final argb = _color[i];
      final alpha = ((argb >>> 24) * math.min(1.0, k * 1.6)).round();
      _paint.color = Color((argb & 0x00FFFFFF) | (alpha << 24));
      final s = _size[i] * (0.5 + 0.5 * k);
      switch (_shape[i]) {
        case crumb:
          canvas.save();
          canvas.translate(_x[i], _y[i]);
          canvas.rotate(_rot[i]);
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: s * 1.6, height: s), _paint);
          canvas.restore();
        case sparkle:
          final x = _x[i];
          final y = _y[i];
          canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: s * 2.4, height: s * 0.5), _paint);
          canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: s * 0.5, height: s * 2.4), _paint);
        default:
          canvas.drawCircle(Offset(_x[i], _y[i]), s, _paint);
      }
    }
  }
}

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

/// A pooled particle system: all particles live in fixed-size typed arrays
/// that are reused, so bursts never allocate objects, and all of them are
/// drawn with a single `drawRawAtlas` call (smooth 60 fps on slow phones).
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
  final Paint _paint = Paint()..filterQuality = FilterQuality.low;

  // Per-frame draw data for drawRawAtlas (reused every frame).
  final _xform = Float32List(capacity * 4);
  final _rects = Float32List(capacity * 4);
  final _colors = Int32List(capacity);

  /// White shapes (circle, crumb, sparkle) in one small image; each particle
  /// is drawn as a tinted, scaled and rotated copy of one of them.
  static Image? _atlas;
  static const double _cell = 64;

  /// How many atlas pixels one unit of particle size is, per shape.
  static const _unit = [30.0, 30.0, 25.0];

  static Image _buildAtlas() {
    final rec = PictureRecorder();
    final c = Canvas(rec);
    final p = Paint()..color = const Color(0xFFFFFFFF);
    // circle: radius 1 unit
    c.drawCircle(const Offset(32, 32), 30, p);
    // crumb: 1.6 x 1 units
    c.drawRect(Rect.fromCenter(center: const Offset(96, 32), width: 48, height: 30), p);
    // sparkle: a cross 2.4 units long, 0.5 units thick
    c.drawRect(Rect.fromCenter(center: const Offset(160, 32), width: 60, height: 12.5), p);
    c.drawRect(Rect.fromCenter(center: const Offset(160, 32), width: 12.5, height: 60), p);
    final picture = rec.endRecording();
    final image = picture.toImageSync(3 * _cell.toInt(), _cell.toInt());
    picture.dispose();
    return image;
  }

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
    if (_count == 0) return;
    final atlas = _atlas ??= _buildAtlas();
    for (var i = 0; i < _count; i++) {
      final k = _life[i] / _maxLife[i];
      final argb = _color[i];
      final alpha = ((argb >>> 24) * math.min(1.0, k * 1.6)).round();
      _colors[i] = (argb & 0x00FFFFFF) | (alpha << 24);
      final shape = _shape[i];
      final scale = _size[i] * (0.5 + 0.5 * k) / _unit[shape];
      // Sparkles do not spin.
      final rot = shape == crumb ? _rot[i] : 0.0;
      final scos = math.cos(rot) * scale;
      final ssin = math.sin(rot) * scale;
      const half = _cell / 2;
      final j = i * 4;
      _xform[j] = scos;
      _xform[j + 1] = ssin;
      _xform[j + 2] = _x[i] - scos * half + ssin * half;
      _xform[j + 3] = _y[i] - ssin * half - scos * half;
      final left = shape * _cell;
      _rects[j] = left;
      _rects[j + 1] = 0;
      _rects[j + 2] = left + _cell;
      _rects[j + 3] = _cell;
    }
    canvas.drawRawAtlas(
      atlas,
      Float32List.sublistView(_xform, 0, _count * 4),
      Float32List.sublistView(_rects, 0, _count * 4),
      Int32List.sublistView(_colors, 0, _count),
      BlendMode.modulate,
      null,
      _paint,
    );
  }
}

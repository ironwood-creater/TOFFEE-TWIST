/// A small, fast, deterministic random number generator (xorshift128).
///
/// We use our own generator instead of `dart:math` so that a given seed gives
/// exactly the same numbers on Android, on the web and in the command-line
/// level simulator. Only 32-bit shifts and xors are used, which behave the same
/// on every Dart platform.
class Rng {
  static const int _mask = 0xFFFFFFFF;

  int _x;
  int _y;
  int _z;
  int _w;

  /// Creates a generator from a seed. Seeds should fit in 32 bits.
  factory Rng(int seed) {
    final s = seed & _mask;
    final rng = Rng._(
      (s ^ 123456789) & _mask,
      (362436069 ^ ((s << 7) & _mask)) & _mask,
      (521288629 ^ (s >>> 3)) & _mask,
      (88675123 ^ ((s << 13) & _mask)) & _mask,
    );
    if ((rng._x | rng._y | rng._z | rng._w) == 0) rng._w = 1;
    // Warm up so that similar seeds quickly diverge.
    for (var i = 0; i < 16; i++) {
      rng.nextUint32();
    }
    return rng;
  }

  Rng._(this._x, this._y, this._z, this._w);

  /// An independent copy that continues with the same sequence.
  Rng copy() => Rng._(_x, _y, _z, _w);

  int nextUint32() {
    final t = (_x ^ ((_x << 11) & _mask)) & _mask;
    _x = _y;
    _y = _z;
    _z = _w;
    _w = (_w ^ (_w >>> 19) ^ (t ^ (t >>> 8))) & _mask;
    return _w;
  }

  /// A random int in `[0, max)`.
  int nextInt(int max) {
    assert(max > 0);
    return nextUint32() % max;
  }

  /// A random int in `[min, max]` (both inclusive).
  int range(int min, int max) => min + nextInt(max - min + 1);

  /// A random double in `[0, 1)`.
  double nextDouble() => nextUint32() / 4294967296.0;

  bool chance(double probability) => nextDouble() < probability;

  T pick<T>(List<T> items) => items[nextInt(items.length)];

  /// Fisher-Yates shuffle in place.
  void shuffle<T>(List<T> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
  }
}

/// Mixes several integers into one 31-bit seed (used for per-level seeds).
int mixSeed(int a, [int b = 0, int c = 0]) {
  var h = 0x811C9DC5;
  for (final v in [a, b, c]) {
    var x = v & 0xFFFFFFFF;
    for (var i = 0; i < 4; i++) {
      h ^= x & 0xFF;
      // FNV-style mixing using shifts only (safe on every platform).
      h = (h ^ ((h << 5) & 0xFFFFFFFF) ^ (h >>> 2)) & 0xFFFFFFFF;
      h = (h + ((h << 3) & 0xFFFFFFFF) + 0x9E3779B9) & 0xFFFFFFFF;
      x >>>= 8;
    }
  }
  return h & 0x7FFFFFFF;
}

/// Basic shared types for the match-3 logic.
///
/// Everything inside `lib/game/logic` is plain Dart (no Flutter), so the same
/// code runs in the game, in unit tests and in the level simulator tool.
library;

/// The six sweets. The order is fixed because the index is used everywhere
/// (levels, saves, sprites).
enum Sweet {
  toffee('Toffee', 't'),
  cupcake('Cupcake', 'k'),
  donut('Donut', 'd'),
  macaron('Macaron', 'm'),
  lollipop('Lollipop', 'l'),
  chocolate('Chocolate', 'h');

  const Sweet(this.label, this.code);

  /// Name shown to players.
  final String label;

  /// One-letter code used in level preset layouts.
  final String code;

  static Sweet? fromName(String name) {
    for (final s in Sweet.values) {
      if (s.name == name) return s;
    }
    return null;
  }

  static Sweet? fromCode(String code) {
    for (final s in Sweet.values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// Special piece kinds.
///
/// * [stripedH] / [stripedV]: "Striped Toffee" - clears its row / column.
/// * [box]: "Sweet Box" - explodes a 3x3 area twice.
/// * [swirl]: "Toffee Swirl" - swap with a sweet to clear all of that color.
enum Special { none, stripedH, stripedV, box, swirl }

/// One piece on the board. Pieces are immutable; changes create a copy that
/// keeps the same [id] so the animation layer can follow it.
class Piece {
  const Piece({
    required this.id,
    required this.color,
    this.special = Special.none,
    this.isNut = false,
    this.armed = false,
    this.big = false,
  });

  final int id;

  /// Sweet index (0..5) or -1 for swirls and golden nuts.
  final int color;
  final Special special;

  /// A "golden nut": cannot be matched, must be brought to the bottom row.
  final bool isNut;

  /// A Sweet Box that already exploded once and will explode again.
  final bool armed;

  /// An armed box created from two Sweet Boxes (explodes 5x5).
  final bool big;

  bool get isSwirl => special == Special.swirl;
  bool get isSpecial => special != Special.none;
  bool get isStriped =>
      special == Special.stripedH || special == Special.stripedV;
  bool get isBox => special == Special.box;

  /// Can take part in a 3-in-a-row match.
  bool get matchable => !isNut && !armed && color >= 0;

  /// Can be moved by the player.
  bool get swappable => !armed;

  Piece copyWith({int? color, Special? special, bool? armed, bool? big}) =>
      Piece(
        id: id,
        color: color ?? this.color,
        special: special ?? this.special,
        isNut: isNut,
        armed: armed ?? this.armed,
        big: big ?? this.big,
      );

  @override
  String toString() {
    if (isNut) return 'Nut#$id';
    if (isSwirl) return 'Swirl#$id';
    final c = color >= 0 ? Sweet.values[color].name : '?';
    return '$c${special == Special.none ? '' : '(${special.name}${armed ? ',armed' : ''})'}#$id';
  }
}

/// A possible swap of two neighbouring cells (cell indexes).
class Move {
  const Move(this.a, this.b);
  final int a;
  final int b;

  @override
  bool operator ==(Object other) =>
      other is Move &&
      ((other.a == a && other.b == b) || (other.a == b && other.b == a));

  @override
  int get hashCode => a < b ? a * 1000 + b : b * 1000 + a;

  @override
  String toString() => 'Move($a<->$b)';
}

enum GameStatus { playing, won, lost }

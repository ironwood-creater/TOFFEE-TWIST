import 'package:toffeetwist/game/logic/board.dart';
import 'package:toffeetwist/game/logic/engine.dart';
import 'package:toffeetwist/game/logic/level.dart';
import 'package:toffeetwist/game/logic/types.dart';

/// Board pieces written as text, one token per cell, separated by spaces:
/// `t k d m l h` = sweets, followed by `-` (striped row), `|` (striped column)
/// or `b` (Sweet Box). `S` = Toffee Swirl, `N` = golden nut, `_` = empty,
/// `#` = hole or crate (no piece).
///
/// A 6x6 board with no matches that tests can modify:
const base6 = [
  't k d m t k',
  'k d m t k d',
  'd m t k d m',
  'm t k d m t',
  't k d m t k',
  'k d m t k d',
];

var _id = 50000;

Piece? parsePiece(String tok) {
  if (tok == '_' || tok == '#') return null;
  if (tok == 'N') return Piece(id: _id++, color: -1, isNut: true);
  if (tok == 'S') return Piece(id: _id++, color: -1, special: Special.swirl);
  final sweet = Sweet.fromCode(tok[0]);
  if (sweet == null) throw ArgumentError('bad token $tok');
  var special = Special.none;
  if (tok.length > 1) {
    special = switch (tok[1]) {
      '-' => Special.stripedH,
      '|' => Special.stripedV,
      'b' => Special.box,
      _ => throw ArgumentError('bad special in $tok'),
    };
  }
  return Piece(id: _id++, color: sweet.index, special: special);
}

List<List<String>> tokens(List<String> rows) =>
    [for (final r in rows) r.trim().split(RegExp(r'\s+'))];

/// A bare board (no level) for match-finding tests.
Board boardFrom(List<String> rows) {
  final t = tokens(rows);
  final b = Board.shape(t.length, t.first.length,
      [for (final row in t) for (final tok in row) tok != '#']);
  for (var r = 0; r < t.length; r++) {
    for (var c = 0; c < t[r].length; c++) {
      b.pieces[b.index(r, c)] = parsePiece(t[r][c]);
    }
  }
  return b;
}

/// Builds a test level. [board] uses the level legend (`.` `#` `c` `C` `1-3` `n`).
LevelDef testLevel({
  required int rows,
  required int cols,
  List<String>? board,
  List<GoalDef> goals = const [GoalDef.score(1000000)],
  int moves = 20,
  List<int> colors = const [0, 1, 2, 3, 4, 5],
}) =>
    LevelDef(
      id: 1,
      moves: moves,
      colors: colors,
      board: board ?? List.filled(rows, '.' * cols),
      goals: goals,
      stars: const [100, 200, 300],
    );

/// An engine whose pieces are exactly [pieces] (overwriting the random fill).
GameEngine engineWith(
  List<String> pieces, {
  List<String>? board,
  List<GoalDef> goals = const [GoalDef.score(1000000)],
  int moves = 20,
  int seed = 7,
  List<int> colors = const [0, 1, 2, 3, 4, 5],
}) {
  final t = tokens(pieces);
  final level = testLevel(
    rows: t.length,
    cols: t.first.length,
    board: board,
    goals: goals,
    moves: moves,
    colors: colors,
  );
  final e = GameEngine(level, seed: seed);
  setPieces(e, pieces);
  return e;
}

void setPieces(GameEngine e, List<String> pieces) {
  final t = tokens(pieces);
  for (var r = 0; r < t.length; r++) {
    for (var c = 0; c < t[r].length; c++) {
      final i = e.board.index(r, c);
      e.board.pieces[i] = e.board.holdsPiece(i) ? parsePiece(t[r][c]) : null;
    }
  }
}

/// Replaces one row of a text board.
List<String> withRow(List<String> rows, int r, String row) =>
    [for (var i = 0; i < rows.length; i++) i == r ? row : rows[i]];

int cell(GameEngine e, int r, int c) => e.board.index(r, c);

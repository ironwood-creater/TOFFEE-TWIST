import 'level.dart';
import 'types.dart';

/// The grid: which cells exist, the blockers on them and the pieces.
///
/// Cells are addressed by a single index `row * cols + col` (fast, and easy to
/// copy). Row 0 is the top row.
class Board {
  Board._({
    required this.rows,
    required this.cols,
    required this.playable,
    required this.caramel,
    required this.crate,
    required this.pieces,
    required this.spawnCell,
    required this.exitCell,
    required this.above,
    required this.below,
  });

  /// Creates an empty board with the given shape (true = cell exists).
  factory Board.shape(int rows, int cols, List<bool> playable) {
    final n = rows * cols;
    final above = List<int>.filled(n, -1);
    final below = List<int>.filled(n, -1);
    final spawn = List<int>.filled(cols, -1);
    final exit = List<int>.filled(cols, -1);
    for (var c = 0; c < cols; c++) {
      var last = -1;
      for (var r = 0; r < rows; r++) {
        final i = r * cols + c;
        if (!playable[i]) continue;
        if (spawn[c] < 0) spawn[c] = i;
        exit[c] = i;
        above[i] = last;
        if (last >= 0) below[last] = i;
        last = i;
      }
    }
    return Board._(
      rows: rows,
      cols: cols,
      playable: List.unmodifiable(playable),
      caramel: List<int>.filled(n, 0),
      crate: List<int>.filled(n, 0),
      pieces: List<Piece?>.filled(n, null),
      spawnCell: List.unmodifiable(spawn),
      exitCell: List.unmodifiable(exit),
      above: List.unmodifiable(above),
      below: List.unmodifiable(below),
    );
  }

  /// Builds the board shape and blockers from a level (pieces stay empty).
  factory Board.fromLevel(LevelDef level) {
    final rows = level.rows;
    final cols = level.cols;
    final playable = <bool>[
      for (final row in level.board)
        for (final ch in row.split('')) ch != '#',
    ];
    final b = Board.shape(rows, cols, playable);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final ch = level.board[r][c];
        final i = r * cols + c;
        switch (ch) {
          case 'c':
            b.caramel[i] = 1;
          case 'C':
            b.caramel[i] = 2;
          case '1' || '2' || '3':
            b.crate[i] = int.parse(ch);
        }
      }
    }
    return b;
  }

  final int rows;
  final int cols;

  /// False for holes.
  final List<bool> playable;

  /// Caramel layers under each cell (0, 1 or 2).
  final List<int> caramel;

  /// Wooden crate hit points (0 = no crate). A crate cell holds no piece.
  final List<int> crate;
  final List<Piece?> pieces;

  /// Top-most cell of each column (new sweets appear here), -1 if none.
  final List<int> spawnCell;

  /// Bottom-most cell of each column (golden nuts leave here), -1 if none.
  final List<int> exitCell;

  /// Next existing cell above / below each cell (holes are skipped), or -1.
  final List<int> above;
  final List<int> below;

  int get length => rows * cols;
  int index(int r, int c) => r * cols + c;
  int rowOf(int i) => i ~/ cols;
  int colOf(int i) => i % cols;

  /// True if the cell exists and is not covered by a crate.
  bool holdsPiece(int i) => playable[i] && crate[i] == 0;

  /// Cell index of the neighbour in direction (dr, dc), or -1.
  int neighbor(int i, int dr, int dc) {
    final r = rowOf(i) + dr;
    final c = colOf(i) + dc;
    if (r < 0 || r >= rows || c < 0 || c >= cols) return -1;
    return r * cols + c;
  }

  bool areAdjacent(int a, int b) {
    final dr = (rowOf(a) - rowOf(b)).abs();
    final dc = (colOf(a) - colOf(b)).abs();
    return dr + dc == 1;
  }

  /// Color used for matching at [i], or -1 if the cell cannot match.
  int matchColor(int i) {
    final p = pieces[i];
    return (p == null || !p.matchable) ? -1 : p.color;
  }

  Board clone() => Board._(
        rows: rows,
        cols: cols,
        playable: playable,
        caramel: List.of(caramel),
        crate: List.of(crate),
        pieces: List.of(pieces),
        spawnCell: spawnCell,
        exitCell: exitCell,
        above: above,
        below: below,
      );

  /// Debug picture of the board, one line per row.
  String dump() {
    final sb = StringBuffer();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = index(r, c);
        if (!playable[i]) {
          sb.write(' #');
        } else if (crate[i] > 0) {
          sb.write(' ${crate[i]}');
        } else {
          final p = pieces[i];
          if (p == null) {
            sb.write(' _');
          } else if (p.isNut) {
            sb.write(' n');
          } else if (p.isSwirl) {
            sb.write(' S');
          } else {
            final ch = Sweet.values[p.color].code;
            sb.write(p.isSpecial ? ' ${ch.toUpperCase()}' : ' $ch');
          }
        }
      }
      sb.writeln();
    }
    return sb.toString();
  }
}

import 'board.dart';
import 'types.dart';

/// A straight line of 3 or more same-colored sweets.
class MatchRun {
  const MatchRun(this.cells, {required this.horizontal});
  final List<int> cells;
  final bool horizontal;
  int get length => cells.length;
}

/// Connected runs of one color that clear together (a line, an L, a T, a +).
class MatchGroup {
  MatchGroup(this.color, this.cells, this.runs);

  final int color;
  final List<int> cells;
  final List<MatchRun> runs;

  int get longestRun => runs.fold(0, (m, r) => r.length > m ? r.length : m);
  bool get hasHorizontal => runs.any((r) => r.horizontal);
  bool get hasVertical => runs.any((r) => !r.horizontal);

  /// The special piece this match creates.
  /// 5 in a line -> Toffee Swirl, L/T/+ -> Sweet Box, 4 in a line -> Striped.
  Special get special {
    final longest = longestRun;
    if (longest >= 5) return Special.swirl;
    if (hasHorizontal && hasVertical) return Special.box;
    if (longest == 4) {
      return runs.first.horizontal ? Special.stripedH : Special.stripedV;
    }
    return Special.none;
  }

  /// A cell shared by a horizontal and a vertical run (corner of an L/T).
  int? get intersection {
    for (final h in runs.where((r) => r.horizontal)) {
      for (final v in runs.where((r) => !r.horizontal)) {
        for (final c in h.cells) {
          if (v.cells.contains(c)) return c;
        }
      }
    }
    return null;
  }

  /// Middle cell of the longest run (fallback place for a new special).
  int get middle {
    var best = runs.first;
    for (final r in runs) {
      if (r.length > best.length) best = r;
    }
    return best.cells[(best.length - 1) ~/ 2];
  }
}

/// Finds every match group currently on the board.
List<MatchGroup> findMatches(Board b) {
  final runs = <MatchRun>[];
  final rows = b.rows;
  final cols = b.cols;

  for (var r = 0; r < rows; r++) {
    var c = 0;
    while (c < cols) {
      final color = b.matchColor(r * cols + c);
      if (color < 0) {
        c++;
        continue;
      }
      var e = c + 1;
      while (e < cols && b.matchColor(r * cols + e) == color) {
        e++;
      }
      if (e - c >= 3) {
        runs.add(MatchRun([for (var k = c; k < e; k++) r * cols + k], horizontal: true));
      }
      c = e;
    }
  }
  for (var c = 0; c < cols; c++) {
    var r = 0;
    while (r < rows) {
      final color = b.matchColor(r * cols + c);
      if (color < 0) {
        r++;
        continue;
      }
      var e = r + 1;
      while (e < rows && b.matchColor(e * cols + c) == color) {
        e++;
      }
      if (e - r >= 3) {
        runs.add(MatchRun([for (var k = r; k < e; k++) k * cols + c], horizontal: false));
      }
      r = e;
    }
  }
  if (runs.isEmpty) return const [];

  // Join runs that share a cell (union-find).
  final parent = List<int>.generate(runs.length, (i) => i);
  int find(int x) {
    while (parent[x] != x) {
      parent[x] = parent[parent[x]];
      x = parent[x];
    }
    return x;
  }

  final owner = <int, int>{};
  for (var ri = 0; ri < runs.length; ri++) {
    for (final cell in runs[ri].cells) {
      final other = owner[cell];
      if (other == null) {
        owner[cell] = ri;
      } else {
        parent[find(ri)] = find(other);
      }
    }
  }
  final byRoot = <int, List<MatchRun>>{};
  for (var ri = 0; ri < runs.length; ri++) {
    byRoot.putIfAbsent(find(ri), () => []).add(runs[ri]);
  }
  final groups = <MatchGroup>[];
  for (final groupRuns in byRoot.values) {
    final cells = <int>{for (final r in groupRuns) ...r.cells}.toList()..sort();
    groups.add(MatchGroup(b.matchColor(cells.first), cells, groupRuns));
  }
  groups.sort((x, y) => x.cells.first.compareTo(y.cells.first));
  return groups;
}

/// True if the sweet at [i] is part of a 3-in-a-row.
bool hasMatchAt(Board b, int i) {
  final color = b.matchColor(i);
  if (color < 0) return false;
  final r = b.rowOf(i);
  final c = b.colOf(i);
  var count = 1;
  for (var k = c - 1; k >= 0 && b.matchColor(r * b.cols + k) == color; k--) {
    count++;
  }
  for (var k = c + 1; k < b.cols && b.matchColor(r * b.cols + k) == color; k++) {
    count++;
  }
  if (count >= 3) return true;
  count = 1;
  for (var k = r - 1; k >= 0 && b.matchColor(k * b.cols + c) == color; k--) {
    count++;
  }
  for (var k = r + 1; k < b.rows && b.matchColor(k * b.cols + c) == color; k++) {
    count++;
  }
  return count >= 3;
}

/// True if swapping cells [a] and [b] is a legal move: it makes a match, or
/// it combines special pieces.
bool isValidSwap(Board board, int a, int b) {
  final pa = board.pieces[a];
  final pb = board.pieces[b];
  if (pa == null || pb == null || !pa.swappable || !pb.swappable) return false;
  if (!board.areAdjacent(a, b)) return false;
  if (pa.isSpecial && pb.isSpecial) return true;
  if (pa.isSwirl && pb.matchable) return true;
  if (pb.isSwirl && pa.matchable) return true;
  board.pieces[a] = pb;
  board.pieces[b] = pa;
  final ok = hasMatchAt(board, a) || hasMatchAt(board, b);
  board.pieces[a] = pa;
  board.pieces[b] = pb;
  return ok;
}

/// All legal moves on the board.
List<Move> findPossibleMoves(Board board) {
  final moves = <Move>[];
  for (var i = 0; i < board.length; i++) {
    final p = board.pieces[i];
    if (p == null || !p.swappable) continue;
    final right = board.colOf(i) + 1 < board.cols ? i + 1 : -1;
    final down = board.rowOf(i) + 1 < board.rows ? i + board.cols : -1;
    for (final j in [right, down]) {
      if (j >= 0 && isValidSwap(board, i, j)) moves.add(Move(i, j));
    }
  }
  return moves;
}

bool hasPossibleMove(Board board) {
  for (var i = 0; i < board.length; i++) {
    final p = board.pieces[i];
    if (p == null || !p.swappable) continue;
    if (board.colOf(i) + 1 < board.cols && isValidSwap(board, i, i + 1)) return true;
    if (board.rowOf(i) + 1 < board.rows && isValidSwap(board, i, i + board.cols)) {
      return true;
    }
  }
  return false;
}

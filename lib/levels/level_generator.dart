import 'dart:math' as math;

import '../game/logic/level.dart';
import '../game/logic/rng.dart';

/// Deterministic level generator for levels 31-500.
///
/// The same (level id, attempt) always produces the same level, on every
/// platform. Moves and star scores are placeholders here; the build tool sets
/// them from bot simulations (see `tool/build_levels.dart`).
class LevelGenerator {
  static const int firstGenerated = 31;
  static const int lastLevel = 500;

  /// Every 10th level is hard, the one after it is an easier "relief" level.
  static LevelKind kindFor(int id) {
    if (id % 10 == 0) return LevelKind.hard;
    if (id % 10 == 1) return LevelKind.relief;
    return LevelKind.normal;
  }

  /// 0 at level 31, 1 at level 500.
  static double difficulty(int id) =>
      ((id - firstGenerated) / (lastLevel - firstGenerated)).clamp(0.0, 1.0);

  /// Allowed bot win-rate band for a level kind.
  static (double, double) band(LevelKind kind) =>
      kind == LevelKind.hard ? (0.30, 0.50) : (0.60, 0.85);

  /// The bot win rate we aim for: slowly harder over time, a dip on hard
  /// levels and an easy level right after.
  static double targetWinRate(int id) {
    final d = difficulty(id);
    return switch (kindFor(id)) {
      LevelKind.hard => 0.46 - 0.10 * d,
      LevelKind.relief => 0.84,
      _ => 0.82 - 0.15 * d - ((id % 10) - 5).abs() * 0.004,
    };
  }

  LevelDef generate(int id, int attempt) {
    final rng = Rng(mixSeed(id, attempt, 7919));
    final kind = kindFor(id);
    final d = difficulty(id);
    // Retries get gradually simpler so a valid level is always found.
    final soften = attempt >= 6 ? (attempt - 5) * 0.07 : 0.0;
    final effort = (switch (kind) {
              LevelKind.hard => 0.35 + 0.65 * d,
              LevelKind.relief => 0.05 + 0.45 * d,
              _ => 0.08 + 0.82 * d,
            } -
            soften)
        .clamp(0.0, 1.0);

    var board = _shape(rng, effort);
    final colors = _colors(rng, kind, d, soften);
    final theme = _theme(id, attempt, rng, kind);
    final goals = <GoalDef>[];
    final parts = theme.split('+');

    for (final part in parts) {
      switch (part) {
        case 'caramel':
          board = _caramel(board, rng, effort, twoLayers: false);
          goals.add(const GoalDef.caramel());
        case 'caramel2':
          board = _caramel(board, rng, effort, twoLayers: true);
          goals.add(const GoalDef.caramel());
        case 'crates':
          board = _crates(board, rng, effort, heavy: false, keepBottom: parts.contains('nuts'));
          goals.add(const GoalDef.crates());
        case 'crates3':
          board = _crates(board, rng, effort, heavy: true, keepBottom: parts.contains('nuts'));
          goals.add(const GoalDef.crates());
        case 'nuts':
          final count = 1 + (effort * 3).round() - (parts.length > 1 ? 1 : 0);
          final n = math.max(1, count);
          final maxOn = n >= 3 ? 2 : 1;
          board = _nutStarts(board, rng, math.min(n, maxOn));
          goals.add(GoalDef.nuts(n, maxOnBoard: maxOn));
        case 'score':
          final target = ((3000 + 14000 * effort) / 500).round() * 500;
          goals.add(GoalDef.score(target));
        case 'collect':
          final kinds = parts.length == 1 && effort > 0.35 && rng.chance(0.6) ? 2 : 1;
          final pool = List.of(colors);
          rng.shuffle(pool);
          for (var k = 0; k < kinds; k++) {
            final base = 16 + 26 * effort + rng.range(-3, 3);
            final count = (base / (parts.length > 1 ? 1.4 : 1) / (kinds == 2 ? 1.25 : 1)).round();
            goals.add(GoalDef.collect(pool[k], math.max(8, count)));
          }
      }
    }

    return LevelDef(
      id: id,
      moves: 30,
      colors: colors,
      board: board,
      goals: goals,
      stars: const [1000, 2000, 3000],
      kind: kind,
      seed: mixSeed(id, attempt, 7919),
    );
  }

  // ---------------------------------------------------------------------------
  // Goal themes
  // ---------------------------------------------------------------------------

  static const _normalThemes = [
    'collect',
    'caramel',
    'crates',
    'nuts',
    'caramel+collect',
    'score',
    'crates+collect',
    'caramel2',
    'nuts+collect',
    'caramel+crates',
    'crates3',
    'nuts+caramel',
    'collect',
    'caramel2+crates',
    'nuts+crates',
  ];
  static const _hardThemes = [
    'caramel2+crates3',
    'nuts+caramel2',
    'crates3+collect',
    'caramel2+collect',
    'nuts+crates3',
    'caramel+crates3',
  ];
  static const _reliefThemes = ['collect', 'score', 'caramel', 'nuts', 'crates'];

  String _theme(int id, int attempt, Rng rng, LevelKind kind) {
    final list = switch (kind) {
      LevelKind.hard => _hardThemes,
      LevelKind.relief => _reliefThemes,
      _ => _normalThemes,
    };
    final index = (id * 7 + attempt * 5 + rng.nextInt(2)) % list.length;
    // Early generated levels avoid the toughest combinations.
    final theme = list[index];
    if (attempt >= 10 && theme.contains('+')) return theme.split('+').first;
    return theme;
  }

  List<int> _colors(Rng rng, LevelKind kind, double d, double soften) {
    var n = switch (kind) {
      LevelKind.relief => rng.chance(0.3 + d * 0.4) ? 5 : 4,
      LevelKind.hard => rng.chance(0.25 + 0.45 * d) ? 6 : 5,
      _ => rng.chance(d * 0.35) ? 6 : (d < 0.2 && rng.chance(0.25) ? 4 : 5),
    };
    if (soften > 0.2 && n > 4) n--;
    final all = [0, 1, 2, 3, 4, 5];
    rng.shuffle(all);
    return all.take(n).toList()..sort();
  }

  // ---------------------------------------------------------------------------
  // Board shapes
  // ---------------------------------------------------------------------------

  static const _shapes = <List<String>>[
    ['.........', '.........', '.........', '.........', '.........', '.........', '.........', '.........', '.........'],
    ['#.......#', '.........', '.........', '.........', '.........', '.........', '.........', '.........', '#.......#'],
    ['##.....##', '#.......#', '.........', '.........', '.........', '.........', '.........', '#.......#', '##.....##'],
    ['###...###', '##.....##', '#.......#', '.........', '.........', '.........', '#.......#', '##.....##', '###...###'],
    ['.........', '.........', '#.......#', '##.....##', '###...###', '##.....##', '#.......#', '.........', '.........'],
    ['.........', '.........', '.........', '..#...#..', '..#...#..', '..#...#..', '.........', '.........', '.........'],
    ['##.....##', '##.....##', '.........', '.........', '.........', '.........', '.........', '##.....##', '##.....##'],
    ['#..###..#', '.........', '.........', '.........', '#.......#', '##.....##', '###...###', '####.####'],
    ['.........', '.........', '.........', '###...###', '###...###', '.........', '.........', '.........', '.........'],
    ['.........', '.........', '.........', '.........', '.........', '....#....', '...###...', '..#####..', '..#####..'],
    ['....#....', '....#....', '....#....', '....#....', '....#....', '....#....', '....#....', '....#....', '....#....'],
    ['.........', '.........', '.........', '...###...', '...###...', '...###...', '.........', '.........', '.........'],
    ['........', '........', '........', '........', '........', '........', '........', '........'],
    ['#......#', '........', '........', '........', '........', '........', '........', '#......#'],
    ['.........', '.........', '.........', '.........', '.........', '.........', '.........', '.........'],
  ];

  List<String> _shape(Rng rng, double effort) {
    var rows = [for (final r in rng.pick(_shapes)) r.split('')];
    if (rng.chance(0.3)) rows = rows.reversed.toList();
    // Optional symmetric notches at the edges.
    if (rng.chance(0.35)) {
      final cols = rows.first.length;
      final notches = rng.range(1, 3);
      for (var k = 0; k < notches; k++) {
        final r = rng.nextInt(rows.length);
        final c = rng.range(0, 1);
        final copy = [for (final row in rows) List.of(row)];
        copy[r][c] = '#';
        copy[r][cols - 1 - c] = '#';
        if (_valid(copy)) rows = copy;
      }
    }
    return [for (final r in rows) r.join()];
  }

  /// Every cell must touch another cell and there must be enough room.
  bool _valid(List<List<String>> rows) {
    var count = 0;
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        if (rows[r][c] == '#') continue;
        count++;
        var near = false;
        for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final rr = r + dr;
          final cc = c + dc;
          if (rr >= 0 && cc >= 0 && rr < rows.length && cc < rows[r].length && rows[rr][cc] != '#') {
            near = true;
          }
        }
        if (!near) return false;
      }
    }
    return count >= 45;
  }

  // ---------------------------------------------------------------------------
  // Blockers
  // ---------------------------------------------------------------------------

  List<String> _set(List<String> board, Iterable<(int, int)> cells, String ch, {bool onlyPlain = true}) {
    final rows = [for (final r in board) r.split('')];
    for (final (r, c) in cells) {
      if (r < 0 || c < 0 || r >= rows.length || c >= rows[r].length) continue;
      if (rows[r][c] == '#') continue;
      if (onlyPlain && rows[r][c] != '.' && !(ch == 'C' && rows[r][c] == 'c')) continue;
      rows[r][c] = ch;
    }
    return [for (final r in rows) r.join()];
  }

  Iterable<(int, int)> _rect(int r0, int c0, int r1, int c1) sync* {
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        yield (r, c);
      }
    }
  }

  List<String> _caramel(List<String> board, Rng rng, double effort, {required bool twoLayers}) {
    final rows = board.length;
    final cols = board.first.length;
    final cr = rows ~/ 2;
    final cc = cols ~/ 2;
    final size = 1 + (effort * 3).round();
    final pattern = rng.nextInt(7);
    final cells = <(int, int)>[
      ...switch (pattern) {
        0 => _rect(cr - size, cc - size, cr + size, cc + size),
        1 => _rect(rows - 1 - size, 0, rows - 1, cols - 1),
        2 => _rect(0, 0, size, cols - 1),
        3 => [
            ..._rect(cr - size, cc - size, cr - size, cc + size),
            ..._rect(cr + size, cc - size, cr + size, cc + size),
            ..._rect(cr - size, cc - size, cr + size, cc - size),
            ..._rect(cr - size, cc + size, cr + size, cc + size),
          ],
        4 => [..._rect(cr - 1, 0, cr + 1, cols - 1), ..._rect(0, cc - 1, rows - 1, cc + 1)],
        5 => [
            for (final (r, c) in _rect(cr - size - 1, cc - size - 1, cr + size + 1, cc + size + 1))
              if ((r + c).isEven) (r, c),
          ],
        _ => [
            ..._rect(0, 0, size, size),
            ..._rect(0, cols - 1 - size, size, cols - 1),
            ..._rect(rows - 1 - size, 0, rows - 1, size),
            ..._rect(rows - 1 - size, cols - 1 - size, rows - 1, cols - 1),
          ],
      },
    ];
    var out = _set(board, cells, 'c');
    if (twoLayers) {
      final inner = math.max(0, size - 1);
      final layer2 = switch (pattern) {
        1 => _rect(rows - 1 - inner, 0, rows - 1, cols - 1),
        2 => _rect(0, 0, inner, cols - 1),
        _ => _rect(cr - inner, cc - inner, cr + inner, cc + inner),
      };
      out = _set(out, layer2, 'C');
    }
    return out;
  }

  List<String> _crates(List<String> board, Rng rng, double effort,
      {required bool heavy, required bool keepBottom}) {
    final rows = board.length;
    final cols = board.first.length;
    final pairs = 1 + (effort * 4).round();
    var out = board;
    final maxRow = keepBottom ? rows - 3 : rows - 2;
    for (var k = 0; k < pairs; k++) {
      final r = rng.range(1, maxRow);
      final c = rng.range(0, cols ~/ 2);
      int hp;
      if (heavy) {
        hp = rng.chance(0.4 + effort * 0.3) ? 3 : 2;
      } else {
        hp = effort > 0.45 && rng.chance(effort * 0.6) ? 2 : 1;
      }
      final ch = '$hp';
      out = _set(out, [(r, c), (r, cols - 1 - c)], ch);
    }
    // A small row of crates sometimes.
    if (rng.chance(0.3)) {
      final r = rng.range(2, maxRow);
      final len = 1 + (effort * 2).round();
      out = _set(out, _rect(r, cols ~/ 2 - len ~/ 2, r, cols ~/ 2 + len ~/ 2), heavy ? '2' : '1');
    }
    // Always at least one crate.
    if (!out.join().contains(RegExp('[123]'))) out = _set(out, [(rows ~/ 2, cols ~/ 2)], '1');
    return out;
  }

  List<String> _nutStarts(List<String> board, Rng rng, int n) {
    final cols = board.first.length;
    final starts = <(int, int)>[];
    final options = [for (var c = 1; c < cols - 1; c++) c]..remove(cols ~/ 2);
    rng.shuffle(options);
    final picks = n == 1 ? [cols ~/ 2] : options.take(n).toList();
    for (final c in picks) {
      for (var r = 0; r < board.length; r++) {
        if (board[r][c] == '.') {
          starts.add((r, c));
          break;
        }
      }
    }
    return _set(board, starts, 'n');
  }
}

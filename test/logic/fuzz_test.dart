import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:toffeetwist/game/logic/engine.dart';
import 'package:toffeetwist/game/logic/events.dart';
import 'package:toffeetwist/game/logic/level.dart';
import 'package:toffeetwist/game/logic/match_finder.dart';
import 'package:toffeetwist/game/logic/types.dart';

/// Replays engine events the same way the Flame board does, keeping track of
/// which piece is drawn in which cell. If the events ever disagree with the
/// engine, pieces would jump on screen at the end of a move.
class ShadowBoard {
  ShadowBoard(GameEngine e) : cells = [for (final p in e.board.pieces) p?.id] {
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] != null) where[cells[i]!] = i;
    }
  }

  final List<int?> cells;
  final Map<int, int> where = {};
  final List<String> problems = [];

  void _remove(int id, int cell, String what) {
    final at = where.remove(id);
    if (at == null) {
      problems.add('$what: piece $id is not on screen');
      return;
    }
    if (at != cell) problems.add('$what: piece $id is drawn at $at, event says $cell');
    if (cells[at] == id) cells[at] = null;
  }

  void _put(int id, int cell, String what) {
    final other = cells[cell];
    if (other != null && other != id) {
      problems.add('$what: cell $cell already shows piece $other (new $id)');
      where.remove(other);
    }
    cells[cell] = id;
    where[id] = cell;
  }

  void apply(List<BoardEvent> events) {
    for (final e in events) {
      switch (e) {
        case SwapEvent():
          if (!e.reverted) {
            final a = cells[e.a];
            final b = cells[e.b];
            cells[e.a] = b;
            cells[e.b] = a;
            if (a != null) where[a] = e.b;
            if (b != null) where[b] = e.a;
          }
        case ClearEvent():
          for (final cp in e.cleared) {
            _remove(cp.piece.id, cp.cell, 'clear');
          }
          for (final cp in e.armed) {
            if (where[cp.piece.id] != cp.cell) problems.add('armed: piece ${cp.piece.id} not at ${cp.cell}');
          }
          for (final cp in e.created) {
            _put(cp.piece.id, cp.cell, 'create');
          }
        case FallEvent():
          final moves = <int, int>{};
          for (final p in e.paths) {
            if (p.cells.length != p.ticks.length) problems.add('fall: cells/ticks length differ');
            for (var k = 1; k < p.ticks.length; k++) {
              if (p.ticks[k] < p.ticks[k - 1]) problems.add('fall: time goes backwards for ${p.piece.id}');
            }
            if (!p.spawned) {
              final at = where[p.piece.id];
              if (at == null) {
                problems.add('fall: piece ${p.piece.id} is not on screen');
              } else if (at != p.cells.first) {
                problems.add('fall: piece ${p.piece.id} is drawn at $at, path starts at ${p.cells.first}');
              }
              if (at != null && cells[at] == p.piece.id) cells[at] = null;
              where.remove(p.piece.id);
            }
            if (moves.containsKey(p.cells.last)) problems.add('fall: two pieces land on ${p.cells.last}');
            moves[p.cells.last] = p.piece.id;
          }
          moves.forEach((cell, id) => _put(id, cell, 'fall'));
        case ConvertEvent():
          for (final cp in e.changes) {
            if (where[cp.piece.id] != cp.cell) problems.add('convert: piece ${cp.piece.id} not at ${cp.cell}');
          }
        case NutsCollectedEvent():
          for (final cp in e.nuts) {
            _remove(cp.piece.id, cp.cell, 'nut');
          }
        case ShuffleEvent():
          for (final cp in e.after) {
            final at = where.remove(cp.piece.id);
            if (at == null) {
              problems.add('shuffle: piece ${cp.piece.id} is not on screen');
            } else if (cells[at] == cp.piece.id) {
              cells[at] = null;
            }
          }
          for (final cp in e.after) {
            _put(cp.piece.id, cp.cell, 'shuffle');
          }
        case BoosterEvent():
          break;
      }
    }
  }

  void compare(GameEngine e, String where_) {
    final b = e.board;
    for (var i = 0; i < b.length; i++) {
      final id = b.pieces[i]?.id;
      if (cells[i] != id) problems.add('$where_: cell $i shows ${cells[i]} but holds $id');
    }
  }
}

/// A cell may stay empty while a crate above it blocks falling pieces.
bool _underCrate(GameEngine e, int i) {
  final b = e.board;
  for (var k = b.above[i]; k >= 0; k = b.above[k]) {
    if (b.crate[k] > 0) return true;
    if (b.pieces[k] != null) return false;
  }
  return false;
}

List<String> checkInvariants(GameEngine e) {
  final out = <String>[];
  final b = e.board;
  final ids = <int>{};
  for (var i = 0; i < b.length; i++) {
    final p = b.pieces[i];
    if (!b.playable[i] && p != null) out.add('piece in hole $i');
    if (b.crate[i] > 0 && p != null) out.add('piece inside crate $i');
    if (b.holdsPiece(i) && p == null && !_underCrate(e, i)) out.add('empty cell $i after the move');
    if (p != null && !ids.add(p.id)) out.add('duplicate piece id ${p.id}');
    if (b.caramel[i] < 0 || b.caramel[i] > 2) out.add('bad caramel ${b.caramel[i]}');
    if (b.crate[i] < 0 || b.crate[i] > 3) out.add('bad crate ${b.crate[i]}');
  }
  if (findMatches(b).isNotEmpty && e.status == GameStatus.playing) {
    out.add('board still has a match after the move');
  }
  if (e.status == GameStatus.playing && !hasPossibleMove(b)) out.add('no possible move left');
  if (e.movesLeft < 0) out.add('negative moves');
  for (final g in e.goals.goals) {
    if (g.progress < 0) out.add('negative goal progress');
  }
  if (e.goals.allDone != (e.status == GameStatus.won)) {
    out.add('status ${e.status} but allDone=${e.goals.allDone}');
  }
  return out;
}

void main() {
  final files = Directory('assets/levels').listSync().whereType<File>().where((f) => RegExp(r'level_\d+\.json$').hasMatch(f.path)).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('random play on every level keeps the board and the animations consistent', () {
    final rnd = math.Random(7);
    var actions = 0;
    final failures = <String>[];
    for (final f in files) {
      final level = LevelDef.parse(f.readAsStringSync());
      for (var seed = 1; seed <= 2; seed++) {
        final e = GameEngine(level, seed: seed * 7919 + level.id);
        final shadow = ShadowBoard(e);
        final start = checkInvariants(e);
        // A fresh board may legitimately need a shuffle before the first move.
        if (start.any((s) => !s.contains('no possible move'))) {
          failures.add('L${level.id} s$seed start: $start');
          continue;
        }
        if (seed == 2) shadow.apply(e.applyStartBox());
        shadow.apply(e.shuffleIfNeeded());
        var guard = 0;
        while (e.status == GameStatus.playing && guard++ < 200) {
          final movesBefore = e.movesLeft;
          final scoreBefore = e.score;
          final roll = rnd.nextDouble();
          MoveResult r;
          var usesMove = false;
          if (roll < 0.05) {
            // Rolling pin on a random cell.
            r = e.useRollingPin(rnd.nextInt(e.board.length));
          } else if (roll < 0.10) {
            // Free swap of a random pair of neighbours.
            final a = rnd.nextInt(e.board.length);
            final b = e.board.neighbor(a, 0, 1);
            r = b < 0 ? MoveResult.invalid : e.freeSwap(a, b);
          } else if (roll < 0.15) {
            // A random (often invalid) swipe.
            final a = rnd.nextInt(e.board.length);
            final b = e.board.neighbor(a, 1, 0);
            r = b < 0 ? MoveResult.invalid : e.swap(a, b);
            usesMove = r.valid;
          } else {
            final moves = e.possibleMoves();
            final m = moves[rnd.nextInt(moves.length)];
            r = e.swap(m.a, m.b);
            usesMove = true;
            if (!r.valid) failures.add('L${level.id}: listed move ${m.a}-${m.b} was refused');
          }
          actions++;
          shadow.apply(r.events);
          final tag = 'L${level.id} s$seed move ${e.movesUsed}';
          shadow.compare(e, tag);
          if (shadow.problems.isNotEmpty) {
            failures.add('$tag: ${shadow.problems.take(3).join('; ')}');
            break;
          }
          final inv = checkInvariants(e);
          if (inv.isNotEmpty) {
            failures.add('$tag: $inv');
            break;
          }
          if (usesMove && e.movesLeft != movesBefore - 1) failures.add('$tag: moves did not go down by 1');
          if (!usesMove && e.movesLeft != movesBefore) failures.add('$tag: a booster used a move');
          if (e.score < scoreBefore) failures.add('$tag: score went down');
          if (e.status == GameStatus.lost && seed == 1 && e.movesUsed < 60) {
            // Continue once with +5 moves, as the game offers after losing.
            e.addMoves(5);
            shadow.apply(e.shuffleIfNeeded());
          }
        }
      }
      if (failures.length > 20) break;
    }
    // ignore: avoid_print
    print('fuzz: $actions actions on ${files.length} levels');
    expect(failures, isEmpty, reason: failures.take(20).join('\n'));
  }, timeout: const Timeout(Duration(minutes: 10)));
}

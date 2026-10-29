import 'package:flutter_test/flutter_test.dart';
import 'package:toffeetwist/game/logic/engine.dart';
import 'package:toffeetwist/game/logic/events.dart';
import 'package:toffeetwist/game/logic/level.dart';
import 'package:toffeetwist/game/logic/types.dart';

import 'helpers.dart';

void main() {
  // Row 5 match: drag the lollipop at (5,3) left onto (5,2) -> l l l.
  final matchBottom = withRow(base6, 5, 'l l k l k d');
  void playBottomMatch(GameEngine e) => e.swap(cell(e, 5, 3), cell(e, 5, 2));

  group('goals', () {
    test('collect goal counts the right sweets and wins', () {
      final e = engineWith(matchBottom, goals: const [GoalDef.collect(4, 3)]);
      expect(e.goals.goals.single.remaining, 3);
      playBottomMatch(e);
      expect(e.goals.goals.single.done, isTrue);
      expect(e.status, GameStatus.won);
      expect(e.stars, greaterThanOrEqualTo(1));
    });

    test('score goal completes when the score is reached', () {
      final e = engineWith(matchBottom, goals: const [GoalDef.score(50)]);
      playBottomMatch(e);
      expect(e.status, GameStatus.won);
    });

    test('caramel needs one hit per layer', () {
      final board = ['......', '......', '......', '......', '......', 'cC....'];
      final e = engineWith(matchBottom, board: board, goals: const [GoalDef.caramel()]);
      expect(e.goals.goals.single.target, 2);
      final r = e.swap(cell(e, 5, 3), cell(e, 5, 2));
      final clear = r.events.whereType<ClearEvent>().first;
      expect(clear.caramel.map((c) => c.value).toSet(), {0, 1});
      expect(e.board.caramel[cell(e, 5, 0)], 0);
      expect(e.board.caramel[cell(e, 5, 1)], lessThanOrEqualTo(1));
      expect(e.goals.goals.single.progress, greaterThanOrEqualTo(1));
    });

    test('a match next to a crate breaks it', () {
      final board = ['......', '......', '......', '......', '.1....', '......'];
      final rows = withRow(matchBottom, 4, 't # d m t k');
      final e = engineWith(rows, board: board, goals: const [GoalDef.crates()]);
      expect(e.goals.goals.single.target, 1);
      final r = e.swap(cell(e, 5, 3), cell(e, 5, 2));
      expect(r.events.whereType<ClearEvent>().first.crates.single.value, 0);
      expect(e.board.crate[cell(e, 4, 1)], 0);
      expect(e.status, GameStatus.won);
    });

    test('a golden nut reaching the bottom row is collected', () {
      final board = ['......', '......', '......', '......', 'n.....', '......'];
      final rows = withRow(matchBottom, 4, 'N k d m t k');
      final e = engineWith(rows, board: board, goals: const [GoalDef.nuts(1)]);
      final r = e.swap(cell(e, 5, 3), cell(e, 5, 2));
      expect(r.events.whereType<NutsCollectedEvent>(), isNotEmpty);
      expect(e.nutsCollected, 1);
      expect(e.status, GameStatus.won);
    });

    test('running out of moves loses; extra moves continue the game', () {
      final e = engineWith(matchBottom, moves: 1, goals: const [GoalDef.collect(4, 99)]);
      playBottomMatch(e);
      expect(e.status, GameStatus.lost);
      expect(e.stars, 0);
      e.addMoves(5);
      expect(e.status, GameStatus.playing);
      expect(e.movesLeft, 5);
    });

    test('the finale adds a bonus for each unused move', () {
      final e = engineWith(matchBottom, moves: 10, goals: const [GoalDef.collect(4, 3)]);
      playBottomMatch(e);
      final before = e.score;
      final bonus = e.applyFinale();
      expect(bonus, 9 * 250);
      expect(e.score, before + bonus);
      expect(e.applyFinale(), 0, reason: 'only once');
    });

    test('stars follow the level thresholds', () {
      final e = engineWith(matchBottom, goals: const [GoalDef.collect(4, 3)]);
      playBottomMatch(e);
      // Test levels use thresholds 100 / 200 / 300.
      expect(e.stars, e.score >= 300 ? 3 : (e.score >= 200 ? 2 : 1));
    });
  });
}

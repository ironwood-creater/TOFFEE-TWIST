import 'package:flutter_test/flutter_test.dart';
import 'package:toffeetwist/game/logic/engine.dart';
import 'package:toffeetwist/game/logic/events.dart';
import 'package:toffeetwist/game/logic/match_finder.dart';

import 'helpers.dart';

void main() {
  group('swapping', () {
    test('a swap without a match goes back and uses no move', () {
      final e = engineWith(base6);
      final before = [for (final p in e.board.pieces) p?.id];
      final r = e.swap(cell(e, 0, 4), cell(e, 0, 5));
      expect(r.valid, isFalse);
      expect(r.events.single, isA<SwapEvent>().having((s) => s.reverted, 'reverted', true));
      expect(e.movesLeft, 20);
      expect([for (final p in e.board.pieces) p?.id], before);
    });

    test('non-adjacent swaps are rejected', () {
      final e = engineWith(base6);
      expect(e.swap(cell(e, 0, 0), cell(e, 2, 2)).valid, isFalse);
      expect(e.swap(cell(e, 0, 5), cell(e, 1, 0)).valid, isFalse);
    });

    test('a matching swap clears, refills and uses a move', () {
      final e = engineWith(withRow(base6, 0, 'l l m l t k'));
      final r = e.swap(cell(e, 0, 3), cell(e, 0, 2));
      expect(r.valid, isTrue);
      expect(e.movesLeft, 19);
      expect(r.events.first, isA<SwapEvent>());
      final clear = r.events.whereType<ClearEvent>().first;
      expect(clear.cleared.map((c) => c.cell).toSet(), {0, 1, 2});
      expect(clear.cascade, 1);
      expect(e.score, greaterThan(0));
      // The board is full and calm afterwards.
      for (var i = 0; i < e.board.length; i++) {
        expect(e.board.pieces[i], isNotNull, reason: 'cell $i empty');
      }
      expect(findMatches(e.board), isEmpty);
      expect(hasPossibleMove(e.board), isTrue);
    });
  });

  group('gravity and refill', () {
    List<String> verticalSetup() {
      final rows = [...base6];
      rows[2] = 'h m t k d m';
      rows[3] = 'm l k d m t';
      rows[4] = 'l k d m t k';
      rows[5] = 'l h h t k d';
      return rows;
    }

    test('pieces above a cleared column fall down in order', () {
      final e = engineWith(verticalSetup());
      final ids = [for (var r = 0; r < 3; r++) e.board.pieces[cell(e, r, 0)]!.id];
      final r = e.swap(cell(e, 3, 1), cell(e, 3, 0));
      expect(r.valid, isTrue);
      final fall = r.events.whereType<FallEvent>().first;
      int endOf(int id) => fall.paths.firstWhere((p) => p.piece.id == id).cells.last;
      expect(endOf(ids[0]), cell(e, 3, 0));
      expect(endOf(ids[1]), cell(e, 4, 0));
      expect(endOf(ids[2]), cell(e, 5, 0));
      final spawned = fall.paths.where((p) => p.spawned).map((p) => p.cells.last).toSet();
      expect(spawned, {cell(e, 0, 0), cell(e, 1, 0), cell(e, 2, 0)});
    });

    test('falling pieces cause a cascade with a bigger multiplier', () {
      final e = engineWith(verticalSetup());
      final r = e.swap(cell(e, 3, 1), cell(e, 3, 0));
      final clears = r.events.whereType<ClearEvent>().toList();
      expect(clears.length, greaterThanOrEqualTo(2));
      final second = clears[1];
      expect(second.cascade, 2);
      expect(second.cleared.map((c) => c.cell).toSet(),
          containsAll({cell(e, 5, 0), cell(e, 5, 1), cell(e, 5, 2)}));
      // 3 sweets x 30 points x2 multiplier.
      expect(second.points, 180);
    });

    test('pieces fall through holes', () {
      final rows = verticalSetup();
      rows[2] = '# m t k d m';
      final board = ['......', '......', '#.....', '......', '......', '......'];
      final e = engineWith(rows, board: board);
      final top = e.board.pieces[cell(e, 0, 0)]!.id;
      final second = e.board.pieces[cell(e, 1, 0)]!.id;
      final r = e.swap(cell(e, 3, 1), cell(e, 3, 0));
      final fall = r.events.whereType<FallEvent>().first;
      int endOf(int id) => fall.paths.firstWhere((p) => p.piece.id == id).cells.last;
      expect(endOf(top), cell(e, 4, 0));
      expect(endOf(second), cell(e, 5, 0));
      expect(e.board.pieces[cell(e, 2, 0)], isNull, reason: 'hole stays empty');
    });

    test('a crate blocks falling; cells below refill diagonally', () {
      final rows = verticalSetup();
      rows[2] = '# m t k d m';
      final board = ['......', '......', '2.....', '......', '......', '......'];
      final e = engineWith(rows, board: board);
      final r = e.swap(cell(e, 3, 1), cell(e, 3, 0));
      expect(r.valid, isTrue);
      expect(e.board.crate[cell(e, 2, 0)], 1, reason: 'adjacent match hits the crate once');
      for (var i = 0; i < e.board.length; i++) {
        if (e.board.holdsPiece(i)) expect(e.board.pieces[i], isNotNull, reason: 'cell $i');
      }
      expect(findMatches(e.board), isEmpty);
    });

    test('the same seed and moves always give the same game', () {
      String play(int seed) {
        final e = engineWith(withRow(base6, 0, 'l l m l t k'), seed: seed);
        e.swap(cell(e, 0, 3), cell(e, 0, 2));
        return e.board.dump() + e.score.toString();
      }

      expect(play(42), play(42));
    });
  });

  group('reshuffle', () {
    const noMoves = [
      't k d m l h',
      'd m l h t k',
      'l h t k d m',
      't k d m l h',
      'd m l h t k',
      'l h t k d m',
    ];

    test('a stuck board is shuffled into a playable one', () {
      final e = engineWith(noMoves);
      expect(findPossibleMoves(e.board), isEmpty, reason: 'test board must be stuck');
      final ids = {for (final p in e.board.pieces) p!.id};
      final events = e.shuffleIfNeeded();
      expect(events.whereType<ShuffleEvent>(), isNotEmpty);
      expect(hasPossibleMove(e.board), isTrue);
      expect(findMatches(e.board), isEmpty);
      expect({for (final p in e.board.pieces) p!.id}, ids, reason: 'same pieces, new places');
    });

    test('a playable board is left alone', () {
      final e = engineWith(withRow(base6, 0, 'l l m l t k'));
      expect(e.shuffleIfNeeded(), isEmpty);
    });

    test('new games always start with a possible move and no matches', () {
      for (final colors in [
        const [0, 1, 2, 3],
        const [0, 1, 2, 3, 4],
        const [0, 1, 2, 3, 4, 5],
      ]) {
        final level = testLevel(rows: 9, cols: 9, colors: colors);
        for (var seed = 0; seed < 40; seed++) {
          final e = GameEngine(level, seed: seed);
          expect(findMatches(e.board), isEmpty, reason: 'seed $seed');
          expect(hasPossibleMove(e.board), isTrue, reason: 'seed $seed');
          expect(e.board.pieces.every((p) => p != null), isTrue);
        }
      }
    });
  });
}

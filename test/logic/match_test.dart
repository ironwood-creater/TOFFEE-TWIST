import 'package:flutter_test/flutter_test.dart';
import 'package:toffeetwist/game/logic/match_finder.dart';
import 'package:toffeetwist/game/logic/types.dart';

import 'helpers.dart';

void main() {
  group('match detection', () {
    test('base test board has no matches', () {
      expect(findMatches(boardFrom(base6)), isEmpty);
    });

    test('finds a horizontal 3', () {
      final b = boardFrom(withRow(base6, 0, 'l l l m t k'));
      final groups = findMatches(b);
      expect(groups, hasLength(1));
      expect(groups.single.cells, [0, 1, 2]);
      expect(groups.single.color, Sweet.lollipop.index);
      expect(groups.single.special, Special.none);
    });

    test('finds a vertical 3', () {
      final rows = [...base6];
      rows[0] = 'h k d m t k';
      rows[1] = 'h d m t k d';
      rows[2] = 'h m t k d m';
      final groups = findMatches(boardFrom(rows));
      expect(groups, hasLength(1));
      expect(groups.single.cells, [0, 6, 12]);
    });

    test('4 in a row makes a striped piece in the same direction', () {
      final h = findMatches(boardFrom(withRow(base6, 0, 'l l l l t k')));
      expect(h.single.special, Special.stripedH);
      final rows = [...base6];
      for (var r = 0; r < 4; r++) {
        rows[r] = 'h${rows[r].substring(1)}';
      }
      final v = findMatches(boardFrom(rows));
      expect(v.single.special, Special.stripedV);
    });

    test('5 in a row makes a Toffee Swirl', () {
      final g = findMatches(boardFrom(withRow(base6, 0, 'l l l l l k')));
      expect(g.single.special, Special.swirl);
    });

    test('L shape makes a Sweet Box at the corner', () {
      final rows = [...base6];
      rows[0] = 'l l l m t k';
      rows[1] = 'l d m t k d';
      rows[2] = 'l m t k d m';
      final g = findMatches(boardFrom(rows));
      expect(g, hasLength(1));
      expect(g.single.cells, hasLength(5));
      expect(g.single.special, Special.box);
      expect(g.single.intersection, 0);
    });

    test('T shape makes a Sweet Box', () {
      final rows = [...base6];
      rows[0] = 'l l l m t k';
      rows[1] = 'k l m t k d';
      rows[2] = 'd l t k d m';
      final g = findMatches(boardFrom(rows));
      expect(g.single.special, Special.box);
      expect(g.single.intersection, 1);
    });

    test('nuts, swirls and empty cells never match', () {
      final b = boardFrom(withRow(base6, 0, 'N N N S S S'));
      expect(findMatches(b), isEmpty);
    });

    test('two separate matches are two groups', () {
      var rows = withRow(base6, 0, 'l l l m t k');
      rows = withRow(rows, 5, 'k d m h h h');
      expect(findMatches(boardFrom(rows)), hasLength(2));
    });
  });

  group('possible moves', () {
    test('a swap that lines up 3 is valid, others are not', () {
      final b = boardFrom(withRow(base6, 0, 'l l m l t k'));
      expect(isValidSwap(b, 2, 3), isTrue);
      expect(isValidSwap(b, 4, 5), isFalse);
      expect(findPossibleMoves(b), contains(const Move(2, 3)));
    });

    test('non-neighbours can never be swapped', () {
      final b = boardFrom(withRow(base6, 0, 'l l m l t k'));
      expect(isValidSwap(b, 0, 7), isFalse);
      expect(isValidSwap(b, 0, 2), isFalse);
    });

    test('special + special and swirl + sweet are always valid', () {
      final b = boardFrom(withRow(base6, 0, 'S k d- m| t k'));
      expect(isValidSwap(b, 0, 1), isTrue, reason: 'swirl + sweet');
      expect(isValidSwap(b, 2, 3), isTrue, reason: 'striped + striped');
    });

    test('a swirl cannot be swapped with a nut', () {
      final b = boardFrom(withRow(base6, 0, 'S N d m t k'));
      expect(isValidSwap(b, 0, 1), isFalse);
    });
  });
}

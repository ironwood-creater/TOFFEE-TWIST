import 'package:flutter_test/flutter_test.dart';
import 'package:toffeetwist/game/logic/engine.dart';
import 'package:toffeetwist/game/logic/events.dart';
import 'package:toffeetwist/game/logic/types.dart';

import 'helpers.dart';

void main() {
  group('creating specials', () {
    test('4 in a row creates a Striped Toffee where the sweet was dragged', () {
      var rows = withRow(base6, 0, 'l l h l t k');
      rows = withRow(rows, 1, 'k d l t k d');
      final e = engineWith(rows);
      final r = e.swap(cell(e, 1, 2), cell(e, 0, 2));
      final clear = r.events.whereType<ClearEvent>().first;
      expect(clear.created, hasLength(1));
      expect(clear.created.single.cell, cell(e, 0, 2));
      expect(clear.created.single.piece.special, Special.stripedH);
      expect(clear.created.single.piece.color, Sweet.lollipop.index);
    });

    test('4 in a column creates a column-clearing Striped Toffee', () {
      final rows = [...base6];
      rows[0] = 'h k d m t k';
      rows[1] = 'h d m t k d';
      rows[2] = 'm h t k d m';
      rows[3] = 'h t k d m t';
      final e = engineWith(rows);
      final r = e.swap(cell(e, 2, 1), cell(e, 2, 0));
      final created = r.events.whereType<ClearEvent>().first.created.single;
      expect(created.piece.special, Special.stripedV);
      expect(created.cell, cell(e, 2, 0));
    });

    test('an L shape creates a Sweet Box', () {
      final rows = [...base6];
      rows[0] = 'l l m l t k';
      rows[1] = 'k d l t k d';
      rows[2] = 'd m l k d m';
      final e = engineWith(rows);
      // Drag the lollipop at (0,3) left onto (0,2): row 0 + column 2 match.
      final r = e.swap(cell(e, 0, 3), cell(e, 0, 2));
      final created = r.events.whereType<ClearEvent>().first.created.single;
      expect(created.piece.special, Special.box);
    });

    test('5 in a row creates a Toffee Swirl', () {
      var rows = withRow(base6, 0, 'l l h l l k');
      rows = withRow(rows, 1, 'k d l t k d');
      final e = engineWith(rows);
      final r = e.swap(cell(e, 1, 2), cell(e, 0, 2));
      final created = r.events.whereType<ClearEvent>().first.created.single;
      expect(created.piece.special, Special.swirl);
      expect(created.piece.color, -1);
    });
  });

  group('activating specials', () {
    Set<int> firstCleared(MoveResult r) =>
        r.events.whereType<ClearEvent>().first.cleared.map((c) => c.cell).toSet();

    test('a row Striped Toffee clears its whole row', () {
      var rows = withRow(base6, 2, 'l- l t k d m');
      rows = withRow(rows, 3, 'm t l d m t');
      final e = engineWith(rows);
      final r = e.swap(cell(e, 3, 2), cell(e, 2, 2));
      expect(firstCleared(r), containsAll([for (var c = 0; c < 6; c++) cell(e, 2, c)]));
      final acts = r.events.whereType<ClearEvent>().first.activations;
      expect(acts.any((a) => a.kind == EffectKind.lineH), isTrue);
    });

    test('a column Striped Toffee clears its whole column', () {
      var rows = withRow(base6, 2, 'l| l t k d m');
      rows = withRow(rows, 3, 'm t l d m t');
      final e = engineWith(rows);
      final r = e.swap(cell(e, 3, 2), cell(e, 2, 2));
      expect(firstCleared(r), containsAll([for (var k = 0; k < 6; k++) cell(e, k, 0)]));
    });

    test('a Sweet Box explodes 3x3 twice (Rolling Pin booster)', () {
      final e = engineWith(withRow(base6, 2, 'd m tb k d m'));
      final boxId = e.board.pieces[cell(e, 2, 2)]!.id;
      final r = e.useRollingPin(cell(e, 2, 2));
      expect(r.valid, isTrue);
      expect(e.movesLeft, 20, reason: 'boosters use no move');
      final clears = r.events.whereType<ClearEvent>().toList();
      final first = clears.first;
      expect(first.armed.single.piece.id, boxId);
      expect(first.cleared.map((c) => c.cell).toSet(), {
        for (var dr = -1; dr <= 1; dr++)
          for (var dc = -1; dc <= 1; dc++)
            if (dr != 0 || dc != 0) cell(e, 2 + dr, 2 + dc),
      });
      // Later the armed box explodes again and disappears.
      final second = clears.skip(1).firstWhere((c) => c.cleared.any((p) => p.piece.id == boxId));
      expect(second.activations.any((a) => a.kind == EffectKind.blast), isTrue);
      expect(e.board.pieces.any((p) => p?.id == boxId), isFalse);
    });
  });

  group('combos', () {
    test('Toffee Swirl + sweet clears every sweet of that color', () {
      final e = engineWith(withRow(base6, 2, 'd m S k d m'));
      final r = e.swap(cell(e, 2, 2), cell(e, 2, 3));
      final clear = r.events.whereType<ClearEvent>().first;
      final sweets = clear.cleared.where((c) => !c.piece.isSwirl).toList();
      expect(sweets, hasLength(10));
      expect(sweets.every((c) => c.piece.color == Sweet.cupcake.index), isTrue);
      expect(clear.activations.first.kind, EffectKind.swirl);
      expect(e.movesLeft, 19);
    });

    test('Swirl + Swirl clears the whole board', () {
      final e = engineWith(withRow(base6, 2, 'd m S S d m'));
      final r = e.swap(cell(e, 2, 2), cell(e, 2, 3));
      final clear = r.events.whereType<ClearEvent>().first;
      expect(clear.cleared, hasLength(36));
      expect(clear.activations.first.kind, EffectKind.boardClear);
    });

    test('Striped + Striped clears a cross', () {
      final e = engineWith(withRow(base6, 2, 'd m l- k| d m'));
      final r = e.swap(cell(e, 2, 2), cell(e, 2, 3));
      final clear = r.events.whereType<ClearEvent>().first;
      expect(clear.cleared.map((c) => c.cell).toSet(), {
        for (var c = 0; c < 6; c++) cell(e, 2, c),
        for (var k = 0; k < 6; k++) cell(e, k, 3),
      });
      expect(clear.activations.first.kind, EffectKind.cross);
    });

    test('Striped + Sweet Box clears 3 rows and 3 columns', () {
      final e = engineWith(withRow(base6, 2, 'd m lb k| d m'));
      final r = e.swap(cell(e, 2, 2), cell(e, 2, 3));
      final clear = r.events.whereType<ClearEvent>().first;
      expect(clear.cleared, hasLength(27));
      expect(clear.activations.first.kind, EffectKind.bigCross);
    });

    test('Sweet Box + Sweet Box makes a 5x5 explosion, twice', () {
      final e = engineWith(withRow(base6, 2, 'd m lb kb d m'));
      final r = e.swap(cell(e, 2, 2), cell(e, 2, 3));
      final clears = r.events.whereType<ClearEvent>().toList();
      final first = clears.first;
      expect(first.armed.single.piece.big, isTrue);
      expect(first.cleared, hasLength(24));
      expect(first.activations.first.radius, 2);
      expect(clears.skip(1).any((c) => c.activations.any((a) => a.radius == 2)), isTrue);
    });

    test('Swirl + Striped turns that color striped, then fires them all', () {
      final e = engineWith(withRow(base6, 2, 'd m S k- d m'));
      final r = e.swap(cell(e, 2, 2), cell(e, 2, 3));
      final convert = r.events.whereType<ConvertEvent>().first;
      expect(convert.changes, hasLength(9));
      expect(convert.changes.every((c) => c.piece.isStriped), isTrue);
      final clear = r.events.whereType<ClearEvent>().first;
      expect(clear.cleared.length, greaterThanOrEqualTo(25));
    });

    test('Swirl + Sweet Box turns that color into boxes', () {
      final e = engineWith(withRow(base6, 2, 'd m S kb d m'));
      final r = e.swap(cell(e, 2, 2), cell(e, 2, 3));
      final convert = r.events.whereType<ConvertEvent>().first;
      expect(convert.changes.every((c) => c.piece.isBox), isTrue);
      expect(r.events.whereType<ClearEvent>().first.armed, isNotEmpty);
    });
  });
}

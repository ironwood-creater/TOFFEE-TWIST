import 'package:flutter_test/flutter_test.dart';
import 'package:toffeetwist/game/logic/board.dart';
import 'package:toffeetwist/game/logic/engine.dart';
import 'package:toffeetwist/game/logic/level.dart';
import 'package:toffeetwist/game/logic/types.dart';

const sample = '''
{
  "id": 12,
  "kind": "normal",
  "moves": 25,
  "sweets": ["toffee", "cupcake", "donut", "macaron", "lollipop"],
  "goals": [
    {"type": "collect", "sweet": "donut", "count": 20},
    {"type": "caramel"},
    {"type": "nuts", "count": 2, "maxOnBoard": 1}
  ],
  "stars": [1000, 4000, 8000],
  "board": [
    "#.......#",
    "...n.....",
    ".........",
    "..cccc...",
    "..cCCc...",
    "...123...",
    ".........",
    ".........",
    "#.......#"
  ],
  "tutorial": {"id": "caramel", "title": "Caramel!", "text": "Clear it."}
}
''';

void main() {
  group('level JSON', () {
    test('parses every field', () {
      final l = LevelDef.parse(sample);
      expect(l.id, 12);
      expect(l.moves, 25);
      expect(l.rows, 9);
      expect(l.cols, 9);
      expect(l.colors, [0, 1, 2, 3, 4]);
      expect(l.goals.map((g) => g.type),
          [GoalType.collect, GoalType.caramel, GoalType.nuts]);
      expect(l.goals.first.color, Sweet.donut.index);
      expect(l.goals.first.target, 20);
      expect(l.goals.last.maxOnBoard, 1);
      expect(l.stars, [1000, 4000, 8000]);
      expect(l.tutorial!.id, 'caramel');
    });

    test('board legend becomes holes, caramel and crates', () {
      final b = Board.fromLevel(LevelDef.parse(sample));
      expect(b.playable[0], isFalse);
      expect(b.playable[1], isTrue);
      expect(b.caramel[b.index(3, 2)], 1);
      expect(b.caramel[b.index(4, 3)], 2);
      expect(b.crate[b.index(5, 3)], 1);
      expect(b.crate[b.index(5, 5)], 3);
      expect(b.spawnCell[0], b.index(1, 0));
      expect(b.exitCell[0], b.index(7, 0));
    });

    test('goals resolve "all caramel" to the number of tiles', () {
      final e = GameEngine(LevelDef.parse(sample), seed: 3);
      expect(e.goals.of(GoalType.caramel)!.target, 8);
      expect(e.board.pieces[e.board.index(1, 3)]!.isNut, isTrue);
    });

    test('toJson -> parse round trip keeps the level', () {
      final l = LevelDef.parse(sample);
      final again = LevelDef.parse(l.toPrettyJson());
      expect(again.toJson(), l.toJson());
    });

    test('presets fix the starting sweets and specials', () {
      final l = LevelDef(
        id: 1,
        moves: 10,
        colors: const [0, 1, 2, 3],
        board: const ['....', '....', '....', '....'],
        goals: const [GoalDef.score(100)],
        stars: const [100, 200, 300],
        preset: const ['tkdm', 'kdmt', 'dmtk', 'tt.t'],
        presetSpecials: const ['....', '.-..', '....', '...s'],
      );
      final e = GameEngine(l, seed: 1);
      expect(e.board.pieces[0]!.color, Sweet.toffee.index);
      expect(e.board.pieces[5]!.special, Special.stripedH);
      expect(e.board.pieces[15]!.isSwirl, isTrue);
    });

    test('bad levels give clear errors', () {
      Map<String, dynamic> base() => {
            'id': 1,
            'moves': 10,
            'sweets': ['toffee', 'cupcake', 'donut', 'macaron'],
            'goals': [
              {'type': 'score', 'target': 100},
            ],
            'stars': [1, 2, 3],
            'board': ['....', '....', '....', '....'],
          };
      expect(() => LevelDef.fromJson(base()), returnsNormally);
      expect(() => LevelDef.fromJson(base()..['board'] = ['..x.', '....', '....', '....']),
          throwsFormatException);
      expect(() => LevelDef.fromJson(base()..['stars'] = [3, 2, 1]), throwsFormatException);
      expect(() => LevelDef.fromJson(base()..['sweets'] = ['toffee', 'bread']),
          throwsFormatException);
      expect(
          () => LevelDef.fromJson(base()
            ..['goals'] = [
              {'type': 'caramel'},
            ]),
          throwsFormatException);
      expect(
          () => LevelDef.fromJson(base()
            ..['goals'] = [
              {'type': 'collect', 'sweet': 'chocolate', 'count': 5},
            ]),
          throwsFormatException);
    });
  });
}

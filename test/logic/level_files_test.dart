import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toffeetwist/game/logic/engine.dart';
import 'package:toffeetwist/game/logic/level.dart';
import 'package:toffeetwist/game/logic/match_finder.dart';
import 'package:toffeetwist/levels/level_generator.dart';
import 'package:toffeetwist/levels/level_repository.dart';
import 'package:toffeetwist/levels/shop_names.dart';
import 'package:toffeetwist/levels/simulator.dart';

void main() {
  final levels = <LevelDef>[
    for (var id = 1; id <= LevelRepository.totalLevels; id++)
      LevelDef.parse(File('assets/levels/${LevelDef.fileName(id)}').readAsStringSync()),
  ];

  test('all 500 level files load and have the right ids', () {
    expect(levels, hasLength(500));
    for (var i = 0; i < levels.length; i++) {
      expect(levels[i].id, i + 1);
    }
  });

  test('every level starts with a playable board', () {
    for (final l in levels) {
      final e = GameEngine(l, seed: l.id);
      expect(findMatches(e.board), isEmpty, reason: 'level ${l.id}');
      expect(hasPossibleMove(e.board), isTrue, reason: 'level ${l.id}');
      expect(l.moves, inInclusiveRange(5, 60), reason: 'level ${l.id}');
      expect(l.colors.length, inInclusiveRange(4, 6), reason: 'level ${l.id}');
    }
  });

  test('tutorial levels teach one thing at a time', () {
    final tutorials = levels.where((l) => l.tutorial != null).map((l) => l.id).toList();
    expect(tutorials.first, 1);
    expect(tutorials.length, greaterThanOrEqualTo(12));
    expect(tutorials.every((id) => id <= 30), isTrue);
    expect(tutorials.map((id) => levels[id - 1].tutorial!.id).toSet().length, tutorials.length);
  });

  test('generated levels: every 10th is hard, the next one a relief level', () {
    for (final l in levels.where((l) => l.id > 30)) {
      expect(l.kind, LevelGenerator.kindFor(l.id), reason: 'level ${l.id}');
    }
    expect(levels[39].kind, LevelKind.hard);
    expect(levels[40].kind, LevelKind.relief);
  });

  test('the generator is deterministic', () {
    final g = LevelGenerator();
    for (final id in [31, 77, 250, 500]) {
      expect(g.generate(id, 0).toPrettyJson(), g.generate(id, 0).toPrettyJson());
      expect(g.generate(id, 0).toPrettyJson(), isNot(g.generate(id, 1).toPrettyJson()));
    }
  });

  test('the bot wins an easy level and reports moves', () {
    final sim = LevelSim.run(levels[0], plays: 10);
    expect(sim.winRate(levels[0].moves), greaterThan(0.5));
    final stars = sim.starThresholds(levels[0].moves);
    expect(stars[0] < stars[1] && stars[1] < stars[2], isTrue);
  });

  test('there are 25 shops of 20 levels', () {
    expect(shopNames, hasLength(25));
    expect(shopNameForLevel(1), 'Toffee Kitchen');
    expect(shopNameForLevel(21), 'Cupcake Café');
    expect(shopNameForLevel(500), 'Golden Twist Palace');
  });
}

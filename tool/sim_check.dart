// Quick bot check of one level file:
//   dart run tool/sim_check.dart tool/levels/sandbox.json [plays]
import 'dart:io';

import 'package:toffeetwist/game/logic/level.dart';
import 'package:toffeetwist/levels/simulator.dart';

void main(List<String> args) {
  final level = LevelDef.parse(File(args[0]).readAsStringSync());
  final plays = args.length > 1 ? int.parse(args[1]) : 50;
  final sw = Stopwatch()..start();
  final sim = LevelSim.run(level, plays: plays);
  final ms = sw.elapsedMilliseconds;
  final used = sim.runs.where((r) => r.won).map((r) => r.movesUsed).toList()..sort();
  stdout.writeln('level ${level.id}: $plays plays in ${ms}ms (${(ms / plays).toStringAsFixed(1)} ms/play)');
  stdout.writeln('unsolved: ${(sim.unsolvedRate * 100).toStringAsFixed(0)}%  moves needed: $used');
  for (final m in [10, 15, 20, 25, 30, 40]) {
    stdout.writeln('  win rate with $m moves: ${(sim.winRate(m) * 100).toStringAsFixed(0)}%');
  }
  stdout.writeln('stars at ${level.moves} moves: ${sim.starThresholds(level.moves)}');
}

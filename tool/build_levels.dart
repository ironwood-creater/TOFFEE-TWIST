// Level building tool for Toffee Twist.
//
//   dart run tool/build_levels.dart tune-hand        # levels 1-30: set moves + stars
//   dart run tool/build_levels.dart generate [a] [b]  # make levels 31-500 (or a..b)
//   dart run tool/build_levels.dart report           # bot-test all levels -> levels_report.csv
//   dart run tool/build_levels.dart all              # everything above
//
// The greedy bot plays every level 50 times. Moves are tuned so normal levels
// have a 60-85% bot win rate and hard levels 30-50%; generated levels the bot
// cannot solve (or wins less than 20%) are thrown away and regenerated.
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:toffeetwist/game/logic/level.dart';
import 'package:toffeetwist/game/logic/types.dart';
import 'package:toffeetwist/levels/level_generator.dart';
import 'package:toffeetwist/levels/shop_names.dart';
import 'package:toffeetwist/levels/simulator.dart';

const levelsDir = 'assets/levels';
const plays = 50;

/// Target bot win rates for the hand-made tutorial levels (easy on purpose).
const handTargets = <int, double>{
  1: 0.98, 2: 0.98, 3: 0.96, 4: 0.96, 5: 0.94, 6: 0.94, 7: 0.92, 8: 0.94, 9: 0.92, 10: 0.92, //
  11: 0.90, 12: 0.90, 13: 0.92, 14: 0.88, 15: 0.86, 16: 0.92, 17: 0.86, 18: 0.88, 19: 0.86, 20: 0.44,
  21: 0.80, 22: 0.85, 23: 0.82, 24: 0.86, 25: 0.82, 26: 0.80, 27: 0.80, 28: 0.78, 29: 0.78, 30: 0.48,
};

String fileFor(int id) => '$levelsDir/${LevelDef.fileName(id)}';

LevelDef loadLevel(int id) => LevelDef.parse(File(fileFor(id)).readAsStringSync());

Future<void> main(List<String> args) async {
  final cmd = args.isEmpty ? 'all' : args.first;
  final sw = Stopwatch()..start();
  switch (cmd) {
    case 'tune-hand':
      await tuneHand();
    case 'generate':
      final from = args.length > 1 ? int.parse(args[1]) : LevelGenerator.firstGenerated;
      final to = args.length > 2 ? int.parse(args[2]) : LevelGenerator.lastLevel;
      await generate(from, to);
    case 'report':
      await report();
    case 'all':
      await tuneHand();
      await generate(LevelGenerator.firstGenerated, LevelGenerator.lastLevel);
      await report();
    default:
      stderr.writeln('Unknown command $cmd');
      exit(64);
  }
  stdout.writeln('Done in ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)} s');
}

/// Runs [work] for every id on all CPU cores.
Future<List<T>> parallel<T>(List<int> ids, T Function(int id) work) async {
  final workers = math.max(1, Platform.numberOfProcessors);
  final chunks = List.generate(workers, (_) => <int>[]);
  for (var i = 0; i < ids.length; i++) {
    chunks[i % workers].add(ids[i]);
  }
  final results = await Future.wait([
    for (final chunk in chunks)
      if (chunk.isNotEmpty) Isolate.run(() => [for (final id in chunk) work(id)]),
  ]);
  return [for (final r in results) ...r];
}

// -----------------------------------------------------------------------------
// Hand-made levels 1-30
// -----------------------------------------------------------------------------

class TuneResult {
  TuneResult(this.id, this.json, this.message);
  final int id;
  final String json;
  final String message;
}

TuneResult tuneOne(int id) {
  final level = loadLevel(id);
  final sim = LevelSim.run(level, plays: plays, seedBase: 1, moveCap: 90);
  final target = handTargets[id] ?? 0.8;
  final moves = sim.movesFor(target, maxMoves: 60) ?? 60;
  final tuned = level.copyWith(moves: moves, stars: sim.starThresholds(moves));
  final msg = 'level $id: moves $moves, bot wins ${(sim.winRate(moves) * 100).round()}% '
      '(target ${(target * 100).round()}%), stars ${tuned.stars}';
  return TuneResult(id, tuned.toPrettyJson(), msg);
}

Future<void> tuneHand() async {
  stdout.writeln('Tuning hand-made levels 1-30 ...');
  final results = await parallel([for (var i = 1; i <= 30; i++) i], tuneOne);
  results.sort((a, b) => a.id.compareTo(b.id));
  for (final r in results) {
    File(fileFor(r.id)).writeAsStringSync(r.json);
    stdout.writeln('  ${r.message}');
  }
}

// -----------------------------------------------------------------------------
// Generated levels 31-500
// -----------------------------------------------------------------------------

class GenResult {
  GenResult(this.id, this.json, this.attempt, this.rate, this.verify);
  final int id;
  final String json;
  final int attempt;
  final double rate;
  final double verify;
}

GenResult generateOne(int id) {
  final gen = LevelGenerator();
  final kind = LevelGenerator.kindFor(id);
  final (lo, hi) = LevelGenerator.band(kind);
  final target = LevelGenerator.targetWinRate(id);
  for (var attempt = 0; attempt < 40; attempt++) {
    LevelDef level;
    try {
      level = gen.generate(id, attempt);
    } on FormatException {
      continue;
    }
    final sim = LevelSim.run(level, plays: plays, seedBase: 1, moveCap: 90);
    // Unsolvable for the bot even with lots of moves: reject.
    if (sim.unsolvedRate > 0.2) continue;
    var moves = sim.movesFor(target, maxMoves: 50);
    if (moves == null) continue;
    if (sim.winRate(moves) > hi && sim.winRate(moves - 1) >= lo) moves--;
    final rate = sim.winRate(moves);
    if (rate < lo || rate > hi) continue;
    if (moves < 10 || moves > 45) continue;
    final tuned = level.copyWith(moves: moves, stars: sim.starThresholds(moves));
    // A second, independent set of 50 plays must agree (not a lucky level).
    final verify = LevelSim.run(tuned, plays: plays, seedBase: 2, moveCap: 90).winRate(moves);
    if (verify < 0.2 || verify < lo - 0.12 || verify > hi + 0.12) continue;
    return GenResult(id, tuned.toPrettyJson(), attempt, rate, verify);
  }
  throw StateError('Could not generate a valid level $id');
}

Future<void> generate(int from, int to) async {
  stdout.writeln('Generating levels $from-$to ...');
  final ids = [for (var i = from; i <= to; i++) i];
  final results = await parallel(ids, generateOne);
  results.sort((a, b) => a.id.compareTo(b.id));
  var retries = 0;
  for (final r in results) {
    File(fileFor(r.id)).writeAsStringSync(r.json);
    retries += r.attempt;
  }
  stdout.writeln('  wrote ${results.length} levels '
      '($retries rejected designs regenerated)');
}

// -----------------------------------------------------------------------------
// Report
// -----------------------------------------------------------------------------

class ReportRow {
  ReportRow(this.id, this.line, this.rate, this.kind);
  final int id;
  final String line;
  final double rate;
  final LevelKind kind;
}

String goalSummary(LevelDef l) => l.goals.map((g) {
      return switch (g.type) {
        GoalType.score => 'score ${g.target}',
        GoalType.collect => 'collect ${g.target} ${Sweet.values[g.color].name}',
        GoalType.caramel => 'caramel',
        GoalType.crates => 'crates',
        GoalType.nuts => 'nuts ${g.target}',
      };
    }).join(' + ');

ReportRow reportOne(int id) {
  final l = loadLevel(id);
  final sim = LevelSim.run(l, plays: plays, seedBase: 1, moveCap: 90);
  final verify = LevelSim.run(l, plays: plays, seedBase: 2, moveCap: 90);
  final rate = sim.winRate(l.moves);
  final cells = l.board.join().replaceAll('#', '').length;
  final caramel = l.board.join().replaceAll(RegExp('[^cC]'), '').length;
  final crates = l.board.join().replaceAll(RegExp('[^123]'), '').length;
  final (lo, hi) = l.kind == LevelKind.tutorial
      ? (0.0, 1.0)
      : LevelGenerator.band(l.kind == LevelKind.hard ? LevelKind.hard : LevelKind.normal);
  final cols = [
    '$id',
    l.kind.name,
    '"${shopNameForLevel(id)}"',
    '"${goalSummary(l)}"',
    l.goals.map((g) => g.type.name).toSet().join('+'),
    '${l.colors.length}',
    '${l.rows}x${l.cols}',
    '$cells',
    '$caramel',
    '$crates',
    '${l.moves}',
    (rate * 100).toStringAsFixed(0),
    (verify.winRate(l.moves) * 100).toStringAsFixed(0),
    sim.averageMovesUsed(l.moves).toStringAsFixed(1),
    '${l.stars[0]}',
    '${l.stars[1]}',
    '${l.stars[2]}',
    l.kind == LevelKind.tutorial ? 'tutorial (easy)' : '${(lo * 100).round()}-${(hi * 100).round()}%',
    l.kind == LevelKind.tutorial || (rate >= lo && rate <= hi) ? 'yes' : 'NO',
  ];
  return ReportRow(id, cols.join(','), rate, l.kind);
}

Future<void> report() async {
  stdout.writeln('Bot-testing every level ($plays plays each) ...');
  final ids = <int>[];
  for (var i = 1; File(fileFor(i)).existsSync(); i++) {
    ids.add(i);
  }
  final rows = await parallel(ids, reportOne);
  rows.sort((a, b) => a.id.compareTo(b.id));
  final sb = StringBuffer()
    ..writeln('level,kind,shop,goals,goal_types,sweets,board,cells,caramel_tiles,crates,moves,'
        'bot_win_rate_pct,verify_win_rate_pct,avg_moves_to_win,star1,star2,star3,target_band,in_band');
  for (final r in rows) {
    sb.writeln(r.line);
  }
  File('levels_report.csv').writeAsStringSync(sb.toString());
  double avg(Iterable<ReportRow> rs) => rs.isEmpty ? 0 : rs.fold(0.0, (a, r) => a + r.rate) / rs.length;
  final normal = rows.where((r) => r.kind == LevelKind.normal || r.kind == LevelKind.relief);
  final hard = rows.where((r) => r.kind == LevelKind.hard && r.id > 30);
  final outside = rows.where((r) => r.line.endsWith(',NO')).map((r) => r.id).toList();
  stdout.writeln('  ${rows.length} levels -> levels_report.csv');
  stdout.writeln('  average bot win rate: normal ${(avg(normal) * 100).toStringAsFixed(1)}%, '
      'hard ${(avg(hard) * 100).toStringAsFixed(1)}%');
  stdout.writeln('  levels outside their band: ${outside.isEmpty ? 'none' : outside}');
}

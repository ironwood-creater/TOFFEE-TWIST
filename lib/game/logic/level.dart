import 'dart:convert';

import 'types.dart';

/// Level goal types.
enum GoalType { score, collect, caramel, crates, nuts }

/// One goal of a level, as written in the level JSON file.
///
/// JSON examples:
/// ```json
/// {"type": "score", "target": 5000}
/// {"type": "collect", "sweet": "donut", "count": 20}
/// {"type": "caramel"}                 // clear all caramel tiles
/// {"type": "crates"}                  // break all wooden crates
/// {"type": "nuts", "count": 3, "maxOnBoard": 2}
/// ```
class GoalDef {
  const GoalDef(this.type, {this.target = 0, this.color = -1, this.maxOnBoard = 1});

  const GoalDef.score(int target) : this(GoalType.score, target: target);
  const GoalDef.collect(int color, int count)
      : this(GoalType.collect, target: count, color: color);
  const GoalDef.caramel() : this(GoalType.caramel);
  const GoalDef.crates() : this(GoalType.crates);
  const GoalDef.nuts(int count, {int maxOnBoard = 1})
      : this(GoalType.nuts, target: count, maxOnBoard: maxOnBoard);

  final GoalType type;

  /// Score to reach, sweets / nuts to collect. For caramel and crates it is 0
  /// in the file and means "all of them on the board".
  final int target;

  /// Sweet index for collect goals, otherwise -1.
  final int color;

  /// Nuts goal only: how many nuts may be on the board at the same time.
  final int maxOnBoard;

  factory GoalDef.fromJson(Map<String, dynamic> j) {
    final typeName = j['type'] as String?;
    final type = GoalType.values.where((t) => t.name == typeName).firstOrNull;
    if (type == null) throw FormatException('Unknown goal type "$typeName"');
    switch (type) {
      case GoalType.score:
        return GoalDef.score(_positive(j['target'], 'score target'));
      case GoalType.collect:
        final sweet = Sweet.fromName(j['sweet'] as String? ?? '');
        if (sweet == null) {
          throw FormatException('Unknown sweet "${j['sweet']}" in collect goal');
        }
        return GoalDef.collect(sweet.index, _positive(j['count'], 'collect count'));
      case GoalType.caramel:
        return const GoalDef.caramel();
      case GoalType.crates:
        return const GoalDef.crates();
      case GoalType.nuts:
        return GoalDef.nuts(
          _positive(j['count'], 'nut count'),
          maxOnBoard: (j['maxOnBoard'] as int?) ?? 1,
        );
    }
  }

  Map<String, dynamic> toJson() => switch (type) {
        GoalType.score => {'type': 'score', 'target': target},
        GoalType.collect => {
            'type': 'collect',
            'sweet': Sweet.values[color].name,
            'count': target,
          },
        GoalType.caramel => {'type': 'caramel'},
        GoalType.crates => {'type': 'crates'},
        GoalType.nuts => {
            'type': 'nuts',
            'count': target,
            'maxOnBoard': maxOnBoard,
          },
      };

  static int _positive(Object? v, String what) {
    if (v is! int || v <= 0) throw FormatException('Missing or invalid $what');
    return v;
  }
}

/// A short tutorial popup shown when a level starts for the first time.
class TutorialDef {
  const TutorialDef({required this.id, required this.title, required this.text});

  /// Which picture to show (match3, collect, striped, box, swirl, combo,
  /// caramel, crate, nut, shape, boosters ...).
  final String id;
  final String title;
  final String text;

  factory TutorialDef.fromJson(Map<String, dynamic> j) => TutorialDef(
        id: j['id'] as String,
        title: j['title'] as String,
        text: j['text'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'text': text};
}

/// What kind of level this is (used for the difficulty badge and reports).
enum LevelKind { tutorial, normal, hard, relief }

/// A complete level definition, loaded from `assets/levels/level_XXXX.json`.
///
/// Board legend (one string per row, max 9x9):
/// * `.` normal cell        * `#` hole (no cell)
/// * `c` caramel (1 layer)  * `C` caramel (2 layers)
/// * `1` `2` `3` wooden crate needing that many hits
/// * `n` a golden nut starts here
///
/// Optional `preset` rows fix the starting sweets (`t k d m l h` = toffee,
/// cupcake, donut, macaron, lollipop, chocolate; `.` = random) and optional
/// `presetSpecials` rows add specials (`-` striped row, `|` striped column,
/// `b` Sweet Box, `s` Toffee Swirl, `.` none).
class LevelDef {
  LevelDef({
    required this.id,
    required this.moves,
    required this.colors,
    required this.board,
    required this.goals,
    required this.stars,
    this.preset,
    this.presetSpecials,
    this.tutorial,
    this.kind = LevelKind.normal,
    this.seed,
  }) {
    _validate();
  }

  static const int maxSize = 9;

  final int id;
  final int moves;

  /// Sweet indexes that can appear (4 to 6 of them).
  final List<int> colors;
  final List<String> board;
  final List<GoalDef> goals;

  /// Score thresholds for 1, 2 and 3 stars.
  final List<int> stars;
  final List<String>? preset;
  final List<String>? presetSpecials;
  final TutorialDef? tutorial;
  final LevelKind kind;

  /// Seed used by the level generator (informational only).
  final int? seed;

  int get rows => board.length;
  int get cols => board.first.length;

  GoalDef? goalOf(GoalType type) =>
      goals.where((g) => g.type == type).firstOrNull;

  LevelDef copyWith({int? moves, List<int>? stars, List<GoalDef>? goals}) =>
      LevelDef(
        id: id,
        moves: moves ?? this.moves,
        colors: colors,
        board: board,
        goals: goals ?? this.goals,
        stars: stars ?? this.stars,
        preset: preset,
        presetSpecials: presetSpecials,
        tutorial: tutorial,
        kind: kind,
        seed: seed,
      );

  void _validate() {
    if (board.isEmpty || board.length > maxSize) {
      throw FormatException('Level $id: board must have 1-$maxSize rows');
    }
    final width = board.first.length;
    if (width == 0 || width > maxSize) {
      throw FormatException('Level $id: board must have 1-$maxSize columns');
    }
    var playable = 0;
    for (final row in board) {
      if (row.length != width) {
        throw FormatException('Level $id: all board rows must have the same length');
      }
      for (final ch in row.split('')) {
        if (!'.#cC123n'.contains(ch)) {
          throw FormatException('Level $id: unknown board character "$ch"');
        }
        if (ch != '#') playable++;
      }
    }
    if (playable < 9) throw FormatException('Level $id: board is too small');
    if (colors.length < 3 || colors.length > 6 || colors.toSet().length != colors.length) {
      throw FormatException('Level $id: needs 3-6 different sweets');
    }
    if (moves <= 0) throw FormatException('Level $id: moves must be positive');
    if (goals.isEmpty) throw FormatException('Level $id: needs at least one goal');
    if (stars.length != 3 || stars[0] > stars[1] || stars[1] > stars[2]) {
      throw FormatException('Level $id: stars must be 3 increasing scores');
    }
    for (final g in goals) {
      if (g.type == GoalType.collect && !colors.contains(g.color)) {
        throw FormatException('Level $id: collect goal uses a sweet not in the level');
      }
    }
    final all = board.join();
    if (goalOf(GoalType.caramel) != null && !all.contains(RegExp('[cC]'))) {
      throw FormatException('Level $id: caramel goal but no caramel tiles');
    }
    if (goalOf(GoalType.crates) != null && !all.contains(RegExp('[123]'))) {
      throw FormatException('Level $id: crate goal but no crates');
    }
    for (final layer in [preset, presetSpecials]) {
      if (layer == null) continue;
      if (layer.length != rows || layer.any((r) => r.length != width)) {
        throw FormatException('Level $id: preset size must match the board');
      }
    }
  }

  factory LevelDef.fromJson(Map<String, dynamic> j) {
    List<String>? strings(Object? v) =>
        v == null ? null : (v as List).cast<String>().toList();
    final colors = <int>[];
    for (final name in (j['sweets'] as List).cast<String>()) {
      final s = Sweet.fromName(name);
      if (s == null) throw FormatException('Unknown sweet "$name"');
      colors.add(s.index);
    }
    final kindName = j['kind'] as String? ?? 'normal';
    return LevelDef(
      id: j['id'] as int,
      moves: j['moves'] as int,
      colors: colors,
      board: strings(j['board'])!,
      goals: [
        for (final g in (j['goals'] as List)) GoalDef.fromJson(g as Map<String, dynamic>),
      ],
      stars: (j['stars'] as List).cast<int>().toList(),
      preset: strings(j['preset']),
      presetSpecials: strings(j['presetSpecials']),
      tutorial: j['tutorial'] == null
          ? null
          : TutorialDef.fromJson(j['tutorial'] as Map<String, dynamic>),
      kind: LevelKind.values.firstWhere((k) => k.name == kindName,
          orElse: () => LevelKind.normal),
      seed: j['seed'] as int?,
    );
  }

  factory LevelDef.parse(String source) =>
      LevelDef.fromJson(jsonDecode(source) as Map<String, dynamic>);

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'moves': moves,
        'sweets': [for (final c in colors) Sweet.values[c].name],
        'goals': [for (final g in goals) g.toJson()],
        'stars': stars,
        'board': board,
        if (preset != null) 'preset': preset,
        if (presetSpecials != null) 'presetSpecials': presetSpecials,
        if (tutorial != null) 'tutorial': tutorial!.toJson(),
        if (seed != null) 'seed': seed,
      };

  /// Pretty JSON with one board row per line (easy to read and edit).
  String toPrettyJson() {
    const enc = JsonEncoder.withIndent('  ');
    var text = enc.convert(toJson());
    // Put short string lists (board rows) on single lines for readability.
    text = text.replaceAllMapped(
      RegExp(r'\[\n((?:\s+"[^"\n]*",?\n)+)\s+\]'),
      (m) {
        final items = RegExp(r'"[^"\n]*"').allMatches(m[1]!).map((x) => x[0]).toList();
        final pad = ' ' * 4;
        return '[\n$pad${items.join(',\n$pad')}\n  ]';
      },
    );
    text = text.replaceAllMapped(
      RegExp(r'\[\n\s+(\d+),\n\s+(\d+),\n\s+(\d+)\n\s+\]'),
      (m) => '[${m[1]}, ${m[2]}, ${m[3]}]',
    );
    return '$text\n';
  }

  static String fileName(int id) => 'level_${id.toString().padLeft(4, '0')}.json';
}

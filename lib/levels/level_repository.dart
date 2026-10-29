import 'package:flutter/services.dart';

import '../game/logic/level.dart';

/// Loads level files from `assets/levels/`.
class LevelRepository {
  LevelRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// Number of levels shipped with the game.
  static const int totalLevels = 500;

  final AssetBundle _bundle;
  final Map<int, LevelDef> _cache = {};

  Future<LevelDef> load(int id) async {
    final cached = _cache[id];
    if (cached != null) return cached;
    final text = await _bundle.loadString('assets/levels/${LevelDef.fileName(id)}', cache: false);
    final level = LevelDef.parse(text);
    if (level.id != id) throw FormatException('File for level $id contains level ${level.id}');
    _cache[id] = level;
    return level;
  }
}

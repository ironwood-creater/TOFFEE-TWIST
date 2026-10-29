import 'package:flutter/material.dart';

import '../levels/level_repository.dart';
import '../services/services.dart';
import '../widgets/ui.dart';
import 'dialogs/meta_dialogs.dart';
import 'game_screen.dart';

/// Starts a level from the map and handles what comes after it
/// (next level, retry, back to the map).
abstract final class LevelFlow {
  /// [onLevelChanged] lets the map scroll to the level being offered.
  static Future<void> play(
    BuildContext context,
    int levelId, {
    void Function(int id)? onLevelChanged,
  }) async {
    var id = levelId;
    {
      while (context.mounted) {
        onLevelChanged?.call(id);
        final p = Services.progress;
        if (!p.hasLife) {
          final ok = await showPopup<bool>(context, const OutOfLivesDialog());
          if (ok != true || !context.mounted) return;
        }
        final level = await Services.levels.load(id);
        if (!context.mounted) return;
        final boosters = await showPopup<Set<Booster>>(
          context,
          PreLevelDialog(level: level),
          dismissible: true,
        );
        if (boosters == null || !context.mounted) return;
        for (final b in boosters) {
          p.useBooster(b);
        }
        final ads = Services.ads;
        final exit = await Navigator.of(context).push<GameExit>(
          MaterialPageRoute(
            builder: (_) => GameScreen(
              level: level,
              startBoosters: boosters,
              ads: GameAdHooks(
                extraMoves: ads.rewardedReady
                    ? () => ads.showRewarded(RewardedPurpose.extraMoves)
                    : null,
                tripleCoins: ads.rewardedReady
                    ? () => ads.showRewarded(RewardedPurpose.tripleCoins)
                    : null,
              ),
            ),
          ),
        );
        // Interstitials only ever appear here: between levels, never in play.
        await ads.betweenLevels(id);
        if (!context.mounted) return;
        switch (exit) {
          case GameExit.next:
            if (id >= LevelRepository.totalLevels) return;
            id++;
          case GameExit.retry:
            break;
          case GameExit.map || null:
            return;
        }
      }
    }
  }
}

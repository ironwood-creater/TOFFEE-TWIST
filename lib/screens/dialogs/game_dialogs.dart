import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/logic/goals.dart';
import '../../game/logic/level.dart';
import '../../services/services.dart';
import '../../theme.dart';
import '../../widgets/goal_widgets.dart';
import '../../widgets/ui.dart';

/// Shown when a level is won.
class WinDialog extends StatefulWidget {
  const WinDialog({
    super.key,
    required this.levelId,
    required this.stars,
    required this.score,
    required this.coins,
    this.onTripleCoins,
  });

  final int levelId;
  final int stars;
  final int score;
  final int coins;

  /// Watch a rewarded ad to triple the coins (null hides the button).
  final Future<bool> Function()? onTripleCoins;

  @override
  State<WinDialog> createState() => _WinDialogState();
}

class _WinDialogState extends State<WinDialog> {
  int _shown = 0;
  bool _tripled = false;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 380), (t) {
      if (_shown >= widget.stars) {
        t.cancel();
        return;
      }
      setState(() => _shown++);
      Services.audio.play(Sfx.star);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coins = _tripled ? widget.coins * 3 : widget.coins;
    return SizedBox(
      width: 330,
      child: ChocoPanel(
        title: 'Level ${widget.levelId}',
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sweet Success!', style: AppText.title(30, color: AppColors.caramelDark, shadows: [])),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  AnimatedScale(
                    scale: i < _shown ? 1 : 0.7,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i == 1 ? 18 : 0),
                      child: Icon(Icons.star_rounded,
                          size: i == 1 ? 74 : 60,
                          color: i < _shown ? AppColors.gold : const Color(0x33000000),
                          shadows: i < _shown
                              ? const [Shadow(color: Color(0xFFB36B00), offset: Offset(0, 3))]
                              : null),
                    ),
                  ),
              ],
            ),
            Text('Score', style: AppText.label(15)),
            Text('${widget.score}', style: AppText.title(34, color: AppColors.chocolate, shadows: [])),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CoinIcon(size: 30),
                const SizedBox(width: 8),
                Text('+$coins', style: AppText.title(28, color: AppColors.caramelDark, shadows: [])),
              ],
            ),
            const SizedBox(height: 14),
            if (widget.onTripleCoins != null && !_tripled) ...[
              GoldButton(
                label: 'Triple coins',
                subtitle: 'Watch a short video',
                icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 30),
                color: GoldButtonColor.pink,
                fontSize: 20,
                height: 60,
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        final ok = await widget.onTripleCoins!();
                        if (!mounted) return;
                        setState(() {
                          _busy = false;
                          _tripled = ok;
                        });
                      },
              ),
              const SizedBox(height: 12),
            ],
            GoldButton(
              label: 'Continue',
              color: GoldButtonColor.green,
              width: 220,
              onPressed: () => Navigator.of(context).pop(_tripled),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the player picked after running out of moves.
enum LoseChoice { buyMoves, adMoves, giveUp }

class OutOfMovesDialog extends StatelessWidget {
  const OutOfMovesDialog({
    super.key,
    required this.level,
    required this.goals,
    required this.price,
    required this.canAfford,
    required this.adAvailable,
  });

  final LevelDef level;
  final GoalTracker goals;
  final int price;
  final bool canAfford;
  final bool adAvailable;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      child: ChocoPanel(
        title: 'Out of moves!',
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('So close! Still needed:', style: AppText.label(16)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final g in goals.goals)
                  if (!g.done) GoalChipDark(goal: g.def, remaining: g.remaining),
              ],
            ),
            const SizedBox(height: 16),
            GoldButton(
              label: '+5 Moves',
              subtitle: '$price coins',
              icon: const CoinIcon(size: 28),
              fontSize: 22,
              height: 60,
              onPressed: canAfford ? () => Navigator.of(context).pop(LoseChoice.buyMoves) : null,
            ),
            if (adAvailable) ...[
              const SizedBox(height: 10),
              GoldButton(
                label: '+5 Moves',
                subtitle: 'Watch a short video',
                icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 30),
                color: GoldButtonColor.pink,
                fontSize: 22,
                height: 60,
                onPressed: () => Navigator.of(context).pop(LoseChoice.adMoves),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(LoseChoice.giveUp),
              child: Text('Give up (lose a life)', style: AppText.label(15, color: AppColors.chocolateLight)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Goal chip for light backgrounds.
class GoalChipDark extends StatelessWidget {
  const GoalChipDark({super.key, required this.goal, required this.remaining});
  final GoalDef goal;
  final int remaining;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.chocolate,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GoalIcon(goal, size: 30),
            const SizedBox(width: 6),
            Text('$remaining', style: AppText.title(20)),
          ],
        ),
      );
}

/// Shown after giving up / losing.
class LevelFailedDialog extends StatelessWidget {
  const LevelFailedDialog({super.key, required this.levelId, required this.livesLeft});
  final int levelId;
  final int livesLeft;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: ChocoPanel(
        title: 'Level $levelId',
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.heart_broken_rounded, size: 70, color: Color(0xFFFF5470)),
            Text('Level failed', style: AppText.title(28, color: AppColors.chocolate, shadows: [])),
            const SizedBox(height: 4),
            Text('You lost a life. Lives left: $livesLeft', style: AppText.label(15)),
            const SizedBox(height: 16),
            GoldButton(
              label: 'Try again',
              color: GoldButtonColor.green,
              width: 220,
              onPressed: livesLeft > 0 ? () => Navigator.of(context).pop(true) : null,
            ),
            const SizedBox(height: 10),
            GoldButton(
              label: 'Map',
              color: GoldButtonColor.choco,
              width: 220,
              height: 50,
              fontSize: 20,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pause menu.
enum PauseChoice { resume, restart, quit }

class PauseDialog extends StatelessWidget {
  const PauseDialog({super.key, required this.level, required this.movesMade});
  final LevelDef level;
  final bool movesMade;

  @override
  Widget build(BuildContext context) {
    final p = Services.progress;
    return SizedBox(
      width: 320,
      child: ChocoPanel(
        title: 'Paused',
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 18),
        child: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, value, setter) in [
                ('Music', p.music, (bool v) => p.setSetting(music: v)),
                ('Sound', p.sound, (bool v) => p.setSetting(sound: v)),
                ('Vibration', p.vibration, (bool v) => p.setSetting(vibration: v)),
              ])
                SwitchListTile(
                  dense: true,
                  title: Text(label, style: AppText.label(18)),
                  value: value,
                  onChanged: (v) {
                    setState(() => setter(v));
                    if (label == 'Music') Services.audio.applySettings();
                  },
                ),
              const SizedBox(height: 10),
              GoldButton(
                label: 'Resume',
                color: GoldButtonColor.green,
                width: 220,
                onPressed: () => Navigator.of(context).pop(PauseChoice.resume),
              ),
              const SizedBox(height: 10),
              GoldButton(
                label: 'Restart',
                width: 220,
                height: 50,
                fontSize: 20,
                subtitle: movesMade ? 'Costs a life' : null,
                onPressed: () => Navigator.of(context).pop(PauseChoice.restart),
              ),
              const SizedBox(height: 10),
              GoldButton(
                label: 'Quit level',
                color: GoldButtonColor.choco,
                width: 220,
                height: 50,
                fontSize: 20,
                subtitle: movesMade ? 'Costs a life' : null,
                onPressed: () => Navigator.of(context).pop(PauseChoice.quit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple message with OK.
class MessageDialog extends StatelessWidget {
  const MessageDialog({super.key, required this.title, required this.text, this.button = 'OK', this.picture});
  final String title;
  final String text;
  final String button;
  final Widget? picture;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 330,
        child: ChocoPanel(
          title: title,
          padding: const EdgeInsets.fromLTRB(18, 30, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (picture != null) ...[picture!, const SizedBox(height: 12)],
              Text(text, textAlign: TextAlign.center, style: AppText.label(17)),
              const SizedBox(height: 16),
              GoldButton(label: button, width: 200, onPressed: () => Navigator.of(context).pop(true)),
            ],
          ),
        ),
      );
}

/// Goals list used before a level starts.
class GoalsList extends StatelessWidget {
  const GoalsList({super.key, required this.level, required this.targets});
  final LevelDef level;
  final List<int> targets;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < level.goals.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  GoalIcon(level.goals[i], size: 34),
                  const SizedBox(width: 10),
                  Expanded(child: Text(goalText(level.goals[i], targets[i]), style: AppText.label(16))),
                ],
              ),
            ),
        ],
      );
}

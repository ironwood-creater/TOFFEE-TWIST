import 'package:flutter/material.dart';

import '../../game/logic/level.dart';
import '../../game/logic/types.dart';
import '../../game/render/sweet_art.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

/// Short how-to popup shown the first time a level with a tutorial starts.
class TutorialDialog extends StatelessWidget {
  const TutorialDialog({super.key, required this.tutorial});
  final TutorialDef tutorial;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: ChocoPanel(
        title: tutorial.title,
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.tileDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.caramel.withValues(alpha: 0.6), width: 2),
              ),
              child: TutorialPicture(id: tutorial.id),
            ),
            const SizedBox(height: 14),
            Text(tutorial.text, textAlign: TextAlign.center, style: AppText.label(17)),
            const SizedBox(height: 16),
            GoldButton(
              label: "Let's go!",
              color: GoldButtonColor.green,
              width: 210,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small diagram for each tutorial.
class TutorialPicture extends StatelessWidget {
  const TutorialPicture({super.key, required this.id});
  final String id;

  static const _s = 40.0;

  Widget _sweet(int c, [Special sp = Special.none]) => SweetIcon(c, size: _s, special: sp);
  Widget get _arrow => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.arrow_forward_rounded, color: AppColors.caramelDark, size: 30),
      );

  Widget _tile(void Function(Canvas, Rect) paint, {Widget? child}) => SizedBox(
        width: _s + 6,
        height: _s + 6,
        child: CustomPaint(painter: _FnPainter(paint), child: Center(child: child)),
      );

  @override
  Widget build(BuildContext context) {
    final row = switch (id) {
      'match3' => [_sweet(2), _sweet(2), _swapHint(_sweet(0)), _sweet(2), _arrow, const _Poof()],
      'collect' => [_sweet(1), _sweet(1), _sweet(1), _arrow, const Icon(Icons.flag_rounded, size: 38, color: AppColors.mint)],
      'striped' => [_sweet(3), _sweet(3), _sweet(3), _sweet(3), _arrow, _sweet(3, Special.stripedH)],
      'box' => [
          Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [_sweet(4), _sweet(4), _sweet(4)]),
            Row(mainAxisSize: MainAxisSize.min, children: [_sweet(4), const SizedBox(width: _s * 2)]),
            Row(mainAxisSize: MainAxisSize.min, children: [_sweet(4), const SizedBox(width: _s * 2)]),
          ]),
          _arrow,
          _sweet(4, Special.box),
        ],
      'swirl' => [
          for (var i = 0; i < 5; i++) SweetIcon(0, size: 32),
          _arrow,
          _sweet(-1, Special.swirl),
        ],
      'combo' => [_sweet(1, Special.stripedH), _plus, _sweet(2, Special.stripedV), _arrow, const Icon(Icons.add_rounded, size: 46, color: AppColors.gold)],
      'combo2' => [_sweet(-1, Special.swirl), _plus, _sweet(3, Special.stripedH), _arrow, const Icon(Icons.auto_awesome_rounded, size: 42, color: AppColors.gold)],
      'caramel' => [_tile((c, r) => SweetArt.paintCaramel(c, r, 1), child: _sweet(5)), _arrow, _tile((c, r) {})],
      'caramel2' => [_tile((c, r) => SweetArt.paintCaramel(c, r, 2)), _arrow, _tile((c, r) => SweetArt.paintCaramel(c, r, 1)), _arrow, _tile((c, r) {})],
      'crate' => [_sweet(0), _sweet(0), _sweet(0), _tile((c, r) => SweetArt.paintCrate(c, r, 1)), _arrow, const _Poof()],
      'crate3' => [_tile((c, r) => SweetArt.paintCrate(c, r, 3)), _arrow, _tile((c, r) => SweetArt.paintCrate(c, r, 2)), _arrow, _tile((c, r) => SweetArt.paintCrate(c, r, 1))],
      'nut' => [
          SweetIcon(-1, size: _s, nut: true),
          const Icon(Icons.arrow_downward_rounded, color: AppColors.caramelDark, size: 34),
          const Icon(Icons.vertical_align_bottom_rounded, color: AppColors.mint, size: 40),
        ],
      'shape' => [const Icon(Icons.grid_view_rounded, size: 50, color: AppColors.chocolateLight)],
      'boosters' => [
          const Icon(Icons.swap_horiz_rounded, size: 44, color: AppColors.chocolate),
          const SizedBox(width: 18),
          const Icon(Icons.horizontal_rule_rounded, size: 44, color: AppColors.chocolate),
        ],
      _ => [const Icon(Icons.lightbulb_rounded, size: 50, color: AppColors.gold)],
    };
    return FittedBox(
      child: Row(mainAxisSize: MainAxisSize.min, children: row),
    );
  }

  Widget get _plus => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2),
        child: Icon(Icons.add_rounded, color: AppColors.caramelDark, size: 26),
      );

  Widget _swapHint(Widget child) => Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          const Positioned(
            right: -2,
            top: -10,
            child: Icon(Icons.swap_vert_rounded, size: 22, color: AppColors.caramelDark),
          ),
        ],
      );
}

class _Poof extends StatelessWidget {
  const _Poof();

  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.auto_awesome_rounded, size: 40, color: AppColors.gold);
}

class _FnPainter extends CustomPainter {
  _FnPainter(this.fn);
  final void Function(Canvas, Rect) fn;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(8)),
        Paint()..color = AppColors.tileLight);
    fn(canvas, r);
  }

  @override
  bool shouldRepaint(_FnPainter oldDelegate) => false;
}

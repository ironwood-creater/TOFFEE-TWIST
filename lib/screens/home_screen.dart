import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../levels/level_repository.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/logo.dart';
import '../widgets/top_bar.dart';
import '../widgets/ui.dart';
import 'dialogs/meta_dialogs.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static bool _offeredDaily = false;

  @override
  void initState() {
    super.initState();
    Services.audio.startMusic();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_offeredDaily && Services.progress.canClaimDaily && mounted) {
        _offeredDaily = true;
        await showPopup<void>(context, const DailyRewardDialog());
      }
    });
  }

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final p = Services.progress;
    return Scaffold(
      body: ShopBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: p,
            builder: (context, _) => LayoutBuilder(
              builder: (context, c) {
                // Size everything from the space we have (small phones to tablets).
                final small = c.maxHeight < 680;
                final logo = math.min(c.maxWidth * 0.82, math.min(360.0, (c.maxHeight - 330) * 0.92))
                    .clamp(140.0, 360.0);
                final level = math.min(p.currentLevel, LevelRepository.totalLevels);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                      child: Row(
                        children: [
                          LivesPill(onTap: () => showPopup<bool>(context, const OutOfLivesDialog(), dismissible: true)),
                          const SizedBox(width: 8),
                          CoinsPill(onTap: () => _open(const ShopScreen())),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ToffeeLogo(size: logo),
                    const Spacer(),
                    GoldButton(
                      label: 'Play',
                      subtitle: p.currentLevel > LevelRepository.totalLevels ? 'All levels done!' : 'Level $level',
                      fontSize: small ? 32 : 38,
                      height: small ? 70 : 86,
                      width: math.min(280, c.maxWidth * 0.75),
                      color: GoldButtonColor.green,
                      onPressed: () => _open(const MapScreen(autoStart: true)),
                    ),
                    SizedBox(height: small ? 10 : 14),
                    GoldButton(
                      label: 'Level map',
                      fontSize: 20,
                      height: 50,
                      width: math.min(220, c.maxWidth * 0.6),
                      color: GoldButtonColor.choco,
                      onPressed: () => _open(const MapScreen()),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _FeatureButton(
                            icon: Icons.calendar_month_rounded,
                            label: 'Daily',
                            badge: p.canClaimDaily,
                            onTap: () => showPopup<void>(context, const DailyRewardDialog()),
                          ),
                          _FeatureButton(
                            icon: Icons.casino_rounded,
                            label: 'Spin',
                            badge: p.canFreeSpin,
                            onTap: () => showPopup<void>(context, const SpinWheelDialog()),
                          ),
                          _FeatureButton(
                            icon: Icons.storefront_rounded,
                            label: 'Shop',
                            onTap: () => _open(const ShopScreen()),
                          ),
                          _FeatureButton(
                            icon: Icons.settings_rounded,
                            label: 'Settings',
                            onTap: () => _open(const SettingsScreen()),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureButton extends StatelessWidget {
  const _FeatureButton({required this.icon, required this.label, required this.onTap, this.badge = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          Services.audio.play(Sfx.button);
          onTap();
        },
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.chocolateLight, AppColors.chocolate],
                    ),
                    border: Border.all(color: AppColors.chocolateDark, width: 3),
                    boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 4), blurRadius: 4)],
                  ),
                  child: Icon(icon, color: AppColors.goldLight, size: 36),
                ),
                if (badge)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: const Center(
                        child: Text('!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: AppText.title(15, color: AppColors.chocolate, shadows: const [])),
          ],
        ),
      ),
    );
  }
}

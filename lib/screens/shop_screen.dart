import 'package:flutter/material.dart';

import '../services/services.dart';
import '../theme.dart';
import '../widgets/top_bar.dart';
import '../widgets/ui.dart';

/// Coin packs and "Remove Ads" (real-money purchases through Google Play) and
/// boosters (bought with coins). The spin wheel is never sold.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  @override
  void initState() {
    super.initState();
    Services.iap.messages.addListener(_onMessage);
  }

  @override
  void dispose() {
    Services.iap.messages.removeListener(_onMessage);
    super.dispose();
  }

  void _onMessage() {
    final m = Services.iap.messages.value;
    if (m == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: AppText.label(15, color: Colors.white)),
      backgroundColor: AppColors.chocolate,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = Services.progress;
    final iap = Services.iap;
    return Scaffold(
      body: ShopBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([p, iap]),
            builder: (context, _) {
              final products = iap.products;
              final coinPacks = products.where((x) => x.coins > 0).toList();
              final removeAds = products.where((x) => x.removeAds).firstOrNull;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                    child: Row(
                      children: [
                        RoundIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back',
                            onPressed: () => Navigator.of(context).pop(), size: 42),
                        const SizedBox(width: 10),
                        Text('Sweet Shop', style: AppText.title(30, color: AppColors.chocolate, shadows: const [])),
                        const Spacer(),
                        const CoinsPill(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                      children: [
                        _SectionTitle('Boosters (coins)'),
                        for (final b in Booster.values)
                          _ShopRow(
                            icon: BoosterIcon(b, size: 44),
                            title: b.label,
                            subtitle: '${b.description} You have ${p.boosterCount(b)}.',
                            button: GoldButton(
                              label: '${b.price}',
                              icon: const CoinIcon(size: 22),
                              fontSize: 18,
                              height: 44,
                              onPressed: p.coins >= b.price
                                  ? () {
                                      if (p.buyBooster(b)) Services.audio.play(Sfx.coin);
                                    }
                                  : null,
                            ),
                          ),
                        const SizedBox(height: 10),
                        _SectionTitle('Coin packs'),
                        for (final pack in coinPacks)
                          _ShopRow(
                            icon: const CoinIcon(size: 44),
                            title: pack.title,
                            subtitle: '${pack.coins} coins',
                            button: GoldButton(
                              label: pack.price,
                              color: GoldButtonColor.green,
                              fontSize: 18,
                              height: 44,
                              onPressed: () => iap.buy(pack),
                            ),
                          ),
                        if (removeAds != null)
                          _ShopRow(
                            icon: const Icon(Icons.block_rounded, size: 44, color: AppColors.red),
                            title: removeAds.title,
                            subtitle: p.removeAds
                                ? 'Thank you! Ads between levels and banners are gone.'
                                : 'No more ads between levels or banners. Optional reward videos stay.',
                            button: p.removeAds
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 40)
                                : GoldButton(
                                    label: removeAds.price,
                                    color: GoldButtonColor.pink,
                                    fontSize: 18,
                                    height: 44,
                                    onPressed: () => iap.buy(removeAds),
                                  ),
                          ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                            onPressed: iap.restore,
                            child: Text('Restore purchases',
                                style: AppText.label(15, color: AppColors.chocolate, weight: FontWeight.w800)),
                          ),
                        ),
                        Text(
                          'Purchases are handled by Google Play. Coins only buy boosters and extra moves; '
                          'the daily spin can never be bought.',
                          textAlign: TextAlign.center,
                          style: AppText.label(12, color: AppColors.chocolateLight),
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
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        child: Text(text, style: AppText.title(22, color: AppColors.chocolate, shadows: const [])),
      );
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({required this.icon, required this.title, required this.subtitle, required this.button});
  final Widget icon;
  final String title;
  final String subtitle;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.chocolate, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 3), blurRadius: 4)],
      ),
      child: Row(
        children: [
          SizedBox(width: 52, child: Center(child: icon)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.title(18, color: AppColors.chocolate, shadows: const [])),
                Text(subtitle, style: AppText.label(13, color: AppColors.chocolateLight)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          button,
        ],
      ),
    );
  }
}

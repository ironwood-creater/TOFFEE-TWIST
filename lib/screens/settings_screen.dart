import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'dialogs/game_dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const credits = 'Toffee Twist is an original game.\n\n'
      'Game design, code and all sweet artwork: made for Toffee Twist (drawn in code).\n'
      'Sound effects and music: generated for Toffee Twist, released under CC0.\n'
      'Fonts: Baloo 2 and Nunito, SIL Open Font License 1.1.\n'
      'Built with Flutter and the Flame engine.';

  Future<void> _openPrivacy() async {
    final ok = await launchUrl(Uri.parse(AppConfig.privacyPolicyUrl), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the privacy policy.')));
    }
  }

  Future<void> _reset() async {
    final sure = await showPopup<bool>(
      context,
      SizedBox(
        width: 320,
        child: ChocoPanel(
          title: 'Reset progress?',
          padding: const EdgeInsets.fromLTRB(18, 30, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('All levels, stars, coins and boosters on this phone will be deleted. '
                  'Purchases like Remove Ads stay.',
                  textAlign: TextAlign.center, style: AppText.label(16)),
              const SizedBox(height: 16),
              GoldButton(
                label: 'Reset',
                color: GoldButtonColor.pink,
                width: 200,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: AppText.label(15, color: AppColors.chocolateLight)),
              ),
            ],
          ),
        ),
      ),
      dismissible: true,
    );
    if (sure == true) {
      await Services.progress.reset();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress reset.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Services.progress;
    Widget toggle(String label, IconData icon, bool value, void Function(bool) onChanged) => SwitchListTile(
          secondary: Icon(icon, color: AppColors.chocolate),
          title: Text(label, style: AppText.label(18)),
          value: value,
          onChanged: (v) => setState(() => onChanged(v)),
        );
    Widget action(String label, IconData icon, VoidCallback onTap) => ListTile(
          leading: Icon(icon, color: AppColors.chocolate),
          title: Text(label, style: AppText.label(18)),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.chocolate),
          onTap: onTap,
        );
    return Scaffold(
      body: ShopBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Row(
                  children: [
                    RoundIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(), size: 42),
                    const SizedBox(width: 10),
                    Text('Settings', style: AppText.title(30, color: AppColors.chocolate, shadows: const [])),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    ChocoPanel(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          toggle('Music', Icons.music_note_rounded, p.music, (v) {
                            p.setSetting(music: v);
                            Services.audio.applySettings();
                          }),
                          toggle('Sound', Icons.volume_up_rounded, p.sound, (v) => p.setSetting(sound: v)),
                          toggle('Vibration', Icons.vibration_rounded, p.vibration, (v) => p.setSetting(vibration: v)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ChocoPanel(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          action('Privacy policy', Icons.privacy_tip_rounded, _openPrivacy),
                          if (Services.ads.privacyOptionsRequired)
                            action('Privacy & ad choices', Icons.tune_rounded, Services.ads.showPrivacyOptions),
                          action('Restore purchases', Icons.restore_rounded, Services.iap.restore),
                          action('Credits', Icons.favorite_rounded, () {
                            showPopup<void>(context, const MessageDialog(title: 'Credits', text: credits), dismissible: true);
                          }),
                          action('Open-source licenses', Icons.description_rounded, () {
                            showLicensePage(
                              context: context,
                              applicationName: AppConfig.appName,
                              applicationVersion: '1.0.0',
                            );
                          }),
                          action('Reset progress', Icons.delete_forever_rounded, _reset),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text('${AppConfig.appName} 1.0.0\nContact: ${AppConfig.supportEmail}',
                          textAlign: TextAlign.center, style: AppText.label(13, color: AppColors.chocolateLight)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

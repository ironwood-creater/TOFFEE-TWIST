import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ads_config.dart';
import 'ads_service.dart';
import 'audio_service.dart';
import 'progress_service.dart';

/// Google AdMob ads with the Google User Messaging Platform (UMP) consent
/// form. Ads are only requested after the consent step (GDPR).
class AdmobAdsService extends AdsService {
  AdmobAdsService(this._progress, this._audio);

  final ProgressService _progress;
  final AudioService _audio;

  bool _canRequest = false;
  bool _started = false;
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  bool _loadingRewarded = false;
  bool _loadingInterstitial = false;
  int _rewardedRetries = 0;
  int _interstitialRetries = 0;
  PrivacyOptionsRequirementStatus _privacy = PrivacyOptionsRequirementStatus.unknown;

  /// Asks for consent if needed (EU/UK users see Google's form), then starts
  /// the ads SDK. Call once after the first screen is shown.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) debugPrint('Consent form: ${error.message}');
        });
        if (!done.isCompleted) done.complete();
      },
      (FormError error) {
        debugPrint('Consent info update failed: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future;
    // Consent from an earlier session still counts if this update failed.
    _canRequest = await ConsentInformation.instance.canRequestAds();
    _privacy = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    if (_canRequest) {
      await MobileAds.instance.updateRequestConfiguration(
        // Teen (13+) content rating at most; this is not a children's app.
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.t),
      );
      await MobileAds.instance.initialize();
      _loadRewarded();
      _loadInterstitial();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Rewarded videos: +5 moves, triple coins, extra spin, free life
  // ---------------------------------------------------------------------------

  @override
  bool get rewardedReady => _rewarded != null;

  void _loadRewarded() {
    if (!_canRequest || _rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdsConfig.rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
          _rewardedRetries = 0;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _loadingRewarded = false;
          _rewardedRetries++;
          Timer(Duration(seconds: (10 * _rewardedRetries).clamp(10, 120)), _loadRewarded);
        },
      ),
    );
  }

  @override
  Future<bool> showRewarded(RewardedPurpose purpose) async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    notifyListeners();
    var earned = false;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
      },
    );
    _audio.pauseForBackground();
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    final result = await done.future;
    _audio.resumeFromBackground();
    _loadRewarded();
    return result;
  }

  // ---------------------------------------------------------------------------
  // Interstitials: only between levels, never before level 10, max 1 per 3
  // ---------------------------------------------------------------------------

  void _loadInterstitial() {
    if (!_canRequest || _progress.removeAds || _interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdsConfig.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
          _interstitialRetries = 0;
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          _interstitialRetries++;
          Timer(Duration(seconds: (15 * _interstitialRetries).clamp(15, 180)), _loadInterstitial);
        },
      ),
    );
  }

  @override
  Future<void> betweenLevels(int levelJustPlayed) async {
    final allowed = InterstitialPolicy.shouldShow(
      levelJustPlayed: levelJustPlayed,
      levelsSinceLast: _progress.levelsSinceInterstitial,
      removeAds: _progress.removeAds,
    );
    if (!allowed) return;
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!done.isCompleted) done.complete();
      },
    );
    _progress.interstitialShown();
    _audio.pauseForBackground();
    await ad.show();
    await done.future;
    _audio.resumeFromBackground();
    _loadInterstitial();
  }

  // ---------------------------------------------------------------------------
  // Banner: only on the map screen
  // ---------------------------------------------------------------------------

  @override
  Widget? banner() => _canRequest && !_progress.removeAds ? const _MapBanner() : null;

  // ---------------------------------------------------------------------------
  // Privacy options (required by GDPR when consent was asked)
  // ---------------------------------------------------------------------------

  @override
  bool get privacyOptionsRequired => _privacy == PrivacyOptionsRequirementStatus.required;

  @override
  Future<void> showPrivacyOptions() async {
    await ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) debugPrint('Privacy options: ${error.message}');
    });
    _canRequest = await ConsentInformation.instance.canRequestAds();
    notifyListeners();
  }
}

class _MapBanner extends StatefulWidget {
  const _MapBanner();

  @override
  State<_MapBanner> createState() => _MapBannerState();
}

class _MapBannerState extends State<_MapBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    _load(MediaQuery.sizeOf(context).width.truncate());
  }

  Future<void> _load(int width) async {
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;
    final ad = BannerAd(
      adUnitId: AdsConfig.bannerId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}

/// In-app purchase products. These IDs are PLACEHOLDERS: create products with
/// exactly these IDs in Google Play Console (Monetize > Products > In-app
/// products), or change the IDs here to match the ones you create.
abstract final class IapConfig {
  /// Non-consumable: removes interstitial and banner ads forever
  /// (rewarded videos stay available because players choose to watch them).
  static const removeAds = 'remove_ads';

  /// Consumable coin packs.
  static const coinsSmall = 'coins_small';
  static const coinsMedium = 'coins_medium';
  static const coinsLarge = 'coins_large';

  static const coinPacks = <String, int>{
    coinsSmall: 1000,
    coinsMedium: 3000,
    coinsLarge: 8000,
  };

  static const titles = <String, String>{
    removeAds: 'Remove Ads',
    coinsSmall: 'Handful of Coins',
    coinsMedium: 'Jar of Coins',
    coinsLarge: 'Chest of Coins',
  };

  /// Shown only until Google Play sends the real local prices.
  static const placeholderPrices = <String, String>{
    removeAds: r'$2.99',
    coinsSmall: r'$0.99',
    coinsMedium: r'$2.99',
    coinsLarge: r'$6.99',
  };

  static const allIds = {removeAds, coinsSmall, coinsMedium, coinsLarge};
}

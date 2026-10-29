import 'package:flutter/foundation.dart';

import '../config/iap_config.dart';

/// A product shown in the shop.
class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.title,
    required this.price,
    this.coins = 0,
    this.removeAds = false,
  });
  final String id;
  final String title;

  /// Price text from Google Play (or a placeholder before the store answers).
  final String price;
  final int coins;
  final bool removeAds;
}

/// In-app purchases. The real one (Google Play Billing) is in
/// play_billing_service.dart; this interface lets web and tests run.
abstract class IapService extends ChangeNotifier {
  bool get available;
  List<ShopProduct> get products;

  /// Starts a purchase. The result arrives later through [onMessage].
  Future<void> buy(ShopProduct product);
  Future<void> restore();

  /// Short messages for the player ("Purchase complete!" ...).
  ValueListenable<String?> get messages;
}

class NoIapService extends IapService {
  NoIapService(this._products);
  final List<ShopProduct> _products;
  final _messages = ValueNotifier<String?>(null);

  @override
  bool get available => false;

  @override
  List<ShopProduct> get products => _products;

  @override
  Future<void> buy(ShopProduct product) async {
    _messages.value = 'Purchases are only available in the Google Play version.';
  }

  @override
  Future<void> restore() async {
    _messages.value = 'Purchases are only available in the Google Play version.';
  }

  @override
  ValueListenable<String?> get messages => _messages;
}

/// Products to show before Google Play answers (or on web/tests).
List<ShopProduct> placeholderProducts() => [
      for (final id in IapConfig.coinPacks.keys)
        ShopProduct(
          id: id,
          title: IapConfig.titles[id]!,
          price: IapConfig.placeholderPrices[id]!,
          coins: IapConfig.coinPacks[id]!,
        ),
      ShopProduct(
        id: IapConfig.removeAds,
        title: IapConfig.titles[IapConfig.removeAds]!,
        price: IapConfig.placeholderPrices[IapConfig.removeAds]!,
        removeAds: true,
      ),
    ];

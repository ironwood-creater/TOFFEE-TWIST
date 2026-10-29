import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/iap_config.dart';
import 'iap_service.dart';
import 'progress_service.dart';

/// Google Play in-app purchases: "Remove Ads" (bought once) and coin packs
/// (can be bought again). Product IDs are in lib/config/iap_config.dart.
class PlayBillingService extends IapService {
  PlayBillingService(this._progress);

  final ProgressService _progress;
  // Only touched in start() and later, so nothing connects before the app is ready.
  InAppPurchase get _iap => InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _available = false;
  final Map<String, ProductDetails> _details = {};
  List<ShopProduct> _products = placeholderProducts();
  final _messages = ValueNotifier<String?>(null);

  @override
  bool get available => _available;

  @override
  List<ShopProduct> get products => _products;

  @override
  ValueListenable<String?> get messages => _messages;

  void _say(String text) {
    _messages.value = null;
    _messages.value = text;
  }

  Future<void> start() async {
    _sub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => _say('Purchase error: $e'),
    );
    _available = await _iap.isAvailable();
    if (!_available) {
      notifyListeners();
      return;
    }
    final response = await _iap.queryProductDetails(IapConfig.allIds);
    for (final d in response.productDetails) {
      _details[d.id] = d;
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not set up in Play Console yet: ${response.notFoundIDs}');
    }
    _products = [
      for (final p in placeholderProducts())
        ShopProduct(
          id: p.id,
          title: p.title,
          price: _details[p.id]?.price ?? p.price,
          coins: p.coins,
          removeAds: p.removeAds,
        ),
    ];
    notifyListeners();
  }

  @override
  Future<void> buy(ShopProduct product) async {
    if (!_available) {
      _say('The Google Play store is not available right now.');
      return;
    }
    final details = _details[product.id];
    if (details == null) {
      _say('This item is not set up in Google Play yet.');
      return;
    }
    final param = PurchaseParam(productDetails: details);
    if (product.removeAds) {
      await _iap.buyNonConsumable(purchaseParam: param);
    } else {
      await _iap.buyConsumable(purchaseParam: param);
    }
  }

  @override
  Future<void> restore() async {
    if (!_available) {
      _say('The Google Play store is not available right now.');
      return;
    }
    _say('Restoring purchases...');
    await _iap.restorePurchases();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _say('Purchase pending...');
        case PurchaseStatus.canceled:
          _say('Purchase cancelled.');
        case PurchaseStatus.error:
          _say('Purchase failed: ${p.error?.message ?? 'unknown error'}');
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          _deliver(p);
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  void _deliver(PurchaseDetails p) {
    if (p.productID == IapConfig.removeAds) {
      if (!_progress.removeAds) {
        _progress.removeAds = true;
        _say('Ads removed. Thank you for your support!');
      }
      return;
    }
    final coins = IapConfig.coinPacks[p.productID];
    if (coins == null || p.status != PurchaseStatus.purchased) return;
    // Never give the same purchase twice (e.g. if the app closed mid-way).
    final key = p.purchaseID ?? '${p.productID}-${p.transactionDate}';
    if (!_progress.markPurchaseDelivered(key)) return;
    _progress.addCoins(coins);
    _say('+$coins coins added!');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

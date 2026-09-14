import 'package:purchases_flutter/purchases_flutter.dart';

class PremiumService {
  static const String entitlementId = 'premium';
  static const String apiKey = String.fromEnvironment('REVENUECAT_API_KEY');

  static bool runtimePremium = false;
  static bool configured = false;

  static Future<void> configure({required String appUserId}) async {
    if (configured || apiKey.isEmpty) return;
    final configuration = PurchasesConfiguration(apiKey)..appUserID = appUserId;
    await Purchases.configure(configuration);
    configured = true;
    await refresh();
  }

  static Future<CustomerInfo?> refresh() async {
    if (!configured) return null;
    final info = await Purchases.getCustomerInfo();
    runtimePremium = info.entitlements.active[entitlementId]?.isActive == true;
    return info;
  }

  static Future<Offerings?> offerings() async {
    if (!configured) return null;
    return Purchases.getOfferings();
  }

  static Future<CustomerInfo?> buyCurrentOffering() async {
    if (!configured) return null;
    final available = await Purchases.getOfferings();
    final current = available.current;
    if (current == null || current.availablePackages.isEmpty) {
      throw StateError('Nenhuma oferta Premium está configurada no RevenueCat.');
    }
    final result = await Purchases.purchaseStoreProduct(
      current.availablePackages.first.storeProduct,
    );
    runtimePremium =
        result.customerInfo.entitlements.active[entitlementId]?.isActive == true;
    return result.customerInfo;
  }

  static Future<CustomerInfo?> restore() async {
    if (!configured) return null;
    final info = await Purchases.restorePurchases();
    runtimePremium = info.entitlements.active[entitlementId]?.isActive == true;
    return info;
  }
}

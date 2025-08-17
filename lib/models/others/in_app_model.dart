import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:trace/app/config.dart';

class InAppPurchaseModel {
  static final String typePopular = "popular";
  static final String typeHot = "hot";
  static final String typeNormal = "normal";

  String? id;
  String? price;
  int? coins;
  DateTime? period;
  String? discount;
  String? type;
  String? image;
  String? currencySymbol;
  String? currency;
  StoreProduct? storeProduct;
  Package? package;

  InAppPurchaseModel({
    this.id,
    this.price,
    this.coins,
    this.period,
    this.discount,
    this.type,
    this.image,
    this.currency,
    this.currencySymbol,
    this.storeProduct,
    this.package,
  });

  // Factory: build model from RevenueCat Package
  static InAppPurchaseModel fromPackage(Package package) {
    final sp = package.storeProduct;
    final identifier = sp.identifier;
    final coins = _extractCoinsFromIdentifier(identifier);

    final model = InAppPurchaseModel(
      id: identifier,
      price: sp.priceString,
      coins: coins,
      type: _typeForCoins(coins),
      image: _imageForCoins(coins),
      currency: sp.currencyCode,
      storeProduct: sp,
      package: package,
    );

    return model;
  }

  // Factory: build model directly from StoreProduct (fallback path)
  static InAppPurchaseModel fromStoreProduct(StoreProduct sp) {
    final identifier = sp.identifier;
    final coins = _extractCoinsFromIdentifier(identifier);

    return InAppPurchaseModel(
      id: identifier,
      price: sp.priceString,
      coins: coins,
      type: _typeForCoins(coins),
      image: _imageForCoins(coins),
      currency: sp.currencyCode,
      storeProduct: sp,
      package: null,
    );
  }

  // Helper: infer popular/normal by coin tiers
  static String _typeForCoins(int coins) {
    if (coins == 1000 || coins == 10000 || coins == 100000 || coins == 300000) {
      return InAppPurchaseModel.typePopular;
    }
    return InAppPurchaseModel.typeNormal;
  }

  // Helper: image by coin tier
  static String _imageForCoins(int coins) {
    if (coins >= 100 && coins <= 600) {
      return "assets/svg/ic_coin_with_star.svg";
    } else if (coins >= 1000 && coins <= 4000) {
      return "assets/images/ic_coins_4000.png";
    } else if (coins >= 10000 && coins <= 50000) {
      return "assets/images/ic_coins_2.png";
    } else if (coins >= 100000) {
      return "assets/images/ic_coins_7.png";
    } else {
      return "assets/images/icon_jinbi.png"; // fallback
    }
  }

  // Helper: map identifier to coin amount with regex fallback
  static int _extractCoinsFromIdentifier(String identifier) {
    final Map<String, int> creditMap = {
      Config.credit100: 100,
      Config.credit200: 200,
      Config.credit400: 400,
      Config.credit600: 600,
      Config.credit1000: 1000,
      Config.credit1600: 1600,
      Config.credit2000: 2000,
      Config.credit3000: 3000,
      Config.credit4000: 4000,
      Config.credit10000: 10000,
      Config.credit20000: 20000,
      Config.credit25000: 25000,
      Config.credit40000: 40000,
      Config.credit50000: 50000,
      Config.credit100000: 100000,
      Config.credit150000: 150000,
      Config.credit300000: 300000,
    };

    if (creditMap.containsKey(identifier)) return creditMap[identifier]!;

    final regExp = RegExp(r'(\d+)\.credits');
    final match = regExp.firstMatch(identifier);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }

    return 0; // Unknown
  }

  String? getId() {
    return id;
  }

  void setId(String id) {
    this.id = id;
  }

  String? getPrice() {
    return price;
  }

  void setPrice(String price) {
    this.price = price;
  }

  int? getCoins() {
    return coins;
  }

  void setCoins(int coins) {
    this.coins = coins;
  }

  DateTime? getPeriod() {
    return period;
  }

  void setPeriod(DateTime time) {
    this.period = time;
  }

  String? getDiscount() {
    return discount;
  }

  void setDiscount(String discount) {
    this.discount = discount;
  }

  String? getType() {
    return type;
  }

  void setType(String type) {
    this.type = type;
  }

  String? getImage() {
    return image;
  }

  void setImage(String image) {
    this.image = image;
  }

  String? getCurrency() {
    return currency;
  }

  void setCurrency(String currency) {
    this.currency = currency;
  }

  String? getCurrencySymbol() {
    return currencySymbol;
  }

  void setCurrencySymbol(String currencySymbol) {
    this.currencySymbol = currencySymbol;
  }

  StoreProduct? getStoreProduct() {
    return storeProduct;
  }

  void setStoreProduct(StoreProduct storeProduct) {
    this.storeProduct = storeProduct;
  }

  Package? getPackage() {
    return package;
  }

  void setPackage(Package package) {
    this.package = package;
  }
}

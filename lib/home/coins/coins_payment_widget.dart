// ignore_for_file: deprecated_member_use, unused_local_variable

import 'dart:math' as Math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:trace/helpers/quick_actions.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:trace/models/GiftsModel.dart';
import 'package:trace/models/PaymentsModel.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/models/others/in_app_model.dart';
import 'package:trace/ui/container_with_corner.dart';
import 'package:trace/ui/text_with_tap.dart';
import 'package:trace/utils/colors.dart';
import 'package:trace/app/config.dart';

class CoinsFlowPayment {
  CoinsFlowPayment(
      {required BuildContext context,
      required UserModel currentUser,
      Function(GiftsModel giftsModel)? onGiftSelected,
      Function(int coins)? onCoinsPurchased,
      bool isDismissible = true,
      bool enableDrag = true,
      bool isScrollControlled = true,
      bool showOnlyCoinsPurchase = false,
      Color backgroundColor = Colors.transparent}) {
    showModalBottomSheet(
        context: (context),
        isScrollControlled: isScrollControlled,
        backgroundColor: backgroundColor,
        enableDrag: enableDrag,
        isDismissible: isDismissible,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
        builder: (context) {
          return _CoinsFlowWidget(
            currentUser: currentUser,
            onCoinsPurchased: onCoinsPurchased,
            onGiftSelected: onGiftSelected,
            showOnlyCoinsPurchase: showOnlyCoinsPurchase,
          );
        });
  }
}

// ignore: must_be_immutable
class _CoinsFlowWidget extends StatefulWidget {
  final Function? onCoinsPurchased;
  final Function? onGiftSelected;
  final bool? showOnlyCoinsPurchase;
  UserModel currentUser;

  _CoinsFlowWidget({
    required this.currentUser,
    this.onCoinsPurchased,
    this.onGiftSelected,
    this.showOnlyCoinsPurchase = false,
  });

  @override
  State<_CoinsFlowWidget> createState() => _CoinsFlowWidgetState();
}

class _CoinsFlowWidgetState extends State<_CoinsFlowWidget>
    with TickerProviderStateMixin {
  AnimationController? _animationController;
  int bottomSheetCurrentIndex = 0;

  late Offerings offerings;
  bool _isAvailable = false;
  bool _loading = true;
  InAppPurchaseModel? _inAppPurchaseModel;
  List<InAppPurchaseModel> _fallbackProducts = [];

  List<InAppPurchaseModel> getInAppList() {
    List<Package> myProductList = offerings.current!.availablePackages;

    print(
        "💰 [PAYMENT CONVERSION DEBUG] Starting conversion of ${myProductList.length} packages");

    List<InAppPurchaseModel> inAppPurchaseList = [];

    // Primary path: packages from offerings
    for (Package package in myProductList) {
      final identifier = package.storeProduct.identifier;
      print("💰 [PAYMENT CONVERSION DEBUG] Processing package: $identifier");

      final inAppPurchaseModel = InAppPurchaseModel.fromPackage(package);
      final coins = inAppPurchaseModel.coins ?? 0;

      print(
          "💰 [PAYMENT DEBUG] Set $coins coins for $identifier with image: ${inAppPurchaseModel.image}");

      if (coins > 0) {
        inAppPurchaseList.add(inAppPurchaseModel);
        print(
            "💰 [PAYMENT CONVERSION DEBUG] Added to list: ${inAppPurchaseModel.coins} coins, ${inAppPurchaseModel.price}");
      } else {
        print(
            "💰 [PAYMENT CONVERSION DEBUG] Skipped unknown product: $identifier");
      }
    }

    // Fallback path: use directly-fetched StoreProducts if needed
    if (inAppPurchaseList.length < 3 && _fallbackProducts.isNotEmpty) {
      print(
          "💰 [PAYMENT FALLBACK DEBUG] Using cached fallback products: ${_fallbackProducts.length}");
      for (final model in _fallbackProducts) {
        final exists = inAppPurchaseList.any((m) => m.id == model.id);
        if (!exists && (model.coins ?? 0) > 0) {
          inAppPurchaseList.add(model);
        }
      }
    }

    // Sort by coins amount for better UI display
    inAppPurchaseList.sort((a, b) => (a.coins ?? 0).compareTo(b.coins ?? 0));

    print(
        "💰 [PAYMENT CONVERSION DEBUG] Final list size: ${inAppPurchaseList.length}");
    return inAppPurchaseList;
  }

  int _extractCoinsFromIdentifier(String identifier) {
    // Map of all possible credit amounts from config
    Map<String, int> creditMap = {
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

    // Direct lookup first
    if (creditMap.containsKey(identifier)) {
      return creditMap[identifier]!;
    }

    // Fallback: try to extract number from identifier using regex
    RegExp regExp = RegExp(r'(\d+)\.credits');
    Match? match = regExp.firstMatch(identifier);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }

    return 0; // Unknown product
  }

  Widget _buildImageWidget(String imagePath) {
    if (imagePath.endsWith('.svg')) {
      return SvgPicture.asset(
        imagePath,
        height: 120, // Increased size
        width: 120, // Increased size
        fit: BoxFit.contain,
        placeholderBuilder: (context) => Image.asset(
          "assets/images/coin_bling.webp",
          height: 120,
          width: 120,
        ),
      );
    } else {
      return Image.asset(
        imagePath,
        height: 120, // Increased size
        width: 120, // Increased size
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            "assets/images/coin_bling.webp",
            height: 120,
            width: 120,
          );
        },
      );
    }
  }

  int _getCrossAxisCount(BuildContext context, int itemCount) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 600) return 5; // More gifts per row on tablets
    return 4; // 4 gifts per row for better spacing
  }

  final selectedGiftItemNotifier = ValueNotifier<GiftsModel?>(null);
  final countNotifier = ValueNotifier<String>('1');

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController.unbounded(vsync: this);
    initProducts();
  }

  initProducts() async {
    try {
      // Identify user with RevenueCat if possible
      try {
        if (widget.currentUser.objectId != null) {
          await Purchases.logIn(widget.currentUser.objectId!);
          print(
              "💰 [PAYMENT INIT DEBUG] Logged in user to RevenueCat: ${widget.currentUser.objectId}");
        }
      } catch (e) {
        print("💰 [PAYMENT INIT DEBUG] RevenueCat logIn failed: $e");
      }

      // Invalidate caches to avoid stale offerings
      try {
        await Purchases.invalidateCustomerInfoCache();
      } catch (_) {}

      print("💰 [PAYMENT INIT DEBUG] Starting to load offerings...");
      offerings = await Purchases.getOfferings();
      print(
          "💰 [PAYMENT INIT DEBUG] Initial offerings loaded with ${offerings.current?.availablePackages.length ?? 0} packages");

      // Prefetch fallback StoreProducts by explicit IDs
      try {
        final ids = [
          Config.credit100,
          Config.credit200,
          Config.credit400,
          Config.credit600,
          Config.credit1000,
          Config.credit1600,
          Config.credit2000,
          Config.credit3000,
          Config.credit4000,
          Config.credit10000,
          Config.credit20000,
          Config.credit25000,
          Config.credit40000,
          Config.credit50000,
          Config.credit100000,
          Config.credit150000,
          Config.credit300000,
        ];
        final products = await Purchases.getProducts(ids);
        _fallbackProducts = products
            .map((sp) => InAppPurchaseModel.fromStoreProduct(sp))
            .where((m) => (m.coins ?? 0) > 0)
            .toList();
        print(
            "💰 [PAYMENT INIT DEBUG] Prefetched fallback StoreProducts: ${_fallbackProducts.length}");
      } catch (e) {
        print(
            "💰 [PAYMENT INIT DEBUG] Failed to prefetch fallback products: $e");
      }

      if (offerings.current != null &&
          offerings.current!.availablePackages.length > 0) {
        print(
            "💰 [PAYMENT INIT DEBUG] Products available, setting state to available");
        setState(() {
          _isAvailable = true;
          _loading = false;
        });

        for (var package in offerings.current!.availablePackages) {
          print(
              "💰 [PAYMENT INIT DEBUG] Available product: ${package.storeProduct.identifier} - ${package.storeProduct.priceString}");
        }
      } else {
        print("💰 [PAYMENT INIT DEBUG] No products available");
        setState(() {
          _isAvailable = _fallbackProducts.isNotEmpty;
          _loading = false;
        });
      }

      _checkForUpdatedOfferings();
    } on PlatformException catch (e) {
      print("💰 [PAYMENT INIT DEBUG] Error loading offerings: ${e.message}");
      setState(() {
        _isAvailable =
            _fallbackProducts.isNotEmpty; // show fallback if possible
        _loading = false;
      });
    } catch (e) {
      print("💰 [PAYMENT INIT DEBUG] Unexpected error loading offerings: $e");
      setState(() {
        _isAvailable =
            _fallbackProducts.isNotEmpty; // show fallback if possible
        _loading = false;
      });
    }
  }

  void _checkForUpdatedOfferings() async {
    await Future.delayed(Duration(seconds: 3));

    try {
      await Purchases.invalidateCustomerInfoCache();
      Offerings updatedOfferings = await Purchases.getOfferings();
      print(
          "💰 [PAYMENT UPDATE DEBUG] Checking for updated offerings: ${updatedOfferings.current?.availablePackages.length ?? 0} packages");

      if (updatedOfferings.current != null &&
          updatedOfferings.current!.availablePackages.length > 0) {
        bool shouldUpdate = false;

        if (offerings.current == null ||
            offerings.current!.availablePackages.length == 0) {
          shouldUpdate = true;
          print(
              "💰 [PAYMENT UPDATE DEBUG] Found offerings when we had none before!");
        } else if (updatedOfferings.current!.availablePackages.length !=
            offerings.current!.availablePackages.length) {
          shouldUpdate = true;
          print(
              "💰 [PAYMENT UPDATE DEBUG] Different number of offerings found!");
        }

        if (shouldUpdate) {
          print(
              "💰 [PAYMENT UPDATE DEBUG] Offerings updated! Refreshing UI...");
          setState(() {
            offerings = updatedOfferings;
            _isAvailable = true;
            _loading = false;
          });
        }
      }
    } catch (e) {
      print(
          "💰 [PAYMENT UPDATE DEBUG] Error checking for updated offerings: $e");
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    selectedGiftItemNotifier.dispose();
    countNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _showGiftAndGetCoinsBottomSheet();
  }

  _purchaseProduct(InAppPurchaseModel inAppPurchaseModel) async {
    // Validate product availability before attempting purchase
    if (inAppPurchaseModel.package == null) {
      try {
        await Purchases.invalidateCustomerInfoCache();
        final fresh = await Purchases.getOfferings();
        final targetId = inAppPurchaseModel.id;
        Package? found;
        for (final offering in fresh.all.values) {
          for (final p in offering.availablePackages) {
            if (p.storeProduct.identifier == targetId) {
              found = p;
              break;
            }
          }
          if (found != null) break;
        }
        if (found != null) {
          inAppPurchaseModel.package = found;
        }
      } catch (e) {
        print("💰 [PAYMENT DEBUG] Failed to refresh package: $e");
      }
    }

    // If still no Package, but we have a StoreProduct (fallback path), we will use it
    if (inAppPurchaseModel.package == null &&
        inAppPurchaseModel.storeProduct == null) {
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        user: widget.currentUser,
        title: "in_app_purchases.product_unavailable_title".tr(),
        message: "in_app_purchases.product_unavailable_message".tr(),
        isError: true,
      );
      return;
    }

    QuickHelp.showLoadingDialog(context);

    try {
      print(
          "💰 [PAYMENT DEBUG] Attempting to purchase: ${inAppPurchaseModel.id} for ${inAppPurchaseModel.coins} coins");

      CustomerInfo customerInfo;
      if (inAppPurchaseModel.package != null) {
        customerInfo =
            await Purchases.purchasePackage(inAppPurchaseModel.package!);
      } else {
        customerInfo = await Purchases.purchaseStoreProduct(
            inAppPurchaseModel.storeProduct!);
      }

      print(
          "💰 [PAYMENT DEBUG] Purchase successful, adding ${inAppPurchaseModel.coins} coins to user");

      widget.currentUser.addCredit = inAppPurchaseModel.coins!;
      await widget.currentUser.save();

      registerPayment(customerInfo, inAppPurchaseModel);

      // Double-check entitlement/product status and finish transactions if needed (Android)
      try {
        if (QuickHelp.isAndroidPlatform()) {
          await Purchases.invalidateCustomerInfoCache();
          await Purchases.getCustomerInfo();
        }
      } catch (_) {}

      if (widget.onCoinsPurchased != null) {
        widget.onCoinsPurchased!(inAppPurchaseModel.coins!);
      }

      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        user: widget.currentUser,
        title: "in_app_purchases.coins_purchased"
            .tr(namedArgs: {"coins": inAppPurchaseModel.coins!.toString()}),
        message: "in_app_purchases.coins_added_to_account".tr(),
        isError: false,
      );
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      QuickHelp.hideLoadingDialog(context);

      print(
          "💰 [PAYMENT ERROR DEBUG] Error code: $errorCode, Message: ${e.message}");

      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          user: widget.currentUser,
          title: "in_app_purchases.purchase_cancelled_title".tr(),
          message: "in_app_purchases.purchase_cancelled".tr(),
        );
      } else if (errorCode ==
          PurchasesErrorCode.productNotAvailableForPurchaseError) {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          user: widget.currentUser,
          title: "in_app_purchases.product_unavailable_title".tr(),
          message: "in_app_purchases.product_unavailable_message".tr(),
          isError: true,
        );
      } else if (errorCode == PurchasesErrorCode.invalidReceiptError) {
        _handleInvalidPurchase();
      } else {
        handleError(e);
      }
    }
  }

  void _handleInvalidPurchase() {
    QuickHelp.showAppNotification(
        context: context, title: "in_app_purchases.invalid_purchase".tr());
    QuickHelp.hideLoadingDialog(context);
  }

  void registerPayment(
      CustomerInfo customerInfo, InAppPurchaseModel productDetails) async {
    PaymentsModel paymentsModel = PaymentsModel();
    paymentsModel.setAuthor = widget.currentUser;
    paymentsModel.setAuthorId = widget.currentUser.objectId!;
    paymentsModel.setPaymentType = PaymentsModel.paymentTypeConsumible;

    paymentsModel.setId = productDetails.id!;
    paymentsModel.setTitle = productDetails.storeProduct!.title;
    paymentsModel.setTransactionId = customerInfo.originalPurchaseDate!;
    paymentsModel.setCurrency = productDetails.currency!.toUpperCase();
    paymentsModel.setPrice = productDetails.price.toString();
    paymentsModel.setMethod = QuickHelp.isAndroidPlatform()
        ? "Google Play"
        : QuickHelp.isIOSPlatform()
            ? "App Store"
            : "";
    paymentsModel.setStatus = PaymentsModel.paymentStatusCompleted;

    await paymentsModel.save();
  }

  void handleError(PlatformException error) {
    QuickHelp.hideLoadingDialog(context);
    QuickHelp.showAppNotification(context: context, title: error.message);
  }

  showPendingUI() {
    QuickHelp.showLoadingDialog(context);
    print("InAppPurchase showPendingUI");
  }

  Widget _showGiftAndGetCoinsBottomSheet() {
    return StatefulBuilder(builder: (context, setState) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.black.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(28.0),
            topRight: const Radius.circular(28.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: ContainerCorner(
          color: kTransparentColor,
          child: IndexedStack(
            index: widget.showOnlyCoinsPurchase! ? 1 : bottomSheetCurrentIndex,
            children: [
              Scaffold(
                backgroundColor: kTransparentColor,
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  elevation: 0,
                  leading: Container(
                    margin: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: BackButton(
                      color: Colors.white,
                    ),
                  ),
                  actions: [
                    Container(
                      margin: EdgeInsets.only(right: 16, top: 8, bottom: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            kWarninngColor,
                            kWarninngColor.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: kWarninngColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ContainerCorner(
                        height: 36,
                        borderRadius: 25,
                        color: kTransparentColor,
                        onTap: () {
                          setState(() {
                            bottomSheetCurrentIndex = 1;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                "assets/svg/coin.svg",
                                width: 18,
                                height: 18,
                              ),
                              SizedBox(width: 6),
                              TextWithTap(
                                "message_screen.get_coins".tr(),
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w600,
                              )
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                  backgroundColor: kTransparentColor,
                  centerTitle: true,
                  title: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SvgPicture.asset(
                            "assets/svg/ic_coin_with_star.svg",
                            width: 20,
                            height: 20,
                          ),
                        ),
                        SizedBox(width: 8),
                        TextWithTap(
                          widget.currentUser.getCredits.toString(),
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        )
                      ],
                    ),
                  ),
                ),
                body: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        SizedBox(height: 8),
                        ContainerCorner(
                            color: kTransparentColor,
                            child: _tabSection(context, setState)),
                      ],
                    ),
                  ),
                ),
              ),
              Scaffold(
                backgroundColor: kTransparentColor,
                appBar: AppBar(
                  elevation: 0,
                  actions: [
                    Container(
                      margin: EdgeInsets.only(right: 16, top: 8, bottom: 8),
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: SvgPicture.asset(
                              "assets/svg/ic_coin_with_star.svg",
                              width: 16,
                              height: 16,
                            ),
                          ),
                          SizedBox(width: 6),
                          TextWithTap(
                            widget.currentUser.getCredits.toString(),
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          )
                        ],
                      ),
                    ),
                  ],
                  backgroundColor: kTransparentColor,
                  title: Container(
                    child: TextWithTap(
                      "message_screen.get_coins".tr(),
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  centerTitle: true,
                  automaticallyImplyLeading: false,
                  leading: Container(
                    margin: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: BackButton(
                      color: Colors.white,
                      onPressed: () {
                        if (widget.showOnlyCoinsPurchase!) {
                          Navigator.of(this.context).pop();
                        } else {
                          setState(() {
                            bottomSheetCurrentIndex = 0;
                          });
                        }
                      },
                    ),
                  ),
                ),
                body: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: getBody(),
                ),
              )
            ],
          ),
        ),
      );
    });
  }

  Widget _tabSection(BuildContext context, StateSetter stateSetter) {
    return DefaultTabController(
      length: 9,
      child: Column(
        children: [
          getGifts(GiftsModel.giftCategoryTypeClassic, stateSetter),
        ],
      ),
    );
  }

  Widget getGifts(String category, StateSetter setState) {
    print("💰 [COINS-GIFT DEBUG] ===== STARTING GIFT FETCH =====");
    print(
        "💰 [COINS-GIFT DEBUG] Current user credits: ${widget.currentUser.getCredits}");
    print("💰 [COINS-GIFT DEBUG] Requested category: $category");

    QueryBuilder<GiftsModel> giftQuery = QueryBuilder<GiftsModel>(GiftsModel());

    return Container(
      constraints: BoxConstraints(
        minHeight: 200,
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: ParseLiveGridWidget<GiftsModel>(
        query: giftQuery,
        crossAxisCount: _getCrossAxisCount(context, 8),
        reverse: false,
        crossAxisSpacing: 20,
        mainAxisSpacing: 24,
        lazyLoading: false,
        childAspectRatio: 0.9,
        shrinkWrap: true,
        listenOnAllSubItems: true,
        duration: Duration(seconds: 0),
        animationController: _animationController,
        childBuilder: (BuildContext context,
            ParseLiveListElementSnapshot<GiftsModel> snapshot) {
          print("💰 [COINS-GIFT DEBUG] Processing gift item from snapshot");

          if (!snapshot.hasData || snapshot.loadedData == null) {
            print(
                "💰 [COINS-GIFT DEBUG] ❌ No data in snapshot, returning placeholder");
            return Container(
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    strokeWidth: 2,
                  ),
                ),
              ),
            );
          }

          GiftsModel gift = snapshot.loadedData!;
          print("💰 [COINS-GIFT DEBUG] ✅ Gift loaded successfully:");
          print("💰 [COINS-GIFT DEBUG] - Gift ID: ${gift.objectId}");
          print("💰 [COINS-GIFT DEBUG] - Gift Name: ${gift.getName}");
          print("💰 [COINS-GIFT DEBUG] - Gift Coins: ${gift.getCoins}");

          return ValueListenableBuilder<GiftsModel?>(
            valueListenable: selectedGiftItemNotifier,
            builder: (context, selectedGiftItem, _) {
              bool isSelected = selectedGiftItem?.objectId == gift.objectId;

              return GestureDetector(
                onTap: () => _checkCredits(gift, setState),
                child: Container(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Gift Image - Larger with glow effect
                      Expanded(
                        flex: 4,
                        child: Container(
                          width: double.infinity,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glow effect for selected item
                              if (isSelected)
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        Color(0xFF6366F1).withOpacity(0.3),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              // Main gift image - larger size, complete image shown
                              Container(
                                width: 90,
                                height: 90,
                                padding: EdgeInsets.all(
                                    4), // Further reduced padding to make image larger
                                child: gift.getPreview?.url != null
                                    ? QuickActions.photosWidget(
                                        gift.getPreview!.url!,
                                        fit: BoxFit
                                            .contain, // Show complete image without cropping
                                      )
                                    : Icon(
                                        Icons.card_giftcard,
                                        color: Colors.white60,
                                        size:
                                            36, // Larger icon to match increased image size
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 12),

                      // Minimal coin price - smaller text and icon
                      Container(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              child: SvgPicture.asset(
                                "assets/svg/ic_coin_with_star.svg",
                                color: Color(0xFFFACC15),
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              gift.getCoins?.toString() ?? "0",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w300, // Thin font
                                letterSpacing: 0.3,
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        queryEmptyElement: Container(
          height: 300,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(
                  Icons.card_giftcard_outlined,
                  size: 32,
                  color: Colors.white30,
                ),
              ),
              SizedBox(height: 20),
              Text(
                "No gifts available",
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        gridLoadingElement: Container(
          height: 300,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 16),
              Text(
                "Loading gifts...",
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget getBody() {
    if (_loading) {
      return Container(
        height: 400,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 20),
            Text(
              "Loading coin packages...",
              style: TextStyle(
                color: Colors.white60,
                fontSize: 16,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      );
    } else if (_isAvailable) {
      List<InAppPurchaseModel> inAppList = getInAppList();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              Container(
                padding: EdgeInsets.all(20),
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      kWarninngColor.withOpacity(0.2),
                      kWarninngColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: kWarninngColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kWarninngColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SvgPicture.asset(
                        "assets/svg/ic_coin_with_star.svg",
                        width: 24,
                        height: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Choose Your Coin Package",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Select the perfect amount for your needs",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Grid section
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // Force 2 columns for bigger items
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 0.75, // Make items taller
                  ),
                  itemCount: inAppList.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    InAppPurchaseModel inApp = inAppList[index];
                    bool isPopular =
                        inApp.type == InAppPurchaseModel.typePopular;

                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isPopular
                              ? [
                                  kWarninngColor.withOpacity(0.3),
                                  kWarninngColor.withOpacity(0.1),
                                ]
                              : [
                                  Colors.white.withOpacity(0.1),
                                  Colors.white.withOpacity(0.05),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isPopular
                              ? kWarninngColor.withOpacity(0.5)
                              : Colors.white.withOpacity(0.2),
                          width: isPopular ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isPopular
                                ? kWarninngColor.withOpacity(0.2)
                                : Colors.black.withOpacity(0.1),
                            blurRadius: isPopular ? 12 : 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Popular badge
                          if (isPopular)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: kWarninngColor,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kWarninngColor.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  "POPULAR",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          // Main content
                          ContainerCorner(
                            color: kTransparentColor,
                            borderRadius: 16,
                            onTap: () {
                              _inAppPurchaseModel = inApp;
                              _purchaseProduct(inApp);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(
                                  20.0), // Increased padding
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Credits text
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12), // Increased padding
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      QuickHelp.checkFundsWithString(
                                          amount: "${inApp.coins}"),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 22, // Increased font size
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  SizedBox(height: 16), // Added spacing
                                  // Image
                                  Container(
                                    width: 130, // Fixed larger size
                                    height: 130, // Fixed larger size
                                    padding: const EdgeInsets.all(12.0),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: _buildImageWidget(inApp.image ??
                                        "assets/images/coin_bling.webp"),
                                  ),
                                  SizedBox(height: 16), // Added spacing
                                  // Price button
                                  Container(
                                    width: double.infinity,
                                    height: 55, // Fixed height for button
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isPopular
                                            ? [
                                                kWarninngColor,
                                                kWarninngColor.withOpacity(0.8),
                                              ]
                                            : [
                                                Colors.deepPurpleAccent,
                                                Colors.deepPurpleAccent
                                                    .withOpacity(0.8),
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(28),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isPopular
                                                  ? kWarninngColor
                                                  : Colors.deepPurpleAccent)
                                              .withOpacity(0.4),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        "${inApp.price}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18, // Increased font size
                                          fontWeight: FontWeight.w700,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        height: 400,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red.withOpacity(0.7),
                size: 32,
              ),
            ),
            SizedBox(height: 20),
            Text(
              "in_app_purchases.no_products_available_title".tr(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              "in_app_purchases.no_products_available_message".tr(),
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.w300,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            // Retry button
            Container(
              width: 200,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    setState(() {
                      _loading = true;
                      _isAvailable = false;
                    });
                    initProducts();
                  },
                  child: Center(
                    child: Text(
                      "in_app_purchases.retry_loading".tr(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  _checkCredits(GiftsModel gift, StateSetter setState) {
    print("💰 [CREDIT CHECK] ===== CHECKING USER CREDITS =====");
    print("💰 [CREDIT CHECK] User credits: ${widget.currentUser.getCredits}");
    print("💰 [CREDIT CHECK] Gift cost: ${gift.getCoins}");
    print("💰 [CREDIT CHECK] Gift name: ${gift.getName}");

    if (widget.currentUser.getCredits! >= gift.getCoins!) {
      print("💰 [CREDIT CHECK] ✅ User has sufficient credits");
      // Update selected gift
      selectedGiftItemNotifier.value = gift;

      if (widget.onGiftSelected != null) {
        print("💰 [CREDIT CHECK] Calling onGiftSelected callback");
        widget.onGiftSelected!(gift);
        Navigator.of(context).pop();
        print("💰 [CREDIT CHECK] Gift selection completed");
      }
    } else {
      print(
          "💰 [CREDIT CHECK] ❌ Insufficient credits - redirecting to purchase");
      setState(() {
        bottomSheetCurrentIndex = 1;
      });
    }
  }
}

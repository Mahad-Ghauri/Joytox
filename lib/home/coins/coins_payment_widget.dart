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
      bool isScrollControlled = false,
      bool showOnlyCoinsPurchase = false,
      Color backgroundColor = Colors.transparent}) {
    showModalBottomSheet(
        context: (context),
        isScrollControlled: isScrollControlled,
        backgroundColor: backgroundColor,
        enableDrag: enableDrag,
        isDismissible: isDismissible,
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

  List<InAppPurchaseModel> getInAppList() {
    List<Package> myProductList = offerings.current!.availablePackages;

    print(
        "💰 [PAYMENT CONVERSION DEBUG] Starting conversion of ${myProductList.length} packages");

    List<InAppPurchaseModel> inAppPurchaseList = [];

    for (Package package in myProductList) {
      print(
          "💰 [PAYMENT CONVERSION DEBUG] Processing package: ${package.storeProduct.identifier}");
      InAppPurchaseModel inAppPurchaseModel = InAppPurchaseModel();

      // Set basic package info
      inAppPurchaseModel.package = package;
      inAppPurchaseModel.storeProduct = package.storeProduct;
      inAppPurchaseModel.id = package.storeProduct.identifier;
      inAppPurchaseModel.price = package.storeProduct.priceString;
      inAppPurchaseModel.currency = package.storeProduct.currencyCode;

      // Extract coins from product identifier using helper method
      String identifier = package.storeProduct.identifier;
      int coins = _extractCoinsFromIdentifier(identifier);

      inAppPurchaseModel.coins = coins;

      // Set image based on coin amount
      if (coins >= 100 && coins <= 600) {
        inAppPurchaseModel.image = "assets/svg/ic_coin_with_star.svg";
      } else if (coins >= 1000 && coins <= 4000) {
        inAppPurchaseModel.image = "assets/images/ic_coins_4000.png";
      } else if (coins >= 10000 && coins <= 55000) {
        inAppPurchaseModel.image = "assets/images/ic_coins_2.png";
      } else if (coins >= 100000) {
        inAppPurchaseModel.image = "assets/images/ic_coins_7.png";
      } else {
        inAppPurchaseModel.image = "assets/images/icon_jinbi.png"; // fallback
      }

      print(
          "💰 [PAYMENT DEBUG] Set $coins coins for ${identifier} with image: ${inAppPurchaseModel.image}");

      // Set type based on coins amount - mark popular packages
      if (coins == 1000 ||
          coins == 10000 ||
          coins == 100000 ||
          coins == 300000) {
        inAppPurchaseModel.type = InAppPurchaseModel.typePopular;
      } else {
        inAppPurchaseModel.type = InAppPurchaseModel.typeNormal;
      }

      // Only add if we successfully extracted coins
      if (coins > 0) {
        inAppPurchaseList.add(inAppPurchaseModel);
        print(
            "💰 [PAYMENT CONVERSION DEBUG] Added to list: ${inAppPurchaseModel.coins} coins, ${inAppPurchaseModel.price}");
      } else {
        print(
            "💰 [PAYMENT CONVERSION DEBUG] Skipped unknown product: $identifier");
      }
    }

    // Sort by coins amount for better UI display
    inAppPurchaseList.sort((a, b) => a.coins!.compareTo(b.coins!));

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
      Config.credit21000: 21000,
      Config.credit23000: 23000,
      Config.credit35000: 35000,
      Config.credit55000: 55000,
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

  int _getCrossAxisCount(int itemCount) {
    if (itemCount <= 4) return 2;
    if (itemCount <= 9) return 3;
    return 4;
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
      offerings = await Purchases.getOfferings();
      print(
          "💰 [PAYMENT INIT DEBUG] Initial offerings loaded with ${offerings.current?.availablePackages.length ?? 0} packages");

      if (offerings.current!.availablePackages.length > 0) {
        // Display packages for sale

        setState(() {
          _isAvailable = true;
          _loading = false;
        });
        // Display packages for sale
      }

      // Set up a timer to check for updated offerings periodically
      _checkForUpdatedOfferings();
    } on PlatformException {
      // optional error handling

      setState(() {
        _isAvailable = false;
        _loading = false;
      });
    }
  }

  void _checkForUpdatedOfferings() async {
    // Wait a bit for network update to complete
    await Future.delayed(Duration(seconds: 3));

    try {
      // Force refresh from network by invalidating cache
      await Purchases.invalidateCustomerInfoCache();
      Offerings updatedOfferings = await Purchases.getOfferings();
      print(
          "💰 [PAYMENT UPDATE DEBUG] Checking for updated offerings: ${updatedOfferings.current?.availablePackages.length ?? 0} packages");

      if (updatedOfferings.current != null &&
          updatedOfferings.current!.availablePackages.length !=
              offerings.current!.availablePackages.length) {
        print("💰 [PAYMENT UPDATE DEBUG] Offerings updated! Refreshing UI...");
        setState(() {
          offerings = updatedOfferings;
        });
      } else {
        print(
            "💰 [PAYMENT UPDATE DEBUG] No new offerings found. Current: ${offerings.current!.availablePackages.length}, Updated: ${updatedOfferings.current?.availablePackages.length ?? 0}");

        // Try one more time with a longer delay
        await Future.delayed(Duration(seconds: 3));
        Offerings finalCheck = await Purchases.getOfferings();
        print(
            "💰 [PAYMENT FINAL CHECK DEBUG] Final check offerings: ${finalCheck.current?.availablePackages.length ?? 0} packages");

        if (finalCheck.current != null &&
            finalCheck.current!.availablePackages.length !=
                offerings.current!.availablePackages.length) {
          print(
              "💰 [PAYMENT FINAL CHECK DEBUG] Final check found updates! Refreshing UI...");
          setState(() {
            offerings = finalCheck;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _showGiftAndGetCoinsBottomSheet();
  }

  _purchaseProduct(InAppPurchaseModel inAppPurchaseModel) async {
    QuickHelp.showLoadingDialog(context);

    try {
      await Purchases.purchasePackage(inAppPurchaseModel.package!);

      widget.currentUser.addCredit = _inAppPurchaseModel!.coins!;
      await widget.currentUser.save();

      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        user: widget.currentUser,
        title: "in_app_purchases.coins_purchased"
            .tr(namedArgs: {"coins": _inAppPurchaseModel!.coins!.toString()}),
        message: "in_app_purchases.coins_added_to_account".tr(),
        isError: false,
      );
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);

      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        QuickHelp.hideLoadingDialog(context);

        QuickHelp.showAppNotificationAdvanced(
          context: context,
          user: widget.currentUser,
          title: "in_app_purchases.purchase_cancelled_title".tr(),
          message: "in_app_purchases.purchase_cancelled".tr(),
        );
      } else if (errorCode != PurchasesErrorCode.invalidReceiptError) {
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
    // Save all payment information
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
                                fontSize: 13,
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

    // Add detailed query debugging
    print("💰 [COINS-GIFT DEBUG] === QUERY DETAILS ===");
    print("💰 [COINS-GIFT DEBUG] Table name: ${GiftsModel.keyTableName}");
    print(
        "💰 [COINS-GIFT DEBUG] keyGiftCategories field: ${GiftsModel.keyGiftCategories}");
    print("💰 [COINS-GIFT DEBUG] gifStatus value: ${GiftsModel.gifStatus}");

    // Show ALL gifts regardless of category
    QueryBuilder<GiftsModel> giftQuery = QueryBuilder<GiftsModel>(GiftsModel());

    // No category filter - show all gifts
    print("💰 [COINS-GIFT DEBUG] === SHOWING ALL GIFTS ===");
    print(
        "💰 [COINS-GIFT DEBUG] Query: SELECT ALL FROM ${GiftsModel.keyTableName}");

    return ContainerCorner(
      color: kTransparentColor,
      child: ParseLiveGridWidget<GiftsModel>(
        query: giftQuery,
        crossAxisCount: 4,
        reverse: false,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        lazyLoading: false,
        //childAspectRatio: 1.0,
        shrinkWrap: true,
        listenOnAllSubItems: true,
        duration: Duration(seconds: 0),
        animationController: _animationController,
        childBuilder: (BuildContext context,
            ParseLiveListElementSnapshot<GiftsModel> snapshot) {
          print("💰 [COINS-GIFT DEBUG] Processing gift item from snapshot");
          print(
              "💰 [COINS-GIFT DEBUG] Snapshot state: ${snapshot.hasData ? 'HAS_DATA' : 'NO_DATA'}");
          print(
              "💰 [COINS-GIFT DEBUG] Data available: ${snapshot.loadedData != null ? 'YES' : 'NO'}");

          if (!snapshot.hasData || snapshot.loadedData == null) {
            print(
                "💰 [COINS-GIFT DEBUG] ❌ No data in snapshot, returning placeholder");
            return Container(
              width: 50,
              height: 50,
              color: Colors.grey.withOpacity(0.3),
              child: Icon(Icons.error, color: Colors.red),
            );
          }

          GiftsModel gift = snapshot.loadedData!;
          print("💰 [COINS-GIFT DEBUG] ✅ Gift loaded successfully:");
          print("💰 [COINS-GIFT DEBUG] - Gift ID: ${gift.objectId}");
          print("💰 [COINS-GIFT DEBUG] - Gift Name: ${gift.getName}");
          print("💰 [COINS-GIFT DEBUG] - Gift Coins: ${gift.getCoins}");
          print(
              "💰 [COINS-GIFT DEBUG] - Gift Category: ${gift.getGiftCategories}");
          print(
              "💰 [COINS-GIFT DEBUG] - Preview URL: ${gift.getPreview?.url ?? 'NULL'}");

          return GestureDetector(
            //onTap: () => _checkCredits(gift, setState),
            child: Container(
              margin: EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _checkCredits(gift, setState),
                    child: Column(
                      children: [
                        ValueListenableBuilder<GiftsModel?>(
                          valueListenable: selectedGiftItemNotifier,
                          builder: (context, selectedGiftItem, _) {
                            bool isSelected =
                                selectedGiftItem?.objectId == gift.objectId;
                            return Container(
                              width: 60,
                              height: 60,
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? kWarninngColor.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? kWarninngColor
                                      : Colors.white.withOpacity(0.1),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: QuickActions.photosWidget(
                                    gift.getPreview!.url),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: SvgPicture.asset(
                            "assets/svg/ic_coin_with_star.svg",
                            width: 12,
                            height: 12,
                          ),
                        ),
                        SizedBox(width: 4),
                        TextWithTap(
                          gift.getCoins.toString(),
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        queryEmptyElement: Container(
          margin: EdgeInsets.only(top: 50),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.card_giftcard_outlined,
                  size: 48,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 20),
              Text(
                "No gifts available",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                "Check back later for new gifts",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        gridLoadingElement: Container(
          margin: EdgeInsets.only(top: 50),
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(kWarninngColor),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 20),
              Text(
                "Loading gifts...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Tab gefTab(String name, String image) {
    return Tab(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            image,
            color: Colors.white.withOpacity(0.7),
            width: 20,
            height: 20,
          ),
          TextWithTap(
            name,
            fontSize: 12,
            marginTop: 5,
          ),
        ],
      ),
    );
  }

  Widget getBody() {
    if (_loading) {
      return Container(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kWarninngColor),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 20),
            Text(
              "Loading coin packages...",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
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
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
            ),
            SizedBox(height: 20),
            Text(
              "No coin packages available",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Please try again later",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
  }

  _testGiftDatabase() async {
    print("💰 [DATABASE TEST] ===== TESTING GIFT DATABASE =====");

    try {
      // Test 1: Count all gifts
      QueryBuilder<GiftsModel> countQuery =
          QueryBuilder<GiftsModel>(GiftsModel());
      countQuery.setLimit(1000);
      ParseResponse countResponse = await countQuery.query();

      print(
          "💰 [DATABASE TEST] Total gifts in database: ${countResponse.results?.length ?? 0}");

      if (countResponse.success &&
          countResponse.results != null &&
          countResponse.results!.isNotEmpty) {
        print("💰 [DATABASE TEST] Sample gift data:");
        for (int i = 0; i < Math.min(3, countResponse.results!.length); i++) {
          GiftsModel gift = countResponse.results![i] as GiftsModel;
          print("💰 [DATABASE TEST] - Gift ${i + 1}:");
          print("💰 [DATABASE TEST]   - ID: ${gift.objectId}");
          print("💰 [DATABASE TEST]   - Name: ${gift.getName}");
          print("💰 [DATABASE TEST]   - Coins: ${gift.getCoins}");
          print("💰 [DATABASE TEST]   - Categories: ${gift.getGiftCategories}");
        }

        // Test 2: Test original query
        print("💰 [DATABASE TEST] === TESTING ORIGINAL QUERY ===");
        QueryBuilder<GiftsModel> originalQuery =
            QueryBuilder<GiftsModel>(GiftsModel());
        originalQuery.whereValueExists(GiftsModel.keyGiftCategories, true);
        originalQuery.whereEqualTo(
            GiftsModel.keyGiftCategories, GiftsModel.gifStatus);
        ParseResponse originalResponse = await originalQuery.query();
        print(
            "💰 [DATABASE TEST] Original query results: ${originalResponse.results?.length ?? 0}");
      } else {
        print("💰 [DATABASE TEST] ❌ No gifts found in database!");
        print("💰 [DATABASE TEST] Response success: ${countResponse.success}");
        print(
            "💰 [DATABASE TEST] Error: ${countResponse.error?.message ?? 'No error message'}");
      }
    } catch (e) {
      print("💰 [DATABASE TEST] ❌ Exception testing database: $e");
    }
  }

  _checkCredits(GiftsModel gift, StateSetter setState) {
    print("💰 [CREDIT CHECK] ===== CHECKING USER CREDITS =====");
    print("💰 [CREDIT CHECK] User credits: ${widget.currentUser.getCredits}");
    print("💰 [CREDIT CHECK] Gift cost: ${gift.getCoins}");
    print("💰 [CREDIT CHECK] Gift name: ${gift.getName}");

    if (widget.currentUser.getCredits! >= gift.getCoins!) {
      print("💰 [CREDIT CHECK] ✅ User has sufficient credits");
      if (widget.onGiftSelected != null) {
        print("💰 [CREDIT CHECK] Calling onGiftSelected callback");
        widget.onGiftSelected!(gift) as void Function()?;
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

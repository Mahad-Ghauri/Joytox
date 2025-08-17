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

  List<InAppPurchaseModel> getInAppList() {
    List<Package> myProductList = offerings.current?.availablePackages ?? [];

    // If current offering has very few packages, try to get from all offerings
    if (myProductList.length < 3) {
      print(
          "💰 [FALLBACK DEBUG] Current offering only has ${myProductList.length} packages, checking all offerings...");
      Set<Package> allPackages = {};
      for (Offering offering in offerings.all.values) {
        allPackages.addAll(offering.availablePackages);
      }
      if (allPackages.length > myProductList.length) {
        myProductList = allPackages.toList();
        print(
            "💰 [FALLBACK DEBUG] Using ${myProductList.length} packages from all offerings");
      }
    }

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
      } else if (coins >= 10000 && coins <= 50000) {
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
        height: 80,
        width: 80,
        fit: BoxFit.contain,
        placeholderBuilder: (context) => Image.asset(
          "assets/images/coin_bling.webp",
          height: 80,
          width: 80,
        ),
      );
    } else {
      return Image.asset(
        imagePath,
        height: 80,
        width: 80,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            "assets/images/coin_bling.webp",
            height: 80,
            width: 80,
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
      print("💰 [PAYMENT INIT DEBUG] Starting to load offerings...");
      offerings = await Purchases.getOfferings();
      print(
          "💰 [PAYMENT INIT DEBUG] Initial offerings loaded with ${offerings.current?.availablePackages.length ?? 0} packages");

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
          _isAvailable = false;
          _loading = false;
        });
      }

      _checkForUpdatedOfferings();
    } on PlatformException catch (e) {
      print("💰 [PAYMENT INIT DEBUG] Error loading offerings: ${e.message}");
      setState(() {
        _isAvailable = false;
        _loading = false;
      });
    } catch (e) {
      print("💰 [PAYMENT INIT DEBUG] Unexpected error loading offerings: $e");
      setState(() {
        _isAvailable = false;
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
    if (inAppPurchaseModel.package == null) {
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

      CustomerInfo customerInfo =
          await Purchases.purchasePackage(inAppPurchaseModel.package!);

      print(
          "💰 [PAYMENT DEBUG] Purchase successful, adding ${inAppPurchaseModel.coins} coins to user");

      widget.currentUser.addCredit = inAppPurchaseModel.coins!;
      await widget.currentUser.save();

      registerPayment(customerInfo, inAppPurchaseModel);

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
      return DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.98,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.black
                  .withOpacity(0.5), // 50% transparent black background
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(24.0),
                topRight: const Radius.circular(24.0),
              ),
            ),
            child: ContainerCorner(
              color: kTransparentColor,
              child: IndexedStack(
                index:
                    widget.showOnlyCoinsPurchase! ? 1 : bottomSheetCurrentIndex,
                children: [
                  // Gifts Section
                  Scaffold(
                    backgroundColor: kTransparentColor,
                    body: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        // Modern App Bar
                        SliverAppBar(
                          expandedHeight: 100,
                          floating: true,
                          pinned: true,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          automaticallyImplyLeading: false,
                          leading: Container(
                            margin: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: BackButton(color: Colors.white70),
                          ),
                          actions: [
                            // Modern Get Coins Button
                            Container(
                              margin: EdgeInsets.all(8),
                              child: _buildGetCoinsButton(setState),
                            ),
                          ],
                          flexibleSpace: FlexibleSpaceBar(
                            centerTitle: true,
                            title: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                  horizontal:
                                      40), // Equal padding on both sides
                              margin: EdgeInsets.only(
                                  top:
                                      10), // Move up a little bit (reduced from 16 to 10)
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildCoinsDisplay(),
                                  Container(), // Empty container to balance the layout
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Gifts Content
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          sliver: SliverToBoxAdapter(
                            child: _buildGiftsSection(setState),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Coins Section
                  Scaffold(
                    backgroundColor: kTransparentColor,
                    body: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverAppBar(
                          expandedHeight: 60, // Reduced from 80 to 60
                          floating: true,
                          pinned: true,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          automaticallyImplyLeading: false,
                          leading: Container(
                            margin: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: BackButton(
                              color: Colors.white70,
                              onPressed: () {
                                if (widget.showOnlyCoinsPurchase!) {
                                  Navigator.of(context).pop();
                                } else {
                                  setState(() {
                                    bottomSheetCurrentIndex = 0;
                                  });
                                }
                              },
                            ),
                          ),
                          actions: [],
                          flexibleSpace: FlexibleSpaceBar(
                            centerTitle: false,
                            title: Container(
                              width: double.infinity,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "message_screen.get_coins".tr(),
                                      style: TextStyle(
                                        fontSize: 12, // Reduced from 14 to 12
                                        color: Colors.white,
                                        fontWeight: FontWeight
                                            .w500, // Reduced from w600 to w500
                                      ),
                                    ),
                                  ),
                                  _buildCoinsDisplay(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 8,
                              bottom: 16), // Reduced top padding from 16 to 8
                          sliver: SliverToBoxAdapter(
                            child: getBody(),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      );
    });
  }

  // Modern Get Coins Button
  Widget _buildGetCoinsButton(StateSetter setState) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(25),
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
          borderRadius: BorderRadius.circular(25),
          onTap: () {
            setState(() {
              bottomSheetCurrentIndex = 1;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  "assets/svg/coin.svg",
                  width: 12,
                  height: 12,
                ),
                SizedBox(width: 8),
                Text(
                  "message_screen.get_coins".tr(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Clean Coins Display
  Widget _buildCoinsDisplay() {
    return Container(
      height: 24, // Reduced from 30 to 24
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.25),
            Colors.black.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(15), // Reduced from 20 to 15
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 8), // Reduced from 12 to 8
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(1), // Reduced from 2 to 1
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFACC15), Color(0xFFEAB308)],
                  ),
                  borderRadius: BorderRadius.circular(4), // Reduced from 6 to 4
                ),
                child: SvgPicture.asset(
                  "assets/svg/ic_coin_with_star.svg",
                  width: 8, // Reduced from 10 to 8
                  height: 8, // Reduced from 10 to 8
                ),
              ),
              SizedBox(width: 6), // Reduced from 8 to 6
              Text(
                widget.currentUser.getCredits.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8, // Reduced from 10 to 8
                  fontWeight: FontWeight.w500, // Reduced from w600 to w500
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiftsSection(StateSetter setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Minimal Header
        Padding(
          padding: EdgeInsets.only(bottom: 24),
          child: Text(
            "Choose a Gift to Send",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w300, // Thin font
              letterSpacing: 0.5,
            ),
          ),
        ),
        // Clean Gifts Grid
        getGifts(GiftsModel.giftCategoryTypeClassic, setState),
      ],
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minimal header
          Padding(
            padding: EdgeInsets.only(bottom: 20), // Reduced from 24 to 20
            child: Text(
              "Choose Your Coin Package",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18, // Reduced from 22 to 18
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Clean grid
          Container(
            height: MediaQuery.of(context).size.height * 0.6,
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16, // Reduced from 20 to 16
                mainAxisSpacing: 16, // Reduced from 20 to 16
                childAspectRatio:
                    0.95, // Reduced from 1.1 to 0.95 for taller containers to fix overflow
              ),
              itemCount: inAppList.length,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: 20),
              itemBuilder: (context, index) {
                InAppPurchaseModel inApp = inAppList[index];
                bool isPopular = inApp.type == InAppPurchaseModel.typePopular;

                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isPopular
                          ? [
                              Color(0xFF6366F1).withOpacity(0.15),
                              Color(0xFF8B5CF6).withOpacity(0.08),
                            ]
                          : [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.03),
                            ],
                    ),
                    borderRadius:
                        BorderRadius.circular(16), // Reduced from 20 to 16
                    border: Border.all(
                      color: isPopular
                          ? Color(0xFF6366F1).withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isPopular
                            ? Color(0xFF6366F1).withOpacity(0.2)
                            : Colors.black.withOpacity(0.1),
                        blurRadius: isPopular ? 16 : 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Popular badge
                      if (isPopular)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "POPULAR",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      // Main content
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            _inAppPurchaseModel = inApp;
                            _purchaseProduct(inApp);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(
                                12.0), // Reduced from 16.0 to 12.0
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Credits text - larger and cleaner
                                Text(
                                  QuickHelp.checkFundsWithString(
                                      amount: "${inApp.coins}"),
                                  style: TextStyle(
                                    fontWeight: FontWeight
                                        .w600, // Reduced from w700 to w600
                                    fontSize: 16, // Reduced from 20 to 16
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Image with subtle glow
                                Container(
                                  width: 60, // Reduced from 70 to 60
                                  height: 60, // Reduced from 70 to 60
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                        12), // Reduced from 16 to 12
                                    boxShadow: [
                                      BoxShadow(
                                        color: isPopular
                                            ? Color(0xFF6366F1).withOpacity(0.3)
                                            : Colors.white.withOpacity(0.1),
                                        blurRadius: 12,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: _buildImageWidget(inApp.image ??
                                      "assets/images/coin_bling.webp"),
                                ),
                                // Price button - sleek and flat
                                Container(
                                  width: double.infinity,
                                  height: 36, // Reduced from 44 to 36
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isPopular
                                          ? [
                                              Color(0xFF6366F1),
                                              Color(0xFF8B5CF6)
                                            ]
                                          : [
                                              Color(0xFF4F46E5),
                                              Color(0xFF7C3AED)
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isPopular
                                                ? Color(0xFF6366F1)
                                                : Color(0xFF4F46E5))
                                            .withOpacity(0.4),
                                        blurRadius: 12,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      "${inApp.price}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14, // Reduced from 16 to 14
                                        fontWeight: FontWeight
                                            .w500, // Reduced from w600 to w500
                                        letterSpacing: 0.3,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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

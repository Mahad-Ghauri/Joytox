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

    List<InAppPurchaseModel> inAppPurchaseList = [];

    for (Package package in myProductList) {
      InAppPurchaseModel inAppPurchaseModel = InAppPurchaseModel();

      // Set basic package info
      inAppPurchaseModel.package = package;
      inAppPurchaseModel.storeProduct = package.storeProduct;
      inAppPurchaseModel.id = package.storeProduct.identifier;
      inAppPurchaseModel.price = package.storeProduct.priceString;
      inAppPurchaseModel.currency = package.storeProduct.currencyCode;

      // Extract coins from product identifier
      if (package.storeProduct.identifier.contains('100')) {
        inAppPurchaseModel.coins = 100;
        inAppPurchaseModel.image = "assets/images/icon_jinbi.png";
        print(
            "💰 [PAYMENT DEBUG] Set 100 coins with image: ${inAppPurchaseModel.image}");
      } else if (package.storeProduct.identifier.contains('200')) {
        inAppPurchaseModel.coins = 200;
        inAppPurchaseModel.image = "assets/images/icon_jinbi.png";
        print(
            "💰 [PAYMENT DEBUG] Set 200 coins with image: ${inAppPurchaseModel.image}");
      }

      // Set type based on coins amount
      if (inAppPurchaseModel.coins == 200) {
        inAppPurchaseModel.type = InAppPurchaseModel.typePopular;
      } else {
        inAppPurchaseModel.type = InAppPurchaseModel.typeNormal;
      }

      inAppPurchaseList.add(inAppPurchaseModel);
    }

    return inAppPurchaseList;
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

      if (offerings.current!.availablePackages.length > 0) {
        // Display packages for sale

        setState(() {
          _isAvailable = true;
          _loading = false;
        });
        // Display packages for sale
      }
    } on PlatformException {
      // optional error handling

      setState(() {
        _isAvailable = false;
        _loading = false;
      });
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
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(25.0),
            topRight: const Radius.circular(25.0),
          ),
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
                  leading: BackButton(
                    color: Colors.white,
                  ),
                  actions: [
                    ContainerCorner(
                      height: 30,
                      borderRadius: 50,
                      marginRight: 10,
                      marginTop: 10,
                      marginBottom: 10,
                      color: kWarninngColor,
                      onTap: () {
                        setState(() {
                          bottomSheetCurrentIndex = 1;
                        });
                      },
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: SvgPicture.asset(
                              "assets/svg/coin.svg",
                              width: 20,
                              height: 20,
                            ),
                          ),
                          TextWithTap(
                            "message_screen.get_coins".tr(),
                            marginRight: 10,
                          )
                        ],
                      ),
                    )
                  ],
                  backgroundColor: kTransparentColor,
                  centerTitle: true,
                  title: Row(
                    children: [
                      SvgPicture.asset(
                        "assets/svg/ic_coin_with_star.svg",
                        width: 20,
                        height: 20,
                      ),
                      TextWithTap(
                        widget.currentUser.getCredits.toString(),
                        color: Colors.white,
                        fontSize: 16,
                        marginLeft: 5,
                      )
                    ],
                  ),
                ),
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      ContainerCorner(
                          color: kTransparentColor,
                          child: _tabSection(context, setState)),
                    ],
                  ),
                ),
              ),
              Scaffold(
                backgroundColor: kTransparentColor,
                appBar: AppBar(
                  actions: [
                    Row(
                      children: [
                        SvgPicture.asset(
                          "assets/svg/ic_coin_with_star.svg",
                          width: 20,
                          height: 20,
                        ),
                        TextWithTap(
                          widget.currentUser.getCredits.toString(),
                          color: Colors.white,
                          marginLeft: 5,
                          marginRight: 15,
                        )
                      ],
                    ),
                  ],
                  backgroundColor: kTransparentColor,
                  title: TextWithTap(
                    "message_screen.get_coins".tr(),
                    marginRight: 10,
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  centerTitle: true,
                  automaticallyImplyLeading: false,
                  leading: BackButton(
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
                body: getBody(),
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
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _checkCredits(gift, setState),
                    child: Column(
                      children: [
                        ValueListenableBuilder<GiftsModel?>(
                          valueListenable: selectedGiftItemNotifier,
                          builder: (context, selectedGiftItem, _) {
                            return Container(
                              width: 50,
                              height: 50,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: QuickActions.photosWidget(
                                    gift.getPreview!.url),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  ContainerCorner(
                    color: kTransparentColor,
                    marginTop: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          "assets/svg/ic_coin_with_star.svg",
                          width: 16,
                          height: 16,
                        ),
                        TextWithTap(
                          gift.getCoins.toString(),
                          color: Colors.white,
                          fontSize: 14,
                          marginLeft: 5,
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
              Icon(Icons.search_off, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "💰 [DEBUG] No gifts found in database",
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                "Query: ${GiftsModel.keyGiftCategories} = '${GiftsModel.gifStatus}'",
                style: TextStyle(color: Colors.grey, fontSize: 12),
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
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                "💰 [DEBUG] Loading gifts from database...",
                style: TextStyle(color: Colors.white),
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
      return QuickHelp.appLoading();
    } else if (_isAvailable) {
      return ContainerCorner(
        color: kTransparentColor,
        marginLeft: 5,
        marginRight: 5,
        child: GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: List.generate(
            getInAppList().length,
            (index) {
              InAppPurchaseModel inApp = getInAppList()[index];

              return ContainerCorner(
                color: kDarkColorsTheme,
                borderRadius: 8,
                onTap: () {
                  _inAppPurchaseModel = inApp;
                  _purchaseProduct(inApp);
                },
                child: Column(
                  children: [
                    TextWithTap(
                      QuickHelp.checkFundsWithString(amount: "${inApp.coins}"),
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      marginTop: 5,
                      color: Colors.white,
                    ),
                    Expanded(
                      child: Image.asset(
                        inApp.image ?? "assets/images/coin_bling.webp",
                        height: 20,
                        width: 20,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            "assets/images/coin_bling.webp",
                            height: 20,
                            width: 20,
                          );
                        },
                      ),
                    ),
                    ContainerCorner(
                      borderRadius: 50,
                      borderWidth: 0,
                      height: 30,
                      marginRight: 10,
                      marginLeft: 10,
                      color: Colors.deepPurpleAccent,
                      marginBottom: 5,
                      child: TextWithTap(
                        "${inApp.price}",
                        color: Colors.white,
                        alignment: Alignment.center,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    } else {
      return QuickActions.noContentFound(context);
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

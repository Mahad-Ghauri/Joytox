// ignore_for_file: deprecated_member_use, unused_local_variable

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:trace/models/UserModel.dart';

import '../../helpers/quick_actions.dart';
import '../../models/PaymentsModel.dart';
import '../../models/others/in_app_model.dart';
import '../../ui/container_with_corner.dart';
import '../../ui/text_with_tap.dart';

// ignore: must_be_immutable
class CoinsScreen extends StatefulWidget {
  bool? scroll;
  static String route = "/home/coins/purchase";

  UserModel? currentUser;

  CoinsScreen({this.scroll, this.currentUser});

  @override
  _CoinsScreenState createState() => _CoinsScreenState();
}

class _CoinsScreenState extends State<CoinsScreen> {
  void getUser() async {
    widget.currentUser = await ParseUser.currentUser();
  }

  late Offerings offerings;
  bool _isAvailable = false;
  bool _loading = true;
  InAppPurchaseModel? _inAppPurchaseModel;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    QuickHelp.saveCurrentRoute(route: CoinsScreen.route);
    initProducts();

    super.initState();
  }

  initProducts() async {
    try {
      offerings = await Purchases.getOfferings();
      print(
          "💰 [INIT DEBUG] Initial offerings loaded with ${offerings.current?.availablePackages.length ?? 0} packages");

      if (offerings.current!.availablePackages.length > 0) {
        setState(() {
          _isAvailable = true;
          _loading = false;
        });
        // Display packages for sale
      }

      // Set up a timer to check for updated offerings periodically
      _checkForUpdatedOfferings();

      // Also set up a periodic refresh every 5 seconds for the first 30 seconds
      _startPeriodicRefresh();
    } on PlatformException {
      // optional error handling

      setState(() {
        _isAvailable = false;
        _loading = false;
      });
    }
  }

  void _startPeriodicRefresh() async {
    for (int i = 0; i < 6; i++) {
      // Check 6 times over 30 seconds
      await Future.delayed(Duration(seconds: 5));
      try {
        Offerings freshOfferings = await Purchases.getOfferings();
        print(
            "💰 [PERIODIC DEBUG] Periodic check $i: ${freshOfferings.current?.availablePackages.length ?? 0} packages");

        if (freshOfferings.current != null &&
            freshOfferings.current!.availablePackages.length >
                offerings.current!.availablePackages.length) {
          print("💰 [PERIODIC DEBUG] Found more packages! Updating UI...");
          setState(() {
            offerings = freshOfferings;
          });
          break; // Stop checking once we find the update
        }
      } catch (e) {
        print("💰 [PERIODIC DEBUG] Error in periodic check: $e");
      }
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
          "💰 [UPDATE DEBUG] Checking for updated offerings: ${updatedOfferings.current?.availablePackages.length ?? 0} packages");

      if (updatedOfferings.current != null &&
          updatedOfferings.current!.availablePackages.length !=
              offerings.current!.availablePackages.length) {
        print("💰 [UPDATE DEBUG] Offerings updated! Refreshing UI...");
        setState(() {
          offerings = updatedOfferings;
        });
      } else {
        print(
            "💰 [UPDATE DEBUG] No new offerings found. Current: ${offerings.current!.availablePackages.length}, Updated: ${updatedOfferings.current?.availablePackages.length ?? 0}");

        // Try one more time with a longer delay
        await Future.delayed(Duration(seconds: 3));
        Offerings finalCheck = await Purchases.getOfferings();
        print(
            "💰 [FINAL CHECK DEBUG] Final check offerings: ${finalCheck.current?.availablePackages.length ?? 0} packages");

        if (finalCheck.current != null &&
            finalCheck.current!.availablePackages.length !=
                offerings.current!.availablePackages.length) {
          print(
              "💰 [FINAL CHECK DEBUG] Final check found updates! Refreshing UI...");
          setState(() {
            offerings = finalCheck;
          });
        }
      }
    } catch (e) {
      print("💰 [UPDATE DEBUG] Error checking for updated offerings: $e");
    }
  }

  List<InAppPurchaseModel> getInAppList() {
    List<Package> myProductList = offerings.current!.availablePackages;

    print(
        "💰 [CONVERSION DEBUG] Starting conversion of ${myProductList.length} packages");

    List<InAppPurchaseModel> inAppPurchaseList = [];
    bool has100Credits = false;
    bool has200Credits = false;

    for (Package package in myProductList) {
      print(
          "💰 [CONVERSION DEBUG] Processing package: ${package.storeProduct.identifier}");
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
        has100Credits = true;
        print(
            "💰 [COINS DEBUG] Set 100 coins with image: ${inAppPurchaseModel.image}");
      } else if (package.storeProduct.identifier.contains('200')) {
        inAppPurchaseModel.coins = 200;
        inAppPurchaseModel.image = "assets/images/icon_jinbi.png";
        has200Credits = true;
        print(
            "💰 [COINS DEBUG] Set 200 coins with image: ${inAppPurchaseModel.image}");
      } else {
        // Default fallback for unknown products
        inAppPurchaseModel.coins = 0;
        inAppPurchaseModel.image = "assets/images/icon_jinbi.png";
        print(
            "💰 [COINS DEBUG] Unknown product: ${package.storeProduct.identifier}");
      }

      // Set type based on coins amount
      if (inAppPurchaseModel.coins == 200) {
        inAppPurchaseModel.type = InAppPurchaseModel.typePopular;
      } else {
        inAppPurchaseModel.type = InAppPurchaseModel.typeNormal;
      }

      inAppPurchaseList.add(inAppPurchaseModel);
      print(
          "💰 [CONVERSION DEBUG] Added to list: ${inAppPurchaseModel.coins} coins, ${inAppPurchaseModel.price}");
    }

    // TEMPORARY WORKAROUND: If we only have 100 credits, manually add 200 credits for testing
    if (has100Credits && !has200Credits && inAppPurchaseList.length == 1) {
      print(
          "💰 [WORKAROUND DEBUG] Only found 100 credits, adding 200 credits manually for testing");
      InAppPurchaseModel mockInAppPurchaseModel = InAppPurchaseModel();
      mockInAppPurchaseModel.coins = 200;
      mockInAppPurchaseModel.image = "assets/images/icon_jinbi.png";
      mockInAppPurchaseModel.price = "Rs 100.00"; // Mock price
      mockInAppPurchaseModel.currency = "PKR";
      mockInAppPurchaseModel.id = "joytox.200.credits";
      mockInAppPurchaseModel.type = InAppPurchaseModel.typePopular;

      // Note: This won't have a real package, so purchases won't work, but UI will show both options
      inAppPurchaseList.add(mockInAppPurchaseModel);
      print("💰 [WORKAROUND DEBUG] Added mock 200 credits for UI testing");
    }

    print("💰 [CONVERSION DEBUG] Final list size: ${inAppPurchaseList.length}");
    return inAppPurchaseList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: getBody(),
    );
  }

  Widget getBody() {
    if (_loading) {
      return QuickHelp.appLoading();
    } else if (_isAvailable) {
      return getProductList();
    } else {
      return QuickActions.noContentFound(context);
    }
  }

  Widget getProductList() {
    bool canScroll = widget.scroll ?? true;
    List<InAppPurchaseModel> inAppList = getInAppList();

    print("💰 [UI DEBUG] Total products to display: ${inAppList.length}");
    for (int i = 0; i < inAppList.length; i++) {
      print(
          "💰 [UI DEBUG] Product $i: ${inAppList[i].coins} coins, price: ${inAppList[i].price}, image: ${inAppList[i].image}");
    }

    return Column(
      children: [
        // Add refresh button if only 1 product is showing
        if (inAppList.length < 2)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () async {
                print("💰 [MANUAL REFRESH] User requested manual refresh");
                setState(() {
                  _loading = true;
                });
                await initProducts();
              },
              child: Text("Refresh Packages"),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 15, right: 15),
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              physics: canScroll ? NeverScrollableScrollPhysics() : null,
              children: List.generate(inAppList.length, (index) {
                InAppPurchaseModel inApp = inAppList[index];
                print(
                    "💰 [RENDER DEBUG] Rendering item $index: ${inApp.coins} coins");
                return ContainerCorner(
                  color: Colors.deepPurpleAccent.withOpacity(0.1),
                  borderRadius: 8,
                  onTap: () {
                    _inAppPurchaseModel = inApp;
                    _purchaseProduct(inApp);
                  },
                  child: Column(
                    children: [
                      TextWithTap(
                        "${inApp.coins ?? 0} Credits",
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        marginTop: 5,
                      ),
                      Expanded(
                        child: Image.asset(
                          inApp.image ?? "assets/images/icon_jinbi.png",
                          height: 20,
                          width: 20,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              "assets/images/icon_jinbi.png",
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
                          "${inApp.price ?? 'No Price'}",
                          color: Colors.white,
                          alignment: Alignment.center,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  _purchaseProduct(InAppPurchaseModel inAppPurchaseModel) async {
    // Check if this is a mock item (no real package)
    if (inAppPurchaseModel.package == null) {
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        user: widget.currentUser,
        title: "Mock Item",
        message:
            "This is a mock item for UI testing. The 200 credits option is not properly configured in RevenueCat yet.",
        isError: true,
      );
      return;
    }

    QuickHelp.showLoadingDialog(context);

    try {
      await Purchases.purchasePackage(inAppPurchaseModel.package!);

      widget.currentUser!.addCredit = _inAppPurchaseModel!.coins!;
      await widget.currentUser!.save();

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
    paymentsModel.setAuthor = widget.currentUser!;
    paymentsModel.setAuthorId = widget.currentUser!.objectId!;
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
}

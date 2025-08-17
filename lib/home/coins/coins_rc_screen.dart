// ignore_for_file: deprecated_member_use, unused_local_variable

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:trace/models/UserModel.dart';

import '../../app/config.dart';
import '../../helpers/quick_actions.dart';
import '../../models/PaymentsModel.dart';
import '../../models/others/in_app_model.dart';
import '../../ui/container_with_corner.dart';

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
  Future<void> getUser() async {
    widget.currentUser = await ParseUser.currentUser();
  }

  late Offerings offerings;
  bool _isAvailable = false;
  bool _loading = true;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    QuickHelp.saveCurrentRoute(route: CoinsScreen.route);

    // Ensure we have current user before initializing products
    if (widget.currentUser == null) {
      _initializeUser();
    } else {
      initProducts();
    }

    super.initState();
  }

  void _initializeUser() async {
    await getUser();
    initProducts();
  }

  initProducts() async {
    try {
      // Ensure user is identified with RevenueCat
      if (widget.currentUser != null && widget.currentUser!.objectId != null) {
        try {
          await Purchases.logIn(widget.currentUser!.objectId!);
          print(
              "💰 [USER DEBUG] User logged in to RevenueCat: ${widget.currentUser!.objectId}");
        } catch (e) {
          print("💰 [USER DEBUG] Error logging in user to RevenueCat: $e");
        }
      }

      // Force clear all caches first
      print("💰 [CACHE DEBUG] Clearing all RevenueCat caches...");
      await Purchases.invalidateCustomerInfoCache();

      // Wait a moment for cache clear
      await Future.delayed(Duration(seconds: 1));

      offerings = await Purchases.getOfferings();
      print(
          "💰 [INIT DEBUG] Initial offerings loaded with ${offerings.current?.availablePackages.length ?? 0} packages");

      // Debug: Print all available offerings
      print("💰 [DEBUG] Total offerings available: ${offerings.all.length}");

      // Check for specific missing packages
      List<String> missingPackages = [
        "joytox.20000.credits",
        "joytox.25000.credits",
        "joytox.40000.credits",
        "joytox.50000.credits"
      ];

      Set<String> allFoundPackages = {};

      for (String key in offerings.all.keys) {
        Offering offering = offerings.all[key]!;
        print(
            "💰 [DEBUG] Offering '$key' has ${offering.availablePackages.length} packages");
        for (Package package in offering.availablePackages) {
          String identifier = package.storeProduct.identifier;
          allFoundPackages.add(identifier);
          print(
              "💰 [DEBUG] - Package: $identifier (${package.storeProduct.priceString})");
        }
      }

      // Check which specific packages are missing
      print("💰 [MISSING CHECK] Checking for missing packages:");
      for (String missingId in missingPackages) {
        bool found = allFoundPackages.contains(missingId);
        print("💰 [MISSING CHECK] $missingId: ${found ? 'FOUND' : 'MISSING'}");
      }

      print(
          "💰 [DEBUG] Total unique packages found across all offerings: ${allFoundPackages.length}");

      // Debug: Print current offering details
      if (offerings.current != null) {
        print(
            "💰 [DEBUG] Current offering identifier: ${offerings.current!.identifier}");
        print(
            "💰 [DEBUG] Current offering packages: ${offerings.current!.availablePackages.length}");
      } else {
        print("💰 [DEBUG] No current offering set!");
      }

      if ((offerings.current?.availablePackages.length ?? 0) > 0) {
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
    for (int i = 0; i < 12; i++) {
      // Check 12 times over 60 seconds (every 5 seconds)
      await Future.delayed(Duration(seconds: 5));
      try {
        // Clear cache before each check
        await Purchases.invalidateCustomerInfoCache();
        await Future.delayed(Duration(milliseconds: 500));

        Offerings freshOfferings = await Purchases.getOfferings();
        print(
            "💰 [PERIODIC DEBUG] Periodic check $i: ${freshOfferings.current?.availablePackages.length ?? 0} packages");

        // Check for our specific missing packages
        Set<String> foundPackages = {};
        for (String key in freshOfferings.all.keys) {
          Offering offering = freshOfferings.all[key]!;
          for (Package package in offering.availablePackages) {
            foundPackages.add(package.storeProduct.identifier);
          }
        }

        List<String> targetPackages = [
          "joytox.20000.credits",
          "joytox.25000.credits",
          "joytox.40000.credits",
          "joytox.50000.credits"
        ];

        int foundTargets = 0;
        for (String target in targetPackages) {
          if (foundPackages.contains(target)) {
            foundTargets++;
          }
        }

        print(
            "💰 [PERIODIC DEBUG] Found $foundTargets/4 target packages in check $i");

        if (foundTargets > 0 ||
            (freshOfferings.current?.availablePackages.length ?? 0) >
                (offerings.current?.availablePackages.length ?? 0)) {
          print("💰 [PERIODIC DEBUG] Found updates! Refreshing UI...");
          setState(() {
            offerings = freshOfferings;
          });
          if (foundTargets == 4) {
            print(
                "💰 [PERIODIC DEBUG] All target packages found! Stopping periodic checks.");
            break; // Stop checking once we find all targets
          }
        }
      } catch (e) {
        print("💰 [PERIODIC DEBUG] Error in periodic check: $e");
      }
    }
  }

  Future<void> _forceCompleteRefresh() async {
    print("💰 [FORCE REFRESH] Starting complete refresh...");
    setState(() {
      _loading = true;
    });

    try {
      // Multiple cache invalidations with delays
      for (int i = 0; i < 3; i++) {
        print("💰 [FORCE REFRESH] Cache clear attempt ${i + 1}");
        await Purchases.invalidateCustomerInfoCache();
        await Future.delayed(Duration(seconds: 1));
      }

      // Wait longer for cache to fully clear
      await Future.delayed(Duration(seconds: 2));

      // Get fresh offerings
      print("💰 [FORCE REFRESH] Fetching fresh offerings...");
      Offerings freshOfferings = await Purchases.getOfferings();

      // Check what we got
      Set<String> allFoundPackages = {};
      for (String key in freshOfferings.all.keys) {
        Offering offering = freshOfferings.all[key]!;
        for (Package package in offering.availablePackages) {
          allFoundPackages.add(package.storeProduct.identifier);
        }
      }

      List<String> targetPackages = [
        "joytox.20000.credits",
        "joytox.25000.credits",
        "joytox.40000.credits",
        "joytox.50000.credits"
      ];

      int foundTargets = 0;
      for (String target in targetPackages) {
        if (allFoundPackages.contains(target)) {
          foundTargets++;
          print("💰 [FORCE REFRESH] ✅ Found target: $target");
        } else {
          print("💰 [FORCE REFRESH] ❌ Missing target: $target");
        }
      }

      print("💰 [FORCE REFRESH] Found $foundTargets/4 target packages");
      print("💰 [FORCE REFRESH] Total packages: ${allFoundPackages.length}");

      setState(() {
        offerings = freshOfferings;
        _loading = false;
      });
    } catch (e) {
      print("💰 [FORCE REFRESH] Error during refresh: $e");
      setState(() {
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
          "💰 [UPDATE DEBUG] Checking for updated offerings: ${updatedOfferings.current?.availablePackages.length ?? 0} packages");

      if (updatedOfferings.current != null &&
          (updatedOfferings.current?.availablePackages.length ?? 0) !=
              (offerings.current?.availablePackages.length ?? 0)) {
        print("💰 [UPDATE DEBUG] Offerings updated! Refreshing UI...");
        setState(() {
          offerings = updatedOfferings;
        });
      } else {
        print(
            "💰 [UPDATE DEBUG] No new offerings found. Current: ${offerings.current?.availablePackages.length ?? 0}, Updated: ${updatedOfferings.current?.availablePackages.length ?? 0}");

        // Try one more time with a longer delay
        await Future.delayed(Duration(seconds: 3));
        Offerings finalCheck = await Purchases.getOfferings();
        print(
            "💰 [FINAL CHECK DEBUG] Final check offerings: ${finalCheck.current?.availablePackages.length ?? 0} packages");

        if (finalCheck.current != null &&
            (finalCheck.current?.availablePackages.length ?? 0) !=
                (offerings.current?.availablePackages.length ?? 0)) {
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
        "💰 [CONVERSION DEBUG] Starting conversion of ${myProductList.length} packages");

    // Debug: List all packages being processed
    print("💰 [CONVERSION DEBUG] Packages to process:");
    for (int i = 0; i < myProductList.length; i++) {
      print(
          "💰 [CONVERSION DEBUG] [$i] ${myProductList[i].storeProduct.identifier}");
    }

    List<InAppPurchaseModel> inAppPurchaseList = [];

    for (Package package in myProductList) {
      String identifier = package.storeProduct.identifier;
      print("💰 [CONVERSION DEBUG] Processing package: $identifier");

      // Check if this is one of our missing packages
      List<String> targetPackages = [
        "joytox.20000.credits",
        "joytox.25000.credits",
        "joytox.40000.credits",
        "joytox.50000.credits"
      ];
      if (targetPackages.contains(identifier)) {
        print("💰 [TARGET DEBUG] Found target package: $identifier");
      }

      InAppPurchaseModel inAppPurchaseModel = InAppPurchaseModel();

      // Set basic package info
      inAppPurchaseModel.package = package;
      inAppPurchaseModel.storeProduct = package.storeProduct;
      inAppPurchaseModel.id = package.storeProduct.identifier;
      inAppPurchaseModel.price = package.storeProduct.priceString;
      inAppPurchaseModel.currency = package.storeProduct.currencyCode;

      // Extract coins from product identifier using regex to get the number
      int coins = _extractCoinsFromIdentifier(identifier);

      // Debug coin extraction for target packages
      if (targetPackages.contains(identifier)) {
        print("💰 [TARGET DEBUG] Extracted $coins coins from $identifier");
      }

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
          "💰 [COINS DEBUG] Set $coins coins for ${identifier} with image: ${inAppPurchaseModel.image}");

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
            "💰 [CONVERSION DEBUG] Added to list: ${inAppPurchaseModel.coins} coins, ${inAppPurchaseModel.price}");

        // Special logging for target packages
        if (targetPackages.contains(identifier)) {
          print(
              "💰 [TARGET DEBUG] Successfully added target package: $identifier with $coins coins");
        }
      } else {
        print("💰 [CONVERSION DEBUG] Skipped unknown product: $identifier");

        // Special logging for target packages that failed
        if (targetPackages.contains(identifier)) {
          print(
              "💰 [TARGET DEBUG] ERROR: Target package $identifier was skipped because coins = $coins");
        }
      }
    }

    // Sort by coins amount for better UI display
    inAppPurchaseList.sort((a, b) => a.coins!.compareTo(b.coins!));

    print("💰 [CONVERSION DEBUG] Final list size: ${inAppPurchaseList.length}");
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
        height: 40,
        width: 40,
        fit: BoxFit.contain,
        placeholderBuilder: (context) => Image.asset(
          "assets/images/icon_jinbi.png",
          height: 40,
          width: 40,
        ),
      );
    } else {
      return Image.asset(
        imagePath,
        height: 40,
        width: 40,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            "assets/images/icon_jinbi.png",
            height: 40,
            width: 40,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: getBody(),
      ),
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
        // Add refresh button and show count
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Available Packages: ${inAppList.length}",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                onPressed: () async {
                  print("💰 [MANUAL REFRESH] User requested manual refresh");
                  await _forceCompleteRefresh();
                },
                child: Text("Refresh"),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(inAppList.length),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: inAppList.length,
                physics: canScroll
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  InAppPurchaseModel inApp = inAppList[index];
                  print(
                      "💰 [RENDER DEBUG] Rendering item $index: ${inApp.coins} coins");
                  return ContainerCorner(
                    color: Colors.deepPurpleAccent.withOpacity(0.1),
                    borderRadius: 12,
                    onTap: () {
                      _purchaseProduct(inApp);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Credits text
                          Flexible(
                            flex: 2,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "${inApp.coins ?? 0} Credits",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          // Image
                          Flexible(
                            flex: 4,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: _buildImageWidget(inApp.image ??
                                  "assets/images/icon_jinbi.png"),
                            ),
                          ),
                          // Price button
                          Flexible(
                            flex: 2,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6.0, horizontal: 8.0),
                              decoration: BoxDecoration(
                                color: Colors.deepPurpleAccent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "${inApp.price ?? 'No Price'}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
          ),
        ),
      ],
    );
  }

  _purchaseProduct(InAppPurchaseModel inAppPurchaseModel) async {
    // Check if user is available
    if (widget.currentUser == null) {
      await getUser();
      if (widget.currentUser == null) {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          user: null,
          title: "Authentication Error",
          message: "Please login to make purchases.",
          isError: true,
        );
        return;
      }
    }

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

    print(
        "💰 [PURCHASE DEBUG] Starting purchase for ${inAppPurchaseModel.coins} credits (${inAppPurchaseModel.id})");

    // Additional validation before purchase
    if (inAppPurchaseModel.storeProduct == null) {
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        user: widget.currentUser,
        title: "Product Error",
        message:
            "Product information is not available. Please try refreshing the page.",
        isError: true,
      );
      return;
    }

    print(
        "💰 [PURCHASE DEBUG] Product validation passed. Store product: ${inAppPurchaseModel.storeProduct!.identifier}");
    QuickHelp.showLoadingDialog(context);

    try {
      // Verify the package is still available before purchase
      print("💰 [PURCHASE DEBUG] Verifying package availability...");

      CustomerInfo customerInfo =
          await Purchases.purchasePackage(inAppPurchaseModel.package!);
      print("💰 [PURCHASE DEBUG] Purchase successful! CustomerInfo received");

      // Debug: Print customer info details
      print(
          "💰 [PURCHASE DEBUG] Active subscriptions: ${customerInfo.activeSubscriptions.length}");
      print(
          "💰 [PURCHASE DEBUG] Non-subscription transactions: ${customerInfo.nonSubscriptionTransactions.length}");
      print(
          "💰 [PURCHASE DEBUG] Entitlements: ${customerInfo.entitlements.all.keys.toList()}");

      // Validate that the purchase was successful
      bool purchaseValidated = false;

      // Check if the purchased product appears in non-subscription transactions
      for (var transaction in customerInfo.nonSubscriptionTransactions) {
        if (transaction.productIdentifier == inAppPurchaseModel.id) {
          purchaseValidated = true;
          print(
              "💰 [PURCHASE DEBUG] Purchase validated via non-subscription transaction: ${transaction.transactionIdentifier}");
          break;
        }
      }

      // If not found in transactions, check entitlements
      if (!purchaseValidated && customerInfo.entitlements.all.isNotEmpty) {
        purchaseValidated = true;
        print("💰 [PURCHASE DEBUG] Purchase validated via entitlements");
      }

      if (!purchaseValidated) {
        print(
            "💰 [PURCHASE DEBUG] WARNING: Purchase could not be validated, but proceeding anyway");
      }

      // Add credits to user account
      widget.currentUser!.addCredit = inAppPurchaseModel.coins!;
      await widget.currentUser!.save();
      print(
          "💰 [PURCHASE DEBUG] Credits added to user account: ${inAppPurchaseModel.coins}");

      // Register the payment for record keeping
      registerPayment(customerInfo, inAppPurchaseModel);

      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        user: widget.currentUser,
        title: "in_app_purchases.coins_purchased"
            .tr(namedArgs: {"coins": inAppPurchaseModel.coins!.toString()}),
        message: "in_app_purchases.coins_added_to_account".tr(),
        isError: false,
      );

      print("💰 [PURCHASE DEBUG] Purchase flow completed successfully");
    } on PlatformException catch (e) {
      print(
          "💰 [PURCHASE DEBUG] Purchase failed with error: ${e.code} - ${e.message}");
      QuickHelp.hideLoadingDialog(context);

      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      print("💰 [PURCHASE DEBUG] Error code: $errorCode");

      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        print("💰 [PURCHASE DEBUG] Purchase was cancelled by user");
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          user: widget.currentUser,
          title: "in_app_purchases.purchase_cancelled_title".tr(),
          message: "in_app_purchases.purchase_cancelled".tr(),
          isError: true,
        );
      } else if (errorCode == PurchasesErrorCode.invalidReceiptError) {
        print("💰 [PURCHASE DEBUG] Invalid receipt error");
        _handleInvalidPurchase();
      } else if (errorCode ==
          PurchasesErrorCode.productNotAvailableForPurchaseError) {
        print("💰 [PURCHASE DEBUG] Product not available for purchase");
        _handleProductNotAvailable(inAppPurchaseModel);
      } else {
        print("💰 [PURCHASE DEBUG] Other purchase error: ${e.message}");
        handleError(e);
      }
    } catch (e) {
      print("💰 [PURCHASE DEBUG] Unexpected error during purchase: $e");
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        user: widget.currentUser,
        title: "Purchase Error",
        message: "An unexpected error occurred during purchase: $e",
        isError: true,
      );
    }
  }

  void _handleInvalidPurchase() {
    QuickHelp.showAppNotification(
        context: context, title: "in_app_purchases.invalid_purchase".tr());
    QuickHelp.hideLoadingDialog(context);
  }

  void _handleProductNotAvailable(InAppPurchaseModel inAppPurchaseModel) {
    QuickHelp.showAppNotificationAdvanced(
      context: context,
      user: widget.currentUser,
      title: "Product Unavailable",
      message:
          "The ${inAppPurchaseModel.coins} credits package is currently unavailable for purchase. This could be due to:\n\n"
          "• Store configuration issues\n"
          "• Regional restrictions\n"
          "• Temporary server issues\n\n"
          "Please try again later or contact support if the issue persists.",
      isError: true,
    );
    QuickHelp.hideLoadingDialog(context);
  }

  void registerPayment(
      CustomerInfo customerInfo, InAppPurchaseModel productDetails) async {
    try {
      print(
          "💰 [PAYMENT DEBUG] Registering payment for ${productDetails.coins} credits");

      // Save all payment information
      PaymentsModel paymentsModel = PaymentsModel();
      paymentsModel.setAuthor = widget.currentUser!;
      paymentsModel.setAuthorId = widget.currentUser!.objectId!;
      paymentsModel.setPaymentType = PaymentsModel.paymentTypeConsumible;

      paymentsModel.setId = productDetails.id!;
      paymentsModel.setTitle = productDetails.storeProduct!.title;

      // Get the latest transaction ID from active subscriptions or non-subscription purchases
      String? transactionId;
      if (customerInfo.activeSubscriptions.isNotEmpty) {
        transactionId = customerInfo.activeSubscriptions.first;
      } else if (customerInfo.nonSubscriptionTransactions.isNotEmpty) {
        transactionId = customerInfo
            .nonSubscriptionTransactions.first.transactionIdentifier;
      } else {
        // Fallback to using current timestamp as string
        transactionId = customerInfo.originalPurchaseDate?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();
      }

      paymentsModel.setTransactionId = transactionId;
      paymentsModel.setCurrency = productDetails.currency!.toUpperCase();
      paymentsModel.setPrice = (productDetails.price ?? "0").toString();
      paymentsModel.setMethod = QuickHelp.isAndroidPlatform()
          ? "Google Play"
          : QuickHelp.isIOSPlatform()
              ? "App Store"
              : "";
      paymentsModel.setStatus = PaymentsModel.paymentStatusCompleted;

      await paymentsModel.save();
      print(
          "💰 [PAYMENT DEBUG] Payment registered successfully with transaction ID: $transactionId");
    } catch (e) {
      print("💰 [PAYMENT DEBUG] Error registering payment: $e");
    }
  }

  void handleError(PlatformException error) {
    QuickHelp.hideLoadingDialog(context);
    QuickHelp.showAppNotification(context: context, title: error.message);
  }
}

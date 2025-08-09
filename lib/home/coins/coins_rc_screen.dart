// ignore_for_file: deprecated_member_use

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:trace/app/Config.dart';
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

  void getUser() async{
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

      if (offerings.current!.availablePackages.length > 0) {

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

  List<InAppPurchaseModel> getInAppList() {

    List<Package> myProductList = offerings.current!.availablePackages;

    List<InAppPurchaseModel> inAppPurchaseList = [];

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
    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 15),
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        physics: canScroll ? NeverScrollableScrollPhysics() : null,
        children: List.generate(getInAppList().length, (index) {
          InAppPurchaseModel inApp = getInAppList()[index];
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
                    QuickHelp.checkFundsWithString(amount: "${inApp.coins}"),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  marginTop: 5,
                ),
                Expanded(
                  child: Image.asset(
                    "assets/images/icon_jinbi.png",
                    height: 20,
                    width: 20,
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
        }),
      ),
    );
  }

  _purchaseProduct(InAppPurchaseModel inAppPurchaseModel) async{

    QuickHelp.showLoadingDialog(context);

    try {
      await Purchases.purchasePackage(inAppPurchaseModel.package!);

      widget.currentUser!.addCredit = _inAppPurchaseModel!.coins!;
      await widget.currentUser!.save();

      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(context:context,
        user: widget.currentUser,
        title: "in_app_purchases.coins_purchased".tr(namedArgs: {"coins" : _inAppPurchaseModel!.coins!.toString()}),
        message: "in_app_purchases.coins_added_to_account".tr(),
        isError: false,
      );

    } on PlatformException catch (e) {

      var errorCode = PurchasesErrorHelper.getErrorCode(e);

      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {

        QuickHelp.hideLoadingDialog(context);

        QuickHelp.showAppNotificationAdvanced(
          context:context,
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

    QuickHelp.showAppNotification(context:context, title: "in_app_purchases.invalid_purchase".tr());
    QuickHelp.hideLoadingDialog(context);
  }

  void registerPayment(CustomerInfo customerInfo, InAppPurchaseModel productDetails) async {

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
    paymentsModel.setMethod = QuickHelp.isAndroidPlatform()? "Google Play" : QuickHelp.isIOSPlatform() ? "App Store" : "";
    paymentsModel.setStatus = PaymentsModel.paymentStatusCompleted;

    await paymentsModel.save();
  }

  void handleError(PlatformException error) {

    QuickHelp.hideLoadingDialog(context);
    QuickHelp.showAppNotification(context:context, title: error.message);
  }
}

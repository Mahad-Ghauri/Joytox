import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:trace/auth/responsive_welcome_screen.dart';
import 'package:trace/auth/welcome_screen.dart';
import 'package:trace/controllers/feed_controller.dart';
import 'package:trace/home/home_screen.dart';
import 'package:trace/home/location_screen.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';

import '../home/responsive_home_screen.dart';
import '../home/profile/profile_edit_complete.dart';
import '../services/push_service.dart';
import '../services/call_services.dart';

// ignore_for_file: must_be_immutable
class DispacheScreen extends StatefulWidget {
  static String route = "/check";

  UserModel? currentUser;

  DispacheScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  _DispacheScreenState createState() => _DispacheScreenState();
}

class _DispacheScreenState extends State<DispacheScreen> {
  @override
  void initState() {
    super.initState();

    // Inicializar o GlobalFeedController com o usuário atual
    if (widget.currentUser != null) {
      try {
        FeedController feedController = Get.find<FeedController>();
        feedController.setCurrentUser(widget.currentUser!);
        print("DispacheScreen: CurrentUser definido no FeedController");
      } catch (e) {
        print("DispacheScreen: Erro ao definir CurrentUser: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUser != null) {
      if (widget.currentUser!.getAppLanguage!.isNotEmpty) {
        if (context.locale.languageCode !=
            widget.currentUser!.getAppLanguage!) {
          context.setLocale(Locale(widget.currentUser!.getAppLanguage!));
        }
      }

      loginUserPurchase(widget.currentUser!.objectId!);

      // Initialize call service for audio/video calls
      print(
          '🔧 DispacheScreen: Initializing call service for user: ${widget.currentUser!.objectId}');
      onUserLogin(widget.currentUser!).then((_) {
        print('✅ Call service initialization completed');
      }).catchError((e) {
        print('❌ Call service initialization failed: $e');
      });

      if (widget.currentUser!.getFirstName == null ||
          widget.currentUser!.getGender == null ||
          widget.currentUser!.getBirthday == null ||
          widget.currentUser!.getAvatar == null ||
          widget.currentUser!.getBio!.isEmpty) {
        return ProfileCompleteEdit(
          currentUser: widget.currentUser,
        );
      } else {
        PushService(
          currentUser: widget.currentUser,
          context: context,
        ).initialise();

        // FIX: Check if we're already on a home screen to prevent multiple instances
        final currentRoute = ModalRoute.of(context)?.settings.name;
        if (currentRoute != null &&
            (currentRoute.contains('home') ||
                currentRoute == '/home' ||
                currentRoute == ResponsiveHomeScreen.route)) {
          // If we're already on a home screen, just return a simple scaffold
          // to prevent creating multiple instances
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return QuickHelp.isMobile()
            ? HomeScreen(
                currentUser: widget.currentUser,
              )
            : ResponsiveHomeScreen(
                currentUser: widget.currentUser,
              );
      }
    } else {
      logoutUserPurchase();

      return QuickHelp.isMobile() ? WelcomeScreen() : ResponsiveWelcomeScreen();
    }
  }

  loginUserPurchase(String userId) async {
    LogInResult result = await Purchases.logIn(userId);
    if (result.created) {
      print("purchase created");
    } else {
      print("purchase logged");
    }
  }

  Widget checkLocation() {
    Location location = Location();

    return Scaffold(
      body: FutureBuilder<PermissionStatus>(
          future: location.hasPermission(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              PermissionStatus permissionStatus =
                  snapshot.data as PermissionStatus;
              if (permissionStatus == PermissionStatus.granted ||
                  permissionStatus == PermissionStatus.grantedLimited) {
                return QuickHelp.isMobile()
                    ? HomeScreen(
                        currentUser: widget.currentUser,
                      )
                    : ResponsiveHomeScreen(
                        currentUser: widget.currentUser,
                      );
              } else {
                return LocationScreen(
                  currentUser: widget.currentUser,
                );
              }
            } else if (snapshot.hasError) {
              return QuickHelp.isMobile()
                  ? HomeScreen(
                      currentUser: widget.currentUser,
                    )
                  : ResponsiveHomeScreen(
                      currentUser: widget.currentUser,
                    );
              //return AddCityScreen(currentUser: widget.currentUser,);
            } else {
              return QuickHelp.appLoadingLogo();
            }
          }),
    );
  }

  logoutUserPurchase() async {
    await Purchases.logOut().then((value) => print("purchase logout"));
  }
}

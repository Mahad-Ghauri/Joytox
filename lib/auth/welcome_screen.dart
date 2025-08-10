// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trace/app/config.dart';
import 'package:trace/app/setup.dart';
import 'package:trace/auth/phone_login_screen.dart';
import 'package:trace/auth/social_login.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:trace/ui/container_with_corner.dart';
import 'package:trace/ui/text_with_tap.dart';
import 'package:trace/utils/colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  static const String route = '/welcome';

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  bool hasError = false;

  late SharedPreferences preferences;

  bool agreeWithTerms = false;
  bool showAgreeAlert = false;

  showAgreeWithTermsAlert() {
    setState(() {
      showAgreeAlert = true;
    });
    hideAgreeWithTermsAlert();
  }

  hideAgreeWithTermsAlert() {
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        showAgreeAlert = false;
      });
    });
  }

  @override
  void initState() {
    initSharedPref();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  initSharedPref() async {
    preferences = await SharedPreferences.getInstance();
  }

  Future<void> googleLogin() async {
    print("=".padRight(50, "="));
    print("🚀 DEBUG: WELCOME SCREEN GOOGLE LOGIN CALLED!");
    print("=".padRight(50, "="));
    try {
      print("🔍 DEBUG: Attempting Google sign in...");
      GoogleSignInAccount? account = await _googleSignIn.signIn();
      print(
          "✅ DEBUG: Google sign in result - Account: ${account?.email ?? 'null'}");

      if (account == null) {
        print(
            "❌ DEBUG: Google sign in returned null account - user cancelled or failed");
        return;
      }

      print("🔑 DEBUG: Getting authentication credentials...");
      GoogleSignInAuthentication authentication = await account.authentication;
      print(
          "✅ DEBUG: Authentication obtained - AccessToken: ${authentication.accessToken != null ? 'Present' : 'Missing'}, IdToken: ${authentication.idToken != null ? 'Present' : 'Missing'}");

      QuickHelp.showLoadingDialog(context);

      var allName = account.displayName!.split(" ");
      String firstName = allName[0];
      String secondName = allName.length > 1 ? allName[1] : "";
      print("👤 DEBUG: Parsed name - First: $firstName, Second: $secondName");

      print(
          "📡 DEBUG: Attempting Parse Server login with Google credentials...");
      print("🔍 DEBUG: User ID: ${_googleSignIn.currentUser!.id}");
      print("🔍 DEBUG: Email: ${account.email}");
      print(
          "🔍 DEBUG: Username: ${firstName.toLowerCase() + secondName.toLowerCase()}");

      final ParseResponse response = await ParseUser.loginWith(
        'google',
        google(authentication.accessToken!, _googleSignIn.currentUser!.id,
            authentication.idToken!),
        email: account.email,
        username: firstName.toLowerCase() + secondName.toLowerCase(),
      );

      print("📋 DEBUG: Parse login response - Success: ${response.success}");
      if (!response.success && response.error != null) {
        print(
            "❌ DEBUG: Parse login error - Code: ${response.error!.code}, Message: ${response.error!.message}");
      }

      if (response.success) {
        print("✅ DEBUG: Parse login successful, getting current user...");
        UserModel? user = await ParseUser.currentUser();
        print(
            "👤 DEBUG: Current user - ${user != null ? 'Found' : 'Not found'}");

        if (user != null) {
          print("🔍 DEBUG: Checking if user needs setup - UID: ${user.getUid}");
          if (user.getUid == null) {
            print("🆕 DEBUG: New user detected, setting up user details...");
            getGoogleUserDetails(user, account, authentication.idToken!);
          } else {
            print("🏠 DEBUG: Existing user, navigating to home...");
            SocialLogin.goHome(context, user);
          }
        } else {
          print("❌ DEBUG: Current user is null after successful Parse login");
          QuickHelp.hideLoadingDialog(context);
          QuickHelp.showAppNotificationAdvanced(
              context: context, title: "auth.gg_login_error".tr());
          await _googleSignIn.signOut();
        }
      } else {
        print("❌ DEBUG: Parse login failed, signing out from Google...");
        print(
            "❌ DEBUG: Error message shown to user: ${response.error!.message}");
        QuickHelp.hideLoadingDialog(context);
        QuickHelp.showAppNotificationAdvanced(
            context: context, title: response.error!.message);
        debugPrint("google_login_error: ${response.error!.message}");
        await _googleSignIn.signOut();
      }
    } catch (error) {
      print("💥 DEBUG: Exception caught in Google login - Error: $error");
      print("🔍 DEBUG: Error type: ${error.runtimeType}");

      if (error == GoogleSignIn.kSignInCanceledError) {
        print("🚫 DEBUG: User cancelled Google sign in");
        QuickHelp.showAppNotificationAdvanced(
            context: context, title: "auth.gg_login_cancelled".tr());
      } else if (error == GoogleSignIn.kNetworkError) {
        print("🌐 DEBUG: Network error during Google sign in");
        QuickHelp.showAppNotificationAdvanced(
            context: context, title: "not_connected".tr());
      } else {
        print("❌ DEBUG: Unknown error during Google sign in: $error");
        QuickHelp.showAppNotificationAdvanced(
            context: context, title: "auth.gg_login_error".tr());
      }

      print("🔄 DEBUG: Signing out from Google due to error...");
      await _googleSignIn.signOut();
    }
  }

  void getGoogleUserDetails(
      UserModel user, GoogleSignInAccount googleUser, String idToken) async {
    print("📝 DEBUG: Starting Google user details setup in welcome screen...");
    print("🔍 DEBUG: Google user email: ${googleUser.email}");
    print("🔍 DEBUG: Google user display name: ${googleUser.displayName}");

    Map<String, dynamic>? idMap = QuickHelp.getInfoFromToken(idToken);
    print("🎫 DEBUG: ID Token parsed - Map: $idMap");

    String firstName = idMap!["given_name"];
    String lastName = idMap["family_name"];
    print("👤 DEBUG: Extracted names - First: $firstName, Last: $lastName");

    String username =
        lastName.replaceAll(" ", "") + firstName.replaceAll(" ", "");
    print("🏷️ DEBUG: Generated username: $username");

    user.setFullName = googleUser.displayName!;
    user.setGoogleId = googleUser.id;
    user.setFirstName = firstName;
    user.setLastName = lastName;
    user.username = username.toLowerCase().trim();
    user.setEmail = googleUser.email;
    user.setEmailPublic = googleUser.email;
    //user.setGender = await getGender();
    user.setUid = QuickHelp.generateUId();
    user.setPopularity = 0;
    user.setUserRole = UserModel.roleUser;
    user.setPrefMinAge = Setup.minimumAgeToRegister;
    user.setPrefMaxAge = Setup.maximumAgeToRegister;
    user.setLocationTypeNearBy = true;
    user.addCredit = Setup.welcomeCredit;
    user.setBio = Setup.bio;
    user.setHasPassword = false;
    //user.setBirthday = QuickHelp.getDateFromString(user['birthday'], QuickHelp.dateFormatFacebook);

    print("💾 DEBUG: Saving user with complete details...");
    print("🔍 DEBUG: Final username: ${user.username}");
    print("🔍 DEBUG: Generated UID: ${user.getUid}");

    ParseResponse response = await user.save();

    if (response.success) {
      print(
          "✅ DEBUG: User details saved successfully to Parse in welcome screen");
      print("📸 DEBUG: Getting photo from URL: ${googleUser.photoUrl}");
      SocialLogin.getPhotoFromUrl(context, user, googleUser.photoUrl!);
    } else {
      print("❌ DEBUG: Failed to save user details to Parse in welcome screen");
      print(
          "❌ DEBUG: Parse error - Code: ${response.error?.code}, Message: ${response.error?.message}");
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showErrorResult(context, response.error!.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    QuickHelp.setWebPageTitle(context,
        "page_title.welcome_title".tr(namedArgs: {"app_name": Config.appName}));
    Size size = MediaQuery.of(context).size;
    return GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.white])),
          child: Scaffold(
            backgroundColor: Colors.white,
            resizeToAvoidBottomInset: false,
            body: Stack(
              alignment: AlignmentDirectional.center,
              children: [
                //SlidingImage(imagePath: "assets/images/background.png",),
                ContainerCorner(
                  width: size.width,
                  height: size.height,
                  borderWidth: 0,
                  child: Image.asset(
                    "assets/images/welcome_background.png", // ✅ Tumhara image path
                    fit: BoxFit.cover,
                  ),
                ),

                SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(
                          height:
                              70), // 👈 adjust karo agar kam/ziyada spacing chahiye
                      Column(
                        children: [
                          ContainerCorner(
                            height: 48,
                            marginLeft: 50,
                            marginRight: 50,
                            color: Colors.white,
                            borderRadius: 50,
                            marginBottom: 10,
                            onTap: () {
                              if (agreeWithTerms) {
                                googleLogin();
                              } else {
                                showAgreeWithTermsAlert();
                              }
                            },
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 20, right: 25),
                                  child: SvgPicture.asset(
                                    "assets/svg/ic_google_logo.svg",
                                    height: 25,
                                    width: 25,
                                  ),
                                ),
                                TextWithTap(
                                  "login_screen.connect_google".tr(),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blueAccent,
                                  textAlign: TextAlign.center,
                                  marginRight: 20,
                                ),
                              ],
                            ),
                          ),
                          Visibility(
                            visible: QuickHelp.isAndroidLogin(),
                            child: ContainerCorner(
                              height: 48,
                              marginLeft: 50,
                              marginRight: 50,
                              color: Colors.white,
                              borderRadius: 50,
                              marginBottom: 50,
                              onTap: () {
                                if (agreeWithTerms) {
                                  SocialLogin.loginApple(context, preferences);
                                } else {
                                  showAgreeWithTermsAlert();
                                }
                              },
                              child: Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 20, right: 25),
                                    child: SvgPicture.asset(
                                      "assets/svg/ic_apple_logo.svg",
                                      height: 25,
                                      width: 25,
                                    ),
                                  ),
                                  TextWithTap(
                                    "login_screen.sign_apple".tr(),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    textAlign: TextAlign.center,
                                    marginRight: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          TextWithTap(
                            "login_screen.more_methods".tr(),
                            fontSize: 9,
                            color: kGrayColor,
                            marginBottom: 10,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Visibility(
                                visible: false,
                                child: ContainerCorner(
                                  color: Colors.white,
                                  height: 40,
                                  width: 40,
                                  borderRadius: 50,
                                  borderWidth: 0,
                                  marginRight: 30,
                                  onTap: () {
                                    if (agreeWithTerms) {
                                      SocialLogin.loginFacebook(context);
                                    } else {
                                      showAgreeWithTermsAlert();
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: SvgPicture.asset(
                                        "assets/svg/ic_facebook_logo.svg"),
                                  ),
                                ),
                              ),
                              ContainerCorner(
                                color: Colors.white,
                                height: 40,
                                width: 40,
                                borderRadius: 50,
                                borderWidth: 0,
                                onTap: () {
                                  if (agreeWithTerms) {
                                    QuickHelp.goToNavigatorScreen(
                                        context, PhoneLoginScreen());
                                  } else {
                                    showAgreeWithTermsAlert();
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: SvgPicture.asset(
                                      "assets/svg/ic_phone_login.svg"),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 30,
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                agreeWithTerms = !agreeWithTerms;
                              });
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  agreeWithTerms
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: agreeWithTerms
                                      ? Colors.blueAccent
                                      : Colors.white,
                                  size: 14,
                                ),
                                TextWithTap(
                                  "login_screen.by_using".tr(
                                      namedArgs: {"app_name": Config.appName}),
                                  color: Colors.white,
                                  fontSize: 11,
                                  marginLeft: 5,
                                ),
                              ],
                            ),
                          ),
                          ContainerCorner(
                            marginLeft: 20,
                            marginRight: 20,
                            marginBottom: 40,
                            child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(children: [
                                  TextSpan(
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.lightBlueAccent,
                                        decoration: TextDecoration.underline,
                                      ),
                                      text:
                                          "login_screen.terms_of_service".tr(),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () {
                                          if (QuickHelp.isMobile()) {
                                            debugPrint("o_que_esta_vend0???");
                                            QuickHelp.goToWebPage(context,
                                                pageType:
                                                    QuickHelp.pageTypeTerms);
                                          } else {
                                            QuickHelp
                                                .launchInWebViewWithJavaScript(
                                                    Config.termsOfUseUrl);
                                          }
                                        }),
                                  TextSpan(
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.normal),
                                    text:
                                        "login_screen.and_".tr().toLowerCase(),
                                  ),
                                  TextSpan(
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.lightBlueAccent,
                                        decoration: TextDecoration.underline,
                                      ),
                                      text: "login_screen.privacy_".tr(),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () {
                                          if (QuickHelp.isMobile()) {
                                            debugPrint("o_que_esta_vend0???");
                                            QuickHelp.goToWebPage(context,
                                                pageType:
                                                    QuickHelp.pageTypePrivacy);
                                          } else {
                                            QuickHelp
                                                .launchInWebViewWithJavaScript(
                                                    Config.privacyPolicyUrl);
                                          }
                                        }),
                                ])),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Visibility(
                  visible: showAgreeAlert,
                  child: ContainerCorner(
                    color: Colors.black.withOpacity(0.5),
                    height: 50,
                    marginRight: 50,
                    marginLeft: 50,
                    borderRadius: 50,
                    shadowColor: kGrayColor,
                    shadowColorOpacity: 0.3,
                    child: Center(
                      child: TextWithTap(
                        "login_screen.please_tick_option".tr(),
                        color: Colors.white,
                        marginBottom: 5,
                        marginTop: 5,
                        marginLeft: 15,
                        marginRight: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}

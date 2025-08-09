// ignore_for_file: deprecated_member_use

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
import 'package:trace/app/Config.dart';
import 'package:trace/auth/phone_login_screen.dart';
import 'package:trace/auth/responsive_forget_password_screen.dart';
import 'package:trace/auth/responsive_signup_screen.dart';
import 'package:trace/auth/social_login.dart';
import 'package:trace/ui/container_with_corner.dart';
import 'package:trace/ui/text_with_tap.dart';
import 'package:trace/utils/colors.dart';

import '../app/setup.dart';
import '../helpers/quick_help.dart';
import '../home/responsive_home_screen.dart';
import '../models/UserModel.dart';
import '../utils/responsive.dart';

class ResponsiveWelcomeScreen extends StatefulWidget {
  ResponsiveWelcomeScreen({super.key});

  @override
  State<ResponsiveWelcomeScreen> createState() =>
      _ResponsiveWelcomeScreenState();
}

class _ResponsiveWelcomeScreenState extends State<ResponsiveWelcomeScreen> {
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  TextEditingController passwordTextController = TextEditingController();
  TextEditingController usernameTextController = TextEditingController();
  GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  bool isPasswordHidden = true;
  bool passwordError = false;

  String usernameErrorText = "";
  String passwordErrorText = "";

  togglePasswordVisibility() {
    setState(() {
      if (isPasswordHidden) {
        isPasswordHidden = false;
      } else {
        isPasswordHidden = true;
      }
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);
    return Scaffold(
      extendBody: true,
      body: ContainerCorner(
        borderWidth: 0,
        width: size.width,
        height: size.height,
        child: Row(
          children: [
            ContainerCorner(
              width: size.width > kHideWelcomeRightSide ? 450 : size.width,
              borderWidth: 0,
              height: size.height,
              color: kBlueDarker,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        "assets/images/ic_logo.png",
                        width: 120,
                        height: 120,
                      ),
                      TextWithTap(
                        "sign_in".tr(),
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 30,
                        marginTop: 15,
                        marginBottom: 15,
                      ),
                      TextWithTap(
                        "edit_data_screen.username_".tr(),
                        color: Colors.white,
                        marginBottom: 8,
                      ),
                      ContainerCorner(
                        borderWidth: 1,
                        color: Colors.white,
                        height: 50,
                        borderRadius: 8,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: Center(
                            child: TextFormField(
                              controller: usernameTextController,
                              keyboardType: TextInputType.text,
                              cursorColor: kGrayColor,
                              autocorrect: false,
                              decoration: InputDecoration(
                                errorMaxLines: 1,
                                errorStyle: TextStyle(fontSize: 10),
                                border: InputBorder.none,
                                hintText: "edit_data_screen.username_".tr(),
                                hintStyle: TextStyle(
                                    color: kGrayColor.withOpacity(0.7),
                                    fontSize: 13),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  setState(
                                    () {
                                      usernameErrorText =
                                          "edit_data_screen.username_".tr();
                                    },
                                  );
                                  return "";
                                } else {
                                  setState(() {
                                    usernameErrorText = "";
                                  });
                                  return null;
                                }
                              },
                              style: TextStyle(
                                color: Colors.black,
                                decorationStyle: TextDecorationStyle.solid,
                              ),
                            ),
                          ),
                        ),
                      ),
                      TextWithTap(
                        usernameErrorText,
                        color: kRedColor1,
                        fontSize: 12,
                        marginBottom: 25,
                        marginTop: 5,
                      ),
                      TextWithTap(
                        "password_".tr(),
                        color: Colors.white,
                        marginBottom: 8,
                      ),
                      ContainerCorner(
                        borderWidth: 1,
                        color: Colors.white,
                        height: 50,
                        borderRadius: 8,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 10,
                            right: 10,
                          ),
                          child: Center(
                            child: TextFormField(
                              controller: passwordTextController,
                              keyboardType: TextInputType.text,
                              cursorColor: kGrayColor,
                              autocorrect: false,
                              obscureText: isPasswordHidden,
                              decoration: InputDecoration(
                                errorMaxLines: 1,
                                errorStyle: TextStyle(fontSize: 0),
                                border: InputBorder.none,
                                hintText: "login_screen.password_hint".tr(),
                                hintStyle: TextStyle(
                                    color: kGrayColor.withOpacity(0.7),
                                    fontSize: 13),
                                suffix: IconButton(
                                  onPressed: () => togglePasswordVisibility(),
                                  icon: Icon(
                                    isPasswordHidden
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  setState(() {
                                    passwordErrorText =
                                        "login_screen.password_required".tr();
                                  });
                                  return "";
                                } else {
                                  setState(() {
                                    passwordErrorText = "";
                                  });
                                  return null;
                                }
                              },
                              style: TextStyle(
                                color: Colors.black,
                                decorationStyle: TextDecorationStyle.solid,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextWithTap(
                            passwordErrorText,
                            color: kRedColor1,
                            fontSize: 12,
                            marginBottom: 25,
                            marginTop: 5,
                          ),
                          TextButton(
                            onPressed: () {
                              QuickHelp.goToNavigatorScreen(
                                context,
                                ResponsiveForgetPasswordScreen(
                                ),
                              );
                            },
                            child: TextWithTap(
                              "forget_password".tr(),
                              color: kBlueColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      ContainerCorner(
                        height: 50,
                        borderRadius: 8,
                        borderWidth: 0,
                        color: kBlueColor,
                        marginBottom: 30,
                        marginTop: 10,
                        child: TextButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              login();
                            }
                          },
                          child: TextWithTap(
                            "connect_".tr(),
                            color: Colors.white,
                            alignment: Alignment.center,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      Align(
                        child: TextButton(
                          onPressed: () {
                            QuickHelp.goToNavigatorScreen(
                              context,
                              ResponsiveSignUpScreen(
                              ),
                            );
                          },
                          child: TextWithTap(
                            "create_account".tr(),
                            color: kBlueColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 30,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ContainerCorner(
                            color: Colors.white,
                            height: 0.5,
                            width: 70,
                          ),
                          TextWithTap(
                            "or_".tr(),
                            color: Colors.white,
                            marginLeft: 10,
                            marginRight: 10,
                          ),
                          ContainerCorner(
                            color: Colors.white,
                            height: 0.5,
                            width: 70,
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 25,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ContainerCorner(
                            color: Colors.white,
                            height: 40,
                            width: 40,
                            borderRadius: 50,
                            borderWidth: 0,
                            onTap: () {
                              googleLogin();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SvgPicture.asset(
                                  "assets/svg/ic_google_logo.svg"),
                            ),
                          ),
                          ContainerCorner(
                            color: Colors.white,
                            height: 40,
                            width: 40,
                            borderRadius: 50,
                            marginLeft: 20,
                            borderWidth: 0,
                            onTap: () {
                              QuickHelp.goToNavigatorScreen(
                                context,
                                PhoneLoginScreen(
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SvgPicture.asset(
                                  "assets/svg/ic_phone_login.svg"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Visibility(
              visible: size.width >= kHideWelcomeRightSide,
              child: Flexible(
                child: ContainerCorner(
                  borderWidth: 0,
                  height: size.height,
                  width: double.infinity,
                  imageDecoration: "assets/images/trace_web_welcome.png",
                  child: Padding(
                    padding: EdgeInsets.only(left: size.width / 30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWithTap(
                          Config.appName,
                          color: Colors.white,
                          fontSize: size.width / 20,
                          fontWeight: FontWeight.w900,
                        ),
                        SizedBox(
                          width: size.width / 2,
                          child: TextWithTap(
                            "dynamic_welcome_screen.welcome_message".tr(
                                namedArgs: {"app_name": "${Config.appName}"}),
                            color: Colors.white.withOpacity(0.6),
                            marginRight: 10,
                          ),
                        ),
                        Visibility(
                          visible: size.width > kBreakWelcomeRightSide,
                          child: Row(
                            children: [
                              usersImages(),
                              joinUsText(),
                            ],
                          ),
                        ),
                        Visibility(
                          visible: size.width <= kBreakWelcomeRightSide,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              usersImages(),
                              joinUsText(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ContainerCorner(
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
                  text: "login_screen.terms_of_service".tr(),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      if (QuickHelp.isMobile()) {
                        QuickHelp.goToWebPage(context,
                            pageType: QuickHelp.pageTypeTerms);
                      } else {
                        QuickHelp.launchInWebViewWithJavaScript(
                            Config.termsOfUseUrl);
                      }
                    }),
              WidgetSpan(
                  child: SizedBox(
                width: 7,
              )),
              TextSpan(
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.normal),
                text: "login_screen.and_".tr().toLowerCase(),
              ),
              WidgetSpan(
                  child: SizedBox(
                width: 7,
              )),
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
                        QuickHelp.goToWebPage(context,
                            pageType: QuickHelp.pageTypePrivacy);
                      } else {
                        QuickHelp.launchInWebViewWithJavaScript(
                            Config.privacyPolicyUrl);
                      }
                    }),
            ])),
      ),
    );
  }

  Widget usersImages() {
    return Image.asset(
      "assets/images/home_pop_icon_middlefaces.png",
      height: 130,
      width: 130,
    );
  }

  Widget joinUsText() {
    return TextWithTap(
      "dynamic_welcome_screen.join_and_enjoy"
          .tr(namedArgs: {"app_name": "${Config.appName}"}),
      color: Colors.white.withOpacity(0.6),
      marginLeft: 10,
      marginRight: 10,
    );
  }

  void login() async {
    QuickHelp.showLoadingDialog(context);

    QueryBuilder<UserModel> queryByEmail =
        QueryBuilder<UserModel>(UserModel.forQuery());

    queryByEmail.whereEqualTo(
        UserModel.keyUsername, usernameTextController.text);

    ParseResponse response = await queryByEmail.query();

    if (response.success) {
      if (response.results != null) {
        final user = ParseUser(
            response.results!.first[UserModel.keyUsername],
            passwordTextController.text,
            response.results!.first[UserModel.keyEmail]);

        ParseResponse loginResponse = await user.login();

        if (loginResponse.success && loginResponse.results != null) {
          QuickHelp.hideLoadingDialog(context);
          UserModel? currentUser = await ParseUser.currentUser();

          if (currentUser != null) {
            QuickHelp.goToNavigatorScreen(
              context,
              ResponsiveHomeScreen(
                currentUser: currentUser,
              ),
              back: false,
              finish: true,
            );
          } else {
            QuickHelp.hideLoadingDialog(context);
            QuickAlert.show(
              context: context,
              type: QuickAlertType.error,
              title: "error".tr(),
              text: "not_connected".tr(),
              confirmBtnColor: kTicketBlueColor,
              width: 350,
              borderRadius: 5,
            );
          }
        } else {
          QuickHelp.hideLoadingDialog(context);
          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            title: "error".tr(),
            text: "dynamic_welcome_screen.invalid_password_explain".tr(),
            confirmBtnColor: kTicketBlueColor,
            width: 350,
            borderRadius: 5,
          );
        }
      } else {
        QuickHelp.hideLoadingDialog(context);
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: "error".tr(),
          text: "dynamic_welcome_screen.invalid_credentials_explain".tr(),
          confirmBtnColor: kTicketBlueColor,
          width: 350,
          borderRadius: 5,
        );
      }
    } else {
      QuickHelp.hideLoadingDialog(context);
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: "error".tr(),
        text: "not_connected".tr(),
        confirmBtnColor: kTicketBlueColor,
        width: 350,
        borderRadius: 5,
      );
    }
  }

  Future<void> googleLogin() async {
    try {
      GoogleSignInAccount? account = await _googleSignIn.signIn();
      GoogleSignInAuthentication authentication = await account!.authentication;

      QuickHelp.showLoadingDialog(context);

      final ParseResponse response = await ParseUser.loginWith(
          'google',
          google(authentication.accessToken!, _googleSignIn.currentUser!.id,
              authentication.idToken!));
      if (response.success) {
        UserModel? user = await ParseUser.currentUser();

        if (user != null) {
          if (user.getUid == null) {
            getGoogleUserDetails(user, account, authentication.idToken!);
          } else {
            SocialLogin.goHome(context, user);
          }
        } else {
          QuickHelp.hideLoadingDialog(context);
          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            title: "error".tr(),
            text: "auth.gg_login_error".tr(),
            confirmBtnColor: kTicketBlueColor,
            width: 350,
            borderRadius: 5,
          );
          await _googleSignIn.signOut();
        }
      } else {
        QuickHelp.hideLoadingDialog(context);
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: "error".tr(),
          text: response.error!.message,
          confirmBtnColor: kTicketBlueColor,
          width: 350,
          borderRadius: 5,
        );
        await _googleSignIn.signOut();
      }
    } catch (error) {
      if (error == GoogleSignIn.kSignInCanceledError) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: "error".tr(),
          text: "auth.gg_login_cancelled".tr(),
          confirmBtnColor: kTicketBlueColor,
          width: 350,
          borderRadius: 5,
        );
      } else if (error == GoogleSignIn.kNetworkError) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: "error".tr(),
          text: "not_connected".tr(),
          confirmBtnColor: kTicketBlueColor,
          width: 350,
          borderRadius: 5,
        );
      } else {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: "error".tr(),
          text: "auth.gg_login_error".tr(),
          confirmBtnColor: kTicketBlueColor,
          width: 350,
          borderRadius: 5,
        );
      }
      await _googleSignIn.signOut();
    }
  }

  void getGoogleUserDetails(
      UserModel user, GoogleSignInAccount googleUser, String idToken) async {
    Map<String, dynamic>? idMap = QuickHelp.getInfoFromToken(idToken);

    String firstName = idMap!["given_name"];
    String lastName = idMap["family_name"];

    String username =
        lastName.replaceAll(" ", "") + firstName.replaceAll(" ", "");

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
    ParseResponse response = await user.save();

    if (response.success) {
      SocialLogin.getPhotoFromUrl(
          context, user, googleUser.photoUrl!);
    } else {
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showErrorResult(context, response.error!.code);
    }
  }
}

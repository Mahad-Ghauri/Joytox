// ignore_for_file: must_be_immutable, deprecated_member_use

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trace/app/config.dart';

import '../helpers/quick_help.dart';
import '../ui/container_with_corner.dart';
import '../ui/text_with_tap.dart';
import '../utils/colors.dart';
import '../utils/responsive.dart';

class ResponsiveForgetPasswordScreen extends StatefulWidget {
  SharedPreferences? preferences;
  ResponsiveForgetPasswordScreen({this.preferences, super.key});

  @override
  State<ResponsiveForgetPasswordScreen> createState() =>
      _ResponsiveForgetPasswordScreenState();
}

class _ResponsiveForgetPasswordScreenState
    extends State<ResponsiveForgetPasswordScreen> {
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  TextEditingController passwordTextController = TextEditingController();
  TextEditingController usernameTextController = TextEditingController();

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
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: kTransparentColor,
        leading: BackButton(
          color: Colors.white,
        ),
      ),
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
              child: Lottie.asset(
                "assets/lotties/password_recover.json",
              ),
            ),
            Flexible(
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
                        "Recuperar palavra pass",
                        color: Colors.white,
                        fontSize: 30,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20),
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                  padding: const EdgeInsets.only(
                                      left: 10, right: 10),
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
                                        hintText:
                                            "edit_data_screen.username_".tr(),
                                        hintStyle: TextStyle(
                                            color: kGrayColor.withOpacity(0.7),
                                            fontSize: 13),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          setState(
                                            () {
                                              usernameErrorText =
                                                  "edit_data_screen.username_"
                                                      .tr();
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
                                        decorationStyle:
                                            TextDecorationStyle.solid,
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
                                        hintText:
                                            "login_screen.password_hint".tr(),
                                        hintStyle: TextStyle(
                                            color: kGrayColor.withOpacity(0.7),
                                            fontSize: 13),
                                        suffix: IconButton(
                                          onPressed: () =>
                                              togglePasswordVisibility(),
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
                                                "login_screen.password_required"
                                                    .tr();
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
                                        decorationStyle:
                                            TextDecorationStyle.solid,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              TextWithTap(
                                passwordErrorText,
                                color: kRedColor1,
                                fontSize: 12,
                                marginBottom: 25,
                                marginTop: 5,
                              ),
                              ContainerCorner(
                                height: 50,
                                borderRadius: 8,
                                borderWidth: 0,
                                color: kBlueColor,
                                marginBottom: 30,
                                child: TextButton(
                                  onPressed: () {
                                    if (formKey.currentState!.validate()) {}
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
                                    QuickHelp.goBackToPreviousPage(context);
                                  },
                                  child: TextWithTap(
                                    "sign_in".tr(),
                                    color: kBlueColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
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
}

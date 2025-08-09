// ignore_for_file: must_be_immutable, unused_local_variable, deprecated_member_use

import 'dart:async';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:linear_progress_bar/linear_progress_bar.dart';
import 'package:lottie/lottie.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trace/ui/text_with_tap.dart';
import 'package:universal_io/io.dart';

import '../app/Config.dart';
import '../app/setup.dart';
import '../helpers/quick_actions.dart';
import '../helpers/quick_help.dart';
import '../models/UserModel.dart';
import '../ui/button_with_icon.dart';
import '../ui/container_with_corner.dart';
import '../ui/phone_number_field.dart';
import '../utils/colors.dart';
import '../utils/responsive.dart';
import '../widgets/CountDownTimer.dart';

class ResponsiveSignUpScreen extends StatefulWidget {
  SharedPreferences? preferences;

  ResponsiveSignUpScreen({this.preferences, super.key});

  @override
  State<ResponsiveSignUpScreen> createState() => _ResponsiveSignUpScreenState();
}

FirebaseAuth _auth = FirebaseAuth.instance;
late ConfirmationResult confirmationResult;
late UserCredential userCredential;

class _ResponsiveSignUpScreenState extends State<ResponsiveSignUpScreen> {
  GlobalKey<FormState> firstFormKey = GlobalKey<FormState>();
  GlobalKey<FormState> secondFormKey = GlobalKey<FormState>();
  GlobalKey<FormState> thirdFormKey = GlobalKey<FormState>();

  TextEditingController passwordTextController = TextEditingController();
  TextEditingController usernameTextController = TextEditingController();
  TextEditingController emailTextController = TextEditingController();
  TextEditingController firstNameTextController = TextEditingController();
  TextEditingController lastNameTextController = TextEditingController();
  TextEditingController confirmPasswordTextController = TextEditingController();
  TextEditingController phoneNumberEditingController = TextEditingController();
  TextEditingController pinCodeEditingController = TextEditingController();

  String countryIsoCode = Config.initialCountry;
  String countryDialCode = QuickHelp.getCountryDialCode(Config.initialCountry);
  List<String> languagesIso =  QuickHelp.getLanguageByCountryIso(code: Config.initialCountry);
  bool isEmptyPhoneField =  false;

  // Web confirmation result for OTP.
  ConfirmationResult? _webConfirmationResult;

  bool isPasswordHidden = true;
  bool isConfirmPasswordHidden = true;

  String usernameErrorText = "";
  String emailErrorText = "";
  String firstNameErrorText = "";
  String lastNameErrorText = "";
  String passwordErrorText = "";
  String confirmPasswordErrorText = "";
  String phoneErrorText = "";
  String avatarErrorText = "";
  String birthdayErrorText = "";
  String genderErrorText = "";

  String _phoneNumber = "";
  String _pinCode = "";

  bool validPhoneNumber = false;
  bool passwordError = false;

  bool _showResend = false;
  late String _verificationId;
  int? _tokenResend;

  togglePasswordVisibility() {
    setState(() {
      if (isPasswordHidden) {
        isPasswordHidden = false;
      } else {
        isPasswordHidden = true;
      }
    });
  }

  toggleConfirmPasswordVisibility() {
    setState(() {
      if (isConfirmPasswordHidden) {
        isConfirmPasswordHidden = false;
      } else {
        isConfirmPasswordHidden = true;
      }
    });
  }

  nextPosition() {
    setState(() {
      currentStep = currentStep + 1;
    });
  }

  previousPosition() {
    setState(() {
      currentStep = currentStep - 1;
    });
  }

  int totalSteps = 3;
  int currentStep = 2;

  StreamController<ErrorAnimationType>? errorController;


  var genders = ["female_".tr(), "male_".tr()];

  var gendersSelectedImage = ["assets/images/ic_female_gender_selected.webp", "assets/images/ic_mal_gender_selected.webp"];
  var gendersUnselectedImage = ["assets/images/ic_female_gender_default.webp", "assets/images/ic_male_gender_default.webp"];

  var isMale = [true, false];
  var selectedGender = [];
  String? mySelectedGender;
  DateTime dateTime = DateTime(1999);
  bool isValidBirthday = false;
  String myBirthday = "";

  String userAvatar = "";
  ParseFileBase? userAvatarPicture;

  @override
  void initState() {
    super.initState();
    errorController = StreamController<ErrorAnimationType>();
  }

  @override
  void dispose() {
    errorController!.close();
    super.dispose();
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
        centerTitle: true,
        title: LinearProgressBar(
          maxSteps: totalSteps,
          progressType: LinearProgressBar.progressTypeDots,
          currentStep: currentStep,
          progressColor: kBlueColor,
          backgroundColor: Colors.white,
          dotsSpacing: EdgeInsets.only(right: 15),
          dotsActiveSize: 10,
        ),
      ),
      body: ContainerCorner(
        borderWidth: 0,
        width: size.width,
        height: size.height,
        child: Row(
          children: [
            Visibility(
              visible: size.width > kHideSignupLeftSide,
              child: ContainerCorner(
                width: size.width > kBreakSignupLeftSide ? 450 : 300,
                borderWidth: 0,
                height: size.height,
                color: kBlueDarker,
                child: Lottie.asset(
                  "assets/lotties/anima_sigup.json",
                ),
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
                        "sign_up".tr(),
                        color: Colors.white,
                        fontSize: 30,
                        marginBottom: 35,
                      ),
                      IndexedStack(
                        index: currentStep,
                        alignment: AlignmentDirectional.center,
                        children: [
                          firstForm(),
                          phoneCodeInput(),
                          thirdForm(),
                        ],
                      ),
                      Visibility(
                        visible: currentStep != 2,
                        child: Align(
                          child: TextButton(
                            onPressed: () {
                              QuickHelp.goBackToPreviousPage(context);
                            },
                            child: TextWithTap(
                              "go_login".tr(),
                              color: kBlueColor,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget firstForm() {
    Size size = MediaQuery.sizeOf(context);
    return Form(
      key: firstFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: size.width > kBreakSignupFirstForm,
            child: Row(
              children: [
                Flexible(
                  child: ContainerCorner(
                    marginRight: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        firstNameTextField(),
                        emailTextField(),
                        passwordTextField(),
                      ],
                    ),
                  ),
                ),
                Flexible(
                  child: ContainerCorner(
                    marginRight: 15,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        lastNameTextField(),
                        phoneNumberTextField(),
                        confirmPasswordTextField(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Visibility(
            visible: size.width <= kBreakSignupFirstForm,
            child: Padding(
              padding: const EdgeInsets.only(left: 15, right: 15),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  firstNameTextField(),
                  lastNameTextField(),
                  emailTextField(),
                  phoneNumberTextField(),
                  passwordTextField(),
                  confirmPasswordTextField(),
                ],
              ),
            ),
          ),
          ContainerCorner(
            height: 50,
            borderRadius: 8,
            borderWidth: 0,
            color: kBlueColor,
            marginBottom: 30,
            marginRight: 15,
            width: 450,
            child: TextButton(
              onPressed: () {
                if (firstFormKey.currentState!.validate()) {
                  verifyRegisteredPhoneOrEmail();
                }
              },
              child: TextWithTap(
                "next".tr(),
                color: Colors.white,
                alignment: Alignment.center,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget thirdForm() {
    return Form(
      key: thirdFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                child: QuickActions.profileAvatar(
                  userAvatar,
                  boxShape: BoxShape.circle,
                  width: 100,
                  height: 100,
                  borderRadius: 100,
                  fit: BoxFit.cover,
                  margin: EdgeInsets.only(
                    bottom: 0,
                    top: 0,
                    right: 5,
                  ),
                ),
                onTap: () => uploadImage(),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: ContainerCorner(
                  color: Colors.white,
                  height: 35,
                  width: 35,
                  borderRadius: 50,
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.red,
                    size: 22,
                  ),
                  onTap: () => uploadImage(),
                ),
              ),
            ],
          ),
          TextWithTap(
            avatarErrorText,
            color: kRedColor1,
            fontSize: 12,
            marginBottom: 30,
            marginTop: 5,
          ),
          userNameTextField(),
          TextWithTap(
            "profile_screen.birthday_".tr(),
            color: Colors.white,
            marginBottom: 8,
          ),
          birthDayTextField(),
          TextWithTap(
            "profile_screen.gender_".tr(),
            color: Colors.white,
            marginBottom: 15,
            marginTop: 30,
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  selectedGender.clear();
                  setState(() {
                    selectedGender.add(0);
                    mySelectedGender = UserModel.keyGenderFemale;
                  });
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      selectedGender.contains(0) ? gendersSelectedImage[0] : gendersUnselectedImage[0],
                      width: 50,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7, top: 7),
                      child: Row(
                        children: [
                          Icon(
                            Icons.female,
                            color: selectedGender.contains(0) ? Colors.redAccent : kGrayColor,
                          ),
                          TextWithTap(genders[0], color: selectedGender.contains(0) ? Colors.redAccent : kGrayColor)
                        ],
                      ),
                    ),
                    Icon(selectedGender.contains(0) ? Icons.check_circle  : Icons.circle_outlined,
                      color: selectedGender.contains(0) ? earnCashColor : kGrayColor,
                    )
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  selectedGender.clear();
                  setState(() {
                    selectedGender.add(1);
                    mySelectedGender = UserModel.keyGenderMale;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 35),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        selectedGender.contains(1) ? gendersSelectedImage[1] : gendersUnselectedImage[1],
                        width: 50,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7, top: 7),
                        child: Row(
                          children: [
                            Icon(
                              Icons.male,
                              color: selectedGender.contains(1) ? Colors.lightBlue : kGrayColor,
                            ),
                            TextWithTap(genders[1], color: selectedGender.contains(1) ? Colors.lightBlue : kGrayColor,)
                          ],
                        ),
                      ),
                      Icon(
                        selectedGender.contains(1) ? Icons.check_circle  : Icons.circle_outlined,
                        color: selectedGender.contains(1) ? earnCashColor : kGrayColor,
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
          TextWithTap(
            genderErrorText,
            color: kRedColor1,
            fontSize: 12,
            marginTop: 5,
          ),
          ContainerCorner(
            height: 50,
            borderRadius: 8,
            borderWidth: 0,
            color: kBlueColor,
            marginBottom: 30,
            marginRight: 15,
            marginTop: 30,
            width: 450,
            child: TextButton(
              onPressed: () {
                if (thirdFormKey.currentState!.validate()) {

                  setState(() {
                    if(userAvatar.isEmpty) {
                      avatarErrorText = "profile_edit_complete.select_avatar".tr();
                    }else{
                      avatarErrorText = "";
                    }

                    if(!isValidBirthday){
                      birthdayErrorText = "profile_screen.choose_birthday".tr();
                    }else{
                      birthdayErrorText = "";
                    }

                    if(selectedGender.isEmpty) {
                      genderErrorText = "personal_data.select_gender".tr();
                    }else{
                      genderErrorText = "";
                    }
                  });
                  if(userAvatar.isNotEmpty && isValidBirthday && selectedGender.isNotEmpty) {
                    verifyUsername();
                  }
                }
              },
              child: TextWithTap(
                "sign_up".tr(),
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
                "go_login".tr(),
                color: kBlueColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
    );
  }

  uploadImage() async{
    //Image? fromPicker = await ImagePickerWeb.getImageAsWidget();
    //File? image = await ImagePickerWeb.getImageAsFile();
    //File imageFile = await File.(image!);
    //print("imagination_path ${imageFile.path}");
    /*setState(() {
      userAvatar = imageFile.path;
    });*/
    //convertImage(File(imageFile.path));
  }

  cropImage(File? image) async{
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: image!.path,
      maxHeight: 400,
      maxWidth: 400,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Cropper',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Cropper',
        ),
        WebUiSettings(
          context: context,
        ),
      ],
    );

    userAvatar = croppedFile!.path;

    File? imageFile =  await File(croppedFile.path);
    print("echo $imageFile");

    convertImage(File(croppedFile.path));
    setState(() {});
  }

  convertImage(File? file) async{
    //QuickHelp.showLoadingDialog(context);
    DateTime date = DateTime.now();

    print("file_recebido ${file}");
    print("file_recebido abs ${file!.absolute}");
    print("file_recebido path ${file.absolute.path}");

    /*if (file!.absolute.path.isNotEmpty) {
      userAvatarPicture = await ParseFile(File(userAvatar),
          name: "avatar${date.second}_${date.millisecond}.png");
      QuickHelp.hideLoadingDialog(context);
    } else {
      userAvatarPicture = await ParseWebFile(file.absolute.readAsBytesSync(),
          name: "avatar${date.second}_${date.millisecond}.png");
      QuickHelp.hideLoadingDialog(context);
    }*/
    print("file_convertidao $userAvatarPicture");
  }

  Widget birthDayTextField() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ContainerCorner(
          marginBottom: 10,
          marginTop: 5,
          width: 450,
          onTap: () => showCalendar(),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: 15,
                  color: Colors.white,
                ),
              ),
              TextWithTap(
                "${dateTime.year}-${dateTime.month}-${dateTime.day}",
                marginLeft: 5,
                color: Colors.white,
              ),
            ],
          ),
        ),
        ContainerCorner(
          height: 0.5,
          color: Colors.white,
          width: 450,
        ),
        TextWithTap(
          birthdayErrorText,
          color: kRedColor1,
          fontSize: 12,
          marginTop: 5,
        ),
      ],
    );
  }

  showCalendar() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            insetPadding: EdgeInsets.only(left: 10, right: 10),
            content: ContainerCorner(
              height: 400,
              width: 400,
              child: CalendarDatePicker2WithActionButtons(
                config: CalendarDatePicker2WithActionButtonsConfig(
                  firstDayOfWeek: 1,
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                  calendarType: CalendarDatePicker2Type.single,
                  selectedDayTextStyle: TextStyle(
                      color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedDayHighlightColor: Colors.purple[800],
                ),
                onValueChanged: (dates) => setState(() {
                  dateTime = dates[0]!;
                }),
                onCancelTapped: () {
                  setState(() {
                    dateTime = DateTime(1999);
                  });
                  QuickHelp.hideLoadingDialog(context);
                },
                onOkTapped: () {
                  _validateBirthday(
                      "${dateTime.day}/${dateTime.month}/${dateTime.year}");
                  QuickHelp.hideLoadingDialog(context);
                },
                value: [],
              ),
            ),
          );
        },
    );
  }

  String? _validateBirthday(String value) {
    isValidBirthday = false;
    if (value.isEmpty) {
      return "profile_screen.choose_birthday".tr();
    } else if (!QuickHelp.isValidDateBirth(value, QuickHelp.dateFormatDmy)) {
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "personal_data.error_".tr(),
        message: "profile_screen.invalid_date".tr(),
        isError: true,
      );
    } else if (!QuickHelp.minimumAgeAllowed(value, QuickHelp.dateFormatDmy)) {
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "personal_data.error_".tr(),
        message: "profile_screen.mim_age_required"
            .tr(namedArgs: {'age': Setup.minimumAgeToRegister.toString()}),
        isError: true,
      );
      setState(() {
        dateTime = DateTime(1999);
      });
    } else {
      isValidBirthday = true;
      myBirthday = value;
      return null;
    }
    return null;
  }

  void _sendVerificationCode(bool resend) async {
    QuickHelp.showLoadingDialog(context, isDismissible: false);

    PhoneVerificationCompleted verificationCompleted =
        (PhoneAuthCredential phoneAuthCredential) async {
      await _auth.signInWithCredential(phoneAuthCredential);

      print('Verified automatically');

      //_checkUserAccount();
    };

    PhoneVerificationFailed verificationFailed = (FirebaseAuthException e) {
      QuickHelp.hideLoadingDialog(context);

      print(
          'Phone number verification failed. Code: ${e.code}. Message: ${e.message}');

      if (e.code == "web-context-cancelled") {
        QuickHelp.showAppNotificationAdvanced(
            context: context,
            title: "error".tr(),
            message: "auth.canceled_phone".tr());
      } else if (e.code == "invalid-verification-code") {
        QuickHelp.showAppNotificationAdvanced(
            context: context,
            title: "error".tr(),
            message: "auth.invalid_code".tr());
      } else if (e.code == "network-request-failed") {
        QuickHelp.showAppNotificationAdvanced(
            context: context,
            title: "error".tr(),
            message: "no_internet_connection".tr());
      } else if (e.code == "invalid-phone-number") {
        QuickHelp.showAppNotificationAdvanced(
            context: context,
            title: "error".tr(),
            message: "auth.invalid_phone_number".tr());
      } else {
        QuickHelp.showAppNotificationAdvanced(
            context: context,
            title: "error".tr(),
            message: "try_again_later".tr());
      }
    };

    PhoneCodeSent codeSent =
        (String verificationId, [int? forceResendingToken]) async {
      QuickHelp.hideLoadingDialog(context);
      // Check your phone for the sms code
      _verificationId = verificationId;
      _tokenResend = forceResendingToken;

      print('Verification code sent');

      if (!resend) {
        nextPosition();
      }

      setState(() {
        _showResend = false;
      });
    };

    PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout =
        (String verificationId) {
      _verificationId = verificationId;
      print('PhoneCodeAutoRetrievalTimeout');
    };

    try {
      if (QuickHelp.isWebPlatform()) {
        _webConfirmationResult = await _auth.signInWithPhoneNumber(
            countryDialCode+phoneNumberEditingController.text,
            RecaptchaVerifier(
              auth: FirebaseAuthPlatform.instance,
              size: RecaptchaVerifierSize.compact,
              theme: RecaptchaVerifierTheme.dark,
              onSuccess: () {
                QuickHelp.hideLoadingDialog(context);

                print('Verification code sent');

                if (!resend) {
                  nextPosition();
                }

                setState(() {
                  _showResend = false;
                });
              },
              onError: (FirebaseAuthException error) {
                QuickHelp.showAppNotificationAdvanced(
                    context: context,
                    title: "error".tr(),
                    message: error.message);
              },
              onExpired: () {
                QuickHelp.showAppNotificationAdvanced(
                    context: context,
                    title: "error".tr(),
                    message: "auth.recaptcha_expired".tr());
              },
            ));

      } else {
        await _auth.verifyPhoneNumber(
            phoneNumber: countryDialCode+phoneNumberEditingController.text,
            timeout: const Duration(seconds: 5),
            verificationCompleted: verificationCompleted,
            verificationFailed: verificationFailed,
            codeSent: codeSent,
            forceResendingToken: _tokenResend,
            codeAutoRetrievalTimeout: codeAutoRetrievalTimeout);
      }
    } on FirebaseAuthException catch (e) {
      QuickHelp.hideLoadingDialog(context);

      if (e.code == "web-context-cancelled") {
        QuickHelp.showAppNotificationAdvanced(
            context: context,
            title: "error".tr(),
            message: "auth.canceled_phone".tr());
      } else if (e.code == "invalid-verification-code") {
        QuickHelp.showAppNotificationAdvanced(
            context: context,
            title: "error".tr(),
            message: "auth.invalid_code".tr());
      } else if (e.code == "network-request-failed") {
        QuickHelp.showAppNotificationAdvanced(
            context: context,
            title: "error".tr(),
            message: "no_internet_connection".tr());
      } else if (e.code == "invalid-phone-number") {
        QuickHelp.showAppNotificationAdvanced(
            context: context,
            title: "error".tr(),
            message: "auth.invalid_phone_number".tr());
      } else {
        QuickHelp.showAppNotificationAdvanced(
            context: context,
            title: "error".tr(),
            message: "try_again_later".tr());
      }
    }
  }

  Future<void> verifyRegisteredPhoneOrEmail() async {
    QuickHelp.showLoadingDialog(context);

    QueryBuilder<UserModel> queryPhoneNumber =
    QueryBuilder<UserModel>(UserModel.forQuery());

    queryPhoneNumber.whereEqualTo(UserModel.keyPhoneNumber, phoneNumberEditingController.text);
    queryPhoneNumber.whereEqualTo(
        UserModel.keyCountryCode, countryIsoCode);
    ParseResponse phoneNumberResponse = await queryPhoneNumber.query();

    QueryBuilder<UserModel> queryEmail =
    QueryBuilder<UserModel>(UserModel.forQuery());

    queryEmail.whereEqualTo(UserModel.keyEmail, emailTextController.text);
    ParseResponse emailResponse = await queryEmail.query();

    if (phoneNumberResponse.success && phoneNumberResponse.results != null) {
      QuickHelp.hideLoadingDialog(context);
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: "responsive_signup_screen.used_phone_title".tr(),
        text: "responsive_signup_screen.used_phone_explain".tr(),
        confirmBtnColor: kTicketBlueColor,
        width: 350,
        borderRadius: 5,
      );
    } else if (emailResponse.success && emailResponse.results != null) {
      QuickHelp.hideLoadingDialog(context);
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: "responsive_signup_screen.used_email_title".tr(),
        text: "responsive_signup_screen.used_email_explain".tr(),
        confirmBtnColor: kTicketBlueColor,
        width: 350,
        borderRadius: 5,
      );
    } else {
      QuickHelp.hideLoadingDialog(context);
      _sendVerificationCode(false);
    }
  }

  /*// Login button clicked
  Future<void> _checkUserAccount() async {
    QuickHelp.showLoadingDialog(context);
    QueryBuilder<UserModel> queryBuilder =
    QueryBuilder<UserModel>(UserModel.forQuery());
    queryBuilder.whereEqualTo(UserModel.keyPhoneNumber, number.parseNumber());
    ParseResponse apiResponse = await queryBuilder.query();

    if (apiResponse.success && apiResponse.results != null) {
      UserModel userModel = apiResponse.results!.first;

      _processLogin(userModel.getUsername, userModel.getSecondaryPassword!);
    } else if (apiResponse.success && apiResponse.results == null) {
      signUpUser();
    } else if (apiResponse.error!.code == DatooException.objectNotFound) {
      signUpUser();
    } else {
      showError(apiResponse.error!.code);
    }
  }*/

  Widget emailTextField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextWithTap(
          "email_".tr(),
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
                controller: emailTextController,
                keyboardType: TextInputType.emailAddress,
                cursorColor: kGrayColor,
                autocorrect: false,
                decoration: InputDecoration(
                  errorMaxLines: 1,
                  errorStyle: TextStyle(fontSize: 10),
                  border: InputBorder.none,
                  hintText: "email_".tr(),
                  hintStyle: TextStyle(
                      color: kGrayColor.withOpacity(0.7), fontSize: 13),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    setState(
                      () {
                        emailErrorText =
                            "responsive_signup_screen.email_required".tr();
                      },
                    );
                    return "";
                  } else if (!QuickHelp.isValidEmail(
                      emailTextController.text)) {
                    setState(
                      () {
                        emailErrorText =
                            "responsive_signup_screen.invalid_email".tr();
                      },
                    );
                    return "";
                  } else {
                    setState(() {
                      emailErrorText = "";
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
          emailErrorText,
          color: kRedColor1,
          fontSize: 12,
          marginBottom: 25,
          marginTop: 5,
        ),
      ],
    );
  }

  Widget firstNameTextField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextWithTap(
          "responsive_signup_screen.first_name".tr(),
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
                controller: firstNameTextController,
                keyboardType: TextInputType.name,
                cursorColor: kGrayColor,
                autocorrect: false,
                decoration: InputDecoration(
                  errorMaxLines: 1,
                  errorStyle: TextStyle(fontSize: 10),
                  border: InputBorder.none,
                  hintText: "responsive_signup_screen.first_name".tr(),
                  hintStyle: TextStyle(
                      color: kGrayColor.withOpacity(0.7), fontSize: 13),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    setState(
                      () {
                        firstNameErrorText =
                            "responsive_signup_screen.first_name_required".tr();
                      },
                    );
                    return "";
                  } else {
                    setState(() {
                      firstNameErrorText = "";
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
          firstNameErrorText,
          color: kRedColor1,
          fontSize: 12,
          marginBottom: 25,
          marginTop: 5,
        ),
      ],
    );
  }

  Widget userNameTextField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
          width: 450,
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
                      color: kGrayColor.withOpacity(0.7), fontSize: 13),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    setState(
                      () {
                        usernameErrorText = "edit_data_screen.username_".tr();
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
      ],
    );
  }

  Widget lastNameTextField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextWithTap(
          "responsive_signup_screen.last_name".tr(),
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
                controller: lastNameTextController,
                keyboardType: TextInputType.name,
                cursorColor: kGrayColor,
                autocorrect: false,
                decoration: InputDecoration(
                  errorMaxLines: 1,
                  errorStyle: TextStyle(fontSize: 10),
                  border: InputBorder.none,
                  hintText: "responsive_signup_screen.last_name".tr(),
                  hintStyle: TextStyle(
                      color: kGrayColor.withOpacity(0.7), fontSize: 13),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    setState(
                      () {
                        lastNameErrorText =
                            "responsive_signup_screen.last_name_required".tr();
                      },
                    );
                    return "";
                  } else {
                    setState(() {
                      lastNameErrorText = "";
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
          lastNameErrorText,
          color: kRedColor1,
          fontSize: 12,
          marginBottom: 25,
          marginTop: 5,
        ),
      ],
    );
  }

  Widget passwordTextField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
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
                      color: kGrayColor.withOpacity(0.7), fontSize: 13),
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
                      passwordErrorText = "login_screen.password_required".tr();
                    });
                    return "";
                  } else if (!QuickHelp.isPasswordCompliant(
                      passwordTextController.text, 8)) {
                    setState(() {
                      passwordErrorText =
                          "login_screen.strong_password_required".tr();
                    });
                    return "";
                  } else if (confirmPasswordTextController.text !=
                      passwordTextController.text) {
                    setState(() {
                      passwordErrorText =
                          "responsive_signup_screen.password_not_much".tr();
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
        TextWithTap(
          passwordErrorText,
          color: kRedColor1,
          fontSize: 12,
          marginBottom: 25,
          marginTop: 5,
        ),
      ],
    );
  }

  Widget confirmPasswordTextField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextWithTap(
          "responsive_signup_screen.confirm_password".tr(),
          color: Colors.white,
          marginBottom: 8,
        ),
        ContainerCorner(
          borderWidth: 0,
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
                controller: confirmPasswordTextController,
                keyboardType: TextInputType.text,
                cursorColor: kGrayColor,
                autocorrect: false,
                obscureText: isConfirmPasswordHidden,
                decoration: InputDecoration(
                  errorMaxLines: 1,
                  errorStyle: TextStyle(fontSize: 0),
                  border: InputBorder.none,
                  hintText: "responsive_signup_screen.confirm_password".tr(),
                  hintStyle: TextStyle(
                      color: kGrayColor.withOpacity(0.7), fontSize: 13),
                  suffix: IconButton(
                    onPressed: () => toggleConfirmPasswordVisibility(),
                    icon: Icon(
                      isConfirmPasswordHidden
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.black,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    setState(() {
                      confirmPasswordErrorText =
                          "responsive_signup_screen.confirm_password_required"
                              .tr();
                    });
                    return "";
                  } else if (!QuickHelp.isPasswordCompliant(
                      passwordTextController.text, 8)) {
                    setState(() {
                      confirmPasswordErrorText =
                          "login_screen.strong_password_required".tr();
                    });
                    return "";
                  } else if (confirmPasswordTextController.text !=
                      passwordTextController.text) {
                    setState(() {
                      confirmPasswordErrorText =
                          "responsive_signup_screen.password_not_much".tr();
                    });
                    return "";
                  } else {
                    setState(() {
                      confirmPasswordErrorText = "";
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
          confirmPasswordErrorText,
          color: kRedColor1,
          fontSize: 12,
          marginBottom: 25,
          marginTop: 5,
        ),
      ],
    );
  }

  Widget phoneNumberTextField() {
    bool isDarkMode = QuickHelp.isDarkMode(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextWithTap(
          "responsive_signup_screen.phone_number".tr(),
          color: Colors.white,
          marginBottom: 8,
        ),
        PhoneNumberTextField(
          marginRight: 15,
          countrySearchHint: "auth.country_input_hint".tr(),
          hintText: "auth.enter_phone_num".tr(),
          marginBottom: 15,
          marginLeft: 15,
          controller: phoneNumberEditingController,
          inputBorder: InputBorder.none,
          radiusBottomRight: 10,
          radiusTopRight: 10,
          radiusTopLeft: 10,
          radiusBottomLeft: 10,
          borderWidth: isEmptyPhoneField ? 1 : 0,
          borderColor: isEmptyPhoneField ? kRedColor1 : kTransparentColor,
          errorTextField: TextStyle(fontSize: 0.0),
          validator: (text) {
            if(text!.isEmpty) {
              isEmptyPhoneField = true;
              setState(() {});
              return "";
            }
            isEmptyPhoneField = false;
            setState(() {});
            return null;
          },
          onChanged: (text) {
            if(text.isEmpty) {
              isEmptyPhoneField = true;
              setState(() {});
            }else{
              isEmptyPhoneField = false;
              setState(() {});
            }
          },
          backgroundColor: isDarkMode
              ? Colors.blueAccent.withOpacity(0.3)
              : Colors.blueAccent.withOpacity(0.05),
          onCountryChanged: (country) {
            countryIsoCode = country.isoCode;
            countryDialCode = country.dialCode;
            languagesIso =  country.languagesIso;
          },
        ),
        TextWithTap(
          phoneErrorText,
          color: kRedColor1,
          fontSize: 12,
          marginBottom: 25,
          marginTop: 5,
        ),
        /*ButtonWithIcon(
          mainAxisAlignment: MainAxisAlignment.center,
          height: 45,
          marginTop: 50,
          marginBottom: 10,
          borderRadius: 60,
          fontSize: 14,
          textColor: Colors.white,
          backgroundColor: validPhoneNumber ? Colors.blueAccent :  Colors.blueAccent.withOpacity(0.4),
          text: "next".tr(),
          fontWeight: FontWeight.normal,
          onTap: !validPhoneNumber ? null : () {
            FocusManager.instance.primaryFocus?.unfocus();

            if (position == _positionPhoneInput) {
              _sendVerificationCode(false);
            }
          },
        ),*/
      ],
    );
  }

Widget phoneCodeInput() {
    return ContainerCorner(
      width: 450,
      height: 450,
      child: Form(
        key: secondFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextWithTap(
              "auth.code_sent_to".tr(),
              marginTop: 20,
              marginBottom: 5,
              fontSize: 13,
              color: Colors.white,
              textAlign: TextAlign.center,
              fontWeight: FontWeight.normal,
              onTap: () => _showResend ? _sendVerificationCode(true) : null,
            ),
            TextWithTap(
              _phoneNumber,
              marginBottom: 5,
              fontSize: 15,
              color: Colors.white,
              textAlign: TextAlign.center,
              fontWeight: FontWeight.bold,
              marginRight: 10,
            ),
            TextWithTap(
              "auth.enter_code".tr(),
              marginTop: 20,
              marginBottom: 10,
              fontSize: 13,
              color: Colors.white,
              textAlign: TextAlign.center,
              fontWeight: FontWeight.normal,
              onTap: () => _showResend ? _sendVerificationCode(true) : null,
            ),
            ContainerCorner(
              borderWidth: 0,
              color: Colors.white,
              height: 50,
              borderRadius: 6,
              child: Padding(
                padding: const EdgeInsets.only(left: 15, right: 15),
                child: PinCodeTextField(
                  appContext: context,
                  length: Setup.verificationCodeDigits,
                  keyboardType: TextInputType.number,
                  obscureText: false,
                  animationType: AnimationType.fade,
                  autoFocus: true,
                  textStyle: TextStyle(color: Colors.black),
                  pinTheme: PinTheme(
                    borderWidth: 2.0,
                    shape: PinCodeFieldShape.underline,
                    borderRadius: BorderRadius.zero,
                    fieldHeight: 50,
                    fieldWidth: 45,
                    activeFillColor: Colors.transparent,
                    inactiveFillColor: Colors.transparent,
                    selectedFillColor: Colors.transparent,
                    activeColor: kBlueColor,
                    inactiveColor: kBlueColor,
                    selectedColor: kBlueColor,
                  ),
                  animationDuration: Duration(milliseconds: 300),
                  backgroundColor: Colors.transparent,
                  errorAnimationController: errorController,
                  enableActiveFill: true,
                  controller: pinCodeEditingController,
                  autovalidateMode: AutovalidateMode.always,
                  validator: (value) {
                    return null;
                  },
                  useHapticFeedback: true,
                  hapticFeedbackTypes: HapticFeedbackTypes.selection,
                  onChanged: (value) {
                    print(value);
                  },
                  onCompleted: (v) {
                    _pinCode = v;
                  },
                  beforeTextPaste: (text) {
                    print("Allowing to paste $text");
                    return true;
                  },
                ),
              ),
            ),
            ButtonWithIcon(
              mainAxisAlignment: MainAxisAlignment.center,
              height: 45,
              marginTop: 50,
              marginBottom: 10,
              borderRadius: 60,
              fontSize: 14,
              textColor: Colors.white,
              backgroundColor: Colors.blueAccent,
              text: "next".tr(),
              fontWeight: FontWeight.normal,
              onTap: () {
                if(secondFormKey.currentState!.validate()) {
                  verifyCode(_pinCode);
                }
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ContainerCorner(
                      marginTop: 3,
                      marginRight: 4,
                      color: Colors.transparent,
                      child: Visibility(
                        visible: !_showResend,
                        child: CountDownTimer(
                          countDownTimerStyle: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.normal,
                              fontSize: 14),
                          text: "auth.resend_in".tr(),
                          secondsRemaining: 30,
                          whenTimeExpires: () {
                            setState(() {
                              _showResend = true;
                            });
                          },
                        ),
                      ),
                    ),
                    Visibility(
                      visible: _showResend,
                      child: TextWithTap(
                        "auth.resend_now".tr(),
                        marginTop: 10,
                        marginBottom: 5,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.normal,
                        fontSize: 14,
                        onTap: () => _showResend ? _sendVerificationCode(true) : null,
                      ),
                    ),
                    TextWithTap(
                      "auth.edit_phone_number".tr(),
                      marginTop: 10,
                      marginBottom: 5,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.normal,
                      fontSize: 14,
                      onTap: () => previousPosition(),
                    ),
                    TextWithTap(
                      "auth.contact_support".tr(),
                      marginTop: 10,
                      marginBottom: 15,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      onTap: () => QuickHelp.goToWebPage(context,
                          pageType: QuickHelp.pageTypeHelpCenter),
                    ),
                  ],
                )
              ],),

          ],
        ),
      ),
    );
  }

  Future<void> verifyCode(String pinCode) async {
    _pinCode = pinCode;
    QuickHelp.showLoadingDialog(context);

    try {
      if (QuickHelp.isWebPlatform()) {

        userCredential =
        await _webConfirmationResult!.confirm(_pinCode);
        final User? user = userCredential.user;

        if (user != null) {
          nextPosition();
        }
      } else {
        final PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId,
          smsCode: _pinCode,
        );

        final User? user = (await _auth.signInWithCredential(credential)).user;

        if (user != null) {
          nextPosition();
        }
      }

      //return;
    } on FirebaseAuthException catch (e) {
      QuickHelp.hideLoadingDialog(context);

      if (e.code == "web-context-cancelled") {
        QuickHelp.showAppNotificationAdvanced(
            context: context,
            title: "error".tr(),
            message: "auth.canceled_phone".tr());
      } else if (e.code == "invalid-verification-code") {
        QuickHelp.showAppNotificationAdvanced(
            context: context,
            title: "error".tr(),
            message: "auth.invalid_code".tr());
      } else if (e.code == "network-request-failed") {
        QuickHelp.showAppNotificationAdvanced(
            context: context,
            title: "error".tr(),
            message: "no_internet_connection".tr());
      } else {
        QuickHelp.showAppNotificationAdvanced(
            context: context,
            title: "error".tr(),
            message: "try_again_later".tr());
      }
    }
  }

  verifyUsername() async{
    QuickHelp.showLoadingDialog(context);

    QueryBuilder queryBuilder = QueryBuilder(UserModel.forQuery());
    queryBuilder.whereEqualTo(UserModel.keyUsername, usernameTextController.text);
    ParseResponse response = await queryBuilder.query();

    if(response.success) {
      QuickHelp.hideLoadingDialog(context);
      if(response.results != null && response.results!.isNotEmpty) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: "responsive_signup_screen.used_username_title".tr(),
          text: "responsive_signup_screen.used_username_explain".tr(),
          confirmBtnColor: kTicketBlueColor,
          width: 350,
          borderRadius: 5,
        );
      }else{
        if(!isPasswordHidden) {
          createAccount();
        }
      }
    }else{
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

  createAccount() async{
    QuickHelp.showLoadingDialog(context);

    String username = usernameTextController.text;
    String password = passwordTextController.text;
    String email = emailTextController.text;
    String fistName = firstNameTextController.text;
    String lastName = lastNameTextController.text;

    UserModel newUser = UserModel(username, password, email);

    newUser.setFirstName = fistName;
    newUser.setLastName = lastName;
    newUser.setFullName = "$fistName $lastName";
    newUser.setGender = mySelectedGender!;
    newUser.setEmail = email;
    newUser.setCountryCode = countryIsoCode;
    newUser.setCountryDialCode = countryDialCode;
    newUser.setCountryLanguages = languagesIso;
    newUser.setPhoneNumber = phoneNumberEditingController.text;
    newUser.setPhoneNumberFull = countryIsoCode+phoneNumberEditingController.text;


    newUser.setUid = QuickHelp.generateUId();
    newUser.setSecondaryPassword = password;
    newUser.setUserRole = UserModel.roleUser;
    newUser.setPrefMinAge = Setup.minimumAgeToRegister;
    newUser.setPrefMaxAge = Setup.maximumAgeToRegister;
    newUser.setBio = Setup.bio;
    newUser.setHasPassword = true;
    newUser.setBirthday = QuickHelp.getDate(myBirthday);
    newUser.setAvatar = userAvatarPicture!;


    ParseACL acl = ParseACL();
    acl.setPublicReadAccess(allowed: true);
    acl.setPublicWriteAccess(allowed: false);
    newUser.setACL(acl); // ✅ Correct object
    ParseResponse response = await newUser.save();
    if(response.success) {
      QuickHelp.hideLoadingDialog(context);
      if(response.results != null && response.results!.isNotEmpty) {
        UserModel currentUser = response.results!.first;
        print("user $currentUser");
      }else{
        print("Error");
      }
    }else{
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
}

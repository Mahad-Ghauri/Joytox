// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:faker/faker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:trace/app/setup.dart';
import 'package:trace/auth/dispache_screen.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:trace/services/call_services.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SocialLogin {
  static Future<void> loginFacebook(BuildContext context) async {
    /*final result = await FacebookAuth.i.login(
      permissions: [
        'email',
        'public_profile',
        //'user_birthday',
        'user_gender',
      ],
    );

    if (result.status == LoginStatus.success) {
      QuickHelp.showLoadingDialog(context);

      final ParseResponse response = await ParseUser.loginWith(
          "facebook",
          facebook(
            result.accessToken!.tokenString,
            "result.accessToken!.userId",
            DateTime.now(),
          ));

      if (response.success) {
        UserModel? user = await ParseUser.currentUser();

        if (user != null) {
        ParseACL acl = ParseACL();
acl.setPublicReadAccess(allowed: true);
acl.setPublicWriteAccess(allowed: false);
user.setACL(acl);

user.set("isVisible", true);
user.set("status", "active");

await user.save();

          if (user.getUid == null) {
            getFbUserDetails(user, context);
          } else {
            goHome(context, user);
          }
        } else {
          QuickHelp.hideLoadingDialog(context);
          QuickHelp.showAppNotificationAdvanced(
              context: context, title: "auth.fb_login_error".tr());
        }
      } else {
        QuickHelp.hideLoadingDialog(context);
        QuickHelp.showAppNotificationAdvanced(
            context: context, title: "auth.fb_login_error".tr());
      }
    } else if (result.status == LoginStatus.cancelled) {
      QuickHelp.showAppNotificationAdvanced(
          context: context, title: "auth.fb_login_canceled".tr());
    } else if (result.status == LoginStatus.failed) {
      QuickHelp.showAppNotificationAdvanced(
          context: context, title: "auth.fb_login_error".tr());
    } else if (result.status == LoginStatus.operationInProgress) {
      print("facebook login in progress");
    }*/
  }

  static void getFbUserDetails(UserModel user, BuildContext context) async {
    dynamic _userData = [];
    /*final _userData = await FacebookAuth.i.getUserData(
      fields:
          "id,email,name,first_name,last_name,gender,birthday,picture.width(920).height(920),location",
    );*/

    String firstName = _userData['first_name'];
    String lastName = _userData['last_name'];

    String username =
        lastName.replaceAll(" ", "") + firstName.replaceAll(" ", "");

    user.setFullName = _userData['name'];
    user.setFacebookId = _userData['id'];
    user.setFirstName = firstName;
    user.setLastName = lastName;
    user.username = username + QuickHelp.generateShortUId().toString();

    if (_userData['email'] != null) {
      user.setEmail = _userData['email'];
      user.setEmailPublic = _userData['email'];
    }

    if (_userData['gender'] != null) {
      user.setGender = _userData['gender'];
    }

    if (_userData['location'] != null &&
        _userData['location']['name'] != null) {
      user.setLocation = _userData['location']['name'];
    }

    user.setUid = QuickHelp.generateUId();
    user.setPopularity = 0;
    user.setUserRole = UserModel.roleUser;
    user.setPrefMinAge = Setup.minimumAgeToRegister;
    user.setPrefMaxAge = Setup.maximumAgeToRegister;
    user.setLocationTypeNearBy = true;
    user.addCredit = Setup.welcomeCredit;
    user.setBio = Setup.bio;
    user.setHasPassword = false;

    if (_userData['birthday'] != null) {
      user.setBirthday = QuickHelp.getDateFromString(
          _userData['birthday'], QuickHelp.dateFormatFacebook);
    }

    ParseResponse response = await user.save();

    if (response.success) {
      getPhotoFromUrl(context, user, _userData['picture']['data']['url']);
    } else {
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showErrorResult(context, response.error!.code);
    }
  }

  static GoogleSignIn _googleSignIn =
      GoogleSignIn(scopes: ['email', 'profile']);

  static Future<void> googleLogin(
      BuildContext context, SharedPreferences preferences) async {
    print("=".padRight(50, "="));
    print("🚀 DEBUG: GOOGLE LOGIN METHOD CALLED!");
    print("🚀 DEBUG: Starting Google login process...");
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

      print(
          "📡 DEBUG: Attempting Parse Server login with Google credentials...");
      print("🔍 DEBUG: User ID: ${_googleSignIn.currentUser!.id}");

      final ParseResponse response = await ParseUser.loginWith(
          'google',
          google(authentication.accessToken!, _googleSignIn.currentUser!.id,
              authentication.idToken!));

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
          print("🔧 DEBUG: Setting up user ACL and properties...");
          ParseACL acl = ParseACL();
          acl.setPublicReadAccess(allowed: true);
          acl.setPublicWriteAccess(allowed: false);
          user.setACL(acl);

          user.set("isVisible", true);
          user.set("status", "active");

          print("💾 DEBUG: Saving user with ACL and status...");
          await user.save();

          print("🔍 DEBUG: Checking if user needs setup - UID: ${user.getUid}");
          if (user.getUid == null) {
            print("🆕 DEBUG: New user detected, setting up user details...");
            getGoogleUserDetails(
                context, user, account, authentication.idToken!, preferences);
          } else {
            print("🏠 DEBUG: Existing user, navigating to home...");
            goHome(context, user);
          }
        } else {
          print("❌ DEBUG: Current user is null after successful Parse login");
          QuickHelp.hideLoadingDialog(context);
          QuickHelp.showAppNotificationAdvanced(
              context: context, title: "auth.gg_login_error".tr());
        }
      } else {
        print("❌ DEBUG: Parse login failed, signing out from Google...");
        QuickHelp.hideLoadingDialog(context);
        QuickHelp.showAppNotificationAdvanced(
            context: context, title: "auth.gg_login_error".tr());
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

  static void getGoogleUserDetails(
      BuildContext context,
      UserModel user,
      GoogleSignInAccount googleUser,
      String idToken,
      SharedPreferences preferences) async {
    print("📝 DEBUG: Starting Google user details setup...");
    print("🔍 DEBUG: Google user email: ${googleUser.email}");
    print("🔍 DEBUG: Google user display name: ${googleUser.displayName}");

    Map<String, dynamic>? idMap = QuickHelp.getInfoFromToken(idToken);
    print("🎫 DEBUG: ID Token parsed - Map: $idMap");

    String firstName = idMap!["given_name"];
    String lastName = idMap["family_name"];
    print("👤 DEBUG: Extracted names - First: $firstName, Last: $lastName");

    String username =
        lastName.replaceAll(" ", "") + firstName.replaceAll(" ", "");
    print("🏷️ DEBUG: Generated username base: $username");

    user.setFullName = googleUser.displayName!;
    user.setGoogleId = googleUser.id;
    user.setFirstName = firstName;
    user.setLastName = lastName;
    user.username =
        username.toLowerCase().trim() + QuickHelp.generateShortUId().toString();
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
    //user.setBirthday = QuickHelp.getDateFromString(_userData!['birthday'], QuickHelp.dateFormatFacebook);

    print("💾 DEBUG: Saving user with complete details...");
    print("🔍 DEBUG: Final username: ${user.username}");
    print("🔍 DEBUG: Generated UID: ${user.getUid}");

    ParseResponse response = await user.save();

    if (response.success) {
      print("✅ DEBUG: User details saved successfully to Parse");
      print("🔍 DEBUG: User objectId: ${user.objectId}");

      try {
        print("🔥 DEBUG: Saving user to Firestore...");
        // ✅ Firestore me user save karo
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.objectId!)
            .set({
          'uid': user.getUid,
          'name': user.getFullName,
          'email': user.getEmail,
          'createdAt': DateTime.now(),
          'isVisible': true, // ✅ Required for discovery
          'role': 'user', // ✅ Required for role-based filters
          'gender': user.getGender, // Optional (if available)
          'avatar': user.getAvatar?.url, // Optional (if available)
        });
        print("✅ DEBUG: User saved to Firestore successfully");
      } catch (firestoreError) {
        print(
            "⚠️ DEBUG: Firestore save failed but continuing: $firestoreError");
      }

      print("📸 DEBUG: Getting photo from URL: ${googleUser.photoUrl}");
      // ✅ Parse ka image aur navigation continue karo
      getPhotoFromUrl(context, user, googleUser.photoUrl!);
    } else {
      print("❌ DEBUG: Failed to save user details to Parse");
      print(
          "❌ DEBUG: Parse error - Code: ${response.error?.code}, Message: ${response.error?.message}");
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showErrorResult(context, response.error!.code);
    }
  }

  static void loginApple(
      BuildContext context, SharedPreferences preferences) async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    QuickHelp.showLoadingDialog(context);

    final ParseResponse response = await ParseUser.loginWith(
        'apple', apple(credential.identityToken!, credential.userIdentifier!));

    if (response.success) {
      UserModel? user = await ParseUser.currentUser();

      if (user != null) {
        ParseACL acl = ParseACL();
        acl.setPublicReadAccess(allowed: true);
        acl.setPublicWriteAccess(allowed: false);
        user.setACL(acl);

        user.set("isVisible", true);
        user.set("status", "active");

        await user.save();

        if (user.getUid == null) {
          getAppleUserDetails(context, user, credential, preferences);
        } else {
          goHome(context, user);
        }
      } else {
        QuickHelp.hideLoadingDialog(context);
        QuickHelp.showAppNotificationAdvanced(
            context: context, title: "auth.apple_login_error".tr());
      }
    } else {
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
          context: context, title: "auth.apple_login_error".tr());
    }
  }

  static void getAppleUserDetails(
      BuildContext context,
      UserModel user,
      AuthorizationCredentialAppleID credentialAppleID,
      SharedPreferences preferences) async {
    var faker = Faker();

    String imageUrl = faker.image.image(
        width: 640,
        height: 640,
        keywords: ["people", "sexy", "models"],
        random: true);

    String? firstName = credentialAppleID.givenName != null
        ? credentialAppleID.givenName
        : ""; //faker.person.firstName();
    String? lastName = credentialAppleID.familyName != null
        ? credentialAppleID.familyName
        : "";
    String? fullName = '$firstName $lastName';

    String username =
        lastName!.replaceAll(" ", "") + firstName!.replaceAll(" ", "");

    /*if(credentialAppleID.givenName == null){
      user.setNeedsChangeName = true;
    }*/

    user.setFullName = fullName;
    user.setAppleId = credentialAppleID.userIdentifier!;
    user.setFirstName = firstName;
    user.setLastName = lastName;
    user.username =
        username.toLowerCase().trim() + QuickHelp.generateShortUId().toString();

    if (credentialAppleID.email != null) {
      user.setEmail = credentialAppleID.email!;
      user.setEmailPublic = credentialAppleID.email!;
    }
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
    //user.setBirthday = QuickHelp.getDateFromString(_userData!['birthday'], QuickHelp.dateFormatFacebook);
    ParseResponse response = await user.save();

    if (response.success) {
      getPhotoFromUrl(context, user, imageUrl);
    } else {
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showErrorResult(context, response.error!.code);
    }
  }

  static void getPhotoFromUrl(
      BuildContext context, UserModel user, String url) async {
    print("📸 DEBUG: Starting photo download from URL: $url");

    try {
      File avatar = await QuickHelp.downloadFile(url, "avatar.jpeg") as File;
      print("✅ DEBUG: Photo downloaded successfully");

      ParseFileBase parseFile;
      if (QuickHelp.isWebPlatform()) {
        print("🌐 DEBUG: Web platform detected, using ParseWebFile");
        //Seems weird, but this lets you get the data from the selected file as an Uint8List very easily.
        ParseWebFile file =
            ParseWebFile(null, name: "avatar.jpeg", url: avatar.path);
        await file.download();
        parseFile = ParseWebFile(file.file, name: file.name);
      } else {
        print("📱 DEBUG: Mobile platform detected, using ParseFile");
        parseFile = ParseFile(File(avatar.path));
      }

      user.setAvatar = parseFile;
      //user.setAvatar1 = parseFile;

      print("💾 DEBUG: Saving user with avatar...");
      final ParseResponse response = await user.save();

      if (response.success) {
        print("✅ DEBUG: User saved with avatar successfully");
        saveAgencyEarn(context, user);
        print("🏠 DEBUG: Navigating to home screen...");
        goHome(context, user);
      } else {
        print(
            "⚠️ DEBUG: Failed to save user with avatar, but continuing anyway");
        print(
            "❌ DEBUG: Avatar save error - Code: ${response.error?.code}, Message: ${response.error?.message}");
        saveAgencyEarn(context, user);
        goHome(context, user);
      }
    } catch (photoError) {
      print("💥 DEBUG: Error in photo download/save process: $photoError");
      print("🏠 DEBUG: Continuing to home without avatar...");
      saveAgencyEarn(context, user);
      goHome(context, user);
    }
  }

  static saveAgencyEarn(BuildContext context, UserModel user) {}

  static void goHome(
    BuildContext context,
    UserModel userModel,
  ) {
    QuickHelp.hideLoadingDialog(context);

    // Initialize ZegoUIKit call service for the logged-in user
    print(
        "📞 [CALL SERVICE] Initializing call service for user: ${userModel.getFullName}");
    try {
      onUserLogin(userModel);
      print("📞 [CALL SERVICE] ✅ Call service initialized successfully");
    } catch (e) {
      print("📞 [CALL SERVICE] ❌ Failed to initialize call service: $e");
    }

    QuickHelp.goToNavigatorScreen(
        context,
        DispacheScreen(
          currentUser: userModel,
        ),
        finish: true,
        back: false);
  }
}

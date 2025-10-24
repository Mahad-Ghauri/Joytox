import 'package:trace/models/UserModel.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import '../app/setup.dart';

/// on App's user login
void onUserLogin(UserModel currentUser) {
  print("📞 [CALL SERVICE] Initializing ZegoUIKit call service...");
  print("📞 [CALL SERVICE] App ID: ${Setup.zegoLiveStreamAppID}");
  print("📞 [CALL SERVICE] User ID: ${currentUser.objectId}");
  print("📞 [CALL SERVICE] User Name: ${currentUser.getFullName}");

  try {
    // Uninitialize first to ensure clean state
    try {
      ZegoUIKitPrebuiltCallInvitationService().uninit();
      print("📞 [CALL SERVICE] ⚠️ Previous call service uninitialized");
    } catch (e) {
      print(
          "📞 [CALL SERVICE] ⚠️ No previous call service to uninitialize: $e");
    }

    ZegoUIKitPrebuiltCallInvitationService().init(
      appID: Setup.zegoLiveStreamAppID,
      appSign: Setup.zegoLiveStreamAppSign,
      userID: currentUser.objectId!,
      userName: currentUser.getFullName!,
      plugins: [ZegoUIKitSignalingPlugin()],
    );
    print(
        "📞 [CALL SERVICE] ✅ ZegoUIKit call service initialized successfully");
  } catch (e) {
    print(
        "📞 [CALL SERVICE] ❌ Failed to initialize ZegoUIKit call service: $e");
    print("📞 [CALL SERVICE] ❌ Error details: ${e.toString()}");
    rethrow;
  }
}

/// on App's user logout
void onUserLogout() {
  ZegoUIKitPrebuiltCallInvitationService().uninit();
}

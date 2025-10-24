import 'package:trace/models/UserModel.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import '../app/setup.dart';
import '../home/streaming/zego_sdk_manager.dart';

/// on App's user login
Future<void> onUserLogin(UserModel currentUser) async {
  print("📞 [CALL SERVICE] Initializing ZegoUIKit call service...");
  print("📞 [CALL SERVICE] App ID: ${Setup.zegoLiveStreamAppID}");
  print("📞 [CALL SERVICE] User ID: ${currentUser.objectId}");
  print("📞 [CALL SERVICE] User Name: ${currentUser.getFullName}");

  try {
    // Initialize ZEGOSDKManager first (this is required for ZIM service)
    print("📞 [CALL SERVICE] Initializing ZEGOSDKManager...");
    await ZEGOSDKManager().init(
      Setup.zegoLiveStreamAppID,
      Setup.zegoLiveStreamAppSign,
    );
    print("📞 [CALL SERVICE] ✅ ZEGOSDKManager initialized");

    // Connect user to ZIM service (this is required for call invitations)
    print("📞 [CALL SERVICE] Connecting user to ZIM service...");
    await ZEGOSDKManager().connectUser(
      currentUser.objectId!,
      currentUser.getFullName!,
    );
    print("📞 [CALL SERVICE] ✅ User connected to ZIM service");

    // Initialize the call service with the same configuration as system calling UI
    print("📞 [CALL SERVICE] Initializing ZegoUIKit call service...");
    ZegoUIKitPrebuiltCallInvitationService().init(
      appID: Setup.zegoLiveStreamAppID,
      appSign: Setup.zegoLiveStreamAppSign,
      userID: currentUser.objectId!,
      userName: currentUser.getFullName!,
      plugins: [ZegoUIKitSignalingPlugin()],
    );

    print(
        "📞 [CALL SERVICE] ✅ ZegoUIKit call service initialized successfully");
    print("📞 [CALL SERVICE] 🔄 All services should be connected now");
  } catch (e) {
    print("📞 [CALL SERVICE] ❌ Failed to initialize call service: $e");
    print("📞 [CALL SERVICE] ❌ Error details: ${e.toString()}");
    rethrow;
  }
}

/// on App's user logout
Future<void> onUserLogout() async {
  try {
    print("📞 [CALL SERVICE] Disconnecting user from all services...");

    // Disconnect from ZEGOSDKManager
    await ZEGOSDKManager().disconnectUser();
    print("📞 [CALL SERVICE] ✅ User disconnected from ZEGOSDKManager");

    // Uninitialize call service
    ZegoUIKitPrebuiltCallInvitationService().uninit();
    print("📞 [CALL SERVICE] ✅ Call service uninitialized");
  } catch (e) {
    print("📞 [CALL SERVICE] ❌ Error during logout: $e");
  }
}

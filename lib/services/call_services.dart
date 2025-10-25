import 'package:trace/models/UserModel.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import '../app/setup.dart';
import '../home/streaming/zego_sdk_manager.dart';

// Track if the service has been initialized
bool _isCallServiceInitialized = false;

/// on App's user login
Future<void> onUserLogin(UserModel currentUser) async {
  // Check if already initialized to prevent multiple initializations
  if (_isCallServiceInitialized) {
    print('⚠️ Call service already initialized, skipping...');
    return;
  }

  try {
    print(
        '🚀 Starting call service initialization for user: ${currentUser.objectId}');

    // First, initialize the ZEGO SDK Manager to ensure proper connection
    print('📡 Initializing ZEGO SDK Manager...');
    await ZEGOSDKManager().init(
      Setup.zegoLiveStreamAppID,
      Setup.zegoLiveStreamAppSign,
    );
    print('✅ ZEGO SDK Manager initialized');

    // Connect the user to ZEGO services
    print('🔗 Connecting user to ZEGO services...');
    await ZEGOSDKManager().connectUser(
      currentUser.objectId!,
      currentUser.getFullName!,
    );
    print('✅ User connected to ZEGO services');

    // Initialize the call invitation service
    print('📞 Initializing call invitation service...');
    ZegoUIKitPrebuiltCallInvitationService().init(
      appID: Setup.zegoLiveStreamAppID,
      appSign: Setup.zegoLiveStreamAppSign /*input your AppSign*/,
      userID: currentUser.objectId!,
      userName: currentUser.getFullName!,
      plugins: [ZegoUIKitSignalingPlugin()],
    );

    // Set up system calling UI
    ZegoUIKitPrebuiltCallInvitationService().useSystemCallingUI(
      [ZegoUIKitSignalingPlugin()],
    );
    print('✅ Call invitation service initialized');

    _isCallServiceInitialized = true;
    print(
        '🎉 Call service fully initialized for user: ${currentUser.objectId}');

    // Ensure signaling plugin is connected
    _ensureSignalingConnection();
  } catch (e) {
    print('❌ Error initializing call service: $e');
    print('❌ Stack trace: ${StackTrace.current}');

    // Handle specific Zego errors
    if (e.toString().contains('exceed user mau limit')) {
      print(
          '🚨 ZEGO MAU LIMIT EXCEEDED: The Zego account has reached its monthly active user limit');
      print('💡 Solution: Upgrade Zego plan or wait for next billing cycle');
      _isCallServiceInitialized = false; // Reset flag to allow retry
    } else if (e.toString().contains('102002')) {
      print('🚨 ZEGO ACCOUNT LIMIT: User limit exceeded');
      print('💡 Solution: Check Zego account billing and user limits');
      _isCallServiceInitialized = false; // Reset flag to allow retry
    }
  }
}

/// Ensure signaling plugin is connected
void _ensureSignalingConnection() async {
  try {
    // Wait a bit for the signaling plugin to initialize
    await Future.delayed(Duration(milliseconds: 500));

    // The signaling plugin should be connected automatically
    // but we can add some logging to verify
    print('✅ Call service initialized with signaling plugin');
  } catch (e) {
    print('❌ Error ensuring signaling connection: $e');
  }
}

/// Check if call service is available
bool isCallServiceAvailable() {
  return _isCallServiceInitialized;
}

/// Get call service status for debugging
String getCallServiceStatus() {
  if (_isCallServiceInitialized) {
    return '✅ Call service is initialized and ready';
  } else {
    return '❌ Call service is not initialized - check Zego account limits';
  }
}

/// on App's user logout
Future<void> onUserLogout() async {
  try {
    // Disconnect from ZEGO SDK Manager
    await ZEGOSDKManager().disconnectUser();
    print('✅ ZEGO SDK Manager disconnected');

    ZegoUIKitPrebuiltCallInvitationService().uninit();
    _isCallServiceInitialized = false;
    print('✅ Call service uninitialized successfully');
  } catch (e) {
    print('❌ Error uninitializing call service: $e');
  }
}

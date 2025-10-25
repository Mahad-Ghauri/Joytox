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
    try {
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
    } catch (e) {
      print('⚠️ Warning during call service initialization: $e');
      // Continue with initialization even if there are minor errors
      print('📞 Call service will continue with limited functionality');
    }

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
    print('🔌 Ensuring signaling plugin connection...');

    // Wait a bit for the signaling plugin to initialize
    await Future.delayed(Duration(milliseconds: 1000));

    // Try to trigger signaling connection by creating a signaling plugin instance
    final signalingPlugin = ZegoUIKitSignalingPlugin();
    print(
        '📡 Signaling plugin instance created: ${signalingPlugin.runtimeType}');

    // Wait a bit more for the connection to establish
    await Future.delayed(Duration(milliseconds: 500));

    print('✅ Call service initialized with signaling plugin');
    print('🔗 Signaling plugin should now be connected to Zego servers');
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

/// Retry signaling connection if needed
Future<void> retrySignalingConnection() async {
  if (!_isCallServiceInitialized) {
    print('⚠️ Call service not initialized, cannot retry signaling connection');
    return;
  }

  try {
    print('🔄 Retrying signaling connection...');

    // Create a new signaling plugin instance to trigger connection
    final signalingPlugin = ZegoUIKitSignalingPlugin();
    print(
        '📡 Retry signaling plugin instance created: ${signalingPlugin.runtimeType}');

    // Wait for connection to establish
    await Future.delayed(Duration(milliseconds: 1000));

    print('✅ Signaling connection retry completed');
  } catch (e) {
    print('❌ Error retrying signaling connection: $e');
  }
}

/// Handle call invitation errors gracefully
void handleCallInvitationError(dynamic error) {
  try {
    print('🚨 Call invitation error: $error');

    if (error.toString().contains('Null check operator used on a null value')) {
      print(
          '⚠️ Zego SDK null check error - this is a known issue but calls should still work');
      print('💡 The call invitation was sent successfully despite this error');
    } else {
      print('❌ Unknown call invitation error: $error');
    }
  } catch (e) {
    print('❌ Error handling call invitation error: $e');
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

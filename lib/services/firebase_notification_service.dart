import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import '../helpers/quick_help.dart';
import '../helpers/send_notifications.dart';
import '../home/feed/comment_post_screen.dart';
import '../home/message/message_screen.dart';
import '../home/prebuild_live/multi_users_live_screen.dart';
import '../home/prebuild_live/prebuild_audio_room_screen.dart';
import '../home/prebuild_live/prebuild_live_screen.dart';
import '../home/profile/user_profile_screen.dart';
import '../home/reels/reels_single_screen.dart';
import '../models/LiveStreamingModel.dart';
import '../models/PostsModel.dart';
import '../models/UserModel.dart';

GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class FirebaseNotificationService {
  static FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static bool _isInitialized = false;
  static UserModel? _currentUser;
  static BuildContext? _context;

  /// Initialize Firebase Cloud Messaging
  static Future<bool> initialize(
      UserModel currentUser, BuildContext context) async {
    try {
      if (_isInitialized) {
        print('✅ Firebase notification service already initialized');
        return true;
      }

      _currentUser = currentUser;
      _context = context;

      print('🚀 Initializing Firebase Cloud Messaging...');

      // Request permission for notifications
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print(
          '📱 Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('❌ Notification permission denied');
        return false;
      }

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      print('🔑 FCM Token: $token');

      if (token != null) {
        // Update user model with FCM token
        if (token != currentUser.getPushId) {
          currentUser.setPushId = token;
          await currentUser.save();
          print('💾 Updated user FCM token: $token');
        }

        // Subscribe to topics if needed
        await _firebaseMessaging.subscribeToTopic('all_users');
        print('📢 Subscribed to general topic');
      }

      // Set up message handlers
      _setupMessageHandlers();

      _isInitialized = true;
      print('✅ Firebase notification service initialized successfully');
      return true;
    } catch (e) {
      print('❌ Error initializing Firebase notification service: $e');
      return false;
    }
  }

  /// Set up Firebase message handlers
  static void _setupMessageHandlers() {
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 Foreground message received: ${message.notification?.title}');
      _handleForegroundMessage(message);
    });

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print(
          '📱 Notification tapped (background): ${message.notification?.title}');
      _handleNotificationTap(message);
    });

    // Handle notification taps when app is terminated
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print(
            '📱 Notification tapped (terminated): ${message.notification?.title}');
        _handleNotificationTap(message);
      }
    });
  }

  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    // Show local notification or in-app notification
    if (message.notification != null) {
      // You can show a custom in-app notification here
      print(
          '📱 Showing foreground notification: ${message.notification!.title}');
    }
  }

  /// Handle notification taps
  static void _handleNotificationTap(RemoteMessage message) {
    if (_context == null || _currentUser == null) return;

    final data = message.data;
    _decodePushMessage(data, _context!);
  }

  /// Decode and handle push message data
  static Future<void> _decodePushMessage(
      Map<String, dynamic> message, BuildContext context) async {
    UserModel? mUser;
    PostsModel? mPost;
    LiveStreamingModel? mLive;

    print("Push Notification: $message");

    var type = message[SendNotifications.pushNotificationType];
    var senderId = message[SendNotifications.pushNotificationSender];
    var objectId = message[SendNotifications.pushNotificationObjectId];

    if (type == SendNotifications.typeChat) {
      QueryBuilder<UserModel> queryUser =
          QueryBuilder<UserModel>(UserModel.forQuery());
      queryUser.whereEqualTo(UserModel.keyObjectId, senderId);

      ParseResponse parseResponse = await queryUser.query();
      if (parseResponse.success && parseResponse.results != null) {
        mUser = parseResponse.results!.first! as UserModel;
      }

      if (_currentUser != null && mUser != null) {
        _gotToChat(_currentUser!, mUser, context);
      }
    } else if (type == SendNotifications.typeLive ||
        type == SendNotifications.typeLiveInvite) {
      QueryBuilder<LiveStreamingModel> queryPost =
          QueryBuilder<LiveStreamingModel>(LiveStreamingModel());
      queryPost.whereEqualTo(LiveStreamingModel.keyObjectId, objectId);
      queryPost.includeObject([LiveStreamingModel.keyAuthor]);

      ParseResponse parseResponse = await queryPost.query();
      if (parseResponse.success && parseResponse.results != null) {
        mLive = parseResponse.results!.first! as LiveStreamingModel;
      }

      if (_currentUser != null && mLive != null) {
        _goToLive(_currentUser!, mLive, context);
      }
    } else if (type == SendNotifications.typeFollow ||
        type == SendNotifications.typeMissedCall ||
        type == SendNotifications.typeProfileVisit ||
        type == SendNotifications.typeLike) {
      QuickHelp.showLoadingDialog(context);
      QueryBuilder<UserModel> queryUser =
          QueryBuilder<UserModel>(UserModel.forQuery());
      queryUser.whereEqualTo(UserModel.keyObjectId, senderId);
      queryUser.setLimit(1);

      ParseResponse parseResponse = await queryUser.query();
      if (parseResponse.success && parseResponse.results != null) {
        QuickHelp.hideLoadingDialog(context);
        mUser = parseResponse.results!.first! as UserModel;
      } else {
        QuickHelp.hideLoadingDialog(context);
      }

      if (_currentUser != null && mUser != null) {
        QuickHelp.goToNavigatorScreen(
          context,
          UserProfileScreen(
            currentUser: _currentUser,
            isFollowing: _currentUser!.getFollowing!.contains(mUser.objectId),
            mUser: mUser,
          ),
        );
      }
    } else if (type == SendNotifications.typeLike ||
        type == SendNotifications.typeComment ||
        type == SendNotifications.typeReplyComment) {
      QueryBuilder<PostsModel> queryPost =
          QueryBuilder<PostsModel>(PostsModel());
      queryPost.whereEqualTo(PostsModel.keyObjectId, objectId);
      queryPost.includeObject([PostsModel.keyAuthor]);

      ParseResponse parseResponse = await queryPost.query();
      if (parseResponse.success && parseResponse.results != null) {
        mPost = parseResponse.results!.first! as PostsModel;
      }

      if (_currentUser != null && mPost != null) {
        if (mPost.isVideo!) {
          _goToReels(_currentUser!, mPost, context);
        } else {
          _goToPost(_currentUser!, mPost, context);
        }
      }
    }
  }

  /// Navigation methods (same as OneSignal implementation)
  static void _gotToChat(
      UserModel currentUser, UserModel mUser, BuildContext context) {
    QuickHelp.goToNavigatorScreen(
      context,
      MessageScreen(
        currentUser: currentUser,
        mUser: mUser,
      ),
    );
  }

  static void _goToPost(
      UserModel currentUser, PostsModel mPost, BuildContext context) {
    QuickHelp.goToNavigatorScreen(
      context,
      CommentPostScreen(
        currentUser: currentUser,
        post: mPost,
      ),
    );
  }

  static void _goToReels(
      UserModel currentUser, PostsModel mPost, BuildContext context) {
    QuickHelp.goToNavigatorScreen(
      context,
      ReelsSingleScreen(
        currentUser: currentUser,
        post: mPost,
      ),
    );
  }

  static void _goToLive(UserModel currentUser, LiveStreamingModel liveStreaming,
      BuildContext context) {
    if (ZegoUIKitPrebuiltLiveStreamingController().minimize.isMinimizing) {
      return;
    }
    if (liveStreaming.getLiveType == LiveStreamingModel.liveVideo) {
      QuickHelp.goToNavigatorScreen(
        context,
        PreBuildLiveScreen(
          isHost: false,
          currentUser: currentUser,
          liveStreaming: liveStreaming,
          liveID: liveStreaming.getStreamingChannel!,
          localUserID: currentUser.objectId!,
        ),
      );
    } else if (liveStreaming.getLiveType == LiveStreamingModel.liveAudio) {
      QuickHelp.goToNavigatorScreen(
        context,
        PrebuildAudioRoomScreen(
          currentUser: currentUser,
          isHost: false,
          liveStreaming: liveStreaming,
        ),
      );
    } else if (liveStreaming.getLiveType == LiveStreamingModel.liveTypeParty) {
      QuickHelp.goToNavigatorScreen(
        context,
        MultiUsersLiveScreen(
          isHost: false,
          currentUser: currentUser,
          liveStreaming: liveStreaming,
          liveID: liveStreaming.getStreamingChannel!,
          localUserID: currentUser.objectId!,
        ),
      );
    }
  }

  /// Get FCM token
  static Future<String?> getFCMToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('📢 Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('📢 Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ Error unsubscribing from topic $topic: $e');
    }
  }

  /// Get notification status
  static Future<Map<String, dynamic>> getNotificationStatus() async {
    try {
      NotificationSettings settings =
          await _firebaseMessaging.getNotificationSettings();
      String? token = await _firebaseMessaging.getToken();

      return {
        'hasPermission':
            settings.authorizationStatus == AuthorizationStatus.authorized,
        'fcmToken': token,
        'isInitialized': _isInitialized,
        'authorizationStatus': settings.authorizationStatus.toString(),
      };
    } catch (e) {
      print('❌ Error getting notification status: $e');
      return {
        'hasPermission': false,
        'fcmToken': null,
        'isInitialized': false,
        'error': e.toString(),
      };
    }
  }

  /// Send a test notification
  static Future<void> sendTestNotification(
      UserModel fromUser, UserModel toUser) async {
    try {
      await SendNotifications.sendPush(
        fromUser,
        toUser,
        SendNotifications.typeChat,
        message: "Test notification from Joytox! 🎉",
        objectId: "test_${DateTime.now().millisecondsSinceEpoch}",
      );
      print('✅ Test notification sent');
    } catch (e) {
      print('❌ Error sending test notification: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📱 Background message received: ${message.notification?.title}');
  // Handle background message here if needed
}

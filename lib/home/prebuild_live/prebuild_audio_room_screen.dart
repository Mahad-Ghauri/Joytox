// Flutter imports:
// ignore_for_file: must_be_immutable, unnecessary_null_comparison, deprecated_member_use, unused_local_variable

import 'dart:async';
import 'package:zego_express_engine/zego_express_engine.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:fade_shimmer/fade_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:get/instance_manager.dart';
import 'package:lottie/lottie.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import '../../app/constants.dart';
import '../../app/setup.dart';
import '../../helpers/quick_actions.dart';
import '../../helpers/quick_cloud.dart';
import '../../helpers/quick_help.dart';
import '../../helpers/users_avatars_service.dart';
import '../../models/GiftsModel.dart';
import '../../models/GiftsSentModel.dart';
import '../../models/LeadersModel.dart';
import '../../models/LiveMessagesModel.dart';
import '../../models/LiveStreamingModel.dart';
import '../../models/LiveViewersModel.dart';
import '../../models/NotificationsModel.dart';
import '../../models/UserModel.dart';
import '../../ui/container_with_corner.dart';
import '../../ui/text_with_tap.dart';
import '../../utils/colors.dart';
import '../coins/coins_payment_widget.dart';
import '../controller/controller.dart';
import '../live_end/live_end_report_screen.dart';
import '../live_end/live_end_screen.dart';
import 'gift/components/svga_player_widget.dart';
import 'gift/gift_manager/gift_manager.dart';
import 'global_private_live_price_sheet.dart';
import 'global_user_profil_sheet.dart';
import 'widgets/seat_action_menu.dart';
import 'widgets/invite_friends_sheet.dart';
import 'widgets/seat_management_fab.dart';
import 'widgets/announcement_dialog.dart';
import 'widgets/announcement_overlay_widget.dart';
import 'room_theme_selector.dart';
import '../streaming/live_audio_room_manager.dart';
import '../streaming/pages/audio_room/audio_room_page.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';
import '../../services/seat_invitation_service.dart';
import '../../services/seat_invitation_listener.dart';

class PrebuildAudioRoomScreen extends StatefulWidget {
  UserModel? currentUser;
  bool? isHost;
  LiveStreamingModel? liveStreaming;

  PrebuildAudioRoomScreen({
    this.currentUser,
    this.isHost,
    this.liveStreaming,
    super.key,
  });

  @override
  State<PrebuildAudioRoomScreen> createState() =>
      _PrebuildAudioRoomScreenState();
}

class _PrebuildAudioRoomScreenState extends State<PrebuildAudioRoomScreen>
    with TickerProviderStateMixin {
  ZegoMediaPlayer? _musicPlayer;
  int _musicPlayerViewID = -1;
  bool _isMusicReady = false;
  late final VoidCallback _musicListener;
  final List<String> _playlistUrls = [
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    'https://www.soundjay.com/misc/sounds/bell-ringing-05.wav',
  ];
  int _currentMusicIndex = 0;
  int numberOfSeats = 0;
  AnimationController? _animationController;

  Subscription? subscription;
  Subscription? messagesSubscription;
  LiveQuery liveQuery = LiveQuery();
  var coHostsList = [];
  bool following = false;

  Controller showGiftSendersController = Get.put(Controller());
  final selectedGiftItemNotifier = ValueNotifier<GiftsModel?>(null);
  Timer? removeGiftTimer;
  Timer? announcementPollingTimer;

  // Seat invitation services
  final SeatInvitationService _seatInvitationService = SeatInvitationService();
  final SeatInvitationListener _seatInvitationListener =
      SeatInvitationListener();

  // Announcement state
  final List<AnnouncementData> _announcements = [];
  final ValueNotifier<List<AnnouncementData>> _announcementsNotifier =
      ValueNotifier([]);

  void startRemovingGifts() {
    removeGiftTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (showGiftSendersController.receivedGiftList.isNotEmpty) {
        showGiftSendersController.giftReceiverList.removeAt(0);
        showGiftSendersController.giftSenderList.removeAt(0);
        showGiftSendersController.receivedGiftList.removeAt(0);
      } else {
        timer.cancel();
        removeGiftTimer = null;
      }
    });
  }

  SharedPreferences? preference;

  initSharedPref() async {
    preference = await SharedPreferences.getInstance();
    Constants.queryParseConfig(preference!);
  }

  sendMessage(String msg) {
    ZegoUIKitPrebuiltLiveStreamingController().message.send(msg);
  }

  final Map<String, Widget> _avatarWidgetsCache = {};
  final AvatarService _avatarService = AvatarService();

  Widget _getOrCreateAvatarWidget(String userId, Size size) {
    if (_avatarWidgetsCache.containsKey(userId)) {
      return _avatarWidgetsCache[userId]!;
    }

    _avatarService.fetchUserAvatar(userId).then((avatarUrl) {
      if (avatarUrl != null && mounted) {
        Widget avatarWidget = QuickActions.photosWidget(
          avatarUrl,
          width: size.width,
          height: size.height,
          borderRadius: 200,
        );

        _avatarWidgetsCache[userId] = avatarWidget;

        if (mounted) setState(() {});
      }
    });

    return _avatarWidgetsCache[userId] = FadeShimmer(
      width: size.width,
      height: size.width,
      radius: 200,
      fadeTheme:
          QuickHelp.isDarkModeNoContext() ? FadeTheme.dark : FadeTheme.light,
    );
  }

  StreamSubscription? _themePropertySubscription; // from dart:async

  @override
  void initState() {
    super.initState();
    print("🚀🚀🚀 [ANNOUNCEMENT DEBUG] ===== INITSTATE CALLED =====");
    print("📢 [ANNOUNCEMENT DEBUG] initState() called");
    print(
        "📢 [ANNOUNCEMENT DEBUG] User role: ${widget.isHost! ? 'HOST' : 'AUDIENCE'}");
    print("📢 [ANNOUNCEMENT DEBUG] User ID: ${widget.currentUser?.objectId}");
    print(
        "📢 [ANNOUNCEMENT DEBUG] Room ID: ${widget.liveStreaming?.getStreamingChannel}");
    print("🚀🚀🚀 [ANNOUNCEMENT DEBUG] ===== STARTING SETUP =====");

    WakelockPlus.enable();
    initSharedPref();
    showGiftSendersController.isPrivateLive.value =
        widget.liveStreaming!.getPrivate!;
    Future.delayed(Duration(minutes: 2)).then((value) {
      widget.currentUser!.addUserPoints = widget.isHost! ? 350 : 200;
      widget.currentUser!.save();
    });
    following = widget.currentUser!.getFollowing!.contains(
      widget.liveStreaming!.getAuthorId!,
    );
    showGiftSendersController.diamondsCounter.value =
        widget.liveStreaming!.getDiamonds!.toString();
    showGiftSendersController.shareMediaFiles.value =
        widget.liveStreaming!.getSharingMedia!;

    // Initialize room theme
    showGiftSendersController.selectedRoomTheme.value =
        widget.liveStreaming!.getRoomTheme ?? 'theme_default';

    // Calculate number of seat rows based on user seats (excluding host)
    // The configuration number represents USER seats, host is always additional
    int userSeats = widget.liveStreaming!.getNumberOfChairs ?? 8;
    int totalChairs = userSeats + 1; // Add 1 for host seat

    if (userSeats == 8) {
      numberOfSeats =
          3; // 1 host row + 2 rows of 4 seats each = 1 + 8 = 9 total
    } else if (userSeats == 12) {
      numberOfSeats =
          4; // 1 host row + 3 rows of 4 seats each = 1 + 12 = 13 total
    } else if (userSeats == 16) {
      numberOfSeats =
          5; // 1 host row + 4 rows of 4 seats each = 1 + 16 = 17 total
    } else if (userSeats == 20) {
      numberOfSeats =
          5; // 1 host row + 4 rows of 5 seats each = 1 + 20 = 21 total
    } else if (userSeats == 24) {
      numberOfSeats =
          5; // 1 host row + 4 rows of 6 seats each = 1 + 24 = 25 total
    } else {
      // Default: calculate rows needed for user seats
      numberOfSeats =
          ((userSeats - 1) ~/ 4) + 2; // 1 host row + rows for user seats
    }

    // Initialize seat states for per-seat management
    // Total seats = total chairs (including host seat at index 0)
    print("🪑 INITIALIZING SEAT STATES for $totalChairs seats");
    showGiftSendersController.initializeSeatStates(totalChairs);

    // Validate initialization
    print("🪑 POST-INITIALIZATION VALIDATION:");
    showGiftSendersController.validateSeatStates();

    // Assign host to seat 0 if this user is the host
    if (widget.isHost!) {
      print("🪑 Assigning host to seat 0");
      showGiftSendersController.updateSeatState(
          0, 'userId', widget.currentUser!.objectId!);
      showGiftSendersController.updateSeatState(
          0, 'userName', widget.currentUser!.getFullName!);
      print("🪑 Host assigned to seat 0: ${widget.currentUser!.getFullName}");

      // Validate host assignment
      print("🪑 POST-HOST-ASSIGNMENT VALIDATION:");
      showGiftSendersController.validateSeatStates();
    }

    // Initialize seat invitation listener for real-time invitations
    print("🎧 Initializing seat invitation listener");
    _seatInvitationListener.initialize(
      currentUser: widget.currentUser!,
      context: context,
    );

    // Debug: Print seat configuration
    print("🪑 SEAT CONFIGURATION:");
    print("🪑 User seats requested: $userSeats");
    print("🪑 Total chairs (including host): $totalChairs");
    print("🪑 Number of seat rows: $numberOfSeats");
    print(
        "🪑 Seat 0 (Host): ${widget.isHost! ? 'OCCUPIED by ${widget.currentUser!.getFullName}' : 'RESERVED for host'}");
    print("🪑 Available seats for users: $userSeats (seats 1-$userSeats)");
    print("🪑 SEAT LAYOUT:");
    if (userSeats == 8) {
      print(
          "🪑 8 user seats: Row 0 (1 host) + Rows 1-2 (4 seats each) = 1 + 8 = 9 total");
    } else if (userSeats == 12) {
      print(
          "🪑 12 user seats: Row 0 (1 host) + Rows 1-3 (4 seats each) = 1 + 12 = 13 total");
    } else if (userSeats == 16) {
      print(
          "🪑 16 user seats: Row 0 (1 host) + Rows 1-4 (4 seats each) = 1 + 16 = 17 total");
    } else if (userSeats == 20) {
      print(
          "🪑 20 user seats: Row 0 (1 host) + Rows 1-4 (5 seats each) = 1 + 20 = 21 total");
    } else if (userSeats == 24) {
      print(
          "🪑 24 user seats: Row 0 (1 host) + Rows 1-4 (6 seats each) = 1 + 24 = 25 total");
    } else {
      print(
          "🪑 $userSeats user seats: Row 0 (1 host) + ${numberOfSeats - 1} rows = 1 + $userSeats = $totalChairs total");
    }

    // Calculate expected total seats for verification
    int expectedTotalSeats = 1; // Host seat
    if (userSeats == 8) {
      expectedTotalSeats += 8; // 2 rows × 4 seats
    } else if (userSeats == 12) {
      expectedTotalSeats += 12; // 3 rows × 4 seats
    } else if (userSeats == 16) {
      expectedTotalSeats += 16; // 4 rows × 4 seats
    } else if (userSeats == 20) {
      expectedTotalSeats += 20; // 4 rows × 5 seats
    } else if (userSeats == 24) {
      expectedTotalSeats += 24; // 4 rows × 6 seats
    }
    print("🪑 EXPECTED TOTAL SEATS: $expectedTotalSeats");
    print("🪑 ZEGO WILL GENERATE: $numberOfSeats rows");

    // Initialize announcement-related debug state
    print("📢 [ANNOUNCEMENT DEBUG] Initializing announcement state");
    print(
        "📢 [ANNOUNCEMENT DEBUG] Initial announcements count: ${_announcements.length}");

    if (widget.isHost!) {
      addOrUpdateLiveViewers();
      print(
          "📢 [ANNOUNCEMENT DEBUG] Host permissions granted - announcement features enabled");
      print(
          "📢 [ANNOUNCEMENT DEBUG] ✅ HOST UI CONFIG: [Announcement, MediaSharing] buttons");
      print(
          "📢 [ANNOUNCEMENT DEBUG] ❌ HOST UI CONFIG: Gift button REMOVED (hosts don't gift themselves)");
    } else {
      print(
          "📢 [ANNOUNCEMENT DEBUG] Audience mode - read-only announcement features");
      print(
          "📢 [ANNOUNCEMENT DEBUG] ✅ AUDIENCE UI CONFIG: [Announcement, Gift] buttons");
      print(
          "📢 [ANNOUNCEMENT DEBUG] ✅ SPEAKER UI CONFIG: [Announcement, Gift] buttons");
    }
    setupLiveGifts();
    setupStreamingLiveQuery();
    loadExistingAnnouncements(); // Load existing announcements first
    setupLiveMessagesQuery(); // Set up live messages query for announcements
    _startAnnouncementPolling(); // Add polling as backup for live query
    _initThemeSync(); // Theme synchronization using room properties
    _animationController = AnimationController.unbounded(vsync: this);
    _musicListener = _onMusicStateChanged;
    ZegoLiveAudioRoomManager().musicStateNoti.addListener(_musicListener);

    // Initialize seat invitation listener
    _seatInvitationListener.initialize(
      currentUser: widget.currentUser!,
      context: context,
    );

    // Check for pending invitations
    _seatInvitationListener.checkPendingInvitations();

    print("📢 [ANNOUNCEMENT DEBUG] initState() completed successfully");

    // Add a test announcement after a delay to verify the system works
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        _addTestAnnouncement();
      }
    });

    // Test Parse query functionality
    Future.delayed(Duration(seconds: 5), () {
      if (mounted) {
        _testParseQuery();
      }
    });

    // Force a manual poll after 8 seconds to test the system
    Future.delayed(Duration(seconds: 8), () {
      if (mounted) {
        print("📢 [ANNOUNCEMENT DEBUG] MANUAL TEST: Forcing announcement poll");
        _pollForNewAnnouncements();
      }
    });
  }

  void _addTestAnnouncement() {
    print("📢 [ANNOUNCEMENT DEBUG] Adding test announcement for debugging");
    final testAnnouncement = AnnouncementData(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Test Announcement',
      message: 'This is a test announcement to verify the system works',
      priority: 'Medium',
      duration: 10,
      authorName: 'System',
      timestamp: DateTime.now(),
    );

    if (mounted) {
      setState(() {
        _announcements.add(testAnnouncement);
        _announcementsNotifier.value = List.from(_announcements);
      });
      print("📢 [ANNOUNCEMENT DEBUG] Test announcement added successfully");
      print(
          "📢 [ANNOUNCEMENT DEBUG] Total announcements: ${_announcements.length}");
    }
  }

  void _testParseQuery() async {
    print("📢 [ANNOUNCEMENT DEBUG] Testing basic Parse query functionality");

    try {
      // Test basic LiveMessagesModel query
      QueryBuilder<LiveMessagesModel> testQuery =
          QueryBuilder<LiveMessagesModel>(
        LiveMessagesModel(),
      );

      testQuery.whereEqualTo(
        LiveMessagesModel.keyLiveStreamingId,
        widget.liveStreaming!.objectId,
      );

      // Don't filter by message type first, get all messages
      testQuery.setLimit(5);

      ParseResponse response = await testQuery.query();

      print(
          "📢 [ANNOUNCEMENT DEBUG] Test query - Success: ${response.success}");
      print(
          "📢 [ANNOUNCEMENT DEBUG] Test query - Results count: ${response.results?.length ?? 0}");
      print(
          "📢 [ANNOUNCEMENT DEBUG] Test query - Error: ${response.error?.message ?? 'None'}");

      if (response.success && response.results != null) {
        List<LiveMessagesModel> messages =
            response.results!.cast<LiveMessagesModel>();
        for (var message in messages) {
          print(
              "📢 [ANNOUNCEMENT DEBUG] Found message - Type: ${message.getMessageType}, Message: ${message.getMessage}");
        }

        // Now test with announcement filter
        QueryBuilder<LiveMessagesModel> announcementQuery =
            QueryBuilder<LiveMessagesModel>(
          LiveMessagesModel(),
        );

        announcementQuery.whereEqualTo(
          LiveMessagesModel.keyLiveStreamingId,
          widget.liveStreaming!.objectId,
        );
        announcementQuery.whereEqualTo(
          LiveMessagesModel.keyMessageType,
          LiveMessagesModel.messageTypeAnnouncement,
        );

        ParseResponse announcementResponse = await announcementQuery.query();
        print(
            "📢 [ANNOUNCEMENT DEBUG] Announcement query - Success: ${announcementResponse.success}");
        print(
            "📢 [ANNOUNCEMENT DEBUG] Announcement query - Results count: ${announcementResponse.results?.length ?? 0}");
      }
    } catch (e) {
      print("📢 [ANNOUNCEMENT DEBUG] Test query error: $e");
    }
  }

  void _startAnnouncementPolling() {
    print("📢 [ANNOUNCEMENT DEBUG] Starting announcement polling as backup");
    print(
        "📢 [ANNOUNCEMENT DEBUG] User role: ${widget.isHost! ? 'HOST' : 'AUDIENCE'}");
    print("📢 [ANNOUNCEMENT DEBUG] Room ID: ${widget.liveStreaming!.objectId}");

    // Do an immediate poll first
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        print("📢 [ANNOUNCEMENT DEBUG] Performing initial poll");
        _pollForNewAnnouncements();
      }
    });

    // Poll every 10 seconds for new announcements
    announcementPollingTimer =
        Timer.periodic(Duration(seconds: 10), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      print(
          "📢 [ANNOUNCEMENT DEBUG] Timer triggered - polling for announcements");
      await _pollForNewAnnouncements();
    });

    print("📢 [ANNOUNCEMENT DEBUG] Polling timer created successfully");
  }

  DateTime? _lastAnnouncementCheck;

  Future<void> _pollForNewAnnouncements() async {
    try {
      print("📢 [ANNOUNCEMENT DEBUG] 🔄 POLLING for new announcements");
      print(
          "📢 [ANNOUNCEMENT DEBUG] Room ID: ${widget.liveStreaming!.objectId}");
      print("📢 [ANNOUNCEMENT DEBUG] Last check: $_lastAnnouncementCheck");

      QueryBuilder<LiveMessagesModel> query = QueryBuilder<LiveMessagesModel>(
        LiveMessagesModel(),
      );

      query.whereEqualTo(
        LiveMessagesModel.keyLiveStreamingId,
        widget.liveStreaming!.objectId,
      );
      query.whereEqualTo(
        LiveMessagesModel.keyMessageType,
        LiveMessagesModel.messageTypeAnnouncement,
      );

      // Only get announcements newer than our last check
      if (_lastAnnouncementCheck != null) {
        query.whereGreaterThan(
            LiveMessagesModel.keyCreatedAt, _lastAnnouncementCheck!);
        print(
            "📢 [ANNOUNCEMENT DEBUG] Filtering for messages after: $_lastAnnouncementCheck");
      } else {
        print(
            "📢 [ANNOUNCEMENT DEBUG] No last check time - getting all announcements");
      }

      query.includeObject([LiveMessagesModel.keySenderAuthor]);
      query.orderByDescending(LiveMessagesModel.keyCreatedAt);
      query.setLimit(5);

      print("📢 [ANNOUNCEMENT DEBUG] Executing polling query...");
      ParseResponse response = await query.query();

      print("📢 [ANNOUNCEMENT DEBUG] Polling query response:");
      print("📢 [ANNOUNCEMENT DEBUG] - Success: ${response.success}");
      print(
          "📢 [ANNOUNCEMENT DEBUG] - Results count: ${response.results?.length ?? 0}");
      print(
          "📢 [ANNOUNCEMENT DEBUG] - Error: ${response.error?.message ?? 'None'}");

      if (response.success && response.results != null) {
        List<LiveMessagesModel> messages =
            response.results!.cast<LiveMessagesModel>();

        if (messages.isNotEmpty) {
          print(
              "📢 [ANNOUNCEMENT DEBUG] ✅ Found ${messages.length} new announcements via polling");

          List<AnnouncementData> newAnnouncements = [];

          for (LiveMessagesModel message in messages) {
            print(
                "📢 [ANNOUNCEMENT DEBUG] Processing message: ${message.objectId}");
            print(
                "📢 [ANNOUNCEMENT DEBUG] - Title: ${message.getAnnouncementTitle}");
            print("📢 [ANNOUNCEMENT DEBUG] - Message: ${message.getMessage}");
            print("📢 [ANNOUNCEMENT DEBUG] - Created: ${message.createdAt}");

            // Skip if we already have this announcement
            if (_announcements.any((a) => a.id == message.objectId)) {
              print(
                  "📢 [ANNOUNCEMENT DEBUG] - Skipping duplicate: ${message.objectId}");
              continue;
            }

            if (message.getAuthor != null) {
              await message.getAuthor!.fetch();
            }

            final announcementData = AnnouncementData.fromLiveMessage(message);
            newAnnouncements.add(announcementData);
            print(
                "📢 [ANNOUNCEMENT DEBUG] New announcement via polling: ${announcementData.title}");
          }

          if (mounted && newAnnouncements.isNotEmpty) {
            setState(() {
              _announcements.addAll(newAnnouncements);
              _announcementsNotifier.value = List.from(_announcements);
            });
            print(
                "📢 [ANNOUNCEMENT DEBUG] Added ${newAnnouncements.length} announcements via polling");
          }
        }
      }

      _lastAnnouncementCheck = DateTime.now();
    } catch (e) {
      print("📢 [ANNOUNCEMENT DEBUG] Error polling for announcements: $e");
    }
  }

  @override
  void dispose() {
    // Clean up seat invitation listener
    _seatInvitationListener.dispose();

    super.dispose();
    WakelockPlus.disable();
    showGiftSendersController.isPrivateLive.value = false;
    if (subscription != null) {
      liveQuery.client.unSubscribe(subscription!);
    }
    subscription = null;

    if (messagesSubscription != null) {
      LiveQuery().client.unSubscribe(messagesSubscription!);
    }
    messagesSubscription = null;

    // Cancel timers
    removeGiftTimer?.cancel();
    announcementPollingTimer?.cancel();
    announcementPollingTimer = null;

    _avatarWidgetsCache.clear();
    _destroyMusicPlayer();
    ZegoLiveAudioRoomManager().musicStateNoti.removeListener(_musicListener);
    _animationController?.dispose();
    _announcementsNotifier.dispose(); // Clean up announcement notifier

    // Optional: clear theme listener if you registered one
    _themePropertySubscription?.cancel();
  }

  var userAvatar;

  final isSeatClosedNotifier = ValueNotifier<bool>(false);
  final isRequestingNotifier = ValueNotifier<bool>(false);

  // Calculate seat index based on user ID and seat layout
  int _calculateSeatIndex(String? userId) {
    if (userId == null) return 1;

    // Host always gets seat index 0
    if (userId == widget.liveStreaming!.getAuthorId) {
      return 0;
    }

    // For other users, we need to determine their seat index
    final seatStates = showGiftSendersController.seatStates;
    for (int i = 1; i < seatStates.length; i++) {
      final seatState = seatStates[i];
      if (seatState != null && seatState['userId'] == userId) {
        return i;
      }
    }

    // If user not found in any seat, return -1
    return 1;
  }

  // Validate if a user can occupy a specific seat
  bool _canUserOccupySeat(int seatIndex, String userId) {
    // Seat 0 is reserved for host/admin only
    if (seatIndex == 0) {
      return userId == widget.liveStreaming!.getAuthorId;
    }

    // Other seats can be occupied by any user (subject to other restrictions)
    return true;
  }

  // Initialize and sync room background theme using Zego room properties
  Future<void> _initThemeSync() async {
    try {
      final roomID = widget.liveStreaming!.getStreamingChannel!;
      final ctrl = Get.find<Controller>();

      // 1) Fetch current room properties to get theme on join
      Map<String, String> props = {};
      try {
        final result = await ZegoUIKitSignalingPlugin().queryRoomProperties(
          roomID: roomID,
        );
        props = Map<String, String>.from(result.properties ?? {});
      } catch (e) {
        debugPrint('queryRoomProperties failed: $e');
      }
      final themeFromRoom = props['theme'];
      if (themeFromRoom != null && themeFromRoom.isNotEmpty) {
        ctrl.updateRoomTheme(themeFromRoom);
      } else {
        // Fallback to backend value; host seeds the room property
        final backendTheme =
            widget.liveStreaming!.getRoomTheme ?? 'theme_default';
        ctrl.updateRoomTheme(backendTheme);
        if (widget.isHost == true) {
          try {
            await ZegoUIKitSignalingPlugin().updateRoomProperties(
              roomID: roomID,
              roomProperties: {'theme': backendTheme},
              isForce: true,
            );
          } catch (e) {
            debugPrint('setRoomProperty (seed) failed: $e');
          }
        }
      }

      // 2) Subscribe to updates
      _themePropertySubscription = ZegoUIKitSignalingPlugin()
          .getRoomPropertiesUpdatedEventStream()
          .listen((event) {
        if (event.roomID != roomID) return;
        final setProps = event.setProperties as Map? ?? {};
        final newTheme = setProps['theme'];
        if (newTheme != null && newTheme is String && newTheme.isNotEmpty) {
          ctrl.updateRoomTheme(newTheme);
        }
      });
    } catch (e) {
      debugPrint('_initThemeSync error: $e');
    }
  }

  // Handle seat management actions with Zego API integration
  Future<void> _handleSeatAction(String action, int seatIndex) async {
    print("🎭 [SEAT ACTION] Handling action '$action' for seat $seatIndex");

    try {
      final controller = ZegoUIKitPrebuiltLiveAudioRoomController();
      final seatState = showGiftSendersController.getSeatState(seatIndex);

      if (seatState == null) {
        print("🎭 [SEAT ACTION] ❌ Seat state is null for seat $seatIndex");
        return;
      }

      String? userId = seatState['userId'] as String?;

      // If local state shows empty, resolve actual occupant from Zego and sync
      if (userId == null) {
        try {
          final seatUser = controller.seat.getUserByIndex(seatIndex);
          if (seatUser != null && seatUser.id.isNotEmpty) {
            userId = seatUser.id;
            // Sync local seat state for future actions
            showGiftSendersController.updateSeatState(
                seatIndex, 'userId', userId);
            showGiftSendersController.updateSeatState(
                seatIndex, 'userName', userId);
            print(
                "🎭 [SEAT ACTION] Resolved occupant via Zego: $userId for seat $seatIndex");
          }
        } catch (e) {
          print(
              "🎭 [SEAT ACTION] Failed to resolve seat occupant via Zego: $e");
        }
      }

      print(
          "🎭 [SEAT ACTION] Current user in seat $seatIndex: ${userId ?? 'empty'}");

      switch (action) {
        case 'lock':
          print("🔒 [SEAT ACTION] Locking seat $seatIndex");
          // Update local state
          showGiftSendersController.lockSeat(seatIndex);

          // Use Zego API to close the seat
          try {
            await controller.seat.host.close(targetIndex: seatIndex);
            print(
                "🔒 [SEAT ACTION] ✅ Successfully locked seat $seatIndex in Zego");
          } catch (e) {
            print("🔒 [SEAT ACTION] ❌ Failed to lock seat in Zego: $e");
          }
          break;

        case 'unlock':
          print("🔓 [SEAT ACTION] Unlocking seat $seatIndex");
          // Update local state
          showGiftSendersController.unlockSeat(seatIndex);

          // Use Zego API to open the seat
          try {
            await controller.seat.host.open(targetIndex: seatIndex);
            print(
                "🔓 [SEAT ACTION] ✅ Successfully unlocked seat $seatIndex in Zego");
          } catch (e) {
            print("🔓 [SEAT ACTION] ❌ Failed to unlock seat in Zego: $e");
          }
          break;

        case 'mute':
          if (userId != null) {
            print("🔇 [SEAT ACTION] Muting user $userId in seat $seatIndex");
            // Update local state
            showGiftSendersController.muteSeat(seatIndex);

            // Use Zego API to mute the user
            try {
              await controller.seat.host
                  .mute(targetIndex: seatIndex, muted: true);
              print(
                  "🔇 [SEAT ACTION] ✅ Successfully muted seat $seatIndex in Zego");
            } catch (e) {
              print("🔇 [SEAT ACTION] ❌ Failed to mute seat in Zego: $e");
              // Try alternative method with user ID
              try {
                await controller.seat.host.muteByUserID(userId, muted: true);
                print(
                    "🔇 [SEAT ACTION] ✅ Successfully muted user $userId via userID");
              } catch (e2) {
                print("🔇 [SEAT ACTION] ❌ Failed to mute user via userID: $e2");
              }
            }
          } else {
            print("🔇 [SEAT ACTION] ❌ Cannot mute empty seat");
          }
          break;

        case 'unmute':
          if (userId != null) {
            print("🔊 [SEAT ACTION] Unmuting user $userId in seat $seatIndex");
            // Update local state
            showGiftSendersController.unmuteSeat(seatIndex);

            // Use Zego API to unmute the user
            try {
              await controller.seat.host
                  .mute(targetIndex: seatIndex, muted: false);
              print(
                  "🔊 [SEAT ACTION] ✅ Successfully unmuted seat $seatIndex in Zego");
            } catch (e) {
              print("🔊 [SEAT ACTION] ❌ Failed to unmute seat in Zego: $e");
              // Try alternative method with user ID
              try {
                await controller.seat.host.muteByUserID(userId, muted: false);
                print(
                    "🔊 [SEAT ACTION] ✅ Successfully unmuted user $userId via userID");
              } catch (e2) {
                print(
                    "🔊 [SEAT ACTION] ❌ Failed to unmute user via userID: $e2");
              }
            }
          } else {
            print("🔊 [SEAT ACTION] ❌ Cannot unmute empty seat");
          }
          break;

        case 'remove':
          if (userId != null) {
            print(
                "👤 [SEAT ACTION] Removing user $userId from seat $seatIndex");

            // Use Zego API to remove the speaker
            try {
              await controller.seat.host.removeSpeaker(userId);
              print(
                  "👤 [SEAT ACTION] ✅ Successfully removed user $userId from Zego");

              // Update local state after successful removal
              showGiftSendersController.updateSeatState(
                  seatIndex, 'userId', null);
              showGiftSendersController.updateSeatState(
                  seatIndex, 'userName', null);
              showGiftSendersController.updateSeatState(
                  seatIndex, 'isMuted', false);
            } catch (e) {
              print("👤 [SEAT ACTION] ❌ Failed to remove user from Zego: $e");
            }
          } else {
            print("👤 [SEAT ACTION] ❌ Cannot remove user from empty seat");
          }
          break;

        case 'invite':
          print("📧 [SEAT ACTION] Opening invite dialog for seat $seatIndex");
          _showInviteFriendsDialog(seatIndex);
          break;

        default:
          print("🎭 [SEAT ACTION] ❌ Unknown action: $action");
      }

      // Show success feedback to user
      if (mounted) {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          user: widget.currentUser,
          title: "Seat Action",
          message: "Action '$action' completed for seat ${seatIndex + 1}",
          isError: false,
        );
      }
    } catch (e) {
      print("🎭 [SEAT ACTION] ❌ Error handling seat action: $e");

      // Show error feedback to user
      if (mounted) {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          user: widget.currentUser,
          title: "Seat Action Failed",
          message: "Failed to $action seat ${seatIndex + 1}: ${e.toString()}",
          isError: true,
        );
      }
    }
  }

  // Show invite friends dialog for a specific seat
  void _showInviteFriendsDialog(int seatIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InviteFriendsSheet(
        currentUser: widget.currentUser!,
        seatIndex: seatIndex,
        onUserSelected: (user, seatIndex) async {
          print(
              "📧 [INVITE] Inviting user ${user.getFullName} to seat $seatIndex");

          // Send seat invitation using the service
          final invitation = await _seatInvitationService.sendSeatInvitation(
            inviter: widget.currentUser!,
            invitee: user,
            liveStreaming: widget.liveStreaming!,
            seatIndex: seatIndex,
            customMessage: "You've been invited to join seat ${seatIndex + 1}!",
          );

          if (invitation != null) {
            print("📧 [INVITE] ✅ Invitation sent successfully");

            // Also send Zego invitation for real-time notification
            try {
              final controller = ZegoUIKitPrebuiltLiveAudioRoomController();
              await controller.seat.host.inviteToTake(user.objectId!);
              print("📧 [INVITE] ✅ Zego invitation sent successfully");
            } catch (e) {
              print("📧 [INVITE] ❌ Failed to send Zego invitation: $e");
            }

            if (mounted) {
              QuickHelp.showAppNotificationAdvanced(
                context: context,
                user: widget.currentUser,
                title: "Invitation Sent",
                message: "Invited ${user.getFullName} to seat ${seatIndex + 1}",
                isError: false,
              );
            }
          } else {
            print("📧 [INVITE] ❌ Failed to send invitation");
            if (mounted) {
              QuickHelp.showAppNotificationAdvanced(
                context: context,
                user: widget.currentUser,
                title: "Invitation Failed",
                message: "Failed to invite ${user.getFullName}",
                isError: true,
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AvatarService avatarService = AvatarService();
    var size = MediaQuery.of(context).size;

    // Define buttons inline to avoid any class definition issues
    final announcementButton = ElevatedButton(
      style: ElevatedButton.styleFrom(
        fixedSize: const Size(40, 40),
        shape: const CircleBorder(),
        backgroundColor: Colors.black26,
      ),
      onPressed: () {
        print("📢 Announcement button pressed! isHost: ${widget.isHost}");
        if (widget.isHost!) {
          print("📢 Host confirmed - showing announcement dialog");
          _showAnnouncementDialog();
        } else {
          print("📢 Audience - showing announcement history");
          _showAnnouncementHistory();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: Icon(Icons.campaign, color: kPrimaryColor, size: 24),
      ),
    );

    final giftButton = ElevatedButton(
      style: ElevatedButton.styleFrom(
        fixedSize: const Size(40, 40),
        shape: const CircleBorder(),
        backgroundColor: Colors.black26,
      ),
      onPressed: () {
        print("🎁 Gift button pressed!");
        if (coHostsList.isNotEmpty) {
          openUserToReceiveCoins();
          return;
        }
        CoinsFlowPayment(
          context: context,
          currentUser: widget.currentUser!,
          onCoinsPurchased: (coins) {
            print(
              "onCoinsPurchased: $coins new: ${widget.currentUser!.getCredits}",
            );
          },
          onGiftSelected: (gift) {
            print("onGiftSelected called ${gift.getCoins}");
            sendGift(gift, widget.liveStreaming!.getAuthor!);

            QuickHelp.showAppNotificationAdvanced(
              context: context,
              user: widget.currentUser,
              title: "live_streaming.gift_sent_title".tr(),
              message: "live_streaming.gift_sent_explain".tr(
                namedArgs: {
                  "name": widget.liveStreaming!.getAuthor!.getFirstName!,
                },
              ),
              isError: false,
            );
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: Lottie.asset("assets/lotties/ic_gift.json", height: 29),
      ),
    );

    final themeButton = ElevatedButton(
      style: ElevatedButton.styleFrom(
        fixedSize: const Size(40, 40),
        shape: const CircleBorder(),
        backgroundColor: Colors.black26,
      ),
      onPressed: () {
        print("🎨 Theme button pressed!");
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) {
            return RoomThemeSelector(
              currentUser: widget.currentUser!,
              liveStreaming: widget.liveStreaming!,
              onThemeSelected: (theme) {
                // Update local controller immediately; remote users will update via room property
                Get.find<Controller>().updateRoomTheme(theme);
              },
            );
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: Icon(Icons.palette, color: kPrimaryColor, size: 24),
      ),
    );

    final Controller controller = Get.find<Controller>();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image reacting to theme changes
          Obx(() {
            final bgPath =
                controller.getThemePath(controller.selectedRoomTheme.value);
            return Image.asset(
              bgPath,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(color: Colors.black),
            );
          }),

          ZegoUIKitPrebuiltLiveAudioRoom(
            appID: Setup.zegoLiveStreamAppID,
            appSign: Setup.zegoLiveStreamAppSign,
            userID: widget.currentUser!.objectId!,
            userName: widget.currentUser!.getFullName!,
            roomID: widget.liveStreaming!.getStreamingChannel!,
            events: ZegoUIKitPrebuiltLiveAudioRoomEvents(
              onLeaveConfirmation: (event, defaultAction) async {
                if (widget.isHost!) {
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        backgroundColor: QuickHelp.isDarkMode(context)
                            ? kContentColorLightTheme
                            : kContentColorDarkTheme,
                        title: TextWithTap(
                          "account_settings.logout_user_sure".tr(),
                          fontWeight: FontWeight.bold,
                        ),
                        content: Text('live_streaming.finish_live_ask'.tr()),
                        actions: [
                          TextWithTap(
                            "cancel".tr(),
                            fontWeight: FontWeight.bold,
                            marginRight: 10,
                            marginLeft: 10,
                            marginBottom: 10,
                            onTap: () => Navigator.of(context).pop(false),
                          ),
                          TextWithTap(
                            "confirm_".tr(),
                            fontWeight: FontWeight.bold,
                            marginRight: 10,
                            marginLeft: 10,
                            marginBottom: 10,
                            onTap: () async {
                              if (widget.isHost!) {
                                QuickHelp.showLoadingDialog(context);
                                onViewerLeave();
                                widget.liveStreaming!.setStreaming = false;
                                ParseResponse response =
                                    await widget.liveStreaming!.save();
                                if (response.success &&
                                    response.result != null) {
                                  QuickHelp.hideLoadingDialog(context);
                                  QuickHelp.goToNavigatorScreen(
                                    context,
                                    LiveEndReportScreen(
                                      currentUser: widget.currentUser,
                                      live: widget.liveStreaming,
                                    ),
                                  );
                                  //onViewerLeave();
                                } else {
                                  QuickHelp.hideLoadingDialog(context);
                                  QuickHelp.showAppNotificationAdvanced(
                                    title: "try_again_later".tr(),
                                    message: "not_connected".tr(),
                                    context: context,
                                  );
                                }
                              } else {
                                QuickHelp.goBackToPreviousPage(context);
                                QuickHelp.goBackToPreviousPage(context);
                              }
                            },
                          ),
                        ],
                      );
                    },
                  );
                } else {
                  return defaultAction.call();
                }
              },
              user: ZegoLiveAudioRoomUserEvents(
                onEnter: (user) {
                  if (user.id != widget.liveStreaming!.getAuthorId) {
                    addOrUpdateLiveViewers();
                    sendMessage("${user.name} ${"has_entered_the_room".tr()}");
                  }
                },
                onLeave: (user) {
                  sendMessage("${user.name} ${"has_left_the_room".tr()}");
                  onViewerLeave();
                },
              ),
              memberList: ZegoLiveAudioRoomMemberListEvents(
                onClicked: (user) {
                  if (user.id != widget.currentUser!.objectId) {
                    QuickHelp.hideLoadingDialog(context);
                    showUserProfileBottomSheet(
                      currentUser: widget.currentUser!,
                      userId: user.id,
                      context: context,
                    );
                  }
                },
              ),
              inRoomMessage: ZegoLiveAudioRoomInRoomMessageEvents(
                onClicked: (message) {
                  if (message.user.id != widget.currentUser!.objectId) {
                    showUserProfileBottomSheet(
                      currentUser: widget.currentUser!,
                      userId: message.user.id,
                      context: context,
                    );
                  }
                },
              ),
              /*onEnded: (event, defaultAction,) {
              QuickHelp.goToNavigatorScreen(
                  context,
                  LiveEndScreen(
                    currentUser: widget.currentUser,
                    preferences: widget.preferences,
                    liveAuthor: widget.liveStreaming!.getAuthor,
                  ),
              );
            }*/
            ),
            config: widget.isHost!
                ? (ZegoUIKitPrebuiltLiveAudioRoomConfig.host()
                  ..confirmDialogInfo = ZegoLiveAudioRoomDialogInfo(
                    title: "account_settings.logout_user_sure".tr(),
                    message: 'live_streaming.finish_live_ask'.tr(),
                    cancelButtonName: "cancel".tr(),
                    confirmButtonName: "confirm_".tr(),
                  )
                  ..bottomMenuBar.hostExtendButtons = [
                    announcementButton, // Host can create announcements
                    themeButton, // Host can change room theme
                    // Gift button removed from host - hosts don't send gifts to themselves
                    Obx(() {
                      print(
                          "📢 [ANNOUNCEMENT DEBUG] Host media sharing button rendered");
                      return ContainerCorner(
                        color: Colors.white,
                        borderRadius: 50,
                        height: 38,
                        width: 38,
                        onTap: () {
                          print(
                              "📢 [ANNOUNCEMENT DEBUG] Host media sharing button pressed");
                          toggleSharingMedia();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: SvgPicture.asset(
                            showGiftSendersController.shareMediaFiles.value
                                ? "assets/svg/stop_sharing_media.svg"
                                : "assets/svg/start_sharing_media.svg",
                          ),
                        ),
                      );
                    }),
                  ])
                : (ZegoUIKitPrebuiltLiveAudioRoomConfig.audience()
                  ..bottomMenuBar.audienceExtendButtons = [
                    announcementButton, // Audience can view announcements
                    giftButton,
                    // Audience can send gifts
                  ]
                  ..bottomMenuBar.speakerExtendButtons = [
                    announcementButton, // Speakers can view announcements
                    giftButton,
                    // Speakers can send gifts
                  ])
              // Continue with your other config options...
              ..seat.avatarBuilder = (
                BuildContext context,
                Size size,
                ZegoUIKitUser? user,
                Map extraInfo,
              ) {
                print(
                  "🪑 Seat avatar builder called for user: ${user?.id ?? 'empty'}, extraInfo: $extraInfo",
                );

                // Get seat index from extraInfo (Zego uses 'index' key)
                int seatIndex = -1;
                final rawIndex = extraInfo['index'];
                if (rawIndex is int) {
                  seatIndex = rawIndex;
                } else if (rawIndex is double) {
                  seatIndex = rawIndex.toInt();
                } else if (rawIndex is String) {
                  seatIndex = int.tryParse(rawIndex) ?? -1;
                }
                print(
                    "🪑 Avatar builder - seat index: $seatIndex for user: ${user?.id ?? 'empty'}");

                // If index missing/invalid, assign deterministically without using 0 for non-hosts
                if (seatIndex < 0) {
                  if (user != null &&
                      user.id == widget.liveStreaming!.getAuthorId) {
                    // Host always seat 0
                    seatIndex = 0;
                  } else {
                    // Non-host -> first empty seat from 1
                    try {
                      final controller =
                          ZegoUIKitPrebuiltLiveAudioRoomController();
                      final int userSeats =
                          widget.liveStreaming!.getNumberOfChairs ?? 8;
                      final int totalSeats = 1 + userSeats; // include host
                      for (int i = 1; i < totalSeats; i++) {
                        final seatUser = controller.seat.getUserByIndex(i);
                        if (seatUser == null) {
                          seatIndex = i;
                          break;
                        }
                      }
                      if (seatIndex < 0) seatIndex = 1; // fallback
                    } catch (e) {
                      debugPrint(
                          'avatarBuilder: resolve first empty seat failed: $e');
                      seatIndex = 1; // safe fallback
                    }
                  }
                  print(
                      "🪑 Resolved seat index for user: ${user?.id ?? 'empty'} => $seatIndex");
                }

                // Sync local seat state for UI consistency
                if (user != null && seatIndex >= 0) {
                  if (seatIndex == 0 &&
                      user.id != widget.liveStreaming!.getAuthorId) {
                    print(
                        "⚠️ WARNING: Non-host user ${user.id} in host seat 0!");
                  }
                  final state =
                      showGiftSendersController.getSeatState(seatIndex);
                  if (state == null || state['userId'] != user.id) {
                    showGiftSendersController.updateSeatState(
                        seatIndex, 'userId', user.id);
                    showGiftSendersController.updateSeatState(
                        seatIndex, 'userName', user.id);
                  }
                }

                Widget avatarWidget;
                if (user == null) {
                  // Empty seat
                  print("🪑 Empty seat at index: $seatIndex");

                  // Ensure local state is cleared for empty seats
                  final state =
                      showGiftSendersController.getSeatState(seatIndex);
                  if (state != null && state['userId'] != null) {
                    showGiftSendersController.updateSeatState(
                        seatIndex, 'userId', null);
                    showGiftSendersController.updateSeatState(
                        seatIndex, 'userName', null);
                  }

                  avatarWidget = Container(
                    width: size.width,
                    height: size.height,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.person_add,
                      color: Colors.grey,
                      size: size.width * 0.4,
                    ),
                  );
                } else {
                  // User in seat - show avatar
                  print("🪑 User ${user.id} in seat $seatIndex");

                  // Verify host is in seat 0
                  if (seatIndex == 0 &&
                      user.id != widget.liveStreaming!.getAuthorId) {
                    print(
                        "⚠️ WARNING: Non-host user ${user.id} in host seat 0!");
                  }

                  // Sync occupant in local state if missing/wrong
                  final state =
                      showGiftSendersController.getSeatState(seatIndex);
                  if (state == null || state['userId'] != user.id) {
                    showGiftSendersController.updateSeatState(
                        seatIndex, 'userId', user.id);
                    showGiftSendersController.updateSeatState(
                        seatIndex, 'userName', user.id);
                  }

                  avatarWidget = FutureBuilder<String?>(
                    future: avatarService.fetchUserAvatar(user.id),
                    builder: (context, snapshot) {
                      return _getOrCreateAvatarWidget(user.id, size);
                    },
                  );
                }

                return avatarWidget;
              }
              ..seat.foregroundBuilder = (
                BuildContext context,
                Size size,
                ZegoUIKitUser? user,
                Map extraInfo,
              ) {
                print(
                  "🎯 Seat foreground builder called for user: ${user?.id ?? 'empty'}, extraInfo: $extraInfo",
                );

                // Get seat index from extraInfo (Zego uses 'index' key)
                int seatIndex = -1;
                final rawIndex = extraInfo['index'];
                if (rawIndex is int) {
                  seatIndex = rawIndex;
                } else if (rawIndex is double) {
                  seatIndex = rawIndex.toInt();
                } else if (rawIndex is String) {
                  seatIndex = int.tryParse(rawIndex) ?? -1;
                }
                print(
                    "📍 Foreground builder - seat index: $seatIndex for user: ${user?.id ?? 'empty'}");

                // If index invalid, try to resolve via controller for correct seat overlay
                if (seatIndex < 0 && user != null) {
                  try {
                    final controller =
                        ZegoUIKitPrebuiltLiveAudioRoomController();
                    final int userSeats =
                        widget.liveStreaming!.getNumberOfChairs ?? 8;
                    final int totalSeats = 1 + userSeats;
                    for (int i = 1; i < totalSeats; i++) {
                      final seatUser = controller.seat.getUserByIndex(i);
                      if (seatUser?.id == user.id) {
                        seatIndex = i;
                        break;
                      }
                    }
                  } catch (e) {
                    debugPrint(
                        'foregroundBuilder: resolve seat by user failed: $e');
                  }
                }

                // Validate seat index
                if (seatIndex < 0) {
                  print(
                      "⚠️ Invalid seat index in foreground builder: $seatIndex");
                  return const SizedBox.shrink();
                }

                // Host seat (index 0) should have no foreground/options
                if (seatIndex == 0) {
                  print("🚫 Host seat (index 0) - no foreground options");
                  return const SizedBox.shrink();
                }

                // Only show clickable overlay for hosts on non-host seats
                if (!widget.isHost!) return const SizedBox.shrink();

                // Return invisible clickable overlay for seat management
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    print(
                      "🔥 SEAT FOREGROUND CLICKED! User: ${user?.id ?? 'empty'}",
                    );
                    print("🎯 Using seat index: $seatIndex");

                    showSeatActionMenu(
                      context: context,
                      currentUser: widget.currentUser!,
                      seatIndex: seatIndex,
                      onActionSelected: _handleSeatAction,
                    );
                  },
                  child: const SizedBox.expand(),
                );
              }
              ..seat.layout.rowSpacing = 10
              ..seat.layout.rowConfigs = List.generate(numberOfSeats, (
                index,
              ) {
                print(
                    "🪑 Generating row $index for ${widget.liveStreaming!.getNumberOfChairs} user seats");
                if (index == 0) {
                  print("🪑 Row $index: Host row with 1 seat");
                  return ZegoLiveAudioRoomLayoutRowConfig(
                    count: 1,
                    alignment: ZegoLiveAudioRoomLayoutAlignment.center,
                  );
                }

                if (widget.liveStreaming!.getNumberOfChairs == 8) {
                  return ZegoLiveAudioRoomLayoutRowConfig(
                    count: 4,
                    alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly,
                  );
                }

                if (widget.liveStreaming!.getNumberOfChairs == 12) {
                  return ZegoLiveAudioRoomLayoutRowConfig(
                    count: 4,
                    alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly,
                  );
                }

                if (widget.liveStreaming!.getNumberOfChairs == 16) {
                  // For 16 user seats: distribute as 4+4+4+4
                  print(
                      "🪑 Row $index: User row with 4 seats (16-seat config)");
                  return ZegoLiveAudioRoomLayoutRowConfig(
                    count: 4,
                    alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly,
                  );
                }

                if (widget.liveStreaming!.getNumberOfChairs == 20) {
                  return ZegoLiveAudioRoomLayoutRowConfig(
                    count: 5,
                    alignment: ZegoLiveAudioRoomLayoutAlignment.start,
                  );
                }

                if (widget.liveStreaming!.getNumberOfChairs == 24) {
                  return ZegoLiveAudioRoomLayoutRowConfig(
                    count: 6,
                    alignment: ZegoLiveAudioRoomLayoutAlignment.start,
                  );
                }

                print("🪑 Row $index: Default user row with 4 seats");
                return ZegoLiveAudioRoomLayoutRowConfig(
                  count: 4,
                  alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly,
                );
              })
              ..foreground = customUiComponents()
              ..inRoomMessage.visible = true
              ..inRoomMessage.showAvatar = true
              ..bottomMenuBar.hostExtendButtons = [
                announcementButton,
                themeButton,
                _buildMusicControlButton(),

                //giftButton,
                Obx(() {
                  return ContainerCorner(
                    color: Colors.white,
                    borderRadius: 50,
                    height: 38,
                    width: 38,
                    onTap: () {
                      toggleSharingMedia();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: SvgPicture.asset(
                        showGiftSendersController.shareMediaFiles.value
                            ? "assets/svg/stop_sharing_media.svg"
                            : "assets/svg/start_sharing_media.svg",
                      ),
                    ),
                  );
                }),
              ]
              ..bottomMenuBar.audienceExtendButtons = [
                announcementButton,
                giftButton,
              ]
              ..background = Obx(() => Image.asset(
                    showGiftSendersController.getThemePath(
                        showGiftSendersController.selectedRoomTheme.value),
                    height: size.height,
                    width: size.width,
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to default theme if current theme fails to load
                      return Image.asset(
                        "assets/images/backgrounds/theme_default.png",
                        height: size.height,
                        width: size.width,
                        fit: BoxFit.fill,
                      );
                    },
                  )),
          ),
          Positioned(
            top: 30,
            left: 10,
            child: SizedBox(
              width: size.width / 1.2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ContainerCorner(
                        height: 37,
                        borderRadius: 50,
                        onTap: () {
                          if (!widget.isHost!) {
                            showUserProfileBottomSheet(
                              currentUser: widget.currentUser!,
                              userId: widget.liveStreaming!.getAuthorId!,
                              context: context,
                            );
                          }
                        },
                        colors: [kVioletColor, earnCashColor],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ContainerCorner(
                                  marginRight: 5,
                                  color: Colors.black.withOpacity(0.5),
                                  child: QuickActions.avatarWidget(
                                    widget.liveStreaming!.getAuthor!,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                  borderRadius: 50,
                                  height: 30,
                                  width: 30,
                                  borderWidth: 0,
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ContainerCorner(
                                      width: 65,
                                      child: TextScroll(
                                        widget.liveStreaming!.getAuthor!
                                            .getFullName!,
                                        mode: TextScrollMode.endless,
                                        velocity: Velocity(
                                          pixelsPerSecond: Offset(30, 0),
                                        ),
                                        delayBefore: Duration(seconds: 1),
                                        pauseBetween: Duration(
                                          milliseconds: 150,
                                        ),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                        textAlign: TextAlign.left,
                                        selectable: true,
                                        intervalSpaces: 5,
                                        numberOfReps: 9999,
                                      ),
                                    ),
                                    ContainerCorner(
                                      width: 65,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 5,
                                            ),
                                            child: Image.asset(
                                              "assets/images/grade_welfare.png",
                                              height: 12,
                                              width: 12,
                                            ),
                                          ),
                                          Obx(() {
                                            return TextWithTap(
                                              QuickHelp.checkFundsWithString(
                                                amount:
                                                    showGiftSendersController
                                                        .diamondsCounter.value,
                                              ),
                                              marginLeft: 5,
                                              marginRight: 5,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Colors.white,
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            ContainerCorner(
                              marginLeft: 10,
                              marginRight: 6,
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: 50,
                              height: 23,
                              width: 23,
                              child: Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: Lottie.asset(
                                  "assets/lotties/ic_live_animation.json",
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!widget.isHost!)
                        ContainerCorner(
                          marginLeft: 5,
                          height: 30,
                          width: 30,
                          marginTop: 15,
                          color: following ? Colors.blueAccent : kVioletColor,
                          child: ContainerCorner(
                            color: kTransparentColor,
                            height: 30,
                            width: 30,
                            child: Center(
                              child: Icon(
                                following ? Icons.done : Icons.add,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          borderRadius: 50,
                          onTap: () {
                            if (!following) {
                              followOrUnfollow();
                              //ZegoInRoomMessage.fromBroadcastMessage(ZegoBroadcastMessageInfo())
                            }
                          },
                        ),
                    ],
                  ),
                  ContainerCorner(
                    width: 70,
                    height: 40,
                    marginRight: 5,
                    child: getTopGifters(),
                  ),
                ],
              ),
            ),
          ),

          // Debug overlay to show announcement count
          Positioned(
            top: 100,
            right: 10,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ValueListenableBuilder<List<AnnouncementData>>(
                valueListenable: _announcementsNotifier,
                builder: (context, announcements, child) {
                  return Text(
                    "📢 ${announcements.length}",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  );
                },
              ),
            ),
          ),

          // Announcement Overlay
          ValueListenableBuilder<List<AnnouncementData>>(
            valueListenable: _announcementsNotifier,
            builder: (context, announcements, child) {
              print(
                  "📢 [ANNOUNCEMENT DEBUG] Building announcement overlay with ${announcements.length} announcements");
              print(
                  "📢 [ANNOUNCEMENT DEBUG] User role: ${widget.isHost! ? 'HOST' : 'AUDIENCE'}");
              for (var announcement in announcements) {
                print(
                    "📢 [ANNOUNCEMENT DEBUG] - ${announcement.title}: ${announcement.message}");
              }
              return AnnouncementOverlayWidget(
                announcements: announcements,
                onDismiss: _onAnnouncementDismiss,
                onPin: _onAnnouncementPin,
              );
            },
          ),
        ],
      ),
    );
  }

  ZegoLiveStreamingMenuBarExtendButton get privateLiveBtn =>
      ZegoLiveStreamingMenuBarExtendButton(
        child: IconButton(
          style: IconButton.styleFrom(
            shape: const CircleBorder(),
            backgroundColor: Colors.black26,
          ),
          onPressed: () {
            if (showGiftSendersController.isPrivateLive.value) {
              unPrivatiseLive();
            } else {
              PrivateLivePriceWidget(
                context: context,
                onCancel: () => QuickHelp.hideLoadingDialog(context),
                onGiftSelected: (gift) {
                  QuickHelp.hideLoadingDialog(context);
                  privatiseLive(gift);
                },
              );
            }
          },
          icon: Obx(
            () => SvgPicture.asset(
              showGiftSendersController.isPrivateLive.value
                  ? "assets/svg/ic_unlocked_live.svg"
                  : "assets/svg/ic_locked_live.svg",
            ),
          ),
        ),
      );

  privatiseLive(GiftsModel gift) async {
    QuickHelp.showLoadingDialog(context);
    widget.liveStreaming!.setPrivate = true;
    widget.liveStreaming!.setPrivateLivePrice = gift;
    ParseResponse response = await widget.liveStreaming!.save();
    if (response.success && response.results != null) {
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        title: "privatise_live_title".tr(),
        message: "privatise_live_succeed".tr(),
        context: context,
        isError: false,
      );
      showGiftSendersController.isPrivateLive.value = true;
    } else {
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        title: "connection_failed".tr(),
        message: "not_connected".tr(),
        context: context,
      );
    }
  }

  unPrivatiseLive() async {
    QuickHelp.showLoadingDialog(context);
    widget.liveStreaming!.setPrivate = false;
    ParseResponse response = await widget.liveStreaming!.save();
    if (response.success && response.results != null) {
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        title: "public_live_title".tr(),
        message: "public_live_succeed".tr(),
        isError: false,
        context: context,
      );
      showGiftSendersController.isPrivateLive.value = false;
    } else {
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        title: "connection_failed".tr(),
        message: "not_connected".tr(),
        context: context,
      );
    }
  }

  onViewerLeave() async {
    QueryBuilder<LiveViewersModel> queryLiveViewers =
        QueryBuilder<LiveViewersModel>(LiveViewersModel());

    queryLiveViewers.whereEqualTo(
      LiveViewersModel.keyAuthorId,
      widget.currentUser!.objectId,
    );
    queryLiveViewers.whereEqualTo(
      LiveViewersModel.keyLiveAuthorId,
      widget.liveStreaming!.getAuthorId!,
    );
    queryLiveViewers.whereEqualTo(
      LiveViewersModel.keyLiveId,
      widget.liveStreaming!.objectId!,
    );

    ParseResponse parseResponse = await queryLiveViewers.query();
    if (parseResponse.success) {
      if (parseResponse.result != null) {
        LiveViewersModel liveViewers =
            parseResponse.results!.first! as LiveViewersModel;

        liveViewers.setWatching = false;
        await liveViewers.save();
      }
    }
  }

  addOrUpdateLiveViewers() async {
    QueryBuilder<LiveViewersModel> queryLiveViewers =
        QueryBuilder<LiveViewersModel>(LiveViewersModel());

    queryLiveViewers.whereEqualTo(
      LiveViewersModel.keyAuthorId,
      widget.currentUser!.objectId,
    );
    queryLiveViewers.whereEqualTo(
      LiveViewersModel.keyLiveId,
      widget.liveStreaming!.objectId!,
    );
    queryLiveViewers.whereEqualTo(
      LiveViewersModel.keyLiveAuthorId,
      widget.liveStreaming!.getAuthorId!,
    );

    ParseResponse parseResponse = await queryLiveViewers.query();
    if (parseResponse.success) {
      if (parseResponse.results != null) {
        LiveViewersModel liveViewers =
            parseResponse.results!.first! as LiveViewersModel;

        liveViewers.setWatching = true;

        await liveViewers.save();
      } else {
        LiveViewersModel liveViewersModel = LiveViewersModel();

        liveViewersModel.setAuthor = widget.currentUser!;
        liveViewersModel.setAuthorId = widget.currentUser!.objectId!;

        liveViewersModel.setWatching = true;

        liveViewersModel.setLiveAuthorId = widget.liveStreaming!.getAuthorId!;
        liveViewersModel.setLiveId = widget.liveStreaming!.objectId!;

        await liveViewersModel.save();
      }
    }
  }

  Widget getTopGifters() {
    QueryBuilder<LiveViewersModel> query = QueryBuilder<LiveViewersModel>(
      LiveViewersModel(),
    );

    //query.whereNotEqualTo(LiveViewersModel.keyAuthorId, widget.liveStreaming!.getAuthorId);
    query.whereEqualTo(
      LiveViewersModel.keyLiveId,
      widget.liveStreaming!.objectId,
    );
    query.whereEqualTo(LiveViewersModel.keyWatching, true);
    query.orderByDescending(LiveViewersModel.keyUpdatedAt);
    query.includeObject([LiveViewersModel.keyAuthor]);
    //query.setLimit(3);

    return ParseLiveListWidget<LiveViewersModel>(
      query: query,
      reverse: false,
      lazyLoading: false,
      shrinkWrap: true,
      scrollDirection: Axis.horizontal,
      duration: const Duration(milliseconds: 200),
      childBuilder: (
        BuildContext context,
        ParseLiveListElementSnapshot<LiveViewersModel> snapshot,
      ) {
        if (snapshot.hasData) {
          LiveViewersModel viewer = snapshot.loadedData!;

          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ContainerCorner(
                height: 25,
                width: 25,
                borderWidth: 0,
                borderRadius: 50,
                marginRight: 7,
                child: QuickActions.avatarWidget(
                  viewer.getAuthor!,
                  height: 25,
                  width: 25,
                ),
              ),
              ContainerCorner(
                color: Colors.white,
                borderRadius: 2,
                marginRight: 7,
                child: TextWithTap(
                  QuickHelp.convertToK(viewer.getAuthor!.getCreditsSent!),
                  fontSize: 5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          );
        } else {
          return const SizedBox();
        }
      },
      listLoadingElement: const SizedBox(),
    );
  }

  void followOrUnfollow() async {
    if (following) {
      widget.currentUser!.removeFollowing = widget.liveStreaming!.getAuthorId!;
      widget.liveStreaming!.removeFollower = widget.currentUser!.objectId!;

      setState(() {
        following = false;
      });
    } else {
      widget.currentUser!.setFollowing = widget.liveStreaming!.getAuthorId!;
      widget.liveStreaming!.addFollower = widget.currentUser!.objectId!;

      setState(() {
        following = true;
      });
    }

    await widget.currentUser!.save();
    widget.liveStreaming!.save();

    ParseResponse parseResponse = await QuickCloudCode.followUser(
      author: widget.currentUser!,
      receiver: widget.liveStreaming!.getAuthor!,
    );

    if (parseResponse.success) {
      sendMessage("start_following".tr());
      QuickActions.createOrDeleteNotification(
        widget.currentUser!,
        widget.liveStreaming!.getAuthor!,
        NotificationsModel.notificationTypeFollowers,
      );
    }
  }

  void _showAnnouncementHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: QuickHelp.isDarkMode(context)
            ? kContentColorLightTheme
            : kContentColorDarkTheme,
        title: TextWithTap("Announcements", fontWeight: FontWeight.bold),
        content: Container(
          height: 300,
          width: double.maxFinite,
          child: _announcements.isEmpty
              ? Center(
                  child: TextWithTap(
                    "No announcements yet",
                    color: Colors.grey,
                  ),
                )
              : ListView.builder(
                  itemCount: _announcements.length,
                  itemBuilder: (context, index) {
                    final announcement = _announcements[index];
                    return Card(
                      child: ListTile(
                        title: Text(announcement.title),
                        subtitle: Text(announcement.message),
                        trailing: Text(
                          announcement.priority,
                          style: TextStyle(
                            color: announcement.priority == 'high'
                                ? Colors.red
                                : announcement.priority == 'medium'
                                    ? Colors.orange
                                    : Colors.green,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showAnnouncementDialog() {
    showDialog(
      context: context,
      builder: (context) => AnnouncementDialog(
        onSend: (title, message, priority, duration) {
          _sendAnnouncement(title, message, priority, duration);
        },
      ),
    );
  }

  void _sendAnnouncement(
    String title,
    String message,
    String priority,
    int duration,
  ) async {
    try {
      // Create announcement message
      LiveMessagesModel announcementMessage = LiveMessagesModel();
      announcementMessage.setAuthor = widget.currentUser!;
      announcementMessage.setAuthorId = widget.currentUser!.objectId!;
      announcementMessage.setLiveStreaming = widget.liveStreaming!;
      announcementMessage.setLiveStreamingId = widget.liveStreaming!.objectId!;
      announcementMessage.setMessageType =
          LiveMessagesModel.messageTypeAnnouncement;
      announcementMessage.setMessage = message;
      announcementMessage.setAnnouncementTitle = title;
      announcementMessage.setAnnouncementPriority = priority;
      announcementMessage.setAnnouncementDuration = duration;

      // Save to Parse
      ParseResponse response = await announcementMessage.save();

      if (response.success) {
        print(
            "📢 [ANNOUNCEMENT DEBUG] Announcement saved successfully to database");

        // Note: We don't add to local list here anymore since the live query will handle it
        // This prevents duplicates for hosts and ensures consistent behavior for all users

        // Send via ZIM for real-time delivery (optional, for immediate chat notification)
        sendMessage("📢 $title: $message");

        QuickHelp.showAppNotificationAdvanced(
          context: context,
          user: widget.currentUser,
          title: "announcement_sent_title".tr(),
          message: "announcement_sent_message".tr(),
          isError: false,
        );
      } else {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          user: widget.currentUser,
          title: "error".tr(),
          message: "announcement_send_failed".tr(),
          isError: true,
        );
      }
    } catch (e) {
      print("Error sending announcement: $e");
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        user: widget.currentUser,
        title: "error".tr(),
        message: "announcement_send_failed".tr(),
        isError: true,
      );
    }
  }

  void _onAnnouncementDismiss(String announcementId) {
    setState(() {
      _announcements.removeWhere((a) => a.id == announcementId);
      _announcementsNotifier.value = List.from(_announcements);
    });
  }

  void _onAnnouncementPin(String announcementId) {
    // Handle pinning logic if needed
    print("Announcement pinned: $announcementId");
  }

  setupStreamingLiveQuery() async {
    QueryBuilder<LiveStreamingModel> query = QueryBuilder<LiveStreamingModel>(
      LiveStreamingModel(),
    );

    query.whereEqualTo(
      LiveStreamingModel.keyObjectId,
      widget.liveStreaming!.objectId,
    );
    query.includeObject([
      LiveStreamingModel.keyPrivateLiveGift,
      LiveStreamingModel.keyGiftSenders,
      LiveStreamingModel.keyGiftSendersAuthor,
      LiveStreamingModel.keyAuthor,
      LiveStreamingModel.keyInvitedPartyLive,
      LiveStreamingModel.keyInvitedPartyLiveAuthor,
    ]);

    subscription = await liveQuery.client.subscribe(query);

    subscription!.on(LiveQueryEvent.update, (
      LiveStreamingModel newUpdatedLive,
    ) async {
      print('*** UPDATE ***');
      await newUpdatedLive.getAuthor!.fetch();
      widget.liveStreaming = newUpdatedLive;
      widget.liveStreaming = newUpdatedLive;

      if (!mounted) return;

      showGiftSendersController.diamondsCounter.value =
          newUpdatedLive.getDiamonds.toString();

      if (newUpdatedLive.getSharingMedia !=
          showGiftSendersController.shareMediaFiles.value) {
        showGiftSendersController.shareMediaFiles.value =
            newUpdatedLive.getSharingMedia!;
      }

      if (!newUpdatedLive.getStreaming! && !widget.isHost!) {
        QuickHelp.goToNavigatorScreen(
          context,
          LiveEndScreen(
            currentUser: widget.currentUser,
            liveAuthor: widget.liveStreaming!.getAuthor,
          ),
        );
        //onViewerLeave();
      }
    });

    subscription!.on(LiveQueryEvent.enter, (
      LiveStreamingModel updatedLive,
    ) async {
      print('*** ENTER ***');
      await updatedLive.getAuthor!.fetch();
      widget.liveStreaming = updatedLive;
      widget.liveStreaming = updatedLive;

      if (!mounted) return;
      showGiftSendersController.diamondsCounter.value =
          widget.liveStreaming!.getDiamonds.toString();
    });
  }

  loadExistingAnnouncements() async {
    print(
        "📢 [ANNOUNCEMENT DEBUG] Loading existing announcements from database");
    print(
        "📢 [ANNOUNCEMENT DEBUG] User role: ${widget.isHost! ? 'HOST' : 'AUDIENCE'}");
    print("📢 [ANNOUNCEMENT DEBUG] Room ID: ${widget.liveStreaming!.objectId}");

    try {
      QueryBuilder<LiveMessagesModel> query = QueryBuilder<LiveMessagesModel>(
        LiveMessagesModel(),
      );

      // Query for existing announcement messages in this live stream
      query.whereEqualTo(
        LiveMessagesModel.keyLiveStreamingId,
        widget.liveStreaming!.objectId,
      );
      query.whereEqualTo(
        LiveMessagesModel.keyMessageType,
        LiveMessagesModel.messageTypeAnnouncement,
      );

      // Include author information
      query.includeObject([
        LiveMessagesModel.keySenderAuthor,
      ]);

      // Order by creation date (newest first)
      query.orderByDescending(LiveMessagesModel.keyCreatedAt);

      // Limit to recent announcements (last 10)
      query.setLimit(10);

      ParseResponse response = await query.query();

      print(
          "📢 [ANNOUNCEMENT DEBUG] Query response - Success: ${response.success}");
      print(
          "📢 [ANNOUNCEMENT DEBUG] Query response - Results count: ${response.results?.length ?? 0}");
      print(
          "📢 [ANNOUNCEMENT DEBUG] Query response - Error: ${response.error?.message ?? 'None'}");

      if (response.success && response.results != null) {
        List<LiveMessagesModel> messages =
            response.results!.cast<LiveMessagesModel>();
        print(
            "📢 [ANNOUNCEMENT DEBUG] Found ${messages.length} existing announcements");

        List<AnnouncementData> existingAnnouncements = [];

        for (LiveMessagesModel message in messages) {
          // Fetch author information if needed
          if (message.getAuthor != null) {
            await message.getAuthor!.fetch();
          }

          final announcementData = AnnouncementData.fromLiveMessage(message);
          existingAnnouncements.add(announcementData);
          print(
              "📢 [ANNOUNCEMENT DEBUG] Loaded announcement: ${announcementData.title}");
        }

        if (mounted && existingAnnouncements.isNotEmpty) {
          setState(() {
            _announcements.addAll(existingAnnouncements);
            _announcementsNotifier.value = List.from(_announcements);
          });
          print(
              "📢 [ANNOUNCEMENT DEBUG] Added ${existingAnnouncements.length} existing announcements to local list");
          print(
              "📢 [ANNOUNCEMENT DEBUG] Total announcements after loading existing: ${_announcements.length}");
          print(
              "📢 [ANNOUNCEMENT DEBUG] Notifier updated with ${_announcementsNotifier.value.length} items");
        } else if (mounted) {
          print(
              "📢 [ANNOUNCEMENT DEBUG] No existing announcements to add, but widget is mounted");
        } else {
          print(
              "📢 [ANNOUNCEMENT DEBUG] Widget not mounted, skipping existing announcements");
        }
      } else {
        print(
            "📢 [ANNOUNCEMENT DEBUG] No existing announcements found or query failed");
      }
    } catch (e) {
      print("📢 [ANNOUNCEMENT DEBUG] Error loading existing announcements: $e");
    }
  }

  setupLiveMessagesQuery() async {
    print(
        "📢 [ANNOUNCEMENT DEBUG] Setting up live messages query for announcements");
    print(
        "📢 [ANNOUNCEMENT DEBUG] User role: ${widget.isHost! ? 'HOST' : 'AUDIENCE'}");
    print("📢 [ANNOUNCEMENT DEBUG] Room ID: ${widget.liveStreaming!.objectId}");

    QueryBuilder<LiveMessagesModel> messagesQuery =
        QueryBuilder<LiveMessagesModel>(
      LiveMessagesModel(),
    );

    // Query for announcement messages in this live stream
    messagesQuery.whereEqualTo(
      LiveMessagesModel.keyLiveStreamingId,
      widget.liveStreaming!.objectId,
    );
    messagesQuery.whereEqualTo(
      LiveMessagesModel.keyMessageType,
      LiveMessagesModel.messageTypeAnnouncement,
    );

    // Include author information
    messagesQuery.includeObject([
      LiveMessagesModel.keySenderAuthor,
    ]);

    // Order by creation date (newest first)
    messagesQuery.orderByDescending(LiveMessagesModel.keyCreatedAt);

    try {
      // Add a small delay to ensure Parse is ready
      await Future.delayed(Duration(milliseconds: 500));

      print("📢 [ANNOUNCEMENT DEBUG] Attempting to subscribe to live query...");
      messagesSubscription = await LiveQuery().client.subscribe(messagesQuery);
      print(
          "📢 [ANNOUNCEMENT DEBUG] Successfully subscribed to live messages query");
      print(
          "📢 [ANNOUNCEMENT DEBUG] Subscription ID: ${messagesSubscription?.hashCode}");
      print(
          "📢 [ANNOUNCEMENT DEBUG] Query details - LiveStreamingId: ${widget.liveStreaming!.objectId}");
      print(
          "📢 [ANNOUNCEMENT DEBUG] Query details - MessageType: ${LiveMessagesModel.messageTypeAnnouncement}");

      // Test the subscription immediately
      print("📢 [ANNOUNCEMENT DEBUG] Testing live query subscription...");

      // Handle new announcement messages
      messagesSubscription!.on(LiveQueryEvent.create,
          (LiveMessagesModel newMessage) async {
        print(
            "📢 [ANNOUNCEMENT DEBUG] ✅ LIVE QUERY TRIGGERED - New announcement received!");
        print("📢 [ANNOUNCEMENT DEBUG] Message ID: ${newMessage.objectId}");
        print(
            "📢 [ANNOUNCEMENT DEBUG] Title: ${newMessage.getAnnouncementTitle}");
        print("📢 [ANNOUNCEMENT DEBUG] Message: ${newMessage.getMessage}");
        print(
            "📢 [ANNOUNCEMENT DEBUG] Priority: ${newMessage.getAnnouncementPriority}");
        print(
            "📢 [ANNOUNCEMENT DEBUG] Duration: ${newMessage.getAnnouncementDuration}");
        print(
            "📢 [ANNOUNCEMENT DEBUG] Author: ${newMessage.getAuthor?.getFullName}");

        // Fetch author information if needed
        if (newMessage.getAuthor != null) {
          await newMessage.getAuthor!.fetch();
          print(
              "📢 [ANNOUNCEMENT DEBUG] Author fetched: ${newMessage.getAuthor!.getFullName}");
        }

        // All users (including hosts) should receive announcements through live query
        // This ensures consistent behavior and prevents timing issues

        // Convert to AnnouncementData and add to local list
        final announcementData = AnnouncementData.fromLiveMessage(newMessage);
        print(
            "📢 [ANNOUNCEMENT DEBUG] Converted to AnnouncementData: ${announcementData.title}");

        if (mounted) {
          setState(() {
            _announcements.add(announcementData);
            _announcementsNotifier.value = List.from(_announcements);
          });
          print(
              "📢 [ANNOUNCEMENT DEBUG] ✅ Added announcement to local list: ${announcementData.title}");
          print(
              "📢 [ANNOUNCEMENT DEBUG] Total announcements now: ${_announcements.length}");
          print(
              "📢 [ANNOUNCEMENT DEBUG] Notifier value updated with ${_announcementsNotifier.value.length} items");

          // Force a rebuild to ensure UI updates
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          }
        } else {
          print(
              "📢 [ANNOUNCEMENT DEBUG] ❌ Widget not mounted, skipping announcement addition");
        }
      });

      // Handle updated announcement messages
      messagesSubscription!.on(LiveQueryEvent.update,
          (LiveMessagesModel updatedMessage) async {
        print(
            "📢 [ANNOUNCEMENT DEBUG] Announcement updated: ${updatedMessage.getAnnouncementTitle}");

        // Fetch author information if needed
        if (updatedMessage.getAuthor != null) {
          await updatedMessage.getAuthor!.fetch();
        }

        // Find and update the existing announcement
        final announcementData =
            AnnouncementData.fromLiveMessage(updatedMessage);

        if (mounted) {
          setState(() {
            final index =
                _announcements.indexWhere((a) => a.id == announcementData.id);
            if (index != -1) {
              _announcements[index] = announcementData;
              _announcementsNotifier.value = List.from(_announcements);
              print(
                  "📢 [ANNOUNCEMENT DEBUG] Updated announcement in local list: ${announcementData.title}");
            }
          });
        }
      });

      // Handle deleted announcement messages
      messagesSubscription!.on(LiveQueryEvent.delete,
          (LiveMessagesModel deletedMessage) {
        print(
            "📢 [ANNOUNCEMENT DEBUG] Announcement deleted: ${deletedMessage.objectId}");

        if (mounted) {
          setState(() {
            _announcements.removeWhere((a) => a.id == deletedMessage.objectId);
            _announcementsNotifier.value = List.from(_announcements);
            print(
                "📢 [ANNOUNCEMENT DEBUG] Removed announcement from local list");
          });
        }
      });

      print(
          "📢 [ANNOUNCEMENT DEBUG] Live messages query setup completed successfully");
    } catch (e) {
      print("📢 [ANNOUNCEMENT DEBUG] Error setting up live messages query: $e");
    }
  }

  sendGift(GiftsModel giftsModel, UserModel mUser) async {
    GiftsSentModel giftsSentModel = new GiftsSentModel();
    giftsSentModel.setAuthor = widget.currentUser!;
    giftsSentModel.setAuthorId = widget.currentUser!.objectId!;

    giftsSentModel.setReceiver = mUser;
    giftsSentModel.setReceiverId = mUser.objectId!;
    giftsSentModel.setLiveId = widget.liveStreaming!.objectId!;

    giftsSentModel.setGift = giftsModel;
    giftsSentModel.setGiftId = giftsModel.objectId!;
    giftsSentModel.setCounterDiamondsQuantity = giftsModel.getCoins!;
    await giftsSentModel.save();

    QuickHelp.saveReceivedGifts(
      receiver: mUser,
      author: widget.currentUser!,
      gift: giftsModel,
    );
    QuickHelp.saveCoinTransaction(
      receiver: mUser,
      author: widget.currentUser!,
      amountTransacted: giftsModel.getCoins!,
    );

    QueryBuilder<LeadersModel> queryBuilder = QueryBuilder<LeadersModel>(
      LeadersModel(),
    );
    queryBuilder.whereEqualTo(
      LeadersModel.keyAuthorId,
      widget.currentUser!.objectId!,
    );
    ParseResponse parseResponse = await queryBuilder.query();

    if (parseResponse.success) {
      updateCurrentUser(giftsSentModel.getDiamondsQuantity!);

      if (parseResponse.results != null) {
        LeadersModel leadersModel =
            parseResponse.results!.first as LeadersModel;
        leadersModel.incrementDiamondsQuantity =
            giftsSentModel.getDiamondsQuantity!;
        leadersModel.setGiftsSent = giftsSentModel;
        await leadersModel.save();
      } else {
        LeadersModel leadersModel = LeadersModel();
        leadersModel.setAuthor = widget.currentUser!;
        leadersModel.setAuthorId = widget.currentUser!.objectId!;
        leadersModel.incrementDiamondsQuantity =
            giftsSentModel.getDiamondsQuantity!;
        leadersModel.setGiftsSent = giftsSentModel;
        await leadersModel.save();
      }

      await QuickCloudCode.sendGift(
        author: mUser,
        credits: giftsModel.getCoins!,
      );

      if (mUser.objectId == widget.liveStreaming!.getAuthorId) {
        widget.liveStreaming!.addDiamonds = QuickHelp.getDiamondsForReceiver(
          giftsModel.getCoins!,
        );
        await widget.liveStreaming!.save();
        sendMessage("sent_gift".tr(namedArgs: {"name": "host_".tr()}));
      } else {
        sendMessage("sent_gift".tr(namedArgs: {"name": mUser.getFullName!}));
      }

      /*sendMessage(LiveMessagesModel.messageTypeGift, "", widget.currentUser,
          giftsSent: giftsSentModel);*/
    } else {
      //QuickHelp.goBackToPreviousPage(context);
      debugPrint("gift Navigator pop up");
    }
  }

  Widget customUiComponents() {
    print(
      "🔥 customUiComponents CALLED! isHost: ${widget.isHost}, totalSeats: ${widget.liveStreaming!.getNumberOfChairs}",
    );

    return Stack(
      children: [
        // Seat Management FAB for per-seat actions (only for hosts)
        if (widget.isHost!)
          SeatManagementFAB(
            currentUser: widget.currentUser!,
            isHost: widget.isHost!,
            totalSeats: widget.liveStreaming!.getNumberOfChairs ?? 0,
            onActionSelected: handleSeatAction,
          ),

        // Debug buttons for hosts - Test individual seat locking
        if (widget.isHost!)
          Positioned(
            top: 100,
            left: 20,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: MaterialButton(
                    onPressed: () {
                      print("🧪 DEBUG: Testing lock seat 1");
                      showGiftSendersController.validateSeatStates();
                      handleSeatAction('lock', 1); // Test lock action on seat 1
                    },
                    child: Text(
                      "LOCK SEAT 1",
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
                SizedBox(height: 5),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: MaterialButton(
                    onPressed: () {
                      print("🧪 DEBUG: Testing unlock seat 1");
                      showGiftSendersController.validateSeatStates();
                      handleSeatAction(
                          'unlock', 1); // Test unlock action on seat 1
                    },
                    child: Text(
                      "UNLOCK SEAT 1",
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
                SizedBox(height: 5),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: MaterialButton(
                    onPressed: () {
                      print("🧪 DEBUG: Testing lock seat 2");
                      showGiftSendersController.validateSeatStates();
                      handleSeatAction('lock', 2); // Test lock action on seat 2
                    },
                    child: Text(
                      "LOCK SEAT 2",
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

        Obx(() {
          return Positioned(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                showGiftSendersController.receivedGiftList.length,
                (index) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ContainerCorner(
                        colors: [Colors.black26, Colors.transparent],
                        borderRadius: 50,
                        marginLeft: 5,
                        marginRight: 10,
                        marginBottom: 15,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  QuickActions.avatarWidget(
                                    showGiftSendersController
                                        .giftSenderList[index],
                                    width: 35,
                                    height: 35,
                                  ),
                                  SizedBox(
                                    width: 45,
                                    child: TextWithTap(
                                      showGiftSendersController
                                          .giftSenderList[index].getFullName!,
                                      fontSize: 8,
                                      color: Colors.white,
                                      marginTop: 2,
                                      overflow: TextOverflow.ellipsis,
                                      alignment: Alignment.center,
                                    ),
                                  ),
                                ],
                              ),
                              TextWithTap(
                                "sent_gift_to".tr(),
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                marginRight: 5,
                                marginLeft: 5,
                                textItalic: true,
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  QuickActions.avatarWidget(
                                    showGiftSendersController
                                        .giftReceiverList[index],
                                    width: 35,
                                    height: 35,
                                  ),
                                  SizedBox(
                                    width: 45,
                                    child: TextWithTap(
                                      showGiftSendersController
                                          .giftReceiverList[index].getFullName!,
                                      fontSize: 8,
                                      color: Colors.white,
                                      marginTop: 2,
                                      overflow: TextOverflow.ellipsis,
                                      alignment: Alignment.center,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 35,
                                height: 35,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: QuickActions.photosWidget(
                                    showGiftSendersController
                                        .receivedGiftList[index]
                                        .getPreview!
                                        .url,
                                  ),
                                ),
                              ),
                              ContainerCorner(
                                color: kTransparentColor,
                                marginTop: 1,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SvgPicture.asset(
                                      "assets/svg/ic_coin_with_star.svg",
                                      width: 10,
                                      height: 10,
                                    ),
                                    TextWithTap(
                                      showGiftSendersController
                                          .receivedGiftList[index].getCoins
                                          .toString(),
                                      color: Colors.white,
                                      fontSize: 10,
                                      marginLeft: 5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          TextWithTap(
                            "x1",
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 25,
                            marginLeft: 10,
                            textItalic: true,
                          ),
                        ],
                      ),
                    ],
                  ).animate().slideX(
                        duration: Duration(seconds: 2),
                        delay: Duration(seconds: 0),
                        begin: -5,
                        end: 0,
                      );
                },
              ),
            ),
          );
        }),
        ValueListenableBuilder<GiftsModel?>(
          valueListenable: ZegoGiftManager().playList.playingDataNotifier,
          builder: (context, playData, _) {
            if (null == playData) {
              return const SizedBox.shrink();
            }
            return svgaWidget(playData);
          },
        ),
      ],
    );
  }

  toggleSharingMedia() async {
    QuickHelp.showLoadingDialog(context);
    if (showGiftSendersController.shareMediaFiles.value) {
      widget.liveStreaming!.setSharingMedia = false;
    } else {
      widget.liveStreaming!.setSharingMedia = true;
    }
    ParseResponse response = await widget.liveStreaming!.save();
    if (response.success && response.results != null) {
      QuickHelp.hideLoadingDialog(context);
    } else {
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        title: "error".tr(),
        message: "not_connected".tr(),
        context: context,
        isError: true,
      );
    }
  }

  updateCurrentUser(int coins) async {
    widget.currentUser!.removeCredit = coins;
    ParseResponse response = await widget.currentUser!.save();
    if (response.success && response.results != null) {
      widget.currentUser = response.results!.first as UserModel;
    }
  }

  // Seat indexing is handled directly by Zego via extraInfo['index']

  // Seat action handlers
  void handleSeatClick(int seatIndex) {
    if (!widget.isHost!) return; // Only hosts can manage seats

    showSeatActionMenu(
      context: context,
      currentUser: widget.currentUser!,
      seatIndex: seatIndex,
      onActionSelected: handleSeatAction,
    );
  }

  void handleSeatAction(String action, int seatIndex) async {
    print("handleSeatAction: $action for seat $seatIndex"); // Debug log

    switch (action) {
      case 'lock':
        await lockSeat(seatIndex);
        break;
      case 'unlock':
        await unlockSeat(seatIndex);
        break;
      case 'mute':
        await muteSeat(seatIndex);
        break;
      case 'unmute':
        await unmuteSeat(seatIndex);
        break;
      case 'invite':
        showInviteFriendsSheet(
          context: context,
          currentUser: widget.currentUser!,
          seatIndex: seatIndex,
          onUserSelected: inviteUserToSeat,
        );
        break;
      case 'remove':
        await removeUserFromSeat(seatIndex);
        break;
    }
  }

  Future<void> lockSeat(int seatIndex) async {
    try {
      print("🔒 MAIN.lockSeat($seatIndex) - Starting lock process");
      print(
          "🔒 MAIN.lockSeat($seatIndex) - Current seat state BEFORE: ${showGiftSendersController.getSeatState(seatIndex)}");

      QuickHelp.showLoadingDialog(context);

      // Validate current state
      showGiftSendersController.validateSeatStates();

      // Update local state FIRST
      print("🔒 MAIN.lockSeat($seatIndex) - Updating local state");
      showGiftSendersController.lockSeat(seatIndex);

      print(
          "🔒 MAIN.lockSeat($seatIndex) - Current seat state AFTER local update: ${showGiftSendersController.getSeatState(seatIndex)}");

      // Update backend - Use a more specific identifier for seat locking
      String seatLockId =
          "SEAT_LOCK_${seatIndex}_${widget.liveStreaming!.objectId}";
      print("🔒 MAIN.lockSeat($seatIndex) - Adding '$seatLockId' to backend");
      widget.liveStreaming!.addRemovedUserIds = seatLockId;

      ParseResponse response = await widget.liveStreaming!.save();
      if (response.success) {
        QuickHelp.hideLoadingDialog(context);
        print("🔒 MAIN.lockSeat($seatIndex) - Backend save SUCCESS");
        print(
            "🔒 MAIN.lockSeat($seatIndex) - Final seat state: ${showGiftSendersController.getSeatState(seatIndex)}");

        // Validate all seats after successful lock
        showGiftSendersController.validateSeatStates();

        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "success".tr(),
          message: "Seat ${seatIndex + 1} locked successfully",
        );
      } else {
        QuickHelp.hideLoadingDialog(context);
        print(
            "🔒 MAIN.lockSeat($seatIndex) - Backend save FAILED: ${response.error}");
        showGiftSendersController.unlockSeat(seatIndex); // Revert local state
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "error".tr(),
          message: "seat_actions.action_failed".tr(),
          isError: true,
        );
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      print("🔒 MAIN.lockSeat($seatIndex) - EXCEPTION: $e");
      showGiftSendersController.unlockSeat(seatIndex); // Revert local state
      print("Error locking seat: $e");
    }
  }

  Future<void> unlockSeat(int seatIndex) async {
    try {
      print("🔓 MAIN.unlockSeat($seatIndex) - Starting unlock process");
      print(
          "🔓 MAIN.unlockSeat($seatIndex) - Current seat state BEFORE: ${showGiftSendersController.getSeatState(seatIndex)}");

      QuickHelp.showLoadingDialog(context);

      // Validate current state
      showGiftSendersController.validateSeatStates();

      // Update local state FIRST
      print("🔓 MAIN.unlockSeat($seatIndex) - Updating local state");
      showGiftSendersController.unlockSeat(seatIndex);

      print(
          "🔓 MAIN.unlockSeat($seatIndex) - Current seat state AFTER local update: ${showGiftSendersController.getSeatState(seatIndex)}");

      // Update backend - Use the same specific identifier used for locking
      String seatLockId =
          "SEAT_LOCK_${seatIndex}_${widget.liveStreaming!.objectId}";
      print(
          "🔓 MAIN.unlockSeat($seatIndex) - Removing '$seatLockId' from backend");
      widget.liveStreaming!.removeRemovedUserIds = seatLockId;

      ParseResponse response = await widget.liveStreaming!.save();
      if (response.success) {
        QuickHelp.hideLoadingDialog(context);
        print("🔓 MAIN.unlockSeat($seatIndex) - Backend save SUCCESS");
        print(
            "🔓 MAIN.unlockSeat($seatIndex) - Final seat state: ${showGiftSendersController.getSeatState(seatIndex)}");

        // Validate all seats after successful unlock
        showGiftSendersController.validateSeatStates();

        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "success".tr(),
          message: "Seat ${seatIndex + 1} unlocked successfully",
        );
      } else {
        QuickHelp.hideLoadingDialog(context);
        print(
            "🔓 MAIN.unlockSeat($seatIndex) - Backend save FAILED: ${response.error}");
        showGiftSendersController.lockSeat(seatIndex); // Revert local state
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "error".tr(),
          message: "seat_actions.action_failed".tr(),
          isError: true,
        );
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      print("🔓 MAIN.unlockSeat($seatIndex) - EXCEPTION: $e");
      showGiftSendersController.lockSeat(seatIndex); // Revert local state
      print("Error unlocking seat: $e");
    }
  }

  Future<void> muteSeat(int seatIndex) async {
    // Get the user in the seat (this would need to be implemented based on ZegoUIKit user tracking)
    final seatState = showGiftSendersController.getSeatState(seatIndex);
    final userId = seatState?['userId'];

    if (userId == null) return;

    try {
      QuickHelp.showLoadingDialog(context);

      // Update local state
      showGiftSendersController.muteSeat(seatIndex);

      // Update backend
      widget.liveStreaming!.addMutedUserIds = userId;

      ParseResponse response = await widget.liveStreaming!.save();
      if (response.success) {
        QuickHelp.hideLoadingDialog(context);
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "seat_actions.muted".tr(),
          message: "seat_actions.seat_muted_success".tr(
            namedArgs: {"seat": "${seatIndex + 1}"},
          ),
        );
      } else {
        QuickHelp.hideLoadingDialog(context);
        showGiftSendersController.unmuteSeat(seatIndex); // Revert local state
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "error".tr(),
          message: "seat_actions.action_failed".tr(),
          isError: true,
        );
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      showGiftSendersController.unmuteSeat(seatIndex);
      print("Error muting seat: $e");
    }
  }

  Future<void> unmuteSeat(int seatIndex) async {
    final seatState = showGiftSendersController.getSeatState(seatIndex);
    final userId = seatState?['userId'];

    if (userId == null) return;

    try {
      QuickHelp.showLoadingDialog(context);

      // Update local state
      showGiftSendersController.unmuteSeat(seatIndex);

      // Update backend
      widget.liveStreaming!.removeMutedUserIds = userId;

      ParseResponse response = await widget.liveStreaming!.save();
      if (response.success) {
        QuickHelp.hideLoadingDialog(context);
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "seat_actions.unmuted".tr(),
          message: "seat_actions.seat_unmuted_success"
              .tr(namedArgs: {"seat": "${seatIndex + 1}"}),
        );
      } else {
        QuickHelp.hideLoadingDialog(context);
        showGiftSendersController.muteSeat(seatIndex); // Revert local state
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "error".tr(),
          message: "seat_actions.action_failed".tr(),
          isError: true,
        );
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      showGiftSendersController.muteSeat(seatIndex);
      print("Error un-muting seat: $e");
    }
  }

  void inviteUserToSeat(UserModel user, int seatIndex) async {
    try {
      QuickHelp.showLoadingDialog(context);

      // Send proper seat invitation using the invitation service
      final invitation = await _seatInvitationService.sendSeatInvitation(
        inviter: widget.currentUser!,
        invitee: user,
        liveStreaming: widget.liveStreaming!,
        seatIndex: seatIndex,
        customMessage: "Join me in seat ${seatIndex + 1}!",
      );

      QuickHelp.hideLoadingDialog(context);

      if (invitation != null) {
        // Send invitation message to the room
        sendMessage(
          "invite_to_seat".tr(
            namedArgs: {
              "name": user.getFirstName ?? "User",
              "seat": "${seatIndex + 1}",
            },
          ),
        );

        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "invite_friends.invited".tr(),
          message: "seat_invitation.invitation_sent_success".tr(
            namedArgs: {
              "name": user.getFirstName ?? "User",
              "seat": "${seatIndex + 1}",
            },
          ),
        );
      } else {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "error".tr(),
          message: "seat_invitation.invitation_failed".tr(),
          isError: true,
        );
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "error".tr(),
        message: "seat_invitation.invitation_failed".tr(),
        isError: true,
      );
      print("Error inviting user to seat: $e");
    }
  }

  Future<void> removeUserFromSeat(int seatIndex) async {
    final seatState = showGiftSendersController.getSeatState(seatIndex);
    final userId = seatState?['userId'];

    if (userId == null) return;

    try {
      QuickHelp.showLoadingDialog(context);

      // Update local state
      showGiftSendersController.updateSeatState(seatIndex, 'userId', null);
      showGiftSendersController.updateSeatState(seatIndex, 'userName', null);

      // Update backend to remove user from seat
      widget.liveStreaming!.addRemovedUserIds = userId;

      ParseResponse response = await widget.liveStreaming!.save();
      if (response.success) {
        QuickHelp.hideLoadingDialog(context);
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "seat_actions.removed".tr(),
          message: "seat_actions.user_removed_success".tr(
            namedArgs: {"seat": "${seatIndex + 1}"},
          ),
        );
      } else {
        QuickHelp.hideLoadingDialog(context);
        // Revert local state
        showGiftSendersController.updateSeatState(seatIndex, 'userId', userId);
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "error".tr(),
          message: "seat_actions.action_failed".tr(),
          isError: true,
        );
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      print("Error removing user from seat: $e");
    }
  }

  Widget svgaWidget(GiftsModel giftItem) {
    /// you can define the area and size for displaying your own
    /// animations here
    int level = 1;
    if (giftItem.getCoins! < 10) {
      level = 1;
    } else if (giftItem.getCoins! < 100) {
      level = 2;
    } else {
      level = 3;
    }
    switch (level) {
      case 2:
        return Positioned(
          top: 100,
          bottom: 100,
          left: 1,
          right: 1,
          child: ZegoSvgaPlayerWidget(
            key: UniqueKey(),
            giftItem: giftItem,
            onPlayEnd: () {
              ZegoGiftManager().playList.next();
            },
            count: 1,
          ),
        );
      case 3:
        return ZegoSvgaPlayerWidget(
          key: UniqueKey(),
          giftItem: giftItem,
          onPlayEnd: () {
            ZegoGiftManager().playList.next();
          },
          count: 1,
        );
    }
    // level 1
    return Positioned(
      bottom: 200,
      child: ZegoSvgaPlayerWidget(
        key: UniqueKey(),
        size: const Size(100, 100),
        giftItem: giftItem,
        onPlayEnd: () {
          /// if there is another gift animation, then play
          ZegoGiftManager().playList.next();
        },
        count: 1,
      ),
    );
  }

  setupLiveGifts() async {
    QueryBuilder<GiftsSentModel> queryBuilder = QueryBuilder<GiftsSentModel>(
      GiftsSentModel(),
    );
    queryBuilder.whereEqualTo(
      GiftsSentModel.keyLiveId,
      widget.liveStreaming!.objectId,
    );
    queryBuilder.includeObject([GiftsSentModel.keyGift]);
    subscription = await liveQuery.client.subscribe(queryBuilder);

    subscription!.on(LiveQueryEvent.create, (GiftsSentModel giftSent) async {
      await giftSent.getGift!.fetch();
      await giftSent.getReceiver!.fetch();
      await giftSent.getAuthor!.fetch();

      GiftsModel receivedGift = giftSent.getGift!;
      UserModel receiver = giftSent.getReceiver!;
      UserModel sender = giftSent.getAuthor!;

      showGiftSendersController.giftSenderList.add(sender);
      showGiftSendersController.giftReceiverList.add(receiver);
      showGiftSendersController.receivedGiftList.add(receivedGift);

      if (removeGiftTimer == null) {
        startRemovingGifts();
      }

      selectedGiftItemNotifier.value = receivedGift;

      /// local play
      ZegoGiftManager().playList.add(receivedGift);

      ValueListenableBuilder<GiftsModel?>(
        valueListenable: ZegoGiftManager().playList.playingDataNotifier,
        builder: (context, playData, _) {
          if (null == playData) {
            return const SizedBox.shrink();
          }
          return svgaWidget(playData);
        },
      );
    });
  }

  void openUserToReceiveCoins() async {
    showModalBottomSheet(
      context: (context),
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) {
        return _showUserToReceiveCoins();
      },
    );
  }

  Widget _showUserToReceiveCoins() {
    coHostsList.add(widget.liveStreaming!.getAuthorId);
    Size size = MediaQuery.sizeOf(context);
    QueryBuilder<UserModel> coHostQuery = QueryBuilder<UserModel>(
      UserModel.forQuery(),
    );
    coHostQuery.whereNotEqualTo(
      UserModel.keyObjectId,
      widget.currentUser!.objectId,
    );
    coHostQuery.whereContainedIn(UserModel.keyObjectId, coHostsList);

    return ContainerCorner(
      color: kIamonDarkBarColor.withOpacity(.9),
      width: size.width,
      borderColor: Colors.white,
      radiusTopLeft: 10,
      radiusTopRight: 10,
      marginRight: 15,
      marginLeft: 15,
      child: Column(
        children: [
          TextWithTap(
            "choose_gift_receiver".tr(),
            color: Colors.white,
            alignment: Alignment.center,
            textAlign: TextAlign.center,
            marginTop: 15,
            marginBottom: 30,
          ),
          Flexible(
            child: ParseLiveGridWidget<UserModel>(
              query: coHostQuery,
              crossAxisCount: 4,
              reverse: false,
              crossAxisSpacing: 5,
              mainAxisSpacing: 10,
              lazyLoading: false,
              padding: EdgeInsets.only(left: 15, right: 15),
              childAspectRatio: 0.7,
              shrinkWrap: true,
              listenOnAllSubItems: true,
              duration: Duration(seconds: 0),
              animationController: _animationController,
              childBuilder: (
                BuildContext context,
                ParseLiveListElementSnapshot<UserModel> snapshot,
              ) {
                UserModel user = snapshot.loadedData!;
                return GestureDetector(
                  onTap: () {
                    CoinsFlowPayment(
                      context: context,
                      currentUser: widget.currentUser!,
                      onCoinsPurchased: (coins) {
                        print(
                          "onCoinsPurchased: $coins new: ${widget.currentUser!.getCredits}",
                        );
                      },
                      onGiftSelected: (gift) {
                        print("onGiftSelected called ${gift.getCoins}");
                        sendGift(gift, user);

                        //QuickHelp.goBackToPreviousPage(context);
                        QuickHelp.showAppNotificationAdvanced(
                          context: context,
                          user: widget.currentUser,
                          title: "live_streaming.gift_sent_title".tr(),
                          message: "live_streaming.gift_sent_explain".tr(
                            namedArgs: {"name": user.getFirstName!},
                          ),
                          isError: false,
                        );
                      },
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      QuickActions.avatarWidget(
                        user,
                        width: size.width / 5.5,
                        height: size.width / 5.5,
                      ),
                      TextWithTap(
                        user.getFullName!,
                        color: Colors.white,
                        marginTop: 5,
                        overflow: TextOverflow.ellipsis,
                        fontSize: 10,
                      ),
                    ],
                  ),
                );
              },
              queryEmptyElement: QuickActions.noContentFound(context),
              gridLoadingElement: Container(
                margin: EdgeInsets.only(top: 50),
                alignment: Alignment.topCenter,
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Theme synchronization setup
  void setupThemeSync() async {
    if (!widget.isHost!) {
      // Only non-hosts need to listen for theme changes
      // Hosts will update themes directly through the UI
      QueryBuilder<LiveStreamingModel> queryBuilder =
          QueryBuilder<LiveStreamingModel>(LiveStreamingModel());
      queryBuilder.whereEqualTo(
          LiveStreamingModel.keyObjectId, widget.liveStreaming!.objectId!);

      subscription = await liveQuery.client.subscribe(queryBuilder);

      subscription!.on(LiveQueryEvent.update, (value) {
        print("🎨 [THEME SYNC] Live streaming model updated");

        if (value is LiveStreamingModel) {
          final newTheme = value.getRoomTheme ?? 'theme_default';
          final currentTheme =
              showGiftSendersController.selectedRoomTheme.value;

          if (newTheme != currentTheme) {
            print(
                "🎨 [THEME SYNC] Theme changed from $currentTheme to $newTheme");
            showGiftSendersController.updateRoomTheme(newTheme);

            // Show notification to participants about theme change
            QuickHelp.showAppNotificationAdvanced(
              context: context,
              title: "Theme Changed",
              message: "The host has changed the room theme!",
              isError: false,
            );
          }
        }
      });
    }
  }

  // Theme management methods
  void _showThemeSelector() {
    if (!widget.isHost!) {
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "Error",
        message: "Only the host can change the room theme.",
        isError: true,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoomThemeSelector(
        currentUser: widget.currentUser!,
        liveStreaming: widget.liveStreaming!,
        onThemeSelected: _onThemeChanged,
      ),
    );
  }

  void _onThemeChanged(String newTheme) {
    print("🎨 Theme changed to: $newTheme");

    // Update the controller state
    showGiftSendersController.updateRoomTheme(newTheme);

    // The UI will automatically update due to Obx wrapper on background
    print("🎨 Theme applied successfully!");
  }

  Future<void> _ensureMusicPlayer() async {
    if (_musicPlayer != null) return;
    _musicPlayer = await ZegoExpressEngine.instance.createMediaPlayer();
    _musicPlayer?.setVolume(60);
    _isMusicReady = false;
  }

  Future<void> _destroyMusicPlayer() async {
    if (_musicPlayer != null) {
      await ZegoExpressEngine.instance.destroyMediaPlayer(_musicPlayer!);
      _musicPlayer = null;
    }
    if (_musicPlayerViewID != -1) {
      await ZegoExpressEngine.instance.destroyCanvasView(_musicPlayerViewID);
      _musicPlayerViewID = -1;
    }
  }

  Future<void> _hostPlayUrl(String url) async {
    if (!widget.isHost!) return;

    try {
      await _ensureMusicPlayer();
      final source = ZegoMediaPlayerResource.defaultConfig()..filePath = url;
      final result = await _musicPlayer!.loadResourceWithConfig(source);

      if (result.errorCode == 0) {
        _isMusicReady = true;
        _musicPlayer!.start();
        await ZegoLiveAudioRoomManager().setMusicState(
            MusicPlaybackState(trackUrl: url, isPlaying: true, positionMs: 0));

        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "Music Playing",
          message: "Background music started",
          isError: false,
        );
      }
    } catch (e) {
      print("Error playing music: $e");
    }
  }

  Future<void> _hostPause() async {
    if (_musicPlayer == null || !widget.isHost!) return;

    _musicPlayer!.pause();
    final cur = ZegoLiveAudioRoomManager().musicStateNoti.value;
    await ZegoLiveAudioRoomManager().setMusicState(
        (cur ?? MusicPlaybackState.empty()).copyWith(isPlaying: false));
  }

  Future<void> _hostResume() async {
    if (_musicPlayer == null || !widget.isHost!) return;

    _musicPlayer!.resume();
    final cur = ZegoLiveAudioRoomManager().musicStateNoti.value;
    await ZegoLiveAudioRoomManager().setMusicState(
        (cur ?? MusicPlaybackState.empty()).copyWith(isPlaying: true));
  }

  Future<void> _hostStop() async {
    if (_musicPlayer == null || !widget.isHost!) return;

    _musicPlayer!.stop();
    await ZegoLiveAudioRoomManager()
        .setMusicState(MusicPlaybackState.stopped());
  }

  Future<void> _hostNextTrack() async {
    if (!widget.isHost!) return;

    _currentMusicIndex = (_currentMusicIndex + 1) % _playlistUrls.length;
    await _hostPlayUrl(_playlistUrls[_currentMusicIndex]);
  }

// Apply incoming music state for non-hosts
  void _onMusicStateChanged() {
    final state = ZegoLiveAudioRoomManager().musicStateNoti.value;
    if (state == null || widget.isHost!) return; // Host drives the player

    () async {
      try {
        await _ensureMusicPlayer();
        if (state.trackUrl == null || state.trackUrl!.isEmpty) {
          _musicPlayer?.stop();
          return;
        }

        if (!_isMusicReady) {
          final source = ZegoMediaPlayerResource.defaultConfig()
            ..filePath = state.trackUrl!;
          final result = await _musicPlayer!.loadResourceWithConfig(source);
          if (result.errorCode == 0) {
            _isMusicReady = true;
          }
        }

        if (state.isPlaying) {
          _musicPlayer?.start();
        } else {
          _musicPlayer?.pause();
        }
      } catch (e) {
        print("Error syncing music state: $e");
      }
    }();
  }

  Widget _buildMusicControlButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        fixedSize: const Size(40, 40),
        shape: const CircleBorder(),
        backgroundColor: Colors.black26,
      ),
      onPressed: () {
        if (widget.isHost!) {
          _showMusicControls();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: Icon(Icons.music_note, color: kPrimaryColor, size: 24),
      ),
    );
  }

// 8. ADD THIS METHOD to show music controls dialog
  void _showMusicControls() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: QuickHelp.isDarkMode(context)
            ? kContentColorLightTheme
            : kContentColorDarkTheme,
        title: TextWithTap("Music Controls", fontWeight: FontWeight.bold),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    _currentMusicIndex = 0;
                    await _hostPlayUrl(_playlistUrls[_currentMusicIndex]);
                  },
                  child: Icon(Icons.play_arrow),
                ),
                ElevatedButton(
                  onPressed: _hostPause,
                  child: Icon(Icons.pause),
                ),
                ElevatedButton(
                  onPressed: _hostResume,
                  child: Icon(Icons.play_circle),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _hostNextTrack,
                  child: Icon(Icons.skip_next),
                ),
                ElevatedButton(
                  onPressed: _hostStop,
                  child: Icon(Icons.stop),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }
}

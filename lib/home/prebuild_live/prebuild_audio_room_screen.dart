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
  LiveQuery liveQuery = LiveQuery();
  var coHostsList = [];
  bool following = false;

  Controller showGiftSendersController = Get.put(Controller());
  final selectedGiftItemNotifier = ValueNotifier<GiftsModel?>(null);
  Timer? removeGiftTimer;

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
    print("📢 [ANNOUNCEMENT DEBUG] initState() called");
    print(
        "📢 [ANNOUNCEMENT DEBUG] User role: ${widget.isHost! ? 'HOST' : 'AUDIENCE'}");
    print("📢 [ANNOUNCEMENT DEBUG] User ID: ${widget.currentUser?.objectId}");
    print(
        "📢 [ANNOUNCEMENT DEBUG] Room ID: ${widget.liveStreaming?.getStreamingChannel}");

    WakelockPlus.enable();
    initSharedPref();
    _resetSeatCounter(); // Reset seat indexing
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
    if (widget.liveStreaming!.getNumberOfChairs == 20) {
      numberOfSeats = (widget.liveStreaming!.getNumberOfChairs! ~/ 5) + 1;
    } else if (widget.liveStreaming!.getNumberOfChairs == 24) {
      numberOfSeats = (widget.liveStreaming!.getNumberOfChairs! ~/ 6) + 1;
    } else {
      numberOfSeats = (widget.liveStreaming!.getNumberOfChairs! ~/ 4) + 1;
    }

    // Initialize seat states for per-seat management
    showGiftSendersController.initializeSeatStates(
      widget.liveStreaming!.getNumberOfChairs ?? 0,
    );

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
    _initThemeSync(); // Theme synchronization using room properties
    _animationController = AnimationController.unbounded(vsync: this);
    _musicListener = _onMusicStateChanged;
    ZegoLiveAudioRoomManager().musicStateNoti.addListener(_musicListener);
    print("📢 [ANNOUNCEMENT DEBUG] initState() completed successfully");
  }

  @override
  void dispose() {
    super.dispose();
    WakelockPlus.disable();
    showGiftSendersController.isPrivateLive.value = false;
    if (subscription != null) {
      liveQuery.client.unSubscribe(subscription!);
    }
    subscription = null;
    _avatarWidgetsCache.clear();
    _resetSeatCounter();
    _destroyMusicPlayer();
    ZegoLiveAudioRoomManager().musicStateNoti.removeListener(
        _musicListener); // Clear seat mappings and reset counter
    _announcementsNotifier.dispose(); // Clean up announcement notifier

    // Optional: clear theme listener if you registered one
    _themePropertySubscription?.cancel();
  }

  var userAvatar;

  final isSeatClosedNotifier = ValueNotifier<bool>(false);
  final isRequestingNotifier = ValueNotifier<bool>(false);

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
                    sendMessage("has_entered_the_room".tr());
                  }
                },
                onLeave: (user) {
                  sendMessage("has_left_the_room".tr());
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

                // Get seat index from extraInfo or calculate it
                int? seatIndex = extraInfo['seatIndex'] as int?;

                Widget avatarWidget;
                if (user == null) {
                  // Empty seat
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

                // Only show clickable overlay for hosts
                if (!widget.isHost!) return SizedBox.shrink();

                // Calculate seat index using our method
                final int seatIndex = _calculateSeatIndex(user?.id);
                print("📍 Calculated seat index: $seatIndex");

                // Don't make host seat (index 0) clickable
                if (seatIndex == 0) {
                  print("🚫 Host seat - not clickable");
                  return SizedBox.shrink();
                }

                // Return invisible clickable overlay (no visual indicators)
                return Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      print(
                        "🔥 SEAT FOREGROUND CLICKED! User: ${user?.id ?? 'empty'}",
                      );
                      print("🎯 Using seat index: $seatIndex");

                      showSeatActionMenu(
                        context: context,
                        currentUser: widget.currentUser!,
                        seatIndex: seatIndex,
                        onActionSelected: handleSeatAction,
                      );
                    },
                    child: Container(
                      // Invisible container - no visual indicators
                      color: Colors.transparent,
                    ),
                  ),
                );
              }
              ..seat.layout.rowConfigs = List.generate(numberOfSeats, (
                index,
              ) {
                if (index == 0) {
                  return ZegoLiveAudioRoomLayoutRowConfig(
                    count: 1,
                    alignment: ZegoLiveAudioRoomLayoutAlignment.center,
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

          // Announcement Overlay
          ValueListenableBuilder<List<AnnouncementData>>(
            valueListenable: _announcementsNotifier,
            builder: (context, announcements, child) {
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
        // Add to local announcements list
        final announcementData = AnnouncementData.fromLiveMessage(
          announcementMessage,
        );
        setState(() {
          _announcements.add(announcementData);
          _announcementsNotifier.value = List.from(_announcements);
        });

        // Send via ZIM for real-time delivery
        final zimMessage = {
          'type': 'announcement',
          'title': title,
          'message': message,
          'priority': priority,
          'duration': duration,
          'authorName': widget.currentUser!.getFullName!,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        // Use existing ZIM infrastructure
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

        // Red debug button for hosts
        if (widget.isHost!)
          Positioned(
            top: 100,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: MaterialButton(
                onPressed: () {
                  print("Debug button pressed");
                  handleSeatAction('lock', 0); // Test lock action on seat 0
                },
                child: Text(
                  "TEST SEAT",
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
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

  // Track seat assignments using sequential indexing
  int _seatBuildCount = 0;
  final Map<String, int> _userSeatMap = {};

  // Helper method to calculate seat index based on build order
  int _calculateSeatIndex(String? userId) {
    final currentSeatIndex = _seatBuildCount++;

    print("🪑 Seat build #$currentSeatIndex for user: ${userId ?? 'empty'}");

    // First seat (index 0) is typically the host - skip for non-hosts
    if (currentSeatIndex == 0) {
      print("🪑 Host seat detected (index 0) - skipping management");
      return 0;
    }

    // For other seats, use sequential indexing (1, 2, 3, etc.)
    print("🪑 Regular seat assigned index: $currentSeatIndex");
    return currentSeatIndex;
  }

  // Reset seat counter when needed
  void _resetSeatCounter() {
    _seatBuildCount = 0;
    _userSeatMap.clear();
  }

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
      QuickHelp.showLoadingDialog(context);

      // Update local state
      showGiftSendersController.lockSeat(seatIndex);

      // Update backend - Add specific user to locked seats list
      String seatUserId = "seat_$seatIndex";
      widget.liveStreaming!.addRemovedUserIds = seatUserId;

      ParseResponse response = await widget.liveStreaming!.save();
      if (response.success) {
        QuickHelp.hideLoadingDialog(context);
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "success".tr(),
          message: "Seat ${seatIndex + 1} locked successfully",
        );
      } else {
        QuickHelp.hideLoadingDialog(context);
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
      showGiftSendersController.unlockSeat(seatIndex); // Revert local state
      print("Error locking seat: $e");
    }
  }

  Future<void> unlockSeat(int seatIndex) async {
    try {
      QuickHelp.showLoadingDialog(context);

      // Update local state
      showGiftSendersController.unlockSeat(seatIndex);

      // Update backend - Remove from locked seats list
      String seatUserId = "seat_$seatIndex";
      widget.liveStreaming!.removeRemovedUserIds = seatUserId;

      ParseResponse response = await widget.liveStreaming!.save();
      if (response.success) {
        QuickHelp.hideLoadingDialog(context);
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "success".tr(),
          message: "Seat ${seatIndex + 1} unlocked successfully",
        );
      } else {
        QuickHelp.hideLoadingDialog(context);
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

      // Update local seat state to show invited user
      showGiftSendersController.updateSeatState(
        seatIndex,
        'userId',
        user.objectId,
      );
      showGiftSendersController.updateSeatState(
        seatIndex,
        'userName',
        user.getFullName,
      );

      // Send invitation message
      sendMessage(
        "invite_to_seat".tr(
          namedArgs: {
            "name": user.getFirstName ?? "User",
            "seat": "${seatIndex + 1}",
          },
        ),
      );

      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "invite_friends.invited".tr(),
        message: "invite_friends.invitation_sent".tr(
          namedArgs: {
            "name": user.getFirstName ?? "User",
            "seat": "${seatIndex + 1}",
          },
        ),
      );
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "error".tr(),
        message: "invite_friends.invitation_failed".tr(),
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

// ignore_for_file: unused_local_variable, must_be_immutable, deprecated_member_use

import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:text_scroll/text_scroll.dart';

import '../../../../../app/setup.dart';
import '../../../../../helpers/quick_actions.dart';
import '../../../../../helpers/quick_cloud.dart';
import '../../../../../helpers/quick_help.dart';
import '../../../../../models/GiftSendersModel.dart';
import '../../../../../models/LiveStreamingModel.dart';
import '../../../../../models/LiveViewersModel.dart';
import '../../../../../models/NotificationsModel.dart';
import '../../../../../models/UserModel.dart';
import '../../../../../ui/container_with_corner.dart';
import '../../../../../ui/text_with_tap.dart';
import '../../../../../utils/colors.dart';
import '../../../components/components.dart';
import '../../../utils/zegocloud_token.dart';
import '../../../zego_live_streaming_manager.dart';
import '../../../zego_sdk_key_center.dart';
import 'live_command.dart';

part 'live_page_buttons.dart';

part 'live_page_gift.dart';

part 'live_page_pk.dart';

class ZegoNormalLivePage extends StatefulWidget {
  UserModel? currentUser;
  SharedPreferences? preferences;
  LiveStreamingModel? mLiveStreaming;
  ZegoNormalLivePage(
      {super.key,
      required this.liveStreamingManager,
      required this.roomID,
      required this.role,
      this.externalControlCommand,
      this.mLiveStreaming,
      this.previewHostID,
      this.currentUser,
      this.preferences});

  final ZegoLiveStreamingManager liveStreamingManager;

  final String roomID;
  final ZegoLiveStreamingRole role;

  /// Use the command-driven APIs.
  /// If external control is required, pass in an external command.
  final ZegoLivePageCommand? externalControlCommand;

  /// Cross-room users, only for preview
  final String? previewHostID;

  @override
  State<ZegoNormalLivePage> createState() => ZegoNormalLivePageState();
}

class ZegoNormalLivePageState extends State<ZegoNormalLivePage> {
  List<StreamSubscription> subscriptions = [];

  ValueNotifier<bool> applying = ValueNotifier(false);
  ZegoLivePageCommand? defaultCommand;

  bool showingDialog = false;
  bool showingPKDialog = false;

  var swipingData = ZegoLivePageSwipingData();

  double get kButtonSize => 30;

  ZIMService get zimService => ZEGOSDKManager().zimService;

  ExpressService get expressService => ZEGOSDKManager().expressService;

  TextEditingController liveTitleTextController = TextEditingController();
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  bool showErrorOnTitleInput = false;
  var liveSubTypeSelected = [];
  ScrollController _scrollController = new ScrollController();

  bool shuffled = false, isBroadcaster = false, following = true;

  var liveTitle = [
    "random_live_title.live_chat".tr(),
    "random_live_title.playing_chat".tr(),
    "random_live_title.live_cooking".tr(),
    "random_live_title.leve_music".tr(),
    "random_live_title.live_meme".tr(),
    "random_live_title.relaxing_live".tr(),
    "random_live_title.complete_live".tr(),
    "random_live_title.drawing_live".tr(),
    "random_live_title.to_films".tr(),
  ];

  @override
  void initState() {
    super.initState();
    liveTitle.add("random_live_title.live_with_me".tr(
      namedArgs: {"name": "${widget.currentUser!.getUsername}"},
    ));
    widget.liveStreamingManager.currentUserRoleNotifier.value = widget.role;
    liveTitle.shuffle();
    liveTitleTextController.text = liveTitle[3];
    liveSubTypeSelected.add(QuickHelp.getLiveTagsList()[0]);

    registerCommandEvent();

    addPreviewUserUpdateListeners();
    addRoomLoginListeners();

    if (!hasExternalCommand) {
      command
        ..registerEvent()
        ..join();
    }

    initGift();
  }

  @override
  void dispose() {
    super.dispose();

    removePreviewUserUpdateListeners();
    removeRoomLoginListeners();

    uninitGift();

    if (!hasExternalCommand) {
      command
        ..unregisterEvent()
        ..leave();
    }

    unregisterCommandEvent();
  }

  @override
  Widget build(Object context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.liveStreamingManager.isLivingNotifier,
      builder: (context, isLiving, _) {
        return ValueListenableBuilder<RoomPKState>(
          valueListenable: widget.liveStreamingManager.pkStateNotifier,
          builder: (context, RoomPKState pkState, child) {
            return Scaffold(
              resizeToAvoidBottomInset: false,
              body: Stack(
                alignment: AlignmentDirectional.topCenter,
                children: [
                  backgroundImage(),
                  hostVideoView(isLiving, pkState),
                  Positioned(
                    right: 20,
                    top: 100,
                    child: coHostVideoView(isLiving, pkState),
                  ),
                  Positioned(
                    bottom: 120,
                    left: 30,
                    child: cohostRequestListButton(isLiving, pkState),
                  ),
                  Positioned(
                    bottom: 80,
                    left: 30,
                    child: pkButton(isLiving, pkState),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: bottomBar(isLiving, pkState),
                  ),
                  Positioned(
                    bottom: 60,
                    left: 0,
                    right: 0,
                    child: startLiveButton(isLiving, pkState),
                  ),
                  Positioned(
                    top: 90,
                    //right: 30,
                    child: liveTitleAndTags(isLiving, pkState),
                  ),
                  Positioned(
                    top: 50,
                    right: 20,
                    child: leaveButton(),
                  ),
                  giftForeground(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget header() {
    Size size = MediaQuery.sizeOf(context);
    return Row(
      children: [
        ContainerCorner(
          height: 30,
          borderRadius: 50,
          color: Colors.black.withOpacity(0.5),
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
                        widget.mLiveStreaming!.getAuthor!,
                        width: 35,
                        height: 35),
                    borderRadius: 50,
                    height: 40,
                    width: 40,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ContainerCorner(
                        width: 65,
                        child: TextScroll(
                          widget.mLiveStreaming!.getAuthor!.getFullName!,
                          mode: TextScrollMode.endless,
                          velocity: Velocity(pixelsPerSecond: Offset(30, 0)),
                          delayBefore: Duration(seconds: 1),
                          pauseBetween: Duration(milliseconds: 150),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 10,
                          ),
                          Flexible(
                            child: ContainerCorner(
                              width: 30,
                              height: 12,
                              borderWidth: 0,
                              marginLeft: 3,
                              marginBottom: 1,
                              child: countViewers(),
                            ),
                          ),
                        ],
                      )
                    ],
                  )
                ],
              ),
              Visibility(
                visible: !isBroadcaster,
                child: ContainerCorner(
                  marginLeft: 15,
                  marginRight: 6,
                  color: following ? Colors.blueAccent : kPrimaryColor,
                  child: ContainerCorner(
                      color: kTransparentColor,
                      marginAll: 5,
                      height: 23,
                      width: 23,
                      child: Center(
                        child: Icon(
                          following ? Icons.done : Icons.person_add_alt,
                          color: Colors.white,
                          size: 12,
                        ),
                      )),
                  borderRadius: 50,
                  height: 23,
                  width: 23,
                  onTap: () {
                    if (!following) {
                      followOrUnfollow(widget.mLiveStreaming!.getAuthor!);
                    }
                  },
                ),
              ),
              ContainerCorner(
                marginLeft: isBroadcaster ? 15 : 3,
                marginRight: 6,
                color: Colors.white,
                borderRadius: 50,
                height: 23,
                width: 23,
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Lottie.asset("assets/lotties/ic_live_animation.json"),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ContainerCorner(
            width: size.width / 3.3,
            marginLeft: 5,
            height: 36,
            child: getTopGifters(),
          ),
        ),
      ],
    );
  }

  void followOrUnfollow(UserModel mUser) async {
    if (widget.currentUser!.getFollowing!.contains(mUser.objectId)) {
      widget.currentUser!.removeFollowing = mUser.objectId!;
      widget.mLiveStreaming!.removeFollower = widget.currentUser!.objectId!;

      setState(() {
        following = false;
      });
    } else {
      widget.currentUser!.setFollowing = mUser.objectId!;
      widget.mLiveStreaming!.addFollower = widget.currentUser!.objectId!;

      setState(() {
        following = true;
      });
    }

    await widget.currentUser!.save();
    widget.mLiveStreaming!.save();

    ParseResponse parseResponse = await QuickCloudCode.followUser(
        author: widget.currentUser!, receiver: mUser);

    if (parseResponse.success) {
      QuickActions.createOrDeleteNotification(widget.currentUser!, mUser,
          NotificationsModel.notificationTypeFollowers);
    }
  }

  Widget getTopGifters() {
    QueryBuilder<GiftsSenderModel> query =
        QueryBuilder<GiftsSenderModel>(GiftsSenderModel());

    query.includeObject([
      GiftsSenderModel.keyAuthor,
    ]);

    query.whereEqualTo(
        GiftsSenderModel.keyLiveId, widget.mLiveStreaming!.objectId);
    query.setLimit(3);
    query.orderByDescending(GiftsSenderModel.keyDiamonds);

    return ParseLiveListWidget<GiftsSenderModel>(
      query: query,
      reverse: false,
      lazyLoading: false,
      shrinkWrap: true,
      scrollDirection: Axis.horizontal,
      duration: const Duration(milliseconds: 200),
      childBuilder: (BuildContext context,
          ParseLiveListElementSnapshot<GiftsSenderModel> snapshot) {
        if (snapshot.hasData) {
          GiftsSenderModel giftSender = snapshot.loadedData!;

          return ContainerCorner(
            height: 30,
            width: 30,
            borderWidth: 0,
            borderRadius: 50,
            marginRight: 7,
            child: QuickActions.avatarWidget(
              giftSender.getAuthor!,
              height: 30,
              width: 30,
            ),
          );
        } else {
          return const SizedBox();
        }
      },
      listLoadingElement: const SizedBox(),
    );
  }

  Widget countViewers() {
    QueryBuilder<LiveViewersModel> query =
        QueryBuilder<LiveViewersModel>(LiveViewersModel());

    query.whereEqualTo(
        LiveViewersModel.keyLiveId, widget.mLiveStreaming!.objectId);
    query.whereEqualTo(LiveViewersModel.keyWatching, true);
    query.whereEqualTo(
        LiveViewersModel.keyLiveAuthorId, widget.mLiveStreaming!.getAuthorId);

    var viewers = [];
    int? indexToRemove;

    return ParseLiveListWidget<LiveViewersModel>(
      query: query,
      scrollController: _scrollController,
      reverse: false,
      lazyLoading: false,
      shrinkWrap: true,
      scrollDirection: Axis.vertical,
      duration: const Duration(milliseconds: 200),
      childBuilder: (BuildContext context,
          ParseLiveListElementSnapshot<LiveViewersModel> snapshot) {
        if (snapshot.failed) {
          return showViewersCount(amountText: "${viewers.length}");
        }

        if (snapshot.hasData) {
          LiveViewersModel liveViewer = snapshot.loadedData!;

          if (!viewers.contains(liveViewer.getAuthorId)) {
            if (liveViewer.getWatching!) {
              viewers.add(liveViewer.getAuthorId);

              WidgetsBinding.instance.addPostFrameCallback((_) async {
                return await _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 5),
                    curve: Curves.easeInOut);
              });
            }
          } else {
            if (!liveViewer.getWatching!) {
              for (int i = 0; i < viewers.length; i++) {
                if (viewers[i] == liveViewer.getAuthorId) {
                  indexToRemove = i;
                }
              }

              viewers.removeAt(indexToRemove!);
            }
          }

          return showViewersCount(
              amountText: "${QuickHelp.convertToK(viewers.length)}");
        } else {
          return showViewersCount(amountText: "${viewers.length}");
        }
      },
      listLoadingElement: showViewersCount(amountText: "${viewers.length}"),
      queryEmptyElement: showViewersCount(amountText: "${viewers.length}"),
    );
  }

  Widget showViewersCount({required String amountText}) {
    return TextWithTap(
      amountText,
      color: Colors.white,
      fontSize: 9,
      marginLeft: 3,
    );
  }

  Widget bottomBar(bool isLiving, RoomPKState pkState) {
    if (!isLiving) return const SizedBox.shrink();

    if (pkState != RoomPKState.isStartPK ||
        widget.liveStreamingManager.iamHost()) {
      return ZegoLiveBottomBar(
        applying: applying,
        liveStreamingManager: widget.liveStreamingManager,
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget backgroundImage() {
    return Image.asset(
      'assets/images/live_bg.png',
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.fill,
    );
  }

  Widget hostVideoView(bool isLiving, RoomPKState pkState) {
    return ValueListenableBuilder(
      valueListenable: widget.liveStreamingManager.onPKViewAvailableNotifier,
      builder: (context, bool showPKView, _) {
        if (pkState == RoomPKState.isStartPK) {
          return ValueListenableBuilder<List<PKUser>>(
              valueListenable: widget.liveStreamingManager.pkInfo!.pkUserList,
              builder: (context, pkUsers, _) {
                /// in sliding, if it is not the current display room, the PK view is not displayed
                var isCurrentRoomHostTakingPK = false;
                if (pkUsers.isNotEmpty) {
                  final mainHost = pkUsers.first;
                  isCurrentRoomHostTakingPK = mainHost.userID ==
                          widget.liveStreamingManager.hostNotifier.value
                              ?.userID &&
                      mainHost.roomID == widget.roomID;
                }
                if (isCurrentRoomHostTakingPK) {
                  if (showPKView || widget.liveStreamingManager.iamHost()) {
                    return hostVideoViewInPK();
                  } else {
                    return hostVideoViewFromManagerNotifier();
                  }
                } else {
                  return ZegoLiveStreamingRole.host == widget.role
                      ? hostVideoViewFromManagerNotifier()
                      : hostVideoViewFromSwipingNotifier();
                }
              });
        } else {
          return ZegoLiveStreamingRole.host == widget.role
              ? hostVideoViewFromManagerNotifier()
              : hostVideoViewFromSwipingNotifier();
        }
      },
    );
  }

  Widget hostVideoViewInPK() {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          Positioned(
            top: 100,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxWidth * 16 / 18,
              child: ZegoPKContainerView(
                liveStreamingManager: widget.liveStreamingManager,
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget hostVideoViewFromManagerNotifier() {
    return ValueListenableBuilder(
      valueListenable: widget.liveStreamingManager.hostNotifier,
      builder: (context, host, _) {
        if (widget.liveStreamingManager.hostNotifier.value == null) {
          return const SizedBox.shrink();
        }

        return ZegoAudioVideoView(
          userInfo: widget.liveStreamingManager.hostNotifier.value!,
        );
      },
    );
  }

  Widget hostVideoViewFromSwipingNotifier() {
    /// Core rendering logic for scrolling up and down preview
    return ValueListenableBuilder<ZegoSDKUser?>(
      valueListenable: swipingData.hostNotifier,
      builder: (context, host, _) {
        final r = widget.roomID;
        return null == host
            ? const SizedBox.shrink()
            : ZegoAudioVideoView(userInfo: host);
      },
    );
  }

  ZegoSDKUser? getHostUser() {
    if (widget.role == ZegoLiveStreamingRole.host) {
      return ZEGOSDKManager().currentUser;
    } else {
      for (final userInfo in expressService.userInfoList) {
        if (userInfo.streamID != null) {
          if (userInfo.streamID!.endsWith('_host')) {
            return userInfo;
          }
        }
      }
    }

    return null;
  }

  Widget coHostVideoView(bool isLiving, RoomPKState pkState) {
    if (pkState != RoomPKState.isStartPK) {
      return Builder(builder: (context) {
        final height =
            (MediaQuery.of(context).size.height - kButtonSize - 100) / 4;
        final width = height * (9 / 16);

        return ValueListenableBuilder<List<ZegoSDKUser>>(
          valueListenable: widget.liveStreamingManager.coHostUserListNotifier,
          builder: (context, cohostList, _) {
            final videoList = widget
                .liveStreamingManager.coHostUserListNotifier.value
                .map((user) {
              return ZegoAudioVideoView(userInfo: user);
            }).toList();

            return SizedBox(
              width: width,
              height: MediaQuery.of(context).size.height - kButtonSize - 150,
              child: ListView.separated(
                reverse: true,
                itemCount: videoList.length,
                itemBuilder: (context, index) {
                  return SizedBox(
                      width: width, height: height, child: videoList[index]);
                },
                separatorBuilder: (context, index) {
                  return const SizedBox(height: 10);
                },
              ),
            );
          },
        );
      });
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget startLiveButton(bool isLiving, RoomPKState pkState) {
    if (!isLiving && widget.role == ZegoLiveStreamingRole.host) {
      Size size = MediaQuery.of(context).size;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Visibility(
            visible: false,
            child: Image.asset(
              "assets/images/ic_room_bottom_beauty.webp",
              height: 45,
            ),
          ),
          ContainerCorner(
            color: kPrimaryColor,
            borderWidth: 0,
            height: 45,
            borderRadius: 50,
            marginLeft: 10,
            width: size.width / 1.8,
            onTap: () {
              if (formKey.currentState!.validate()) {
                startLive();
              }
            },
            child: TextWithTap(
              "live_start_screen.start_live_streaming".tr(),
              color: Colors.white,
              alignment: Alignment.center,
            ),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget liveTitleAndTags(bool isLiving, RoomPKState pkState) {
    if (!isLiving && widget.role == ZegoLiveStreamingRole.host) {
      Size size = MediaQuery.of(context).size;
      return ContainerCorner(
        height: 110,
        width: size.width - 30,
        color: Colors.black.withOpacity(0.1),
        borderRadius: 20,
        borderWidth: 0,
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ContainerCorner(
                marginTop: 10,
                height: 40,
                width: size.width,
                borderRadius: 10,
                marginLeft: 10,
                marginRight: 10,
                borderColor:
                    showErrorOnTitleInput ? Colors.red : kTransparentColor,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: TextFormField(
                    controller: liveTitleTextController,
                    maxLines: 1,
                    autocorrect: false,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "live_streaming.enter_title".tr(),
                      hintStyle: GoogleFonts.roboto(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      errorStyle: GoogleFonts.roboto(
                        fontSize: 0.0,
                      ),
                    ),
                    autovalidateMode: AutovalidateMode.disabled,
                    validator: (value) {
                      if (value!.isEmpty) {
                        showErrorOnTitleInput = true;
                        setState(() {});
                        return "";
                      } else {
                        showErrorOnTitleInput = false;
                        setState(() {});
                        return null;
                      }
                    },
                  ),
                ),
              ),
              ContainerCorner(
                marginTop: 15,
                height: 30,
                marginLeft: 10,
                child: ListView(
                  padding: EdgeInsets.zero,
                  scrollDirection: Axis.horizontal,
                  children: List.generate(QuickHelp.getLiveTagsList().length,
                      (index) {
                    bool isSelected = liveSubTypeSelected
                        .contains(QuickHelp.getLiveTagsList()[index]);
                    return ContainerCorner(
                      borderRadius: 10,
                      height: 25,
                      borderWidth: isSelected ? 0 : 1,
                      borderColor:
                          isSelected ? kTransparentColor : Colors.white,
                      color: isSelected ? kPrimaryColor : kTransparentColor,
                      onTap: () {
                        liveSubTypeSelected.clear();
                        liveSubTypeSelected
                            .add(QuickHelp.getLiveTagsList()[index]);
                        setState(() {});
                      },
                      marginRight: 10,
                      child: TextWithTap(
                        QuickHelp.getLiveTagsByCode(
                            QuickHelp.getLiveTagsList()[index]),
                        color: Colors.white,
                        marginLeft: 8,
                        marginRight: 8,
                        alignment: Alignment.center,
                        fontSize: 12,
                      ),
                    );
                  }),
                ),
              )
            ],
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  void startLive() {
    if (liveSubTypeSelected.isEmpty) {
      liveSubTypeSelected.add(
        QuickHelp.getLiveTagsList()[0],
      );
    }
    createLive();
  }

  void createLive() async {
    QuickHelp.showLoadingDialog(context, isDismissible: false);

    QueryBuilder<LiveStreamingModel> queryBuilder =
        QueryBuilder(LiveStreamingModel());
    queryBuilder.whereEqualTo(
        LiveStreamingModel.keyAuthorId, widget.currentUser!.objectId);
    queryBuilder.whereEqualTo(LiveStreamingModel.keyStreaming, true);

    ParseResponse parseResponse = await queryBuilder.query();
    if (parseResponse.success) {
      if (parseResponse.results != null) {
        LiveStreamingModel live =
            parseResponse.results!.first! as LiveStreamingModel;

        live.setStreaming = false;
        await live.save();

        createLiveFinish();
      } else {
        createLiveFinish();
      }
    } else {
      QuickHelp.hideLoadingDialog(context);

      QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "live_streaming.live_set_cover_error".tr(),
          message: parseResponse.error!.message,
          isError: true,
          user: widget.currentUser);
    }
  }

  createLiveFinish() async {
    LiveStreamingModel streamingModel = LiveStreamingModel();
    if (Setup.isDebug) print("Check live 1");
    streamingModel.setStreamingChannel =
        widget.currentUser!.objectId! + widget.currentUser!.getUid!.toString();
    if (Setup.isDebug) print("Check live 2");
    streamingModel.setAuthor = widget.currentUser!;
    if (Setup.isDebug) print("Check live 3");
    streamingModel.setAuthorId = widget.currentUser!.objectId!;
    if (Setup.isDebug) print("Check live 4");
    streamingModel.setAuthorUid = widget.currentUser!.getUid!;
    if (Setup.isDebug) print("Check live 5");
    streamingModel.addAuthorTotalDiamonds =
        widget.currentUser!.getDiamondsTotal!;
    if (Setup.isDebug) print("Check live 6");
    streamingModel.setFirstLive = widget.currentUser!.isFirstLive!;
    if (Setup.isDebug) print("Check live 7");

    if (widget.currentUser!.getLiveCover != null) {
      streamingModel.setImage = widget.currentUser!.getLiveCover!;
    } else {
      streamingModel.setImage = widget.currentUser!.getAvatar!;
    }

    if (Setup.isDebug) print("Check live 8");
    if (widget.currentUser!.getGeoPoint != null) {
      if (Setup.isDebug) print("Check live 9");
      streamingModel.setStreamingGeoPoint = widget.currentUser!.getGeoPoint!;
    }

    if (Setup.isDebug) print("Check live 10");

    if (Setup.isDebug) print("Check live 12");
    streamingModel.setPrivate = false;
    if (Setup.isDebug) print("Check live 3");
    streamingModel.setStreaming = true;
    if (Setup.isDebug) print("Check live 14");
    streamingModel.addViewersCount = 0;
    if (Setup.isDebug) print("Check live 15");
    streamingModel.addDiamonds = 0;
    if (Setup.isDebug) print("Check live 16");

    streamingModel.setLiveTitle = liveTitleTextController.text;
    if (Setup.isDebug) print("Check live 16");

    streamingModel.setLiveType = LiveStreamingModel.liveVideo;
    streamingModel.save().then((value) {
      if (Setup.isDebug) print("Check live 17");

      if (value.success) {
        LiveStreamingModel liveStreaming = value.results!.first!;
        setState(() {
          widget.mLiveStreaming = liveStreaming;
        });
        QuickHelp.hideLoadingDialog(context);
        widget.liveStreamingManager
            .startLive(liveStreaming.getStreamingChannel!)
            .then((value) {
          if (value.errorCode != 0) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("live_create_failed"
                    .tr(namedArgs: {"error": "${value.errorCode}"}))));
          } else {
            expressService.startPublishingStream(
                widget.liveStreamingManager.hostStreamID());
          }
        }).catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  "live_create_failed".tr(namedArgs: {"error": "${error}"}))));
        });
        if (widget.currentUser!.isFirstLive!) {
          widget.currentUser!.setIsFirstLive = false;
          widget.currentUser!.save().then((value) {
            if (value.success && value.results != null)
              setState(() {
                widget.currentUser = value.results!.first;
              });
          });
        }
      } else {
        QuickHelp.hideLoadingDialog(context);

        QuickHelp.showAppNotificationAdvanced(
            context: context,
            title: "live_streaming.live_set_cover_error".tr(),
            message: value.error!.message,
            isError: true,
            user: widget.currentUser);
      }

      if (Setup.isDebug) print("Check live 17 (1)");
    }).onError((ParseError error, stackTrace) {
      if (Setup.isDebug) print("Check live 18");

      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "live_streaming.live_set_cover_error".tr(),
          message: "unknown_error".tr(),
          isError: true,
          user: widget.currentUser);
    }).catchError((err) {
      if (Setup.isDebug) print("Check live 19: $err");

      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "live_streaming.live_set_cover_error".tr(),
          message: "unknown_error".tr(),
          isError: true,
          user: widget.currentUser);
    });
  }

  Widget cohostRequestListButton(bool isLiving, RoomPKState pkState) {
    if (isLiving &&
        (widget.role == ZegoLiveStreamingRole.host) &&
        (pkState != RoomPKState.isStartPK)) {
      return const CoHostRequestListButton();
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget hostText() {
    return ValueListenableBuilder<ZegoSDKUser?>(
      valueListenable: swipingData.hostNotifier,
      builder: (context, userInfo, _) {
        return Text(
          'RoomID: ${widget.roomID}\n'
          'HostID: ${userInfo?.userID ?? ''}',
          style: const TextStyle(
              fontSize: 8, color: Color.fromARGB(255, 104, 94, 94)),
        );
      },
    );
  }

  Widget leaveButton() {
    return CommonButton(
      width: 24,
      height: 24,
      padding: const EdgeInsets.all(6),
      onTap: () {
        Navigator.pop(context);
      },
      child: Image.asset('assets/icons/nav_close.png'),
    );
  }

  Widget pkButton(bool isLiving, RoomPKState pkState) {
    if (isLiving && widget.role == ZegoLiveStreamingRole.host) {
      return PKButton(
        liveStreamingManager: widget.liveStreamingManager,
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  void onExpressRoomStateChanged(ZegoRoomStateEvent event) {
    debugPrint('LivePage:onExpressRoomStateChanged: $event');

    if (event.roomID != widget.roomID) {
      return;
    }

    if (event.errorCode != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1000),
          content: Text(
              'onExpressRoomStateChanged: reason:${event.reason.name}, errorCode:${event.errorCode}'),
        ),
      );
    }

    if ((event.reason == ZegoRoomStateChangedReason.KickOut) ||
        (event.reason == ZegoRoomStateChangedReason.ReconnectFailed) ||
        (event.reason == ZegoRoomStateChangedReason.LoginFailed)) {
      Navigator.pop(context);
    }
  }

  void onZIMRoomStateChanged(ZIMServiceRoomStateChangedEvent event) {
    debugPrint('LivePage:onZIMRoomStateChanged: $event');

    if (event.roomID != widget.roomID) {
      return;
    }

    if ((event.event != ZIMRoomEvent.success) &&
        (event.state != ZIMRoomState.connected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1000),
          content: Text('onZIMRoomStateChanged: $event'),
        ),
      );
    }
    if (event.state == ZIMRoomState.disconnected) {
      if (mounted) Navigator.pop(context);
    }
  }

  void onZIMConnectionStateChanged(
      ZIMServiceConnectionStateChangedEvent event) {
    debugPrint('LivePage:onZIMConnectionStateChanged: $event');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1000),
        content: Text('onZIMConnectionStateChanged: $event'),
      ),
    );
    if (event.state == ZIMConnectionState.disconnected) {
      Navigator.pop(context);
    }
  }

  void onInComingRoomRequest(OnInComingRoomRequestReceivedEvent event) {}

  void onInComingRoomRequestCancel(OnInComingRoomRequestCancelledEvent event) {}

  void onOutgoingRoomRequestAccepted(OnOutgoingRoomRequestAcceptedEvent event) {
    applying.value = false;
    widget.liveStreamingManager.startCoHost();
  }

  void onOutgoingRoomRequestRejected(OnOutgoingRoomRequestRejectedEvent event) {
    applying.value = false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(milliseconds: 1000),
        content:
            Text('Your request to co-host with the host has been refused.'),
      ),
    );
  }

  void showApplyCohostDialog() {
    RoomRequestListView.showBasicModalBottomSheet(context);
  }

  void refuseApplyCohost(RoomRequest roomRequest) {
    zimService
        .rejectRoomRequest(roomRequest.requestID ?? '')
        .then((value) {})
        .catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Disagree cohost failed: $error')));
    });
  }
}

extension ZegoLivePageStateCommand on ZegoNormalLivePageState {
  /// Whether to enable external command control, if not, then it is internal control
  bool get hasExternalCommand => null != widget.externalControlCommand;

  /// current command
  ZegoLivePageCommand get command =>
      widget.externalControlCommand ?? lazyCreateDefaultCommand();

  /// default internal command
  ZegoLivePageCommand lazyCreateDefaultCommand() {
    defaultCommand ??= ZegoLivePageCommand(roomID: widget.roomID);

    return defaultCommand!;
  }

  void registerCommandEvent() {
    command.joinRoomCommand.addListener(onJoinRoomCommand);
    command.leaveRoomCommand.addListener(onLeaveRoomCommand);
    command.registerEventCommand.addListener(onRegisterEventCommand);
    command.unregisterEventCommand.addListener(onUnregisterEventCommand);
  }

  void unregisterCommandEvent() {
    command.joinRoomCommand.removeListener(onJoinRoomCommand);
    command.leaveRoomCommand.removeListener(onLeaveRoomCommand);
    command.registerEventCommand.removeListener(onRegisterEventCommand);
    command.unregisterEventCommand.removeListener(onUnregisterEventCommand);
  }

  void onRegisterEventCommand() {
    debugPrint('xxxx onRegisterEventCommand');
    for (final subscription in subscriptions) {
      subscription.cancel();
    }

    subscriptions.addAll([
      expressService.roomStateChangedStreamCtrl.stream
          .listen(onExpressRoomStateChanged),
      zimService.roomStateChangedStreamCtrl.stream
          .listen(onZIMRoomStateChanged),
      zimService.connectionStateStreamCtrl.stream
          .listen(onZIMConnectionStateChanged),
      zimService.onInComingRoomRequestStreamCtrl.stream
          .listen(onInComingRoomRequest),
      zimService.onInComingRoomRequestCancelledStreamCtrl.stream
          .listen(onInComingRoomRequestCancel),
      zimService.onOutgoingRoomRequestAcceptedStreamCtrl.stream
          .listen(onOutgoingRoomRequestAccepted),
      zimService.onOutgoingRoomRequestRejectedStreamCtrl.stream
          .listen(onOutgoingRoomRequestRejected),
    ]);
    listenPKEvents();
  }

  void onUnregisterEventCommand() {
    debugPrint('xxxx onUnregisterEventCommand');

    for (final subscription in subscriptions) {
      subscription.cancel();
    }
  }

  void onJoinRoomCommand() {
    if (widget.role == ZegoLiveStreamingRole.audience) {
      /// Join room now
      String? token;
      if (kIsWeb) {
        // ! ** Warning: ZegoTokenUtils is only for use during testing. When your application goes live,
        // ! ** tokens must be generated by the server side. Please do not generate tokens on the client side!
        token = ZegoTokenUtils.generateToken(
          Setup.zegoLiveStreamAppID,
          Setup.zegoLiveStreamServerSecret,
          ZEGOSDKManager().currentUser!.userID,
        );
      }

      ZEGOSDKManager()
          .loginRoom(widget.roomID, ZegoScenario.Broadcast, token: token)
          .then(
        (value) {
          if (value.errorCode != 0) {
            debugPrint('login room failed: ${value.errorCode}');
          }
        },
      );
    } else if (widget.role == ZegoLiveStreamingRole.host) {
      /// will join room on startLive

      /// cache host
      widget.liveStreamingManager.hostNotifier.value =
          ZEGOSDKManager().currentUser;
      swipingData.hostNotifier.value = ZEGOSDKManager().currentUser;

      /// start preview
      ZEGOSDKManager().expressService.turnCameraOn(true);
      ZEGOSDKManager().expressService.turnMicrophoneOn(true);
      ZEGOSDKManager().expressService.startPreview();
    }
  }

  void onLeaveRoomCommand() {
    ZEGOSDKManager().expressService.stopPreview();

    widget.liveStreamingManager.leaveRoom();
  }
}

class ZegoLivePageSwipingData {
  /// room login notifiers, sliding up and down will cause changes in the state of the room
  var roomLoginNotifier = ZegoRoomLoginNotifier();

  /// room logout notifiers, sliding up and down will cause changes in the state of the room
  var roomLogoutNotifier = ZegoRoomLogoutNotifier();

  /// room ready notifiers, sliding up and down will cause changes in the state of the room
  var roomReadyNotifier = ValueNotifier<bool>(false);

  /// preview host or real host
  var hostNotifier = ValueNotifier<ZegoSDKUser?>(null);
}

extension ZegoLivePageStateSwiping on ZegoNormalLivePageState {
  void addRoomLoginListeners() {
    swipingData.roomLoginNotifier.notifier.addListener(onRoomLoginStateChanged);
    swipingData.roomLogoutNotifier.notifier
        .addListener(onRoomLogoutStateChanged);
    swipingData.roomLoginNotifier.resetCheckingData(widget.roomID);
    swipingData.roomLogoutNotifier.resetCheckingData(widget.roomID);
  }

  void removeRoomLoginListeners() {
    swipingData.roomLoginNotifier.notifier
        .removeListener(onRoomLoginStateChanged);
    swipingData.roomLogoutNotifier.notifier
        .removeListener(onRoomLogoutStateChanged);
  }

  void onRoomLoginStateChanged() {
    if (swipingData.roomLoginNotifier.notifier.value) {
      swipingData.roomLogoutNotifier.resetCheckingData(widget.roomID);
      swipingData.roomReadyNotifier.value = true;
    }
  }

  void onRoomLogoutStateChanged() {
    if (swipingData.roomLogoutNotifier.notifier.value) {
      swipingData.roomLoginNotifier.resetCheckingData(widget.roomID);
      swipingData.roomReadyNotifier.value = false;
    }
  }

  void addPreviewUserUpdateListeners() {
    if (ZegoLiveStreamingRole.host == widget.role) {
      return;
    }

    /// Monitor cross-room user updates
    if (widget.previewHostID != null) {
      final previewUser = expressService.getRemoteUser(widget.previewHostID!);
      if (null != previewUser) {
        /// remote user's stream is playing
        swipingData.hostNotifier.value = previewUser;
      }
    }

    ///  in sliding, the room/host will switch, so need to listen for
    ///  changes in the flow
    onRemoteStreamUserUpdated();
    expressService.remoteStreamUserInfoListNotifier
        .addListener(onRemoteStreamUserUpdated);
    onHostUpdated();
    widget.liveStreamingManager.hostNotifier.addListener(onHostUpdated);
  }

  void removePreviewUserUpdateListeners() {
    expressService.remoteStreamUserInfoListNotifier
        .removeListener(onRemoteStreamUserUpdated);
  }

  void onRemoteStreamUserUpdated() {
    if (!mounted) return;

    if (widget.previewHostID != null) {
      final previewUser = expressService.getRemoteUser(widget.previewHostID!);
      if (null != previewUser) {
        /// remote user's stream start playing
        swipingData.hostNotifier.value = previewUser;
      }
    }
  }

  void onHostUpdated() {
    if (expressService.currentRoomID == widget.roomID) {
      /// Sliding the LIVE room will trigger it, which only takes effect for updates caused by the current room
      if (null != widget.liveStreamingManager.hostNotifier.value) {
        /// To prevent the preview from flashing when sliding the LIVE room, the host caused by checking out is null
        swipingData.hostNotifier.value =
            widget.liveStreamingManager.hostNotifier.value;
      }
    }
  }
}

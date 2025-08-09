// ignore_for_file: must_be_immutable

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../models/LiveStreamingModel.dart';
import '../../../../models/UserModel.dart';
import '../../zego_live_streaming_manager.dart';
import 'normal/live_page.dart';
import 'swiping/defines.dart';
import 'swiping/live_page.dart';

class ZegoLivePage extends StatefulWidget {
  UserModel? currentUser;
  SharedPreferences? preferences;
  LiveStreamingModel? mLiveStreaming;

  ZegoLivePage({
    super.key,
    this.roomID = '',
    this.role = ZegoLiveStreamingRole.audience,
    this.swipingConfig,
    this.preferences,
    this.currentUser,
    this.mLiveStreaming
  });

  final String roomID;
  final ZegoLiveStreamingRole role;
  final ZegoLiveSwipingConfig? swipingConfig;

  @override
  State<ZegoLivePage> createState() => ZegoLivePageState();
}

class ZegoLivePageState extends State<ZegoLivePage> {
  final liveStreamingManager = ZegoLiveStreamingManager();

  @override
  void initState() {
    super.initState();

    liveStreamingManager.init();
  }

  @override
  void dispose() {
    super.dispose();

    liveStreamingManager.uninit();
  }

  @override
  Widget build(BuildContext context) {
    return null == widget.swipingConfig
        ? ZegoNormalLivePage(
            liveStreamingManager: liveStreamingManager,
            roomID: widget.roomID,
            mLiveStreaming: widget.mLiveStreaming,
            role: widget.role,
            currentUser: widget.currentUser,
            preferences: widget.preferences,
          )
        : ZegoSwipingLivePage(
            liveStreamingManager: liveStreamingManager,
            config: widget.swipingConfig!,
          );
  }
}

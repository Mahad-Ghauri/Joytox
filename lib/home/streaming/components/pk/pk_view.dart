import 'dart:async';

import 'package:flutter/material.dart';

import '../../zego_live_streaming_manager.dart';
import 'pk_mute_button.dart';

class PKView extends StatefulWidget {
  const PKView({
    super.key,
    required this.pkUser,
    required this.liveStreamingManager,
  });

  final PKUser pkUser;
  final ZegoLiveStreamingManager liveStreamingManager;

  @override
  State<PKView> createState() => _PKViewState();
}

class _PKViewState extends State<PKView> {
  List<StreamSubscription> subscriptions = [];

  @override
  void initState() {
    super.initState();
    subscriptions.add(widget.liveStreamingManager.onPKUserConnectingCtrl.stream
        .listen(onPKUserConnecting));

    // Ensure proper stream management for PK battles
    _initializePKStream();
  }

  void _initializePKStream() async {
    if (widget.pkUser.userID == ZEGOSDKManager().currentUser!.userID) {
      // For self (host), ensure we're publishing our stream
      if (widget.pkUser.pkUserStream.isNotEmpty) {
        debugPrint(
            'PKView: Starting to publish stream for self: ${widget.pkUser.pkUserStream}');
        await ZEGOSDKManager()
            .expressService
            .startPublishingStream(widget.pkUser.pkUserStream);

        // Ensure camera and mic are on for PK
        ZEGOSDKManager().expressService.turnCameraOn(true);
        ZEGOSDKManager().expressService.turnMicrophoneOn(true);
      }
    } else {
      // For other hosts, start playing their stream
      debugPrint(
          'PKView: Starting to play stream for other host: ${widget.pkUser.pkUserStream}');
      await ZEGOSDKManager().expressService.startPlayingAnotherHostStream(
          widget.pkUser.pkUserStream, widget.pkUser.sdkUser);
    }
  }

  @override
  void dispose() {
    super.dispose();

    // Clean up streams when PK view is disposed
    if (widget.pkUser.userID != ZEGOSDKManager().currentUser!.userID) {
      // Stop playing other host's stream
      ZEGOSDKManager()
          .expressService
          .stopPlayingStream(widget.pkUser.pkUserStream);
    }

    for (final element in subscriptions) {
      element.cancel();
    }
  }

  void onPKUserConnecting(PKBattleUserConnectingEvent event) {
    // if (event.userID == widget.pkUser.userID) {
    //   final pkUserMuted = widget.liveStreamingManager.isPKUserMuted(event.userID);
    //   if (event.duration > 5000) {
    //     if (!pkUserMuted) {
    //       widget.liveStreamingManager.mutePKUser([event.userID], true).then((value) {
    //         if (value.errorCode == 0) {
    mutePlayAudio(true);
    //         }
    //       });
    //     }
    //   } else {
    //     if (pkUserMuted) {
    //       widget.liveStreamingManager.mutePKUser([event.userID], false).then((value) {
    //         if (value.errorCode == 0) {
    //           mutePlayAudio(false);
    //         }
    //       });
    //     }
    //   }
    // }
  }

  void mutePlayAudio(bool mute) {
    ZEGOSDKManager()
        .expressService
        .mutePlayStreamAudio(widget.pkUser.pkUserStream, mute);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: widget.pkUser.connectingDuration,
        builder: (context, int duration, _) {
          if (duration > 5000) {
            return hostReconnecting();
          } else {
            return ValueListenableBuilder(
                valueListenable: widget.pkUser.sdkUser.isCameraOnNotifier,
                builder: (context, bool isCameraOn, _) {
                  if (isCameraOn) {
                    return SizedBox(
                      child: Stack(
                        children: [videoView(), foregroundView()],
                      ),
                    );
                  } else {
                    return SizedBox(
                      child: backGroundView(),
                    );
                  }
                });
          }
        });
  }

  Widget backGroundView() {
    return Stack(
      children: [
        Image.asset(
          'assets/icons/bg.png',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.fill,
        ),
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: const BorderRadius.all(Radius.circular(30.0)),
              border: Border.all(width: 0),
            ),
            child: Center(
              child: SizedBox(
                  height: 20,
                  child: Text(
                    widget.pkUser.userName[0],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  )),
            ),
          ),
        ),
      ],
    );
  }

  Widget foregroundView() {
    if (ZEGOSDKManager().currentUser!.userID == widget.pkUser.userID) {
      return const SizedBox.shrink();
    } else {
      return LayoutBuilder(builder: (context, constraints) {
        return Stack(
          children: [
            Positioned(
              left: constraints.maxWidth - 80,
              top: 20,
              width: 60,
              height: 60,
              child: PKMuteButton(
                pkUser: widget.pkUser,
                liveStreamingManager: widget.liveStreamingManager,
              ),
            )
          ],
        );
      });
    }
  }

  Widget videoView() {
    return ValueListenableBuilder<Widget?>(
      valueListenable: widget.pkUser.sdkUser.videoViewNotifier,
      builder: (context, view, _) {
        if (view != null) {
          return Container(
            color: Colors.blue,
            child: view,
          );
        } else {
          return Container(
            color: Colors.red,
          );
        }
      },
    );
  }

  Widget hostReconnecting() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'Host is reconnecting…',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

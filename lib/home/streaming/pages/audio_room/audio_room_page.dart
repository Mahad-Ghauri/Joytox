// ignore_for_file: must_be_immutable

import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../models/UserModel.dart';
import '../../components/components.dart';
import '../../live_audio_room_manager.dart';
import '../../utils/zegocloud_token.dart';
import '../../zego_sdk_key_center.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import '../../zego_live_audio_room_seat_tile.dart';


part 'audio_room_gift.dart';

class AudioRoomPage extends StatefulWidget {
  UserModel? currentUser;
  SharedPreferences? preferences;
  AudioRoomPage({
    this.currentUser,
    this.preferences,
    super.key,
    required this.roomID,
    required this.role,
  });

  final String roomID;
  final ZegoLiveAudioRoomRole role
  ;

  @override
  State<AudioRoomPage> createState() => AudioRoomPageState();
}

class AudioRoomPageState extends State<AudioRoomPage> {
  List<StreamSubscription> subscriptions = [];
  String? currentRequestID;
  ValueNotifier<bool> isApplyStateNoti = ValueNotifier(false);
  ZegoMediaPlayer? _musicPlayer;
  int _musicPlayerViewID = -1;
  bool _isMusicReady = false;
  late final VoidCallback _musicListener;
  final List<String> _playlistUrls = [
   'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    'https://www.soundjay.com/misc/sounds/bell-ringing-05.wav',
  ];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    final zimService = ZEGOSDKManager().zimService;
    final expressService = ZEGOSDKManager().expressService;
    subscriptions.addAll([
      expressService.roomStateChangedStreamCtrl.stream.listen(onExpressRoomStateChanged),
      zimService.roomStateChangedStreamCtrl.stream.listen(onZIMRoomStateChanged),
      zimService.connectionStateStreamCtrl.stream.listen(onZIMConnectionStateChanged),
      zimService.onInComingRoomRequestStreamCtrl.stream.listen(onInComingRoomRequest),
      zimService.onOutgoingRoomRequestAcceptedStreamCtrl.stream.listen(onOutgoingRoomRequestAccepted),
      zimService.onOutgoingRoomRequestRejectedStreamCtrl.stream.listen(onOutgoingRoomRequestRejected),
      expressService.onMediaPlayerStateUpdateCtrl.stream.listen((event) {
        // keep for future UI updates
      }),
    ]);

    _musicListener = _onMusicStateChanged;
    ZegoLiveAudioRoomManager().musicStateNoti.addListener(_musicListener);

    loginRoom();

    initGift();
  }

  void loginRoom() {
    final token = kIsWeb
        ? ZegoTokenUtils.generateToken(
        SDKKeyCenter.appID, SDKKeyCenter.serverSecret, ZEGOSDKManager().currentUser!.userID)
        : null;
    ZegoLiveAudioRoomManager().loginRoom(widget.roomID, widget.role, token: token).then((result) {
      if (result.errorCode == 0) {
        hostTakeSeat();
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("room_failed".tr()+' error: \${result.errorCode}')));
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    uninitGift();
    ZegoLiveAudioRoomManager().logoutRoom();
    _destroyMusicPlayer();
    ZegoLiveAudioRoomManager().musicStateNoti.removeListener(_musicListener);
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
  }

  Future<void> hostTakeSeat() async {
    if (widget.role == ZegoLiveAudioRoomRole.host) {
      await ZegoLiveAudioRoomManager().setSelfHost();
      await ZegoLiveAudioRoomManager().takeSeat(0, isForce: true).then((result) {
        if (mounted && ((result == null) || result.errorKeys.contains(ZEGOSDKManager().currentUser!.userID))) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("failed_take_seat".tr(namedArgs: {"error":"\$result"}))));
        }
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("failed_take_seat".tr(namedArgs: {"error":"\$error"}))));
      });
    }
  }

  // ===== Music Player host-only controls and sync =====
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
    if (ZegoLiveAudioRoomManager().roleNoti.value != ZegoLiveAudioRoomRole.host) return;
    await _ensureMusicPlayer();
    final source = ZegoMediaPlayerResource.defaultConfig()
      ..filePath = url;
    final result = await _musicPlayer!.loadResourceWithConfig(source);
    if (result.errorCode == 0) {
      _isMusicReady = true;
      _musicPlayer!.start();
      await ZegoLiveAudioRoomManager().setMusicState(MusicPlaybackState(trackUrl: url, isPlaying: true, positionMs: 0));
    }
  }

  Future<void> _hostPause() async {
    if (_musicPlayer == null) return;
    _musicPlayer!.pause();
    final cur = ZegoLiveAudioRoomManager().musicStateNoti.value;
    await ZegoLiveAudioRoomManager().setMusicState((cur ?? MusicPlaybackState.empty()).copyWith(isPlaying: false));
  }

  Future<void> _hostResume() async {
    if (_musicPlayer == null) return;
    _musicPlayer!.resume();
    final cur = ZegoLiveAudioRoomManager().musicStateNoti.value;
    await ZegoLiveAudioRoomManager().setMusicState((cur ?? MusicPlaybackState.empty()).copyWith(isPlaying: true));
  }

  Future<void> _hostStop() async {
    if (_musicPlayer == null) return;
    _musicPlayer!.stop();
    await ZegoLiveAudioRoomManager().setMusicState(MusicPlaybackState.stopped());
  }

  // Apply incoming music state for non-hosts
  void _onMusicStateChanged() {
    final state = ZegoLiveAudioRoomManager().musicStateNoti.value;
    if (state == null) return;
    final isHost = ZegoLiveAudioRoomManager().roleNoti.value == ZegoLiveAudioRoomRole.host;
    if (isHost) return; // host drives the player

    () async {
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
    }();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        body: Stack(
          children: [
            backgroundImage(),
            Positioned(top: 30, right: 20, child: leaveButton()),
            Positioned(top: 100, child: seatListView()),
            Positioned(bottom: 20, left: 0, right: 0, child: bottomView()),
            giftForeground()
          ],
        ),
      ),
    );
  }

  Widget backgroundImage() {
    return Image.asset('assets/images/audio_bg.png', width: double.infinity, height: double.infinity, fit: BoxFit.fill);
  }

  Widget roomTitle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LiveAudioRoom', style: Theme.of(context).textTheme.titleMedium),
            Text('Room ID: \${widget.roomID}'),
            ValueListenableBuilder(
              valueListenable: ZegoLiveAudioRoomManager().hostUserNoti,
              builder: (BuildContext context, ZegoSDKUser? host, Widget? child) {
                return host != null ? Text('Host: \${host.userName} (id: \${host.userID})') : const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget bottomView() {
    return ValueListenableBuilder<ZegoLiveAudioRoomRole>(
        valueListenable: ZegoLiveAudioRoomManager().roleNoti,
        builder: (context, currentRole, _) {
          if (currentRole == ZegoLiveAudioRoomRole.host) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(width: 10),
                    requestMemberButton(),
                    const SizedBox(width: 10),
                    micorphoneButton(),
                    const SizedBox(width: 10),
                  ],
                ),
                const SizedBox(height: 8),
                _hostMusicControls(),
              ],
            );
          } else if (currentRole == ZegoLiveAudioRoomRole.speaker) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  giftButton(),
                  const SizedBox(width: 10),
                  leaveSeatButton(),
                  const SizedBox(width: 10),
                  micorphoneButton(),
                ],
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  giftButton(),
                  const SizedBox(width: 10),
                  requestTakeSeatButton(),
                ],
              ),
            );
          }
        });
  }

  Widget _hostMusicControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () async {
              _currentIndex = 0;
              await _hostPlayUrl(_playlistUrls[_currentIndex]);
            },
            child: const Icon(Icons.play_arrow),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _hostPause,
            child: const Icon(Icons.pause),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _hostResume,
            child: const Icon(Icons.play_circle),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              _currentIndex = (_currentIndex + 1) % _playlistUrls.length;
              await _hostPlayUrl(_playlistUrls[_currentIndex]);
            },
            child: const Icon(Icons.skip_next),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _hostStop,
            child: const Icon(Icons.stop),
          ),
        ],
      ),
    );
  }

  Widget requestMemberButton() {
    return ValueListenableBuilder(
      valueListenable: ZEGOSDKManager().zimService.roomRequestMapNoti,
      builder: (context, Map<String, dynamic> requestMap, child) {
        final requestList = requestMap.values.toList();
        return Badge(smallSize: 12, isLabelVisible: requestList.isNotEmpty, child: child);
      },
      child: ElevatedButton(
        onPressed: () => RoomRequestListView.showBasicModalBottomSheet(context),
        child: const Icon(Icons.link),
      ),
    );
  }

  Widget micorphoneButton() {
    return ValueListenableBuilder(
      valueListenable: ZEGOSDKManager().currentUser!.isMicOnNotifier,
      builder: (context, bool micIsOn, child) {
        return ElevatedButton(
          onPressed: () => ZEGOSDKManager().expressService.turnMicrophoneOn(!micIsOn),
          child: micIsOn ? const Icon(Icons.mic) : const Icon(Icons.mic_off),
        );
      },
    );
  }

  Widget requestTakeSeatButton() {
    return ElevatedButton(
      onPressed: () {
        if (!isApplyStateNoti.value) {
          final senderMap = {'room_request_type': RoomRequestType.audienceApplyToBecomeCoHost};
          ZEGOSDKManager()
              .zimService
              .sendRoomRequest(ZegoLiveAudioRoomManager().hostUserNoti.value?.userID ?? '', jsonEncode(senderMap))
              .then((value) {
            isApplyStateNoti.value = true;
            currentRequestID = value.requestID;
          });
        } else {
          if (currentRequestID != null) {
            ZEGOSDKManager().zimService.cancelRoomRequest(currentRequestID ?? '').then((value) {
              isApplyStateNoti.value = false;
              currentRequestID = null;
            });
          }
        }
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: isApplyStateNoti,
        builder: (context, isApply, _) {
          return Text(isApply ? 'Cancel Application' : 'Apply Take Seat');
        },
      ),
    );
  }

  Widget leaveSeatButton() {
    return ElevatedButton(
        onPressed: () {
          for (final element in ZegoLiveAudioRoomManager().seatList) {
            if (element.currentUser.value?.userID == ZEGOSDKManager().currentUser!.userID) {
              ZegoLiveAudioRoomManager().leaveSeat(element.seatIndex).then((value) {
                ZegoLiveAudioRoomManager().roleNoti.value = ZegoLiveAudioRoomRole.audience;
                isApplyStateNoti.value = false;
                ZEGOSDKManager().expressService.stopPublishingStream();
              });
            }
          }
        },
        child: const Text('Leave Seat'));
  }

  Widget leaveButton() {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
      },
      child: SizedBox(
        width: 40,
        height: 40,
        child: Image.asset('assets/icons/top_close.png'),
      ),
    );
  }

  Widget seatListView() {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: 300,
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisCount: 4,
        children: [
          ...List.generate(ZegoLiveAudioRoomManager().seatList.length, (seatIndex) {
            final seat = ZegoLiveAudioRoomManager().seatList[seatIndex];

            return GestureDetector(
              onTap: () {
                if (seatIndex == 0) return;

                // 🔒 Host lock/unlock
                if (widget.role == ZegoLiveAudioRoomRole.host) {
                  seat.isLocked.value = !seat.isLocked.value;
                  return;
                }

                // ❌ Locked seat for others
                if (seat.isLocked.value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("This seat is locked")),
                  );
                  return;
                }

                if (seat.currentUser.value == null) {
                  if (ZegoLiveAudioRoomManager().roleNoti.value == ZegoLiveAudioRoomRole.audience) {
                    ZegoLiveAudioRoomManager().takeSeat(seat.seatIndex).then((result) {
                      if (mounted && ((result == null) || result.errorKeys.contains(ZEGOSDKManager().currentUser!.userID))) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('take seat failed: $result')));
                      }
                    }).catchError((error) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('take seat failed: $error')));
                    });
                  } else if (ZegoLiveAudioRoomManager().roleNoti.value == ZegoLiveAudioRoomRole.speaker) {
                    if (getLocalUserSeatIndex() != -1) {
                      ZegoLiveAudioRoomManager().switchSeat(getLocalUserSeatIndex(), seat.seatIndex);
                    }
                  }
                } else {
                  if (widget.role == ZegoLiveAudioRoomRole.host &&
                      (ZEGOSDKManager().currentUser!.userID != seat.currentUser.value?.userID)) {
                    showRemoveSpeakerAndKitOutSheet(context, seat.currentUser.value!);
                  }
                }
              },
              child: ZegoLiveAudioRoomSeatTile(
                userName: seat.currentUser.value?.userName ?? 'Empty',
                isLocked: seat.isLocked.value,
                onLongPress: () {
                  // Sirf host lock/unlock kar sake
                  if (widget.role == ZegoLiveAudioRoomRole.host) {
                    seat.isLocked.value = !seat.isLocked.value;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(seat.isLocked.value
                            ? 'Seat ${seat.seatIndex} locked'
                            : 'Seat ${seat.seatIndex} unlocked'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Only host can lock/unlock seats")),
                    );
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  void showRemoveSpeakerAndKitOutSheet(BuildContext context, ZegoSDKUser targetUser) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              title: const Text('remove speaker', textAlign: TextAlign.center),
              onTap: () {
                Navigator.pop(context);
                ZegoLiveAudioRoomManager().removeSpeakerFromSeat(targetUser.userID);
              },
            ),
            ListTile(
              title: Text(targetUser.isMicOnNotifier.value ? 'mute speaker' : 'unMute speaker',
                  textAlign: TextAlign.center),
              onTap: () {
                Navigator.pop(context);
                ZegoLiveAudioRoomManager().muteSpeaker(targetUser.userID, targetUser.isMicOnNotifier.value);
              },
            ),
            ListTile(
              title: const Text('kick out user', textAlign: TextAlign.center),
              onTap: () {
                Navigator.pop(context);
                ZegoLiveAudioRoomManager().kickOutRoom(targetUser.userID);
              },
            ),
          ],
        );
      },
    );
  }

  int getLocalUserSeatIndex() {
    for (final element in ZegoLiveAudioRoomManager().seatList) {
      if (element.currentUser.value?.userID == ZEGOSDKManager().currentUser!.userID) {
        return element.seatIndex;
      }
    }
    return -1;
  }

  void onInComingRoomRequest(OnInComingRoomRequestReceivedEvent event) {}
  void onInComingRoomRequestCancelled(OnInComingRoomRequestCancelledEvent event) {}
  void onInComingRoomRequestTimeOut() {}

  void onOutgoingRoomRequestAccepted(OnOutgoingRoomRequestAcceptedEvent event) {
    isApplyStateNoti.value = false;
    for (final seat in ZegoLiveAudioRoomManager().seatList) {
      if (seat.currentUser.value == null) {
        ZegoLiveAudioRoomManager().takeSeat(seat.seatIndex).then((result) {
          if (mounted && ((result == null) || result.errorKeys.contains(ZEGOSDKManager().currentUser!.userID))) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('take seat failed: \$result')));
          }
        }).catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('take seat failed: \$error')));
        });
        break;
      }
    }
  }

  void onOutgoingRoomRequestRejected(OnOutgoingRoomRequestRejectedEvent event) {
    isApplyStateNoti.value = false;
    currentRequestID = null;
  }

  void onExpressRoomStateChanged(ZegoRoomStateEvent event) {
    debugPrint('AudioRoomPage:onExpressRoomStateChanged: \$event');
    if (event.errorCode != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1000),
          content: Text('onExpressRoomStateChanged: reason:\${event.reason.name}, errorCode:\${event.errorCode}'),
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
    debugPrint('AudioRoomPage:onZIMRoomStateChanged: \$event');
    if ((event.event != ZIMRoomEvent.success) && (event.state != ZIMRoomState.connected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1000),
          content: Text('onZIMRoomStateChanged: \$event'),
        ),
      );
    }
    if (event.state == ZIMRoomState.disconnected) {
      Navigator.pop(context);
    }
  }

  void onZIMConnectionStateChanged(ZIMServiceConnectionStateChangedEvent event) {
    debugPrint('AudioRoomPage:onZIMConnectionStateChanged: \$event');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1000),
        content: Text('onZIMConnectionStateChanged: \$event'),
      ),
    );
    if (event.state == ZIMConnectionState.disconnected) {
      Navigator.pop(context);
    }
  }
}
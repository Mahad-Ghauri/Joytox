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
  
  // ✅ NEW: Enhanced state management and error handling
  bool _isMusicPlayerInitializing = false;
  bool _isMusicPlayerError = false;
  String? _lastErrorMessage;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Timer? _retryTimer;
  
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
      expressService.onMediaPlayerStateUpdateCtrl.stream.listen(_onMediaPlayerStateUpdate),
    ]);

    _musicListener = _onMusicStateChanged;
    ZegoLiveAudioRoomManager().musicStateNoti.addListener(_musicListener);

    loginRoom();

    initGift();
  }

  // ✅ NEW: Enhanced media player state update handling
  void _onMediaPlayerStateUpdate(ZegoPlayerStateChangeEvent event) {
    debugPrint('AudioRoomPage: Media player state update: ${event.state}, error: ${event.errorCode}');
    
    if (event.errorCode != 0) {
      _handleMediaPlayerError(event.errorCode, 'Media player error: ${event.state.name}');
    }
    
    // Update UI based on state changes
    if (mounted) {
      setState(() {
        switch (event.state) {
          case ZegoMediaPlayerState.Playing:
            _isMusicReady = true;
            _isMusicPlayerError = false;
            _lastErrorMessage = null;
            break;
          case ZegoMediaPlayerState.Pausing:
            _isMusicReady = true;
            break;
          case ZegoMediaPlayerState.PlayEnded:
            _isMusicReady = false;
            break;
          case ZegoMediaPlayerState.NoPlay:
            _isMusicReady = false;
            break;
          default:
            break;
        }
      });
    }
  }

  // ✅ NEW: Comprehensive error handling
  void _handleMediaPlayerError(int errorCode, String message) {
    debugPrint('AudioRoomPage: Media player error: $message (code: $errorCode)');
    
    if (mounted) {
      setState(() {
        _isMusicPlayerError = true;
        _lastErrorMessage = message;
        _isMusicReady = false;
      });
    }
    
    // Show error to user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Audio Error: $message'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    
    // Attempt recovery if possible
    _attemptRecovery();
  }

  // ✅ NEW: Recovery mechanism
  void _attemptRecovery() {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      debugPrint('AudioRoomPage: Attempting recovery (attempt $_retryCount/$_maxRetries)');
      
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 2), () async {
        await _recreateMusicPlayer();
      });
    } else {
      debugPrint('AudioRoomPage: Max retry attempts reached, manual intervention required');
      _showRecoveryDialog();
    }
  }

  // ✅ NEW: Recreate music player
  Future<void> _recreateMusicPlayer() async {
    try {
      debugPrint('AudioRoomPage: Recreating music player...');
      await _destroyMusicPlayer();
      await Future.delayed(const Duration(milliseconds: 500));
      await _ensureMusicPlayer();
      
      if (mounted) {
        setState(() {
          _isMusicPlayerError = false;
          _lastErrorMessage = null;
        });
      }
      
      debugPrint('AudioRoomPage: Music player recreated successfully');
    } catch (e) {
      debugPrint('AudioRoomPage: Failed to recreate music player: $e');
      _handleMediaPlayerError(-1, 'Failed to recreate music player: $e');
    }
  }

  // ✅ NEW: Recovery dialog
  void _showRecoveryDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audio Playback Error'),
        content: Text('Audio playback has encountered persistent errors. Would you like to try to fix it?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              _retryCount = 0;
              await _recreateMusicPlayer();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
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
    _retryTimer?.cancel();
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
    if (_musicPlayer != null && !_isMusicPlayerError) return;
    
    if (_isMusicPlayerInitializing) return;
    
    try {
      _isMusicPlayerInitializing = true;
      
      // Clean up existing player if there's an error
      if (_musicPlayer != null && _isMusicPlayerError) {
        await _destroyMusicPlayer();
      }
      
      // Create new player with error handling
      _musicPlayer = await ZegoExpressEngine.instance.createMediaPlayer();
      if (_musicPlayer == null) {
        throw Exception('Failed to create media player');
      }
      
      // Configure player
      _musicPlayer!.setVolume(60);
      
      // Note: Event handling is done through the express service stream controller
      // which is already set up in initState()
      
      _isMusicReady = false;
      _isMusicPlayerError = false;
      _lastErrorMessage = null;
      
      debugPrint('AudioRoomPage: Music player created successfully');
    } catch (e) {
      debugPrint('AudioRoomPage: Error creating music player: $e');
      _handleMediaPlayerError(-1, 'Failed to create music player: $e');
    } finally {
      _isMusicPlayerInitializing = false;
    }
  }

  Future<void> _destroyMusicPlayer() async {
    try {
      if (_musicPlayer != null) {
        await _musicPlayer!.stop();
        await ZegoExpressEngine.instance.destroyMediaPlayer(_musicPlayer!);
        _musicPlayer = null;
      }
      if (_musicPlayerViewID != -1) {
        await ZegoExpressEngine.instance.destroyCanvasView(_musicPlayerViewID);
        _musicPlayerViewID = -1;
      }
      
      _isMusicReady = false;
      _isMusicPlayerError = false;
      _lastErrorMessage = null;
      
      debugPrint('AudioRoomPage: Music player destroyed successfully');
    } catch (e) {
      debugPrint('AudioRoomPage: Error destroying music player: $e');
    }
  }

  Future<void> _hostPlayUrl(String url) async {
    if (ZegoLiveAudioRoomManager().roleNoti.value != ZegoLiveAudioRoomRole.host) return;
    
    try {
      await _ensureMusicPlayer();
      
      if (_musicPlayer == null) {
        throw Exception('Music player not available');
      }
      
      // Validate URL
      if (url.isEmpty) {
        throw Exception('Invalid URL provided');
      }
      
      debugPrint('AudioRoomPage: Loading audio resource: $url');
      
      final source = ZegoMediaPlayerResource.defaultConfig()
        ..filePath = url;
      
      final result = await _musicPlayer!.loadResourceWithConfig(source);
      
      if (result.errorCode != 0) {
        throw Exception('Failed to load audio resource: ${result.errorCode}');
      }
      
      _isMusicReady = true;
      _isMusicPlayerError = false;
      _lastErrorMessage = null;
      
      // Start playback
      await _musicPlayer!.start();
      
      // Sync state to room
      await ZegoLiveAudioRoomManager().setMusicState(
        MusicPlaybackState(trackUrl: url, isPlaying: true, positionMs: 0)
      );
      
      debugPrint('AudioRoomPage: Audio playback started successfully');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio playback started'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      debugPrint('AudioRoomPage: Error playing URL: $e');
      _handleMediaPlayerError(-1, 'Failed to play audio: $e');
    }
  }

  Future<void> _hostPause() async {
    if (_musicPlayer == null || _isMusicPlayerError) return;
    
    try {
      await _musicPlayer!.pause();
      final cur = ZegoLiveAudioRoomManager().musicStateNoti.value;
      await ZegoLiveAudioRoomManager().setMusicState(
        (cur ?? MusicPlaybackState.empty()).copyWith(isPlaying: false)
      );
      
      debugPrint('AudioRoomPage: Audio paused successfully');
    } catch (e) {
      debugPrint('AudioRoomPage: Error pausing audio: $e');
      _handleMediaPlayerError(-1, 'Failed to pause audio: $e');
    }
  }

  Future<void> _hostResume() async {
    if (_musicPlayer == null || _isMusicPlayerError) return;
    
    try {
      await _musicPlayer!.resume();
      final cur = ZegoLiveAudioRoomManager().musicStateNoti.value;
      await ZegoLiveAudioRoomManager().setMusicState(
        (cur ?? MusicPlaybackState.empty()).copyWith(isPlaying: true)
      );
      
      debugPrint('AudioRoomPage: Audio resumed successfully');
    } catch (e) {
      debugPrint('AudioRoomPage: Error resuming audio: $e');
      _handleMediaPlayerError(-1, 'Failed to resume audio: $e');
    }
  }

  Future<void> _hostStop() async {
    if (_musicPlayer == null) return;
    
    try {
      await _musicPlayer!.stop();
      await ZegoLiveAudioRoomManager().setMusicState(MusicPlaybackState.stopped());
      
      _isMusicReady = false;
      
      debugPrint('AudioRoomPage: Audio stopped successfully');
    } catch (e) {
      debugPrint('AudioRoomPage: Error stopping audio: $e');
      _handleMediaPlayerError(-1, 'Failed to stop audio: $e');
    }
  }

  // Apply incoming music state for non-hosts
  void _onMusicStateChanged() {
    final state = ZegoLiveAudioRoomManager().musicStateNoti.value;
    if (state == null) return;
    
    final isHost = ZegoLiveAudioRoomManager().roleNoti.value == ZegoLiveAudioRoomRole.host;
    if (isHost) return; // host drives the player

    () async {
      try {
        await _ensureMusicPlayer();
        
        if (_musicPlayer == null) {
          debugPrint('AudioRoomPage: Music player not available for state sync');
          return;
        }
        
        if (state.trackUrl == null || state.trackUrl!.isEmpty) {
          _musicPlayer?.stop();
          _isMusicReady = false;
          return;
        }
        
        // Load new resource if not ready
        if (!_isMusicReady) {
          final source = ZegoMediaPlayerResource.defaultConfig()
            ..filePath = state.trackUrl!;
          
          final result = await _musicPlayer!.loadResourceWithConfig(source);
          if (result.errorCode == 0) {
            _isMusicReady = true;
            _isMusicPlayerError = false;
            _lastErrorMessage = null;
          } else {
            throw Exception('Failed to load audio resource: ${result.errorCode}');
          }
        }
        
        // Control playback based on state
        if (state.isPlaying) {
          await _musicPlayer!.start();
        } else {
          await _musicPlayer!.pause();
        }
        
        debugPrint('AudioRoomPage: Music state synced successfully');
        
      } catch (e) {
        debugPrint('AudioRoomPage: Error syncing music state: $e');
        _handleMediaPlayerError(-1, 'Failed to sync music state: $e');
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ NEW: Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isMusicPlayerError ? Colors.red.shade100 : Colors.green.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isMusicPlayerError ? Colors.red : Colors.green,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isMusicPlayerError ? Icons.error : Icons.music_note,
                  size: 16,
                  color: _isMusicPlayerError ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 6),
                Text(
                  _isMusicPlayerError 
                    ? 'Audio Error' 
                    : (_isMusicReady ? 'Audio Ready' : 'Audio Loading...'),
                  style: TextStyle(
                    fontSize: 12,
                    color: _isMusicPlayerError ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // ✅ NEW: Error message display
          if (_lastErrorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, size: 16, color: Colors.red.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _lastErrorMessage!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // ✅ NEW: Enhanced music controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isMusicPlayerError || _isMusicPlayerInitializing 
                  ? null 
                  : () async {
                      _currentIndex = 0;
                      await _hostPlayUrl(_playlistUrls[_currentIndex]);
                    },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: const Icon(Icons.play_arrow),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isMusicPlayerError || _isMusicPlayerInitializing || _musicPlayer == null
                  ? null 
                  : _hostPause,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: const Icon(Icons.pause),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isMusicPlayerError || _isMusicPlayerInitializing || _musicPlayer == null
                  ? null 
                  : _hostResume,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: const Icon(Icons.play_circle),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isMusicPlayerError || _isMusicPlayerInitializing 
                  ? null 
                  : () async {
                      _currentIndex = (_currentIndex + 1) % _playlistUrls.length;
                      await _hostPlayUrl(_playlistUrls[_currentIndex]);
                    },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: const Icon(Icons.skip_next),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isMusicPlayerError || _isMusicPlayerInitializing || _musicPlayer == null
                  ? null 
                  : _hostStop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: const Icon(Icons.stop),
              ),
            ],
          ),
          
          // ✅ NEW: Recovery button when errors occur
          if (_isMusicPlayerError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton.icon(
                onPressed: _isMusicPlayerInitializing ? null : () async {
                  _retryCount = 0;
                  await _recreateMusicPlayer();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(_isMusicPlayerInitializing ? 'Recovering...' : 'Recover Audio'),
              ),
            ),
          
          // ✅ NEW: Current track info
          if (_isMusicReady && ZegoLiveAudioRoomManager().musicStateNoti.value?.trackUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.music_note, size: 16, color: Colors.blue.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Track ${_currentIndex + 1}/${_playlistUrls.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
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
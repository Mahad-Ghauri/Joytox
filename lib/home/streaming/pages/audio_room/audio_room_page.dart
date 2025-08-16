// ignore_for_file: must_be_immutable, deprecated_member_use

import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/setup.dart';
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
  final ZegoLiveAudioRoomRole role;

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

  // ✅ NEW: Enhanced playlist management
  String get currentTrackUrl =>
      _playlistUrls.isNotEmpty ? _playlistUrls[_currentIndex] : '';
  bool get hasNextTrack =>
      _playlistUrls.isNotEmpty && _currentIndex < _playlistUrls.length - 1;
  bool get hasPreviousTrack => _playlistUrls.isNotEmpty && _currentIndex > 0;
  bool get isPlaying =>
      ZegoLiveAudioRoomManager().musicStateNoti.value?.isPlaying ?? false;

  @override
  void initState() {
    super.initState();
    final zimService = ZEGOSDKManager().zimService;
    final expressService = ZEGOSDKManager().expressService;
    subscriptions.addAll([
      expressService.roomStateChangedStreamCtrl.stream
          .listen(onExpressRoomStateChanged),
      zimService.roomStateChangedStreamCtrl.stream
          .listen(onZIMRoomStateChanged),
      zimService.connectionStateStreamCtrl.stream
          .listen(onZIMConnectionStateChanged),
      zimService.onInComingRoomRequestStreamCtrl.stream
          .listen(onInComingRoomRequest),
      zimService.onOutgoingRoomRequestAcceptedStreamCtrl.stream
          .listen(onOutgoingRoomRequestAccepted),
      zimService.onOutgoingRoomRequestRejectedStreamCtrl.stream
          .listen(onOutgoingRoomRequestRejected),
      expressService.onMediaPlayerStateUpdateCtrl.stream
          .listen(_onMediaPlayerStateUpdate),
    ]);

    _musicListener = _onMusicStateChanged;
    ZegoLiveAudioRoomManager().musicStateNoti.addListener(_musicListener);

    loginRoom();

    initGift();
  }

  // ✅ NEW: Enhanced media player state update handling
  void _onMediaPlayerStateUpdate(ZegoPlayerStateChangeEvent event) {
    debugPrint(
        'AudioRoomPage: Media player state update: ${event.state}, error: ${event.errorCode}');

    if (event.errorCode != 0) {
      _handleMediaPlayerError(
          event.errorCode, 'Media player error: ${event.state.name}');
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
            // ✅ NEW: Auto-advance to next track when current track ends
            _autoAdvanceToNextTrack();
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

  // ✅ NEW: Auto-advance to next track when current track ends
  void _autoAdvanceToNextTrack() {
    if (hasNextTrack &&
        ZegoLiveAudioRoomManager().roleNoti.value ==
            ZegoLiveAudioRoomRole.host) {
      // Small delay to ensure smooth transition
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted) {
          await _hostForward();
        }
      });
    }
  }

  // ✅ NEW: Comprehensive error handling
  void _handleMediaPlayerError(int errorCode, String message) {
    debugPrint(
        'AudioRoomPage: Media player error: $message (code: $errorCode)');

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
      debugPrint(
          'AudioRoomPage: Attempting recovery (attempt $_retryCount/$_maxRetries)');

      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 2), () async {
        await _recreateMusicPlayer();
      });
    } else {
      debugPrint(
          'AudioRoomPage: Max retry attempts reached, manual intervention required');
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
        content: Text(
            'Audio playback has encountered persistent errors. Would you like to try to fix it?'),
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
            Setup.zegoLiveStreamAppID,
            Setup.zegoLiveStreamServerSecret,
            ZEGOSDKManager().currentUser!.userID)
        : null;
    ZegoLiveAudioRoomManager()
        .loginRoom(widget.roomID, widget.role, token: token)
        .then((result) {
      if (result.errorCode == 0) {
        hostTakeSeat();
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text("room_failed".tr() + ' error: \${result.errorCode}')));
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
      await ZegoLiveAudioRoomManager()
          .takeSeat(0, isForce: true)
          .then((result) {
        if (mounted &&
            ((result == null) ||
                result.errorKeys
                    .contains(ZEGOSDKManager().currentUser!.userID))) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  "failed_take_seat".tr(namedArgs: {"error": "\$result"}))));
        }
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text("failed_take_seat".tr(namedArgs: {"error": "\$error"}))));
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
    if (ZegoLiveAudioRoomManager().roleNoti.value != ZegoLiveAudioRoomRole.host)
      return;

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

      final source = ZegoMediaPlayerResource.defaultConfig()..filePath = url;

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
          MusicPlaybackState(trackUrl: url, isPlaying: true, positionMs: 0));

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
          (cur ?? MusicPlaybackState.empty()).copyWith(isPlaying: false));

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
          (cur ?? MusicPlaybackState.empty()).copyWith(isPlaying: true));

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
      await ZegoLiveAudioRoomManager()
          .setMusicState(MusicPlaybackState.stopped());

      _isMusicReady = false;

      debugPrint('AudioRoomPage: Audio stopped successfully');
    } catch (e) {
      debugPrint('AudioRoomPage: Error stopping audio: $e');
      _handleMediaPlayerError(-1, 'Failed to stop audio: $e');
    }
  }

  // ✅ NEW: Forward functionality - skip to next track
  Future<void> _hostForward() async {
    if (ZegoLiveAudioRoomManager().roleNoti.value != ZegoLiveAudioRoomRole.host)
      return;

    if (!hasNextTrack) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No more tracks available'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      _currentIndex = (_currentIndex + 1) % _playlistUrls.length;
      await _hostPlayUrl(_playlistUrls[_currentIndex]);

      debugPrint('AudioRoomPage: Forwarded to next track: $_currentIndex');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Playing track ${_currentIndex + 1}/${_playlistUrls.length}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('AudioRoomPage: Error forwarding to next track: $e');
      _handleMediaPlayerError(-1, 'Failed to forward to next track: $e');
    }
  }

  // ✅ NEW: Backward functionality - go to previous track
  Future<void> _hostBackward() async {
    if (ZegoLiveAudioRoomManager().roleNoti.value != ZegoLiveAudioRoomRole.host)
      return;

    if (!hasPreviousTrack) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No previous tracks available'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      _currentIndex = (_currentIndex - 1) % _playlistUrls.length;
      await _hostPlayUrl(_playlistUrls[_currentIndex]);

      debugPrint('AudioRoomPage: Backward to previous track: $_currentIndex');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Playing track ${_currentIndex + 1}/${_playlistUrls.length}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('AudioRoomPage: Error going to previous track: $e');
      _handleMediaPlayerError(-1, 'Failed to go to previous track: $e');
    }
  }

  // ✅ NEW: Play specific track by index
  Future<void> _hostPlayTrack(int trackIndex) async {
    if (ZegoLiveAudioRoomManager().roleNoti.value != ZegoLiveAudioRoomRole.host)
      return;

    if (trackIndex < 0 || trackIndex >= _playlistUrls.length) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid track index'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      _currentIndex = trackIndex;
      await _hostPlayUrl(_playlistUrls[_currentIndex]);

      debugPrint('AudioRoomPage: Playing specific track: $_currentIndex');
    } catch (e) {
      debugPrint('AudioRoomPage: Error playing specific track: $e');
      _handleMediaPlayerError(-1, 'Failed to play specific track: $e');
    }
  }

  // Apply incoming music state for non-hosts
  void _onMusicStateChanged() {
    final state = ZegoLiveAudioRoomManager().musicStateNoti.value;
    if (state == null) return;

    final isHost =
        ZegoLiveAudioRoomManager().roleNoti.value == ZegoLiveAudioRoomRole.host;
    if (isHost) return; // host drives the player

    () async {
      try {
        await _ensureMusicPlayer();

        if (_musicPlayer == null) {
          debugPrint(
              'AudioRoomPage: Music player not available for state sync');
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
            throw Exception(
                'Failed to load audio resource: ${result.errorCode}');
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
    return Image.asset('assets/images/audio_bg.png',
        width: double.infinity, height: double.infinity, fit: BoxFit.fill);
  }

  Widget roomTitle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LiveAudioRoom',
                style: Theme.of(context).textTheme.titleMedium),
            Text('Room ID: \${widget.roomID}'),
            ValueListenableBuilder(
              valueListenable: ZegoLiveAudioRoomManager().hostUserNoti,
              builder:
                  (BuildContext context, ZegoSDKUser? host, Widget? child) {
                return host != null
                    ? Text('Host: \${host.userName} (id: \${host.userID})')
                    : const SizedBox.shrink();
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ NEW: Enhanced status indicator with better styling
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isMusicPlayerError
                    ? [Colors.red.shade400, Colors.red.shade600]
                    : [Colors.green.shade400, Colors.green.shade600],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: (_isMusicPlayerError ? Colors.red : Colors.green)
                      .withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _isMusicPlayerError
                        ? Icons.error_outline
                        : Icons.music_note,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _isMusicPlayerError
                      ? 'Audio Error'
                      : (_isMusicReady ? 'Audio Ready' : 'Audio Loading...'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ✅ NEW: Error message display with improved styling
          if (_lastErrorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.red.shade200, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.warning_amber_rounded,
                        size: 20, color: Colors.red.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _lastErrorMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ✅ NEW: Modern music controls with improved layout
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                // Main control buttons in a row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Back Button - Goes to previous track
                    _buildControlButton(
                      onPressed: _isMusicPlayerError ||
                              _isMusicPlayerInitializing ||
                              !hasPreviousTrack
                          ? null
                          : () async {
                              try {
                                await _hostBackward();
                              } catch (e) {
                                debugPrint(
                                    'AudioRoomPage: Error in Back button: $e');
                                _handleMediaPlayerError(
                                    -1, 'Failed to go to previous track: $e');
                              }
                            },
                      icon: Icons.skip_previous_rounded,
                      label: 'Back',
                      backgroundColor: Colors.blue.shade500,
                      disabledColor: Colors.grey.shade300,
                      size: 60,
                    ),

                    // Play Button - Starts/resumes audio playback
                    _buildControlButton(
                      onPressed: _isMusicPlayerError ||
                              _isMusicPlayerInitializing
                          ? null
                          : () async {
                              try {
                                if (_musicPlayer == null || !_isMusicReady) {
                                  // Start playing current track
                                  await _hostPlayUrl(
                                      _playlistUrls[_currentIndex]);
                                } else if (!isPlaying) {
                                  // Resume playback
                                  await _hostResume();
                                } else {
                                  // Already playing, show feedback
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Audio is already playing'),
                                        backgroundColor: Colors.blue,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                debugPrint(
                                    'AudioRoomPage: Error in Play button: $e');
                                _handleMediaPlayerError(
                                    -1, 'Failed to play audio: $e');
                              }
                            },
                      icon: Icons.play_circle_filled_rounded,
                      label: 'Play',
                      backgroundColor: Colors.green.shade500,
                      disabledColor: Colors.grey.shade300,
                      size: 80,
                      isPrimary: true,
                    ),

                    // Pause Button - Pauses audio playback
                    _buildControlButton(
                      onPressed: _isMusicPlayerError ||
                              _isMusicPlayerInitializing ||
                              _musicPlayer == null ||
                              !isPlaying
                          ? null
                          : () async {
                              try {
                                if (isPlaying) {
                                  await _hostPause();
                                } else {
                                  // Not playing, show feedback
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Audio is not currently playing'),
                                        backgroundColor: Colors.orange,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                debugPrint(
                                    'AudioRoomPage: Error in Pause button: $e');
                                _handleMediaPlayerError(
                                    -1, 'Failed to pause audio: $e');
                              }
                            },
                      icon: Icons.pause_circle_filled_rounded,
                      label: 'Pause',
                      backgroundColor: Colors.orange.shade500,
                      disabledColor: Colors.grey.shade300,
                      size: 80,
                      isPrimary: true,
                    ),

                    // Forward Button - Skips to next track
                    _buildControlButton(
                      onPressed: _isMusicPlayerError ||
                              _isMusicPlayerInitializing ||
                              !hasNextTrack
                          ? null
                          : () async {
                              try {
                                await _hostForward();
                              } catch (e) {
                                debugPrint(
                                    'AudioRoomPage: Error in Forward button: $e');
                                _handleMediaPlayerError(
                                    -1, 'Failed to go to next track: $e');
                              }
                            },
                      icon: Icons.skip_next_rounded,
                      label: 'Forward',
                      backgroundColor: Colors.purple.shade500,
                      disabledColor: Colors.grey.shade300,
                      size: 60,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Secondary control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Stop Button
                    _buildControlButton(
                      onPressed: _isMusicPlayerError ||
                              _isMusicPlayerInitializing ||
                              _musicPlayer == null
                          ? null
                          : _hostStop,
                      icon: Icons.stop_circle_rounded,
                      label: 'Stop',
                      backgroundColor: Colors.red.shade500,
                      disabledColor: Colors.grey.shade300,
                      size: 50,
                    ),

                    // Play First Track Button
                    _buildControlButton(
                      onPressed: _isMusicPlayerError ||
                              _isMusicPlayerInitializing
                          ? null
                          : () async {
                              _currentIndex = 0;
                              await _hostPlayUrl(_playlistUrls[_currentIndex]);
                            },
                      icon: Icons.first_page_rounded,
                      label: 'First',
                      backgroundColor: Colors.teal.shade500,
                      disabledColor: Colors.grey.shade300,
                      size: 50,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ✅ NEW: Recovery button when errors occur with improved styling
          if (_isMusicPlayerError)
            Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isMusicPlayerInitializing
                    ? null
                    : () async {
                        _retryCount = 0;
                        await _recreateMusicPlayer();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade500,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 8,
                  shadowColor: Colors.amber.withOpacity(0.4),
                ),
                icon: Icon(
                  _isMusicPlayerInitializing
                      ? Icons.hourglass_empty
                      : Icons.refresh_rounded,
                  size: 20,
                ),
                label: Text(
                  _isMusicPlayerInitializing
                      ? 'Recovering...'
                      : 'Recover Audio System',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // ✅ NEW: Enhanced current track info with better styling
          if (_isMusicReady &&
              ZegoLiveAudioRoomManager().musicStateNoti.value?.trackUrl != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade500,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Now Playing',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Track ${_currentIndex + 1} of ${_playlistUrls.length}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // ✅ NEW: Playlist management section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.playlist_play_rounded,
                      color: Colors.grey.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Playlist',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_playlistUrls.length} tracks',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Track list
                ...List.generate(_playlistUrls.length, (index) {
                  final isCurrentTrack = index == _currentIndex;
                  final isPlayingTrack = isCurrentTrack && isPlaying;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isMusicPlayerError || _isMusicPlayerInitializing
                            ? null
                            : () => _hostPlayTrack(index),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isCurrentTrack
                                ? (isPlayingTrack
                                    ? Colors.green.shade100
                                    : Colors.blue.shade100)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrentTrack
                                  ? (isPlayingTrack
                                      ? Colors.green.shade300
                                      : Colors.blue.shade300)
                                  : Colors.grey.shade200,
                              width: isCurrentTrack ? 2 : 1,
                            ),
                            boxShadow: isCurrentTrack
                                ? [
                                    BoxShadow(
                                      color: (isPlayingTrack
                                              ? Colors.green
                                              : Colors.blue)
                                          .withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isCurrentTrack
                                      ? (isPlayingTrack
                                          ? Colors.green.shade500
                                          : Colors.blue.shade500)
                                      : Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  isCurrentTrack
                                      ? (isPlayingTrack
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded)
                                      : Icons.music_note_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Track ${index + 1}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isCurrentTrack
                                            ? (isPlayingTrack
                                                ? Colors.green.shade800
                                                : Colors.blue.shade800)
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                    Text(
                                      _playlistUrls[index].split('/').last,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (isCurrentTrack)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPlayingTrack
                                        ? Colors.green.shade500
                                        : Colors.blue.shade500,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isPlayingTrack ? 'Playing' : 'Current',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Helper method to build consistent control buttons
  Widget _buildControlButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color disabledColor,
    required double size,
    bool isPrimary = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: onPressed != null ? backgroundColor : disabledColor,
            borderRadius: BorderRadius.circular(size / 2),
            boxShadow: onPressed != null
                ? [
                    BoxShadow(
                      color: backgroundColor.withOpacity(0.4),
                      blurRadius: isPrimary ? 15 : 10,
                      offset: Offset(0, isPrimary ? 8 : 5),
                      spreadRadius: isPrimary ? 2 : 1,
                    ),
                  ]
                : null,
            border: onPressed != null
                ? Border.all(
                    color: Colors.white,
                    width: isPrimary ? 3 : 2,
                  )
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(size / 2),
              child: Center(
                child: Icon(
                  icon,
                  size: size * 0.4,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color:
                onPressed != null ? Colors.grey.shade700 : Colors.grey.shade400,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget requestMemberButton() {
    return ValueListenableBuilder(
      valueListenable: ZEGOSDKManager().zimService.roomRequestMapNoti,
      builder: (context, Map<String, dynamic> requestMap, child) {
        final requestList = requestMap.values.toList();
        return Badge(
            smallSize: 12,
            isLabelVisible: requestList.isNotEmpty,
            child: child);
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
          onPressed: () =>
              ZEGOSDKManager().expressService.turnMicrophoneOn(!micIsOn),
          child: micIsOn ? const Icon(Icons.mic) : const Icon(Icons.mic_off),
        );
      },
    );
  }

  Widget requestTakeSeatButton() {
    return ElevatedButton(
      onPressed: () {
        if (!isApplyStateNoti.value) {
          final senderMap = {
            'room_request_type': RoomRequestType.audienceApplyToBecomeCoHost
          };
          ZEGOSDKManager()
              .zimService
              .sendRoomRequest(
                  ZegoLiveAudioRoomManager().hostUserNoti.value?.userID ?? '',
                  jsonEncode(senderMap))
              .then((value) {
            isApplyStateNoti.value = true;
            currentRequestID = value.requestID;
          });
        } else {
          if (currentRequestID != null) {
            ZEGOSDKManager()
                .zimService
                .cancelRoomRequest(currentRequestID ?? '')
                .then((value) {
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
            if (element.currentUser.value?.userID ==
                ZEGOSDKManager().currentUser!.userID) {
              ZegoLiveAudioRoomManager()
                  .leaveSeat(element.seatIndex)
                  .then((value) {
                ZegoLiveAudioRoomManager().roleNoti.value =
                    ZegoLiveAudioRoomRole.audience;
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
          ...List.generate(ZegoLiveAudioRoomManager().seatList.length,
              (seatIndex) {
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
                  if (ZegoLiveAudioRoomManager().roleNoti.value ==
                      ZegoLiveAudioRoomRole.audience) {
                    ZegoLiveAudioRoomManager()
                        .takeSeat(seat.seatIndex)
                        .then((result) {
                      if (mounted &&
                          ((result == null) ||
                              result.errorKeys.contains(
                                  ZEGOSDKManager().currentUser!.userID))) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('take seat failed: $result')));
                      }
                    }).catchError((error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('take seat failed: $error')));
                    });
                  } else if (ZegoLiveAudioRoomManager().roleNoti.value ==
                      ZegoLiveAudioRoomRole.speaker) {
                    if (getLocalUserSeatIndex() != -1) {
                      ZegoLiveAudioRoomManager()
                          .switchSeat(getLocalUserSeatIndex(), seat.seatIndex);
                    }
                  }
                } else {
                  if (widget.role == ZegoLiveAudioRoomRole.host &&
                      (ZEGOSDKManager().currentUser!.userID !=
                          seat.currentUser.value?.userID)) {
                    showRemoveSpeakerAndKitOutSheet(
                        context, seat.currentUser.value!);
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
                      const SnackBar(
                          content: Text("Only host can lock/unlock seats")),
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

  void showRemoveSpeakerAndKitOutSheet(
      BuildContext context, ZegoSDKUser targetUser) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              title: const Text('remove speaker', textAlign: TextAlign.center),
              onTap: () {
                Navigator.pop(context);
                ZegoLiveAudioRoomManager()
                    .removeSpeakerFromSeat(targetUser.userID);
              },
            ),
            ListTile(
              title: Text(
                  targetUser.isMicOnNotifier.value
                      ? 'mute speaker'
                      : 'unMute speaker',
                  textAlign: TextAlign.center),
              onTap: () {
                Navigator.pop(context);
                ZegoLiveAudioRoomManager().muteSpeaker(
                    targetUser.userID, targetUser.isMicOnNotifier.value);
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
      if (element.currentUser.value?.userID ==
          ZEGOSDKManager().currentUser!.userID) {
        return element.seatIndex;
      }
    }
    return -1;
  }

  void onInComingRoomRequest(OnInComingRoomRequestReceivedEvent event) {}
  void onInComingRoomRequestCancelled(
      OnInComingRoomRequestCancelledEvent event) {}
  void onInComingRoomRequestTimeOut() {}

  void onOutgoingRoomRequestAccepted(OnOutgoingRoomRequestAcceptedEvent event) {
    isApplyStateNoti.value = false;
    for (final seat in ZegoLiveAudioRoomManager().seatList) {
      if (seat.currentUser.value == null) {
        ZegoLiveAudioRoomManager().takeSeat(seat.seatIndex).then((result) {
          if (mounted &&
              ((result == null) ||
                  result.errorKeys
                      .contains(ZEGOSDKManager().currentUser!.userID))) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('take seat failed: \$result')));
          }
        }).catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('take seat failed: \$error')));
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
          content: Text(
              'onExpressRoomStateChanged: reason:\${event.reason.name}, errorCode:\${event.errorCode}'),
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
    if ((event.event != ZIMRoomEvent.success) &&
        (event.state != ZIMRoomState.connected)) {
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

  void onZIMConnectionStateChanged(
      ZIMServiceConnectionStateChangedEvent event) {
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

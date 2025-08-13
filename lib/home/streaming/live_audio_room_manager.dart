import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../main.dart';
import 'zego_sdk_manager.dart';
export 'zego_sdk_manager.dart';
import 'internal/business/audio_room/room_seat_service.dart'; // ✅ Required for RoomSeatService

class ZegoLiveAudioRoomManager {
  factory ZegoLiveAudioRoomManager() => instance;
  ZegoLiveAudioRoomManager._internal();
  static final ZegoLiveAudioRoomManager instance =
      ZegoLiveAudioRoomManager._internal();

  static const String roomKey = 'audioRoom';

  Map<String, dynamic> roomExtraInfoDict = {};
  List<StreamSubscription<dynamic>> subscriptions = [];

  ValueNotifier<bool> isLockSeat = ValueNotifier(false);
  ValueNotifier<ZegoSDKUser?> hostUserNoti = ValueNotifier(null);
  ValueNotifier<ZegoLiveAudioRoomRole> roleNoti =
      ValueNotifier(ZegoLiveAudioRoomRole.audience);

  /// Music playback state synced via room extra info so all users can hear consistent background music
  ValueNotifier<MusicPlaybackState?> musicStateNoti = ValueNotifier(null);

  // ✅ NEW: Enhanced state management
  ValueNotifier<bool> isMusicStateUpdating = ValueNotifier(false);
  ValueNotifier<String?> lastMusicError = ValueNotifier(null);
  int _musicStateRetryCount = 0;
  static const int _maxMusicStateRetries = 3;
  Timer? _musicStateRetryTimer;

  RoomSeatService? roomSeatService;

  int get hostSeatIndex {
    return roomSeatService?.hostSeatIndex ?? 0;
  }

  List<ZegoLiveAudioRoomSeat> get seatList {
    return roomSeatService?.seatList ?? [];
  }

  ZegoSDKUser? get localUser {
    return ZEGOSDKManager().currentUser;
  }

  String get hostUserID {
    return hostUserNoti.value?.userID ?? '';
  }

  Future<ZegoRoomLoginResult> loginRoom(
      String roomID, ZegoLiveAudioRoomRole role,
      {String? token}) async {
    try {
      roomSeatService = RoomSeatService();
      roleNoti.value = role;
      final expressService = ZEGOSDKManager().expressService;
      final zimService = ZEGOSDKManager().zimService;
      subscriptions.addAll([
        expressService.roomExtraInfoUpdateCtrl.stream
            .listen(onRoomExtraInfoUpdate),
        expressService.roomUserListUpdateStreamCtrl.stream
            .listen(onRoomUserListUpdate),
        zimService.onRoomCommandReceivedEventStreamCtrl.stream
            .listen(onRoomCommandReceived)
      ]);
      roomSeatService?.initWithConfig(role);
      return ZEGOSDKManager()
          .loginRoom(roomID, ZegoScenario.HighQualityChatroom, token: token);
    } catch (e) {
      debugPrint('ZegoLiveAudioRoomManager: Error in loginRoom: $e');
      rethrow;
    }
  }

  void unInit() {
    try {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
      subscriptions.clear();
      roomSeatService?.unInit();
      _musicStateRetryTimer?.cancel();
    } catch (e) {
      debugPrint('ZegoLiveAudioRoomManager: Error in unInit: $e');
    }
  }

  bool isSeatLocked() {
    return isLockSeat.value;
  }

  Future<ZIMRoomAttributesOperatedCallResult?> takeSeat(int seatIndex,
      {bool? isForce}) async {
    try {
      final result =
          await roomSeatService?.takeSeat(seatIndex, isForce: isForce);
      if (result != null) {
        if (!result.errorKeys.contains(seatIndex.toString())) {
          for (final element in seatList) {
            if (element.seatIndex == seatIndex) {
              if (roleNoti.value != ZegoLiveAudioRoomRole.host) {
                roleNoti.value = ZegoLiveAudioRoomRole.speaker;
              }
              break;
            }
          }
        }
      }
      if (result != null &&
          !result.errorKeys.contains(ZEGOSDKManager().currentUser!.userID)) {
        openMicAndStartPublishStream();
      }
      return result;
    } catch (e) {
      debugPrint('ZegoLiveAudioRoomManager: Error in takeSeat: $e');
      rethrow;
    }
  }

  void openMicAndStartPublishStream() {
    try {
      ZEGOSDKManager().expressService.turnCameraOn(false);
      ZEGOSDKManager().expressService.turnMicrophoneOn(true);
      ZEGOSDKManager().expressService.startPublishingStream(generateStreamID());
    } catch (e) {
      debugPrint(
          'ZegoLiveAudioRoomManager: Error in openMicAndStartPublishStream: $e');
    }
  }

  String generateStreamID() {
    try {
      final userID = ZEGOSDKManager().currentUser!.userID;
      final roomID = ZEGOSDKManager().expressService.currentRoomID;
      final streamID =
          '${roomID}${userID}${ZegoLiveAudioRoomManager().roleNoti.value == ZegoLiveAudioRoomRole.host ? 'host' : 'speaker'}';
      return streamID;
    } catch (e) {
      debugPrint('ZegoLiveAudioRoomManager: Error generating stream ID: $e');
      return 'fallback_stream_id';
    }
  }

  Future<ZIMRoomAttributesBatchOperatedResult?> switchSeat(
      int fromSeatIndex, int toSeatIndex) async {
    try {
      return roomSeatService?.switchSeat(fromSeatIndex, toSeatIndex);
    } catch (e) {
      debugPrint('ZegoLiveAudioRoomManager: Error in switchSeat: $e');
      rethrow;
    }
  }

  Future<ZIMRoomAttributesOperatedCallResult?> leaveSeat(int seatIndex) async {
    try {
      return roomSeatService?.leaveSeat(seatIndex);
    } catch (e) {
      debugPrint('ZegoLiveAudioRoomManager: Error in leaveSeat: $e');
      rethrow;
    }
  }

  Future<ZIMRoomAttributesOperatedCallResult?> removeSpeakerFromSeat(
      String userID) async {
    try {
      return roomSeatService?.removeSpeakerFromSeat(userID);
    } catch (e) {
      debugPrint(
          'ZegoLiveAudioRoomManager: Error in removeSpeakerFromSeat: $e');
      rethrow;
    }
  }

  Future<ZIMMessageSentResult> muteSpeaker(String userID, bool isMute) async {
    try {
      final messageType =
          isMute ? RoomCommandType.muteSpeaker : RoomCommandType.unMuteSpeaker;
      final commandMap = {
        'room_command_type': messageType,
        'receiver_id': userID
      };
      final result = await ZEGOSDKManager()
          .zimService
          .sendRoomCommand(jsonEncode(commandMap));
      return result;
    } catch (e) {
      debugPrint('ZegoLiveAudioRoomManager: Error in muteSpeaker: $e');
      rethrow;
    }
  }

  Future<ZIMMessageSentResult> kickOutRoom(String userID) async {
    try {
      final commandMap = {
        'room_command_type': RoomCommandType.kickOutRoom,
        'receiver_id': userID
      };
      final result = await ZEGOSDKManager()
          .zimService
          .sendRoomCommand(jsonEncode(commandMap));
      return result;
    } catch (e) {
      debugPrint('ZegoLiveAudioRoomManager: Error in kickOutRoom: $e');
      rethrow;
    }
  }

  void logoutRoom() {
    try {
      ZEGOSDKManager().logoutRoom();
      clear();
    } catch (e) {
      debugPrint('ZegoLiveAudioRoomManager: Error in logoutRoom: $e');
    }
  }

  void clear() {
    try {
      roomSeatService?.clear();
      roomExtraInfoDict.clear();
      isLockSeat.value = false;
      hostUserNoti.value = null;
      musicStateNoti.value = null;
      // MEMORY OPTIMIZATION: Clear retry state to prevent memory leaks
      _musicStateRetryCount = 0;
      _musicStateRetryTimer?.cancel();
      _musicStateRetryTimer = null;
      isMusicStateUpdating.value = false;
      lastMusicError.value = null;

      for (final subscription in subscriptions) {
        subscription.cancel();
      }
      subscriptions.clear();
    } catch (e) {
      debugPrint('ZegoLiveAudioRoomManager: Error in clear: $e');
    }
  }

  Future<ZegoRoomSetRoomExtraInfoResult?> setSelfHost() async {
    try {
      if (ZEGOSDKManager().currentUser == null) return null;

      roomExtraInfoDict['host'] = ZEGOSDKManager().currentUser!.userID;
      final dataJson = jsonEncode(roomExtraInfoDict);
      final result = await ZEGOSDKManager()
          .expressService
          .setRoomExtraInfo(roomKey, dataJson);

      if (result.errorCode == 0) {
        roleNoti.value = ZegoLiveAudioRoomRole.host;
        hostUserNoti.value = ZEGOSDKManager().currentUser;
      }
      return result;
    } catch (e) {
      debugPrint('ZegoLiveAudioRoomManager: Error in setSelfHost: $e');
      rethrow;
    }
  }

  String? getUserAvatar(String userID) {
    try {
      return ZEGOSDKManager().zimService.getUserAvatar(userID);
    } catch (e) {
      debugPrint('ZegoLiveAudioRoomManager: Error getting user avatar: $e');
      return null;
    }
  }

  /// ✅ NEW: Sync per-seat lock state from backend lockseats
  void updateLockedSeats(List<int> lockedSeatIndexes) {
    try {
      for (var seat in seatList) {
        seat.isLocked.value = lockedSeatIndexes.contains(seat.seatIndex);
      }
    } catch (e) {
      debugPrint('ZegoLiveAudioRoomManager: Error updating locked seats: $e');
    }
  }

  void onRoomExtraInfoUpdate(ZegoRoomExtraInfoEvent event) {
    try {
      for (final extraInfo in event.extraInfoList) {
        if (extraInfo.key == roomKey) {
          roomExtraInfoDict = jsonDecode(extraInfo.value);

          if (roomExtraInfoDict.containsKey('lockseat')) {
            final bool temp = roomExtraInfoDict['lockseat'];
            isLockSeat.value = temp;
          }

          if (roomExtraInfoDict.containsKey('host')) {
            final String tempUserID = roomExtraInfoDict['host'];
            hostUserNoti.value = getHostUser(tempUserID);
          }

          /// ✅ APPLY PER-SEAT LOCKS
          if (roomExtraInfoDict.containsKey('lockseats')) {
            List<dynamic> lockedSeatList = roomExtraInfoDict['lockseats'];
            List<int> lockedIndexes = lockedSeatList
                .map((e) => int.tryParse(e.toString()) ?? -1)
                .where((e) => e >= 0)
                .toList();
            updateLockedSeats(lockedIndexes);
          }

          /// ✅ MUSIC STATE SYNC
          if (roomExtraInfoDict.containsKey('music')) {
            try {
              final musicJson = roomExtraInfoDict['music'];
              if (musicJson is Map<String, dynamic>) {
                musicStateNoti.value = MusicPlaybackState.fromJson(musicJson);
              } else if (musicJson is String) {
                musicStateNoti.value =
                    MusicPlaybackState.fromJson(jsonDecode(musicJson));
              }

              // Clear any previous errors when music state updates successfully
              lastMusicError.value = null;
              _musicStateRetryCount = 0;
            } catch (e) {
              debugPrint(
                  'ZegoLiveAudioRoomManager: Error parsing music state: $e');
              lastMusicError.value = 'Failed to parse music state: $e';
            }
          }
        }
      }
    } catch (e) {
      debugPrint(
          'ZegoLiveAudioRoomManager: Error in onRoomExtraInfoUpdate: $e');
    }
  }

  /// Host updates music state which is broadcast to the room via room extra info
  Future<ZegoRoomSetRoomExtraInfoResult?> setMusicState(
      MusicPlaybackState state) async {
    if (roleNoti.value != ZegoLiveAudioRoomRole.host) {
      return null;
    }

    if (isMusicStateUpdating.value) {
      debugPrint(
          'ZegoLiveAudioRoomManager: Music state update already in progress, skipping');
      return null;
    }

    try {
      isMusicStateUpdating.value = true;
      lastMusicError.value = null;

      roomExtraInfoDict['music'] = state.toJson();
      final dataJson = jsonEncode(roomExtraInfoDict);
      final result = await ZEGOSDKManager()
          .expressService
          .setRoomExtraInfo(roomKey, dataJson);

      if (result.errorCode == 0) {
        musicStateNoti.value = state;
        _musicStateRetryCount = 0; // Reset retry count on success
        debugPrint(
            'ZegoLiveAudioRoomManager: Music state updated successfully');
      } else {
        throw Exception('Failed to update music state: ${result.errorCode}');
      }

      return result;
    } catch (e) {
      debugPrint('ZegoLiveAudioRoomManager: Error setting music state: $e');
      lastMusicError.value = 'Failed to update music state: $e';

      // Attempt retry if possible
      if (_musicStateRetryCount < _maxMusicStateRetries) {
        _musicStateRetryCount++;
        debugPrint(
            'ZegoLiveAudioRoomManager: Retrying music state update (attempt $_musicStateRetryCount/$_maxMusicStateRetries)');

        _musicStateRetryTimer?.cancel();
        _musicStateRetryTimer = Timer(const Duration(seconds: 2), () async {
          await setMusicState(state);
        });
      } else {
        debugPrint(
            'ZegoLiveAudioRoomManager: Max retry attempts reached for music state update');
      }

      return null;
    } finally {
      isMusicStateUpdating.value = false;
    }
  }

  void onRoomUserListUpdate(ZegoRoomUserListUpdateEvent event) {
    try {
      if (event.updateType == ZegoUpdateType.Add) {
        final userIDList = <String>[];
        for (final element in event.userList) {
          userIDList.add(element.userID);
        }
        ZEGOSDKManager().zimService.queryUsersInfo(userIDList);
      }
    } catch (e) {
      debugPrint('ZegoLiveAudioRoomManager: Error in onRoomUserListUpdate: $e');
    }
  }

  void onRoomCommandReceived(OnRoomCommandReceivedEvent event) {
    try {
      final Map<String, dynamic> messageMap = jsonDecode(event.command);
      if (messageMap.containsKey('room_command_type')) {
        final type = messageMap['room_command_type'];
        final receiverID = messageMap['receiver_id'];
        if (receiverID == ZEGOSDKManager().currentUser!.userID) {
          if (type == RoomCommandType.muteSpeaker) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                const SnackBar(
                    content: Text('You have been muted by the host')));
            ZEGOSDKManager().expressService.turnMicrophoneOn(false);
          } else if (type == RoomCommandType.unMuteSpeaker) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                const SnackBar(
                    content: Text('You have been unmuted by the host')));
            ZEGOSDKManager().expressService.turnMicrophoneOn(true);
          } else if (type == RoomCommandType.kickOutRoom) {
            logoutRoom();
            Navigator.pop(navigatorKey.currentContext!);
          }
        }
      }
    } catch (e) {
      debugPrint(
          'ZegoLiveAudioRoomManager: Error in onRoomCommandReceived: $e');
    }
  }

  ZegoSDKUser? getHostUser(String userID) {
    try {
      return ZEGOSDKManager().getUser(userID);
    } catch (e) {
      debugPrint('ZegoLiveAudioRoomManager: Error getting host user: $e');
      return null;
    }
  }
}

/// Serializable music playback state used to sync across room
class MusicPlaybackState {
  final String? trackUrl;
  final bool isPlaying;
  final int positionMs;

  MusicPlaybackState(
      {this.trackUrl, required this.isPlaying, required this.positionMs});

  factory MusicPlaybackState.empty() =>
      MusicPlaybackState(trackUrl: null, isPlaying: false, positionMs: 0);
  factory MusicPlaybackState.stopped() =>
      MusicPlaybackState(trackUrl: null, isPlaying: false, positionMs: 0);

  Map<String, dynamic> toJson() => {
        'trackUrl': trackUrl,
        'isPlaying': isPlaying,
        'positionMs': positionMs,
      };

  factory MusicPlaybackState.fromJson(Map<String, dynamic> json) =>
      MusicPlaybackState(
        trackUrl: json['trackUrl'] as String?,
        isPlaying: (json['isPlaying'] ?? false) as bool,
        positionMs: (json['positionMs'] ?? 0) as int,
      );

  MusicPlaybackState copyWith(
      {String? trackUrl, bool? isPlaying, int? positionMs}) {
    return MusicPlaybackState(
      trackUrl: trackUrl ?? this.trackUrl,
      isPlaying: isPlaying ?? this.isPlaying,
      positionMs: positionMs ?? this.positionMs,
    );
  }
}

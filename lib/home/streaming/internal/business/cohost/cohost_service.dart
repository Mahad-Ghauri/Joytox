import 'package:flutter/material.dart';

import '../../../zego_sdk_manager.dart';

bool isHostStreamID(String streamID) {
  return streamID.endsWith('_main_host');
}

class CoHostService {
  ValueNotifier<ZegoSDKUser?> hostNotifier = ValueNotifier(null);
  ListNotifier<ZegoSDKUser> coHostUserListNotifier = ListNotifier([]);

  bool isHost(String userID) {
    return hostNotifier.value?.userID == userID;
  }

  bool isCoHost(String userID) {
    for (final user in coHostUserListNotifier.value) {
      if (user.userID == userID) {
        return true;
      }
    }
    return false;
  }

  bool isAudience(String userID) {
    if (isHost(userID) || isCoHost(userID)) {
      return false;
    }
    return true;
  }

  bool iamHost() {
    return isHost(ZEGOSDKManager().currentUser!.userID);
  }

  void clearData() {
    coHostUserListNotifier.clear();
    hostNotifier.value = null;
  }

  void startCoHost() {
    debugPrint(
        'CoHostService: Starting co-host for user: ${ZEGOSDKManager().currentUser!.userID}');
    coHostUserListNotifier.add(ZEGOSDKManager().currentUser!);
  }

  void endCoHost() {
    debugPrint(
        'CoHostService: Ending co-host for user: ${ZEGOSDKManager().currentUser!.userID}');
    coHostUserListNotifier.removeWhere((element) {
      return element.userID == ZEGOSDKManager().currentUser!.userID;
    });
  }

  void onReceiveStreamUpdate(ZegoRoomStreamListUpdateEvent event) {
    debugPrint(
        'CoHostService: Stream update - Type: ${event.updateType}, Streams: ${event.streamList.map((s) => s.streamID).toList()}');

    if (event.updateType == ZegoUpdateType.Add) {
      for (final element in event.streamList) {
        if (isHostStreamID(element.streamID)) {
          debugPrint(
              'CoHostService: Host stream detected: ${element.streamID}');
          hostNotifier.value = ZEGOSDKManager().getUser(element.user.userID);
          debugPrint(
              'CoHostService: Host set to: ${hostNotifier.value?.userID}');
        } else if (element.streamID.endsWith('_cohost')) {
          debugPrint(
              'CoHostService: Cohost stream detected: ${element.streamID}');
          final cohostUser = ZEGOSDKManager().getUser(element.user.userID);
          if (cohostUser != null) {
            coHostUserListNotifier.add(cohostUser);
            debugPrint('CoHostService: Cohost added: ${cohostUser.userID}');
          }
        }
      }
    } else {
      for (final element in event.streamList) {
        if (isHostStreamID(element.streamID)) {
          debugPrint('CoHostService: Host stream removed: ${element.streamID}');
          hostNotifier.value = null;
        } else if (element.streamID.endsWith('_cohost')) {
          debugPrint(
              'CoHostService: Cohost stream removed: ${element.streamID}');
          coHostUserListNotifier.removeWhere((coHostUser) {
            return coHostUser.userID == element.user.userID;
          });
        }
      }
    }
  }

  void onRoomUserListUpdate(ZegoRoomUserListUpdateEvent event) {
    for (final user in event.userList) {
      if (event.updateType == ZegoUpdateType.Delete) {
        coHostUserListNotifier
            .removeWhere((coHost) => coHost.userID == user.userID);
        if (hostNotifier.value?.userID == user.userID) {
          hostNotifier.value = null;
        }
      }
    }
  }
}

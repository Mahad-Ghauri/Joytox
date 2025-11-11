import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/instance_manager.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

import '../controller/controller.dart';

Controller controller = Get.put(Controller());

class PointsController {
  static StreamSubscription? _subscription;

  /// Initialize the points controller with command receiver for the current room
  /// This listens to commands sent TO this room (from both this room and opponent room)
  static void initialize(String roomID, Function(int, int) onPointsUpdate) {
    // Cancel any existing subscription
    _subscription?.cancel();
    
    // Subscribe to command stream for THIS room only
    // We will receive commands from:
    // 1. Same room users (when gifts sent to our host)
    // 2. Opponent room (when they send cross-room updates)
    _subscribeToCommands(roomID, onPointsUpdate);
    
    debugPrint('🎯 PointsController initialized for room: $roomID');
  }

  static void loadInitialPoints(
      int myPoints, int hisPoints, Function(int, int) onPointsUpdate) {
    controller.myBattlePoints.value = myPoints;
    controller.hisBattlePoints.value = hisPoints;
    onPointsUpdate(myPoints, hisPoints);
    debugPrint('🎯 Initial points loaded - My: $myPoints, His: $hisPoints');
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
    debugPrint('🎯 PointsController disposed');
  }

  static void _subscribeToCommands(
      String roomID, Function(int, int) onPointsUpdate) {
    _subscription = ZegoUIKitPrebuiltLiveStreamingController()
        .room
        .commandReceivedStream()
        .listen((event) {
      for (var message in event.messages) {
        final commandString = utf8.decode(message.message);
        try {
          final command = jsonDecode(commandString);
          if (command is Map<String, dynamic>) {
            // Extract command metadata
            final senderRoomID = command['senderRoomID'] ?? '';
            final currentRoomID = command['currentRoomID'] ?? roomID;
            final isFromOpponent = senderRoomID.isNotEmpty && senderRoomID != currentRoomID;

            debugPrint('🎯 [${roomID}] Command received: $commandString');
            debugPrint('🎯 Sender room: $senderRoomID, My room: $currentRoomID, From opponent: $isFromOpponent');

            // Handle points update
            if (command.containsKey('points')) {
              final points = command['points'] as int;
              
              if (isFromOpponent) {
                // Points from opponent room = update hisBattlePoints
                debugPrint('🎯 ✅ OPPONENT points update: $points');
                _updateHisPoints(points, onPointsUpdate);
              } else {
                // Points from my room = update myBattlePoints
                debugPrint('🎯 ✅ MY points update: $points');
                _updateMyPoints(points, onPointsUpdate);
              }
            }
          }
        } catch (e) {
          debugPrint('🎯 ❌ Error decoding command: $e');
        }
      }
    });
    
    debugPrint('🎯 Started listening to commands in room: $roomID');
  }

  static void _updateMyPoints(int absolutePoints, Function(int, int) onPointsUpdate) {
    controller.myBattlePoints.value = absolutePoints;
    onPointsUpdate(
        controller.myBattlePoints.value, controller.hisBattlePoints.value);
  }

  static void _updateHisPoints(int absolutePoints, Function(int, int) onPointsUpdate) {
    // Use absolute value instead of incremental to avoid accumulation errors
    controller.hisBattlePoints.value = absolutePoints;
    onPointsUpdate(
        controller.myBattlePoints.value, controller.hisBattlePoints.value);
  }

  /// Send points update to MY room only
  /// The opponent will receive updates via cloud function database sync + LiveQuery
  static void sendPointsUpdateToMyRoom({
    required String currentRoomID,
    required int myTotalPoints,
    required String senderHostID,
  }) async {
    // Create command with room identification
    final command = jsonEncode({
      'points': myTotalPoints,
      'senderRoomID': currentRoomID,
      'currentRoomID': currentRoomID,
      'senderHostID': senderHostID,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    debugPrint('🎯 📤 Sending points=$myTotalPoints to MY room=$currentRoomID');

    // Send to MY room (so viewers in my room see the update)
    // NOTE: Cannot send to opponent's room - Zego doesn't support cross-room commands
    // Opponent will get updates via cloud function + LiveQuery database sync
    ZegoUIKitPrebuiltLiveStreamingController().room.sendCommand(
      roomID: currentRoomID,
      command: Uint8List.fromList(utf8.encode(command)),
    ).then((sent) {
      if (sent) {
        debugPrint('🎯 ✅ Sent to MY room ($currentRoomID)');
      } else {
        debugPrint('🎯 ❌ Failed to send to MY room');
      }
    });
  }

  static void updateLocalPoints(int absolutePoints, Function(int, int) onPointsUpdate) {
    // Use absolute value for consistency
    controller.myBattlePoints.value = absolutePoints;
    onPointsUpdate(
        controller.myBattlePoints.value, controller.hisBattlePoints.value);
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/instance_manager.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

import '../controller/controller.dart';

Controller controller = Get.put(Controller());

class TimerController {
  static late StreamSubscription _subscription;
  static Timer? _timer;
  static int _battleStartTime = 0;
  //static int _remainingTime = 0;

  static void initialize(
      {required String roomID, required Function(int) onTimerUpdate}) {
    _subscribeToCommands(roomID: roomID, onTimerUpdate: onTimerUpdate);
  }

  static void dispose() {
    _subscription.cancel();
    _timer?.cancel();
  }

  static void _subscribeToCommands(
      {required String roomID, required Function(int) onTimerUpdate}) {
    _subscription = ZegoUIKitPrebuiltLiveStreamingController()
        .room
        .commandReceivedStream()
        .listen((event) {
      for (var message in event.messages) {
        final commandString = utf8.decode(message.message);
        print('Raw command received: $commandString');
        try {
          final command = jsonDecode(commandString);
          if (command is Map<String, dynamic>) {
            // Handle timer commands
            if (command.containsKey('startTime') &&
                command.containsKey('duration')) {
              final startTime = command['startTime'];
              final int duration = command['duration'];
              debugPrint('Timer command received: $commandString');
              if (duration > 0) {
                startTimer(
                    startTime: startTime,
                    onTimerUpdate: onTimerUpdate,
                    battleDuration: duration);
              }
            }
            // Handle battle result commands
            else if (command.containsKey('type') &&
                command['type'] == 'battleResult') {
              debugPrint(
                  '🏆 [PK BATTLE] Battle result command received: $commandString');
              handleBattleResultCommand(command);
            } else {
              debugPrint('Invalid command format');
            }
          } else {
            debugPrint('Invalid command format');
          }
        } catch (e) {
          debugPrint('Error decoding command: $e');
        }
      }
    });
  }

  static void handleBattleResultCommand(Map<String, dynamic> command) {
    final action = command['action'];
    if (action == 'show') {
      final myPoints = command['myPoints'] ?? 0;
      final hisPoints = command['hisPoints'] ?? 0;
      debugPrint(
          '🏆 [PK BATTLE] Showing battle result - My points: $myPoints, His points: $hisPoints');

      // Update battle points for display
      controller.myBattlePoints.value = myPoints;
      controller.hisBattlePoints.value = hisPoints;
      controller.showBattleWinner.value = true;

      // Auto-hide after 15 seconds
      Future.delayed(Duration(seconds: 15), () {
        controller.showBattleWinner.value = false;
        debugPrint('🏆 [PK BATTLE] Auto-hiding battle result after 15 seconds');
      });
    } else if (action == 'hide') {
      debugPrint('🏆 [PK BATTLE] Hiding battle result');
      controller.showBattleWinner.value = false;
    }
  }

  static void startTimer({
    required int startTime,
    required Function(int) onTimerUpdate,
    required int battleDuration,
  }) {
    _battleStartTime = startTime;
    controller.battleTimer.value = _calculateRemainingTime(battleDuration);
    debugPrint('Timer started with start time: $_battleStartTime');

    _timer?.cancel(); // Cancel any previous timer
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      controller.battleTimer.value = _calculateRemainingTime(battleDuration);
      debugPrint('Remaining Time: ${controller.battleTimer.value} seconds');
      onTimerUpdate(controller.battleTimer.value);
      if (controller.battleTimer.value <= 0) {
        timer.cancel();
        debugPrint('Timer finished');
      }
    });
  }

  static int _calculateRemainingTime(int duration) {
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final elapsedTime = currentTime - _battleStartTime;
    int battleDuration = duration; // battle time
    return battleDuration - elapsedTime;
  }

  static void startLocalTimer(
      {required Function(int) onTimerUpdate, required int duration}) {
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    startTimer(
        startTime: currentTime,
        onTimerUpdate: onTimerUpdate,
        battleDuration: duration);
  }
}

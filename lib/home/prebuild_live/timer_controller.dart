import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/instance_manager.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

import '../controller/controller.dart';

Controller controller = Get.put(Controller());

class TimerController {
  static StreamSubscription? _subscription;
  static Timer? _timer;
  static int _battleStartTime = 0;
  static int _lastRemainingTime = -1; // Track to prevent duplicate logs

  static void initialize(
      {required String roomID, required Function(int) onTimerUpdate}) {
    _subscribeToCommands(roomID: roomID, onTimerUpdate: onTimerUpdate);
  }

  static void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    _battleStartTime = 0;
    _lastRemainingTime = -1;
    debugPrint('[TIMER_CONTROLLER] 🛑 Disposed and reset');
  }
  
  // Reset timer state (for restart scenarios)
  static void reset() {
    _timer?.cancel();
    _battleStartTime = 0;
    _lastRemainingTime = -1;
    debugPrint('[TIMER_CONTROLLER] 🔄 Reset called - cleared old state');
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
          if (command is Map<String, dynamic> &&
              command.containsKey('startTime') &&
              command.containsKey('duration')) {
            final startTime = command['startTime'];
            final int duration = command['duration'];
            debugPrint('Command received: $commandString');
            if (duration > 0) {
              startTimer(
                  startTime: startTime,
                  onTimerUpdate: onTimerUpdate,
                  battleDuration: duration);
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

  static void startTimer({
    required int startTime,
    required Function(int) onTimerUpdate,
    required int battleDuration,
  }) {
    debugPrint('[TIMER_CONTROLLER] 🚀 ========== STARTING TIMER ==========');
    debugPrint('[TIMER_CONTROLLER] 📅 Start time: $startTime');
    debugPrint('[TIMER_CONTROLLER] ⏱️  Duration: $battleDuration seconds');
    
    // Cancel any existing timer first
    _timer?.cancel();
    
    // Set new start time
    _battleStartTime = startTime;
    
    // Calculate initial remaining time
    final initialRemaining = _calculateRemainingTime(battleDuration);
    _lastRemainingTime = initialRemaining;
    
    debugPrint('[TIMER_CONTROLLER] ⏰ Initial remaining: $initialRemaining seconds');
    debugPrint('[TIMER_CONTROLLER] ✅ Timer initialized and running');
    
    // Immediately update via callback to set correct initial value
    onTimerUpdate(initialRemaining);

    // Start periodic timer
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      final remaining = _calculateRemainingTime(battleDuration);
      
      // Only log if time changed (prevent spam)
      if (remaining != _lastRemainingTime) {
        if (remaining % 10 == 0 || remaining <= 5) {
          debugPrint('[TIMER_CONTROLLER] ⏱️  ${remaining}s remaining');
        }
        _lastRemainingTime = remaining;
      }
      
      onTimerUpdate(remaining);
      
      if (remaining <= 0) {
        timer.cancel();
        debugPrint('[TIMER_CONTROLLER] 🏁 Timer finished - Battle ended');
        _battleStartTime = 0;
        _lastRemainingTime = -1;
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
    debugPrint('[TIMER_CONTROLLER] 🎯 Starting LOCAL timer');
    debugPrint('[TIMER_CONTROLLER] 🕐 Current timestamp: $currentTime');
    startTimer(
        startTime: currentTime,
        onTimerUpdate: onTimerUpdate,
        battleDuration: duration);
  }
}

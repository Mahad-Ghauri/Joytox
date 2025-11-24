import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:trace/models/LiveStreamingModel.dart';

/// Singleton service that handles automatic cleanup of stream documents
/// when the host closes the app without explicitly ending the stream.
class StreamCleanupService {
  static final StreamCleanupService instance = StreamCleanupService._internal();

  factory StreamCleanupService() {
    return instance;
  }

  StreamCleanupService._internal();

  // Current stream being monitored (if any)
  LiveStreamingModel? _monitoredStream;

  // Timer for delayed cleanup
  Timer? _cleanupTimer;

  // Flag to track if we're monitoring a stream
  bool _isMonitoring = false;

  // Flag to prevent duplicate cleanup attempts
  bool _cleanupInProgress = false;

  /// Start monitoring a stream for cleanup
  /// Called when host starts streaming
  void startMonitoring(LiveStreamingModel stream) {
    debugPrint(
        '[STREAM_CLEANUP] 🎬 Starting monitoring for stream: ${stream.objectId}');
    debugPrint('[STREAM_CLEANUP] 📍 Channel: ${stream.getStreamingChannel}');

    // Cancel any existing timer
    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    // Store the stream reference
    _monitoredStream = stream;
    _isMonitoring = true;
    _cleanupInProgress = false;

    debugPrint('[STREAM_CLEANUP] ✅ Monitoring started');
  }

  /// Stop monitoring the stream
  /// Called when host ends stream normally (will delete immediately elsewhere)
  void stopMonitoring() {
    debugPrint('[STREAM_CLEANUP] 🛑 Stopping monitoring');

    // Cancel any pending cleanup timer
    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    // Clear references
    _monitoredStream = null;
    _isMonitoring = false;
    _cleanupInProgress = false;

    debugPrint('[STREAM_CLEANUP] ✅ Monitoring stopped');
  }

  /// Called when app goes to background/paused
  /// Starts 10-second countdown to delete stream
  void onAppPaused() {
    if (!_isMonitoring || _monitoredStream == null) {
      debugPrint(
          '[STREAM_CLEANUP] ⏸️ App paused but no stream being monitored');
      return;
    }

    if (_cleanupInProgress) {
      debugPrint(
          '[STREAM_CLEANUP] ⏸️ App paused but cleanup already in progress');
      return;
    }

    debugPrint(
        '[STREAM_CLEANUP] ⏸️ App paused - starting 10-second cleanup timer');
    debugPrint(
        '[STREAM_CLEANUP] 📍 Stream to delete: ${_monitoredStream!.objectId}');

    // Cancel any existing timer
    _cleanupTimer?.cancel();

    // Start 10-second countdown
    _cleanupTimer = Timer(const Duration(seconds: 10), () {
      debugPrint('[STREAM_CLEANUP] ⏰ 10 seconds elapsed - executing cleanup');
      _deleteStreamDocument();
    });

    debugPrint('[STREAM_CLEANUP] ⏰ Timer started - will delete in 10 seconds');
  }

  /// Called when app resumes/comes to foreground
  /// Cancels the cleanup timer if it's running
  void onAppResumed() {
    if (_cleanupTimer != null) {
      debugPrint('[STREAM_CLEANUP] ▶️ App resumed - cancelling cleanup timer');
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
      debugPrint(
          '[STREAM_CLEANUP] ✅ Cleanup timer cancelled - stream preserved');
    } else {
      debugPrint('[STREAM_CLEANUP] ▶️ App resumed (no active timer)');
    }
  }

  /// Delete the stream document from Parse database
  Future<void> _deleteStreamDocument() async {
    if (_cleanupInProgress) {
      debugPrint('[STREAM_CLEANUP] ⚠️ Cleanup already in progress, skipping');
      return;
    }

    if (_monitoredStream == null) {
      debugPrint('[STREAM_CLEANUP] ⚠️ No stream to delete');
      return;
    }

    _cleanupInProgress = true;

    try {
      final streamId = _monitoredStream!.objectId;
      final streamChannel = _monitoredStream!.getStreamingChannel;

      debugPrint('[STREAM_CLEANUP] 🗑️ Deleting stream document...');
      debugPrint('[STREAM_CLEANUP] 📍 Stream ID: $streamId');
      debugPrint('[STREAM_CLEANUP] 📍 Channel: $streamChannel');

      // Check if stream is in active PK battle - if so, handle carefully
      final isBattle = _monitoredStream!.getBattle ?? false;
      final battleStatus = _monitoredStream!.getBattleStatus;

      if (isBattle && battleStatus == LiveStreamingModel.battleAlive) {
        debugPrint('[STREAM_CLEANUP] ⚠️ Stream is in active PK battle');
        debugPrint(
            '[STREAM_CLEANUP] 🔧 Setting battle status to ended before deletion');

        // End the battle gracefully before deletion
        _monitoredStream!.setBattle = false;
        _monitoredStream!.setBattleStatus = LiveStreamingModel.battleEnded;
        await _monitoredStream!.save();

        // Give a moment for battle cleanup
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Delete the stream document
      final response = await _monitoredStream!.delete();

      if (response.success) {
        debugPrint('[STREAM_CLEANUP] ✅ Stream document deleted successfully');
        debugPrint('[STREAM_CLEANUP] 🎉 Cleanup completed');
      } else {
        debugPrint(
            '[STREAM_CLEANUP] ❌ Failed to delete stream: ${response.error?.message}');
      }
    } catch (e) {
      debugPrint('[STREAM_CLEANUP] ❌ Error during cleanup: $e');
    } finally {
      // Clear everything
      _monitoredStream = null;
      _isMonitoring = false;
      _cleanupInProgress = false;
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
    }
  }

  /// Force cleanup (for emergency situations)
  Future<void> forceCleanup() async {
    debugPrint('[STREAM_CLEANUP] 🚨 Force cleanup requested');
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    await _deleteStreamDocument();
  }

  /// Get monitoring status (for debugging)
  bool get isMonitoring => _isMonitoring;
  bool get hasActiveTimer => _cleanupTimer != null;
  String? get monitoredStreamId => _monitoredStream?.objectId;
}

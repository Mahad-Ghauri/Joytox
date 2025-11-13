// ===============================
// 🔄 PK Points Sync Service (JOYTOX)
// ===============================
// Real-time synchronization using Parse LiveQuery
// Eliminates polling and ensures instant updates

import 'dart:async';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:flutter/foundation.dart';

class PKPointsSyncService {
  static final PKPointsSyncService _instance = PKPointsSyncService._internal();
  factory PKPointsSyncService() => _instance;
  PKPointsSyncService._internal();

  // LiveQuery subscriptions
  Subscription<ParseObject>? _myChannelSubscription;
  LiveQuery? _liveQuery;

  // Callbacks for UI updates
  Function(int myPoints, int hisPoints)? onPointsUpdated;
  
  // Current state
  String? _currentChannel;
  int _myPoints = 0;
  int _hisPoints = 0;

  // ========================================
  // Initialize LiveQuery for a channel
  // ========================================
  Future<void> startListening(String channel) async {
    if (_currentChannel == channel && _myChannelSubscription != null) {
      debugPrint('✅ Already listening to $channel');
      return;
    }

    // Stop any existing subscription
    await stopListening();

    _currentChannel = channel;
    _liveQuery = LiveQuery();

    try {
      // Create query for PKUpdate events on this channel
      final query = QueryBuilder<ParseObject>(ParseObject('PKUpdate'))
        ..whereEqualTo('channel', channel);

      // Subscribe to LiveQuery
      _myChannelSubscription = await _liveQuery!.client.subscribe(query);

      // Listen for CREATE events (new updates)
      _myChannelSubscription!.on(LiveQueryEvent.create, (ParseObject value) {
        _handleLiveUpdate(value);
      });

      // Listen for UPDATE events
      _myChannelSubscription!.on(LiveQueryEvent.update, (ParseObject value) {
        _handleLiveUpdate(value);
      });

      debugPrint('✅ LiveQuery started for channel: $channel');
    } catch (e) {
      debugPrint('❌ Failed to start LiveQuery: $e');
    }
  }

  // ========================================
  // Handle incoming LiveQuery update
  // ========================================
  void _handleLiveUpdate(ParseObject update) {
    try {
      final myPoints = update.get<int>('my_points') ?? 0;
      final hisPoints = update.get<int>('his_points') ?? 0;
      final timestamp = update.get<int>('timestamp') ?? 0;

      // Ignore stale updates (older than 5 seconds)
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > 5000) {
        debugPrint('⏰ Ignoring stale update (${age}ms old)');
        return;
      }

      // Update local state
      _myPoints = myPoints;
      _hisPoints = hisPoints;

      // Notify UI
      onPointsUpdated?.call(myPoints, hisPoints);

      debugPrint('📡 LiveQuery update | My: $myPoints, His: $hisPoints');
    } catch (e) {
      debugPrint('❌ Error handling LiveQuery update: $e');
    }
  }

  // ========================================
  // Add points (send gift)
  // ========================================
  Future<bool> addPoints(String channel, int points) async {
    try {
      debugPrint('🎁 Sending +$points to channel $channel');

      final response = await ParseCloudFunction('addPKPoints').execute(
        parameters: {
          'liveChannel': channel,
          'points': points,
        },
      );

      if (response.success && response.result != null) {
        final result = response.result as Map<String, dynamic>;
        
        // Update local state immediately (optimistic update)
        _myPoints = result['my_points'] ?? _myPoints;
        _hisPoints = result['his_points'] ?? _hisPoints;
        
        // Notify UI
        onPointsUpdated?.call(_myPoints, _hisPoints);

        debugPrint('✅ Points added | My: $_myPoints, His: $_hisPoints');
        return true;
      } else {
        debugPrint('❌ Failed to add points: ${response.error?.message}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error adding points: $e');
      return false;
    }
  }

  // ========================================
  // Fetch current points from database
  // ========================================
  Future<Map<String, int>> fetchCurrentPoints(String channel) async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Streaming'))
        ..whereEqualTo('streaming_channel', channel);

      final result = await query.first();
      
      if (result != null) {
        _myPoints = result.get<int>('my_points') ?? 0;
        _hisPoints = result.get<int>('his_points') ?? 0;

        debugPrint('📊 Fetched points | My: $_myPoints, His: $_hisPoints');
        
        return {
          'my_points': _myPoints,
          'his_points': _hisPoints,
        };
      }
    } catch (e) {
      debugPrint('❌ Error fetching points: $e');
    }
    
    return {'my_points': 0, 'his_points': 0};
  }

  // ========================================
  // Stop listening
  // ========================================
  Future<void> stopListening() async {
    if (_myChannelSubscription != null) {
      _liveQuery?.client.unSubscribe(_myChannelSubscription!);
      _myChannelSubscription = null;
      debugPrint('🛑 Stopped LiveQuery for $_currentChannel');
    }
    _currentChannel = null;
  }

  // ========================================
  // Get current state
  // ========================================
  int get myPoints => _myPoints;
  int get hisPoints => _hisPoints;
  
  // ========================================
  // Dispose
  // ========================================
  void dispose() {
    stopListening();
    onPointsUpdated = null;
  }
}

import 'dart:async';
import 'package:get/get.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:trace/models/LiveStreamingModel.dart';

/// BattlePointsManager - Single Source of Truth for PK Battle Points
/// 
/// This manager ensures:
/// 1. Reads from the CORRECT document (the host whose stream you joined)
/// 2. Single state source - eliminates conflicts between multiple controllers
/// 3. Automatic UI rebuilds when points change
/// 4. Polling backup for LiveQuery reliability
/// 5. Fresh data fetch on viewer join
class BattlePointsManager extends GetxController {
  // Observable points - UI automatically rebuilds on changes
  final RxInt myPoints = 0.obs;
  final RxInt hisPoints = 0.obs;
  final RxBool isPolling = false.obs;
  
  // The document we're reading from (the host whose stream we joined)
  LiveStreamingModel? _currentStreamingDoc;
  
  // Polling timer for backup sync
  Timer? _pollingTimer;
  
  // LiveQuery subscription
  Subscription<ParseObject>? _liveQuerySubscription;
  
  /// Initialize manager with the streaming document
  /// CRITICAL: Pass the document of the host whose stream you're viewing
  /// For host: pass their own document
  /// For viewers: pass the document from widget.liveStreaming
  /// 
  /// Safe to call multiple times - will clean up and re-initialize
  void initialize(LiveStreamingModel streamingDoc) {
    print('[PK_BATTLE_SYNC] BattlePointsManager initialized for channel: ${streamingDoc.getStreamingChannel}');
    
    // Clean up any existing subscriptions/polling if re-initializing
    if (isPolling.value) {
      stopPolling();
    }
    _liveQuerySubscription = null;
    
    _currentStreamingDoc = streamingDoc;
    
    // Load initial points from the correct document
    _loadPointsFromDocument();
    
    // Start LiveQuery subscription
    _setupLiveQuery();
    
    // Start polling backup
    _startPolling();
  }
  
  /// Load points from the streaming document
  /// my_points = points of the host whose stream you're viewing
  /// his_points = points of their opponent
  void _loadPointsFromDocument() {
    if (_currentStreamingDoc == null) return;
    
    final newMyPoints = _currentStreamingDoc!.getMyBattlePoints ?? 0;
    final newHisPoints = _currentStreamingDoc!.getHisBattlePoints ?? 0;
    
    print('[PK_BATTLE_SYNC] Loaded from document - My: $newMyPoints, His: $newHisPoints');
    
    myPoints.value = newMyPoints;
    hisPoints.value = newHisPoints;
  }
  
  /// Setup LiveQuery to listen for database updates
  void _setupLiveQuery() async {
    if (_currentStreamingDoc == null) return;
    
    try {
      final String streamingChannel = _currentStreamingDoc!.getStreamingChannel ?? '';
      
      if (streamingChannel.isEmpty) {
        print('[PK_BATTLE_SYNC] ERROR: Empty streaming channel, cannot setup LiveQuery');
        return;
      }
      
      // Query for THIS specific document
      QueryBuilder<LiveStreamingModel> query = QueryBuilder<LiveStreamingModel>(LiveStreamingModel())
        ..whereEqualTo('streaming_channel', streamingChannel);
      
      _liveQuerySubscription = await LiveQuery().client.subscribe(query);
      
      // Listen for UPDATE events
      _liveQuerySubscription!.on(LiveQueryEvent.update, (LiveStreamingModel updatedDoc) {
        print('[PK_BATTLE_SYNC] LiveQuery UPDATE received for channel: $streamingChannel');
        
        // Update the document reference
        _currentStreamingDoc = updatedDoc;
        
        // Load fresh points
        _loadPointsFromDocument();
      });
      
      print('[PK_BATTLE_SYNC] LiveQuery subscription active for channel: $streamingChannel');
      
    } catch (e) {
      print('[PK_BATTLE_SYNC] ERROR setting up LiveQuery: $e');
    }
  }
  
  /// Start polling backup - queries database every 2 seconds
  /// This ensures points sync even if LiveQuery has delays
  void _startPolling() {
    if (isPolling.value) return;
    
    isPolling.value = true;
    print('[PK_BATTLE_SYNC] Polling backup started (every 2 seconds)');
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchFreshPoints();
    });
  }
  
  /// Stop polling backup
  void stopPolling() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
      isPolling.value = false;
      print('[PK_BATTLE_SYNC] Polling backup stopped');
    }
  }
  
  /// Fetch fresh points from database
  Future<void> _fetchFreshPoints() async {
    if (_currentStreamingDoc == null) return;
    
    try {
      final String streamingChannel = _currentStreamingDoc!.getStreamingChannel ?? '';
      
      if (streamingChannel.isEmpty) return;
      
      // Query for the current document
      QueryBuilder<LiveStreamingModel> query = QueryBuilder<LiveStreamingModel>(LiveStreamingModel())
        ..whereEqualTo('streaming_channel', streamingChannel);
      
      final response = await query.query();
      
      if (response.success && response.results != null && response.results!.isNotEmpty) {
        final LiveStreamingModel freshDoc = response.results!.first as LiveStreamingModel;
        
        // Update document reference
        _currentStreamingDoc = freshDoc;
        
        // Get fresh points
        final freshMyPoints = _currentStreamingDoc!.getMyBattlePoints ?? 0;
        final freshHisPoints = _currentStreamingDoc!.getHisBattlePoints ?? 0;
        
        // Only log if points changed (reduce spam)
        if (freshMyPoints != myPoints.value || freshHisPoints != hisPoints.value) {
          print('[PK_BATTLE_SYNC] Polling found new points - My: $freshMyPoints (was ${myPoints.value}), His: $freshHisPoints (was ${hisPoints.value})');
          
          myPoints.value = freshMyPoints;
          hisPoints.value = freshHisPoints;
        }
        
      }
    } catch (e) {
      print('[PK_BATTLE_SYNC] ERROR fetching fresh points: $e');
    }
  }
  
  /// Manually update points (e.g., from cloud function response)
  /// Call this after sending gift to own host
  void updatePoints({required int newMyPoints, required int newHisPoints}) {
    print('[PK_BATTLE_SYNC] Manual update - My: $newMyPoints, His: $newHisPoints');
    
    myPoints.value = newMyPoints;
    hisPoints.value = newHisPoints;
    
    // Also update the document reference
    if (_currentStreamingDoc != null) {
      _currentStreamingDoc!.setMyBattlePoints = newMyPoints;
      _currentStreamingDoc!.setHisBattlePoints = newHisPoints;
    }
  }
  
  /// Reset points to zero (new battle start)
  void resetPoints() {
    print('[PK_BATTLE_SYNC] Resetting points to zero');
    
    myPoints.value = 0;
    hisPoints.value = 0;
    
    if (_currentStreamingDoc != null) {
      _currentStreamingDoc!.setMyBattlePoints = 0;
      _currentStreamingDoc!.setHisBattlePoints = 0;
    }
  }
  
  /// Fetch fresh points immediately (for viewers joining mid-battle)
  Future<void> fetchFreshPointsNow() async {
    print('[PK_BATTLE_SYNC] Fetching fresh points NOW (viewer joined or refresh needed)');
    await _fetchFreshPoints();
  }
  
  /// Cleanup - call when battle ends or user leaves
  @override
  void onClose() {
    print('[PK_BATTLE_SYNC] BattlePointsManager cleanup');
    
    stopPolling();
    
    // LiveQuery subscriptions clean up automatically when not used
    _liveQuerySubscription = null;
    
    super.onClose();
  }
}

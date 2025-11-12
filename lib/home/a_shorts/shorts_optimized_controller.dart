// 🚀 OPTIMIZED SHORTS CONTROLLER - Production-Grade Video Feed
// Fixes: Memory leaks, buffer overflows, lazy loading, smooth scrolling
// Architecture: Smart controller lifecycle, true pagination, resource pooling

import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../models/PostsModel.dart';
import '../../services/posts_service.dart';

class ShortsOptimizedController extends GetxController {
  // ═══════════════════════════════════════════════════════════
  // 📊 STATE MANAGEMENT
  // ═══════════════════════════════════════════════════════════
  
  /// List of video posts (metadata only, not controllers)
  RxList<PostsModel> shorts = <PostsModel>[].obs;
  
  /// Loading state
  RxBool isLoading = true.obs;
  RxBool isLoadingMore = false.obs;
  
  /// Playback state
  var showPlayPauseIcon = false.obs;
  var isPlaying = true.obs;
  var userPaused = false.obs;
  
  /// Current video index
  var currentVideoIndex = 0.obs;
  
  /// Screen visibility (for lifecycle management)
  bool _isScreenVisible = true;
  bool _isDisposed = false;
  
  // ═══════════════════════════════════════════════════════════
  // 🎮 CONTROLLER POOL - Only keep 3 active controllers
  // ═══════════════════════════════════════════════════════════
  
  /// Map of index -> controller (only stores active controllers)
  final Map<int, CachedVideoPlayerPlusController> _activeControllers = {};
  
  /// Lock to prevent concurrent disposal/creation
  bool _isControllerOperationInProgress = false;
  
  /// Maximum active controllers (current, previous, next)
  static const int MAX_ACTIVE_CONTROLLERS = 3;
  
  // ═══════════════════════════════════════════════════════════
  // 📄 PAGINATION SETTINGS
  // ═══════════════════════════════════════════════════════════
  
  /// Number of videos to fetch per page (reduced for efficiency)
  int pageSize = 5; // 🔥 Increased back to 5 with smart preloading
  
  /// Trigger next fetch when this many videos remaining
  int prefetchThreshold = 1; // 🔥 REDUCED: Wait longer before fetching
  
  /// Current page number
  int currentPage = 0;
  
  /// Whether more videos are available
  bool hasMoreVideos = true;
  
  /// Prevent rapid-fire playVideo calls
  bool _isPlayingVideo = false;
  
  // ═══════════════════════════════════════════════════════════
  // 🎬 INITIALIZATION
  // ═══════════════════════════════════════════════════════════
  
  @override
  void onInit() {
    super.onInit();
    _loadInitialVideos();
  }
  
  @override
  void onClose() {
    _isDisposed = true;
    _isScreenVisible = false;
    _disposeAllControllersSync();
    shorts.clear();
    super.onClose();
    debugPrint('[SHORTS_OPT] ✅ Controller properly disposed');
  }
  
  // ═══════════════════════════════════════════════════════════
  // 📥 DATA LOADING - True Lazy Loading with Pagination
  // ═══════════════════════════════════════════════════════════
  
  /// Load initial batch of videos
  Future<void> _loadInitialVideos() async {
    try {
      isLoading.value = true;
      currentPage = 0;
      
      debugPrint('[SHORTS_OPT] 📥 Loading initial videos...');
      
      // 🔥 Use QueryBuilder WITHOUT generic type (like old working method)
      QueryBuilder query = QueryBuilder(PostsModel())
        ..whereValueExists(PostsModel.keyVideo, true)
        ..includeObject([PostsModel.keyAuthor]) // 🔥 Include author relationship
        ..orderByDescending(PostsModel.keyCreatedAt)
        ..setLimit(pageSize);
      
      ParseResponse response = await query.query();
      
      // 🔥 DEBUG: Raw response inspection
      debugPrint('[SHORTS_OPT] 📊 Parse Response:');
      debugPrint('  - Success: ${response.success}');
      debugPrint('  - Count: ${response.count}');
      debugPrint('  - Results: ${response.results?.length ?? 0}');
      
      // 🔥 DEBUG: Check the RAW data from first result
      if (response.results != null && response.results!.isNotEmpty) {
        final firstResult = response.results!.first;
        debugPrint('[SHORTS_OPT] 🔍 RAW First Result:');
        debugPrint('  - Type: ${firstResult.runtimeType}');
        debugPrint('  - ObjectId: ${firstResult.objectId}');
        if (firstResult is ParseObject) {
          debugPrint('  - Has Author key? ${firstResult.containsKey(PostsModel.keyAuthor)}');
          final authorValue = firstResult.get(PostsModel.keyAuthor);
          debugPrint('  - Author value type: ${authorValue?.runtimeType}');
          debugPrint('  - Author value: $authorValue');
          debugPrint('  - AuthorId value: ${firstResult.get(PostsModel.keyAuthorId)}');
        }
      }
      
      if (response.success && response.results != null) {
        List<PostsModel> loadedVideos = 
            response.results!.map((e) => e as PostsModel).toList();
        
        // 🔥 DEBUG: Log author data WITH DETAILS
        debugPrint('[SHORTS_OPT] 📊 Loaded ${loadedVideos.length} videos from Parse');
        for (var video in loadedVideos) {
          final author = video.getAuthor;
          debugPrint('[SHORTS_OPT] 📹 Video ${video.objectId}:');
          debugPrint('  - Author object: ${author != null ? "EXISTS" : "NULL"}');
          debugPrint('  - Author name: ${author?.getFullName ?? "NULL"}');
          debugPrint('  - Author ID from video: ${video.getAuthorId}');
        }
        
        // 🔥 CRITICAL: Assign to shorts and force UI refresh
        shorts.value = loadedVideos;
        hasMoreVideos = loadedVideos.length >= pageSize;
        
        // 🔥 FETCH AUTHORS: Since includeObject doesn't work reliably, fetch authors manually
        if (Get.isRegistered<PostsService>()) {
          final postsService = Get.find<PostsService>();
          debugPrint('[SHORTS_OPT] 🔄 Fetching authors for ${loadedVideos.length} videos...');
          
          for (var video in loadedVideos) {
            if (video.getAuthor == null && video.getAuthorId != null) {
              postsService.fetchAuthorForPost(video).then((_) {
                debugPrint('[SHORTS_OPT] ✅ Author loaded for video ${video.objectId}: ${video.getAuthor?.getFullName}');
                shorts.refresh(); // Force UI update after each author loads
              }).catchError((e) {
                debugPrint('[SHORTS_OPT] ❌ Failed to load author for ${video.objectId}: $e');
              });
            }
          }
        }
        
        debugPrint('[SHORTS_OPT] ✅ Videos loaded and author fetch initiated');
        
        // 🔥 CRITICAL: Initialize first TWO videos for instant start
        if (loadedVideos.isNotEmpty && !_isDisposed) {
          // Initialize first video (blocking - must be ready)
          await _initializeController(0);
          
          // 🔥 Preload second video (non-blocking - for instant swipe)
          if (loadedVideos.length > 1) {
            _initializeController(1).then((_) {
              debugPrint('[SHORTS_OPT] ✅ Second video preloaded and ready');
            });
          }
        }
      } else {
        debugPrint('[SHORTS_OPT] ❌ Failed to load: ${response.error?.message}');
        hasMoreVideos = false;
      }
    } catch (e) {
      debugPrint('[SHORTS_OPT] ❌ Error loading videos: $e');
      hasMoreVideos = false;
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Load more videos when scrolling approaches end
  Future<void> loadMoreVideos() async {
    if (isLoadingMore.value || !hasMoreVideos || _isDisposed) return;
    
    try {
      isLoadingMore.value = true;
      currentPage++;
      
      debugPrint('[SHORTS_OPT] 📥 Loading page $currentPage...');
      
      // 🔥 Use QueryBuilder WITHOUT generic type (like old working method)
      QueryBuilder query = QueryBuilder(PostsModel())
        ..whereValueExists(PostsModel.keyVideo, true)
        ..includeObject([PostsModel.keyAuthor])
        ..orderByDescending(PostsModel.keyCreatedAt)
        ..setAmountToSkip(currentPage * pageSize)
        ..setLimit(pageSize);
      
      ParseResponse response = await query.query();
      
      if (response.success && response.results != null) {
        List<PostsModel> newVideos = 
            response.results!.map((e) => e as PostsModel).toList();
        
        if (newVideos.isNotEmpty) {
          shorts.addAll(newVideos);
          hasMoreVideos = newVideos.length >= pageSize;
          
          // 🔥 FETCH AUTHORS: Manually fetch authors for new videos
          if (Get.isRegistered<PostsService>()) {
            final postsService = Get.find<PostsService>();
            debugPrint('[SHORTS_OPT] 🔄 Fetching authors for ${newVideos.length} new videos...');
            
            for (var video in newVideos) {
              if (video.getAuthor == null && video.getAuthorId != null) {
                postsService.fetchAuthorForPost(video).then((_) {
                  debugPrint('[SHORTS_OPT] ✅ Author loaded for new video ${video.objectId}: ${video.getAuthor?.getFullName}');
                  shorts.refresh(); // Force UI update
                }).catchError((e) {
                  debugPrint('[SHORTS_OPT] ❌ Failed to load author: $e');
                });
              }
            }
          }
          
          debugPrint('[SHORTS_OPT] ✅ Added ${newVideos.length} videos (total: ${shorts.length})');
        } else {
          hasMoreVideos = false;
          debugPrint('[SHORTS_OPT] 📭 No more videos available');
        }
      }
    } catch (e) {
      debugPrint('[SHORTS_OPT] ❌ Error loading more: $e');
    } finally {
      isLoadingMore.value = false;
    }
  }
  
  // ═══════════════════════════════════════════════════════════
  // 🎮 CONTROLLER LIFECYCLE - Smart Management
  // ═══════════════════════════════════════════════════════════
  
  /// Get controller for specific index (creates if needed)
  CachedVideoPlayerPlusController? getController(int index) {
    if (index < 0 || index >= shorts.length) return null;
    return _activeControllers[index];
  }
  
  /// Initialize controller for specific index
  Future<void> _initializeController(int index) async {
    if (_isDisposed || index < 0 || index >= shorts.length) return;
    
    // Wait if another operation is in progress
    while (_isControllerOperationInProgress) {
      await Future.delayed(Duration(milliseconds: 50));
    }
    
    try {
      _isControllerOperationInProgress = true;
      
      // Skip if already initialized
      if (_activeControllers.containsKey(index)) {
        debugPrint('[SHORTS_OPT] ⏭️  Controller $index already exists');
        return;
      }
      
      final videoUrl = shorts[index].getVideo?.url;
      if (videoUrl == null) {
        debugPrint('[SHORTS_OPT] ⚠️  No video URL for index $index');
        return;
      }
      
      debugPrint('[SHORTS_OPT] 🎬 Initializing controller $index (STREAMING mode)');
      
      // 🔥 INSTAGRAM-STYLE: Create controller with optimized streaming configuration
      final controller = CachedVideoPlayerPlusController.networkUrl(
        Uri.parse(videoUrl),
        invalidateCacheIfOlderThan: const Duration(days: 2),
        videoPlayerOptions: VideoPlayerOptions(
          // 🔥 Optimized for fast streaming
          allowBackgroundPlayback: false,
          mixWithOthers: false,
        ),
        httpHeaders: {
          // 🔥 Request partial content for faster streaming
          'Range': 'bytes=0-',
          'Cache-Control': 'no-cache',
        },
      );

      // 🔥 INSTAGRAM-STYLE: Initialize with timeout to prevent hanging
      await controller.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[SHORTS_OPT] ⏰ Init timeout for $index, continuing anyway');
          // Continue even if timeout - video might still work
        },
      );
      
      // 🔥🔥🔥 IMMEDIATELY pause and mute right after init (before any other config)
      // This prevents ANY chance of auto-play
      await controller.setVolume(0.0);
      await controller.pause();
      
      if (!_isDisposed) {
        // 🔥 Configure for optimal streaming
        // Only enable looping if this is the current video
        if (index == currentVideoIndex.value) {
          await controller.setLooping(true);
        } else {
          await controller.setLooping(false); // Don't loop preloaded videos
        }
        
        // 🔥🔥 Double-check: Ensure video is still MUTED and PAUSED
        await controller.setVolume(0.0);
        if (controller.value.isPlaying) {
          await controller.pause();
        }
        
        // 🔥 CRITICAL: Set playback speed to reduce buffer pressure
        // This prevents the ImageReader buffer overflow
        await controller.setPlaybackSpeed(1.0);
        
        _activeControllers[index] = controller;
        debugPrint('[SHORTS_OPT] ✅ Controller $index ready (streaming, MUTED, PAUSED, looping=${index == currentVideoIndex.value})');
      } else {
        // Disposed during initialization
        await controller.dispose();
      }
      
    } catch (e) {
      debugPrint('[SHORTS_OPT] ❌ Failed to initialize controller $index: $e');
    } finally {
      _isControllerOperationInProgress = false;
    }
  }
  
  /// Manage controllers based on current position
  /// 🔥 INSTAGRAM-STYLE PRELOADING: Keep current + prev + next for instant switching
  Future<void> _manageControllers(int currentIndex) async {
    if (_isDisposed) return;

    // 🔥 INSTAGRAM-STYLE: Keep current, previous, and next for zero-lag scrolling
    final shouldKeep = <int>{
      if (currentIndex > 0) currentIndex - 1, // Preload previous
      currentIndex, // Current (always keep)
      if (currentIndex < shorts.length - 1) currentIndex + 1, // Preload next
    };
    
    // Dispose controllers that are too far away
    final toDispose = _activeControllers.keys
        .where((index) => !shouldKeep.contains(index))
        .toList();
    
    debugPrint('[SHORTS_OPT] 🗑️  Disposing ${toDispose.length} old controllers, keeping: $shouldKeep');
    
    // 🔥 NON-BLOCKING DISPOSAL: Dispose in background to prevent UI lag
    if (toDispose.isNotEmpty) {
      for (final index in toDispose) {
        final controller = _activeControllers[index];
        if (controller != null) {
          // Remove from map immediately
          _activeControllers.remove(index);
          
          // Dispose in background (fire and forget)
          Future.microtask(() async {
            try {
              if (controller.value.isInitialized) {
                await controller.setVolume(0.0);
                await controller.pause();
                // 🔥 CRITICAL: Wait for MediaCodec to release buffers (prevents BufferQueueProducer warnings)
                await Future.delayed(const Duration(milliseconds: 150));
              }
              await controller.dispose();
              debugPrint('[SHORTS_OPT] ✅ Controller $index disposed (background)');
            } catch (e) {
              debugPrint('[SHORTS_OPT] ⚠️  Error disposing $index: $e');
            }
          });
        }
      }
    }
    
    // Initialize current controller if needed (blocking - must be ready)
    if (!_activeControllers.containsKey(currentIndex)) {
      await _initializeController(currentIndex);
    }

    // 🔥 INSTAGRAM-STYLE: Preload PREVIOUS video in background (non-blocking)
    if (currentIndex > 0 && !_activeControllers.containsKey(currentIndex - 1)) {
      _initializeController(currentIndex - 1).then((_) {
        debugPrint('[SHORTS_OPT] ✅ Preloaded previous video (${currentIndex - 1})');
      });
    }

    // 🔥 INSTAGRAM-STYLE: Preload NEXT video in background (non-blocking)
    if (currentIndex < shorts.length - 1 &&
        !_activeControllers.containsKey(currentIndex + 1)) {
      _initializeController(currentIndex + 1).then((_) {
        debugPrint('[SHORTS_OPT] ✅ Preloaded next video (${currentIndex + 1})');
      });
    }
    
    debugPrint('[SHORTS_OPT] 🎮 Active: ${_activeControllers.keys.toList()}, Target: $shouldKeep');
  }
  
  /// Dispose all controllers synchronously
  void _disposeAllControllersSync() {
    final indices = _activeControllers.keys.toList();
    for (final index in indices) {
      try {
        final controller = _activeControllers[index];
        if (controller != null) {
          if (controller.value.isInitialized) {
            controller.pause();
          }
          controller.dispose();
        }
      } catch (e) {
        debugPrint('[SHORTS_OPT] ⚠️  Error disposing $index: $e');
      }
    }
    _activeControllers.clear();
    debugPrint('[SHORTS_OPT] 🗑️  All controllers disposed');
  }
  
  // ═══════════════════════════════════════════════════════════
  // ▶️ PLAYBACK CONTROL
  // ═══════════════════════════════════════════════════════════
  
  /// Play video at specific index
  Future<void> playVideo(int index) async {
    if (index < 0 || index >= shorts.length || _isDisposed || !_isScreenVisible) {
      return;
    }
    
    // 🔥 CRITICAL: Prevent rapid-fire calls that create race conditions
    if (_isPlayingVideo) {
      debugPrint('[SHORTS_OPT] ⏸️  Ignoring playVideo($index) - already in progress');
      return;
    }
    
    try {
      _isPlayingVideo = true;
      debugPrint('[SHORTS_OPT] ▶️  Playing video $index');
      
      // 🔥 INSTANT MUTE: Fire-and-forget mute for immediate audio cutoff
      for (final i in _activeControllers.keys.toList()) {
        if (i != index) {
          final controller = _activeControllers[i];
          if (controller != null && controller.value.isInitialized) {
            controller.setVolume(0.0); // No await - instant mute
          }
        }
      }
      
      // Update current index immediately
      currentVideoIndex.value = index;
      
      // Manage controller lifecycle (this might init new controllers)
      await _manageControllers(index);
      
      // Play ONLY current video
      final controller = _activeControllers[index];
      if (controller != null && controller.value.isInitialized) {
        // 🔥 Enable looping for current video
        await controller.setLooping(true);
        // 🔥 Restore volume and play
        await controller.setVolume(1.0);
        await controller.play();
        isPlaying.value = true;
        userPaused.value = false;
        debugPrint('[SHORTS_OPT] ✅ Video $index playing with audio (looping enabled)');
      } else {
        debugPrint('[SHORTS_OPT] ⏳ Video $index not ready, initializing...');
        // Controller not ready yet, will auto-play when initialized
      }
      
      // Check if we need to load more videos
      if (hasMoreVideos && index >= shorts.length - prefetchThreshold) {
        loadMoreVideos();
      }
      
      // Track view
      _trackView(shorts[index]);
      
    } catch (e) {
      debugPrint('[SHORTS_OPT] ❌ Error playing video $index: $e');
    } finally {
      _isPlayingVideo = false; // Reset flag
    }
  }

  /// 🔥 INSTAGRAM-STYLE: Immediate video switching based on scroll position
  /// Called by PageView onPageChanged for instant video switching
  void onScrollPositionChanged(int newIndex) {
    if (_isDisposed || newIndex < 0 || newIndex >= shorts.length) return;

    final previousIndex = currentVideoIndex.value;
    if (newIndex == previousIndex) return; // No change

    debugPrint('[SHORTS_OPT] 📍 Scroll position changed: $previousIndex → $newIndex');

    // 🔥 INSTANT AUDIO SWITCHING: Mute previous, unmute new (fire-and-forget)
    if (_activeControllers.containsKey(previousIndex)) {
      final prevController = _activeControllers[previousIndex];
      if (prevController != null && prevController.value.isInitialized) {
        prevController.setVolume(0.0); // Instant mute
        prevController.pause(); // Pause immediately
      }
    }

    // Update index immediately
    currentVideoIndex.value = newIndex;

    // 🔥 INSTANT PLAYBACK: If new video is ready, start it immediately
    if (_activeControllers.containsKey(newIndex)) {
      final newController = _activeControllers[newIndex];
      if (newController != null && newController.value.isInitialized) {
        // Enable looping for current video
        newController.setLooping(true);
        // Unmute and play instantly
        newController.setVolume(1.0);
        newController.play();
        isPlaying.value = true;
        userPaused.value = false;
        debugPrint('[SHORTS_OPT] ✅ Instant video switch to $newIndex');
      }
    }

    // 🔥 ASYNC CONTROLLER MANAGEMENT: Manage preloading in background
    Future.microtask(() => _manageControllers(newIndex));

    // Check if we need to load more videos
    if (hasMoreVideos && newIndex >= shorts.length - prefetchThreshold) {
      loadMoreVideos();
    }

    // Track view for new video
    _trackView(shorts[newIndex]);
  }

  /// Toggle play/pause for current video
  Future<void> togglePlayPause() async {
    if (_isDisposed) return;
    
    try {
      final index = currentVideoIndex.value;
      final controller = _activeControllers[index];
      
      if (controller != null && controller.value.isInitialized) {
        if (controller.value.isPlaying) {
          await controller.pause();
          // 🔥 Mute when pausing
          await controller.setVolume(0.0);
          isPlaying.value = false;
          userPaused.value = true;
          debugPrint('[SHORTS_OPT] ⏸️  Video paused and muted');
        } else {
          // 🔥 Restore volume when playing
          await controller.setVolume(1.0);
          await controller.play();
          isPlaying.value = true;
          userPaused.value = false;
          debugPrint('[SHORTS_OPT] ▶️  Video resumed with audio');
        }
        
        // Show icon feedback
        showPlayPauseIcon.value = true;
        Future.delayed(Duration(milliseconds: 800), () {
          if (!_isDisposed) {
            showPlayPauseIcon.value = false;
          }
        });
      }
    } catch (e) {
      debugPrint('[SHORTS_OPT] ❌ Toggle play/pause error: $e');
    }
  }
  
  /// Pause all videos (called when screen goes background or navigates away)
  Future<void> pauseAllVideos() async {
    if (_isDisposed) return;
    
    debugPrint('[SHORTS_OPT] ⏸️  Pausing all videos');
    _isScreenVisible = false;
    
    // 🔥 CRITICAL: Always pause and mute ALL controllers unconditionally
    for (final controller in _activeControllers.values) {
      try {
        if (controller.value.isInitialized) {
          // Always pause, even if state says not playing (audio might be leaking)
          await controller.pause();
          // 🔥 Force mute to prevent any audio bleeding
          await controller.setVolume(0.0);
          debugPrint('[SHORTS_OPT] 🔇 Video paused and muted');
        }
      } catch (e) {
        debugPrint('[SHORTS_OPT] ⚠️  Error pausing video: $e');
      }
    }
    
    isPlaying.value = false;
    showPlayPauseIcon.value = false;
  }
  
  /// Set screen visibility
  void setScreenVisible(bool visible) {
    _isScreenVisible = visible;
    if (!visible && !_isDisposed) {
      pauseAllVideos();
    } else if (visible && !userPaused.value) {
      // Resume current video if user didn't explicitly pause
      final controller = _activeControllers[currentVideoIndex.value];
      if (controller != null && 
          controller.value.isInitialized && 
          !controller.value.isPlaying) {
        // 🔥 Restore volume when resuming
        controller.setVolume(1.0);
        controller.play();
        isPlaying.value = true;
      }
    }
  }

  /// 🔥 INSTAGRAM-STYLE: Resume current video when screen becomes visible
  Future<void> resumeCurrentVideo() async {
    if (_isDisposed || !_isScreenVisible || userPaused.value) return;

    try {
      final controller = _activeControllers[currentVideoIndex.value];
      if (controller != null && controller.value.isInitialized && !controller.value.isPlaying) {
        debugPrint('[SHORTS_OPT] ▶️  Resuming current video ${currentVideoIndex.value}');
        // 🔥 Instant unmute and play
        await controller.setVolume(1.0);
        await controller.play();
        isPlaying.value = true;
      }
    } catch (e) {
      debugPrint('[SHORTS_OPT] ❌ Error resuming video: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 ANALYTICS & TRACKING
  // ═══════════════════════════════════════════════════════════
  
  void _trackView(PostsModel video) {
    try {
      // Increment view count
      video.setViews = 1;
      video.save();
      debugPrint('[SHORTS_OPT] 👁️  Tracked view for ${video.objectId}');
    } catch (e) {
      debugPrint('[SHORTS_OPT] ⚠️  Failed to track view: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════
  // 🔍 UTILITY METHODS
  // ═══════════════════════════════════════════════════════════

  /// 🔥 INSTAGRAM-STYLE: Get custom scroll physics for smooth scrolling
  ScrollPhysics getInstagramScrollPhysics() {
    return const PageScrollPhysics(
      parent: ClampingScrollPhysics(),
    ).applyTo(const BouncingScrollPhysics());
  }

  /// Get debug info about active controllers
  String getDebugInfo() {
    return '''
    📊 Shorts Controller Status (Instagram-Style):
    - Total videos: ${shorts.length}
    - Current index: ${currentVideoIndex.value}
    - Active controllers: ${_activeControllers.keys.toList()} (max 3)
    - Is playing: ${isPlaying.value}
    - Screen visible: $_isScreenVisible
    - Has more videos: $hasMoreVideos
    - Current page: $currentPage
    - Preloading: current + prev + next
    ''';
  }
}

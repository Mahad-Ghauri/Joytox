// 🚀 OPTIMIZED SHORTS CONTROLLER - Production-Grade Video Feed
// Fixes: Memory leaks, buffer overflows, lazy loading, smooth scrolling
// Architecture: Smart controller lifecycle, true pagination, resource pooling

import 'dart:async';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
  final Map<String, bool> _videoStartedById = {};
  final ValueNotifier<int> playbackVersionNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> controllerVersionNotifier = ValueNotifier<int>(0);

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

  /// Track failed video indices and their retry attempts
  final Map<int, int> _failedVideoAttempts = {}; // index -> attempt count
  static const int MAX_RETRY_ATTEMPTS = 3;

  /// Public getter for failed video indices
  bool isVideoFailed(int index) =>
      _failedVideoAttempts[index] != null &&
      _failedVideoAttempts[index]! >= MAX_RETRY_ATTEMPTS;

  /// Track concurrent initialization operations - using Set for better tracking
  final Set<int> _initializingIndices = {};
  static const int MAX_CONCURRENT_INITS = 2;

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
    unawaited(_disposeAllControllers());
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
        ..includeObject(
            [PostsModel.keyAuthor]) // 🔥 Include author relationship
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
          debugPrint(
              '  - Has Author key? ${firstResult.containsKey(PostsModel.keyAuthor)}');
          final authorValue = firstResult.get(PostsModel.keyAuthor);
          debugPrint('  - Author value type: ${authorValue?.runtimeType}');
          debugPrint('  - Author value: $authorValue');
          debugPrint(
              '  - AuthorId value: ${firstResult.get(PostsModel.keyAuthorId)}');
        }
      }

      if (response.success && response.results != null) {
        List<PostsModel> loadedVideos =
            response.results!.map((e) => e as PostsModel).toList();

        // 🔥 VALIDATION: Check video file sizes and log warnings
        _validateVideoSizes(loadedVideos);

        // 🔥 DEBUG: Log author data WITH DETAILS
        debugPrint(
            '[SHORTS_OPT] 📊 Loaded ${loadedVideos.length} videos from Parse');
        for (var video in loadedVideos) {
          final author = video.getAuthor;
          debugPrint('[SHORTS_OPT] 📹 Video ${video.objectId}:');
          debugPrint(
              '  - Author object: ${author != null ? "EXISTS" : "NULL"}');
          debugPrint('  - Author name: ${author?.getFullName ?? "NULL"}');
          debugPrint('  - Author ID from video: ${video.getAuthorId}');
        }

        // 🔥 CRITICAL: Assign to shorts and force UI refresh
        shorts.value = loadedVideos;
        hasMoreVideos = loadedVideos.length >= pageSize;

        // 🔥 FETCH AUTHORS: Since includeObject doesn't work reliably, fetch authors manually
        if (Get.isRegistered<PostsService>()) {
          final postsService = Get.find<PostsService>();
          debugPrint(
              '[SHORTS_OPT] 🔄 Fetching authors for ${loadedVideos.length} videos...');

          for (var video in loadedVideos) {
            if (video.getAuthor == null && video.getAuthorId != null) {
              postsService.fetchAuthorForPost(video).then((_) {
                debugPrint(
                    '[SHORTS_OPT] ✅ Author loaded for video ${video.objectId}: ${video.getAuthor?.getFullName}');
                shorts.refresh(); // Force UI update after each author loads
              }).catchError((e) {
                debugPrint(
                    '[SHORTS_OPT] ❌ Failed to load author for ${video.objectId}: $e');
              });
            }
          }
        }

        debugPrint('[SHORTS_OPT] ✅ Videos loaded and author fetch initiated');

        // 🔥 SMART PRELOADING: Initialize first video immediately
        if (loadedVideos.isNotEmpty && !_isDisposed) {
          // Initialize and play first video immediately
          await _initializeController(0);

          // Auto-play first video
          final firstController = _activeControllers[0];
          if (firstController != null && firstController.value.isInitialized) {
            await firstController.setLooping(true);
            await firstController.setVolume(1.0);
            await firstController.play();
            isPlaying.value = true;
            userPaused.value = false;
            debugPrint('[SHORTS_OPT] ✅ First video auto-playing');
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
          // 🔥 VALIDATION: Check video sizes for new videos
          _validateVideoSizes(newVideos);

          shorts.addAll(newVideos);
          hasMoreVideos = newVideos.length >= pageSize;

          // 🔥 FETCH AUTHORS: Manually fetch authors for new videos
          if (Get.isRegistered<PostsService>()) {
            final postsService = Get.find<PostsService>();
            debugPrint(
                '[SHORTS_OPT] 🔄 Fetching authors for ${newVideos.length} new videos...');

            for (var video in newVideos) {
              if (video.getAuthor == null && video.getAuthorId != null) {
                postsService.fetchAuthorForPost(video).then((_) {
                  debugPrint(
                      '[SHORTS_OPT] ✅ Author loaded for new video ${video.objectId}: ${video.getAuthor?.getFullName}');
                  shorts.refresh(); // Force UI update
                }).catchError((e) {
                  debugPrint('[SHORTS_OPT] ❌ Failed to load author: $e');
                });
              }
            }
          }

          debugPrint(
              '[SHORTS_OPT] ✅ Added ${newVideos.length} videos (total: ${shorts.length})');
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

  /// Validate video file sizes and log warnings for optimization
  void _validateVideoSizes(List<PostsModel> videos) {
    const int maxRecommendedSize = 50 * 1024 * 1024; // 50 MB
    const int warningSize = 30 * 1024 * 1024; // 30 MB

    for (var video in videos) {
      final videoFile = video.getVideo;
      if (videoFile != null) {
        // Note: Parse doesn't always expose file size, but we can check URL length as a proxy
        final url = videoFile.url ?? '';

        // Check if URL contains size metadata (some CDNs include it)
        if (url.contains('size=')) {
          final sizeMatch = RegExp(r'size=(\d+)').firstMatch(url);
          if (sizeMatch != null) {
            final size = int.tryParse(sizeMatch.group(1) ?? '0') ?? 0;
            final sizeMB = (size / (1024 * 1024)).toStringAsFixed(1);

            if (size > maxRecommendedSize) {
              debugPrint(
                  '[SHORTS_OPT] ⚠️  Video ${video.objectId} is ${sizeMB}MB - RECOMMEND COMPRESSION');
              debugPrint(
                  '   💡 Ideal: < 30MB, Max: < 50MB for smooth playback');
            } else if (size > warningSize) {
              debugPrint(
                  '[SHORTS_OPT] ⚡ Video ${video.objectId} is ${sizeMB}MB - Consider compression');
            } else {
              debugPrint(
                  '[SHORTS_OPT] ✅ Video ${video.objectId} is ${sizeMB}MB - Optimal size');
            }
          }
        }
      }
    }
  }

  /// Get controller for specific index (creates if needed)
  CachedVideoPlayerPlusController? getController(int index) {
    if (index < 0 || index >= shorts.length) return null;
    return _activeControllers[index];
  }

  /// Get timeout duration based on attempt number (optimized for streaming)
  Duration _getTimeoutForAttempt(int attempt) {
    switch (attempt) {
      case 0:
        return Duration(seconds: 30); // First attempt: generous for buffering
      case 1:
        return Duration(seconds: 25); // Second: still reasonable
      default:
        return Duration(seconds: 15); // Subsequent: fast fail
    }
  }

  /// Check if video URL is valid
  bool _isValidVideoUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    try {
      Uri.parse(url);
      return url.startsWith('http://') || url.startsWith('https://');
    } catch (e) {
      return false;
    }
  }

  /// Initialize controller for specific index with retry logic
  Future<void> _initializeController(int index) async {
    if (_isDisposed || index < 0 || index >= shorts.length) return;

    // Skip if already initialized
    if (_activeControllers.containsKey(index)) {
      // If initialized but marked as initializing, clear it
      if (_initializingIndices.contains(index)) {
        _initializingIndices.remove(index);
      }
      return;
    }

    // Skip if already initializing (deduplication)
    if (_initializingIndices.contains(index)) {
      debugPrint(
          '[SHORTS_OPT] ⏳ Controller $index already initializing, skipping duplicate request');
      return;
    }

    // 🔥 THROTTLE: Only allow initializing the CURRENT video (strict mode)
    if (_initializingIndices.isNotEmpty && index != currentVideoIndex.value) {
      debugPrint(
          '[SHORTS_OPT] ⏸️  Strict mode: Skipping background init for $index');
      return;
    }

    // Skip if permanently failed after max retries
    if (isVideoFailed(index)) {
      debugPrint(
          '[SHORTS_OPT] ⚠️  Skipping video $index - max retries exceeded');
      return;
    }

    try {
      _initializingIndices.add(index);
      final attempts = (_failedVideoAttempts[index] ?? 0);
      final videoUrl = shorts[index].getVideo?.url;

      // Validate URL
      if (!_isValidVideoUrl(videoUrl)) {
        debugPrint(
            '[SHORTS_OPT] ❌ Invalid URL for video $index (attempt ${attempts + 1}): $videoUrl');
        _failedVideoAttempts[index] =
            MAX_RETRY_ATTEMPTS; // Mark as permanently failed

        // Auto-skip if this is current video
        if (index == currentVideoIndex.value && !_isDisposed) {
          _skipFailedVideo(index);
        }
        return;
      }

      final timeout = _getTimeoutForAttempt(attempts);
      debugPrint(
          '[SHORTS_OPT] 🎬 Initializing controller $index (attempt ${attempts + 1}/$MAX_RETRY_ATTEMPTS, timeout=${timeout.inSeconds}s)');
      debugPrint('[SHORTS_OPT] 🌐 Video URL: $videoUrl');

      // 🔥 Create controller with STREAMING-OPTIMIZED configuration
      final controller = CachedVideoPlayerPlusController.networkUrl(
        Uri.parse(videoUrl!),
        invalidateCacheIfOlderThan: const Duration(days: 2),
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: false,
          mixWithOthers: false,
        ),
        // 🔥 Enable partial content streaming explicitly
        httpHeaders: {
          'Connection': 'keep-alive',
        },
      );

      try {
        debugPrint('[SHORTS_OPT] 🌐 Fetching video from: $videoUrl');

        await controller.initialize().timeout(
          timeout,
          onTimeout: () {
            throw TimeoutException(
                'Video initialization timed out after ${timeout.inSeconds}s');
          },
        );

        // Success! Reset failure counter
        _failedVideoAttempts.remove(index);

        final duration = controller.value.duration;
        final size = controller.value.size;
        debugPrint('[SHORTS_OPT] ✅ Controller $index initialized successfully');
        debugPrint(
            '[SHORTS_OPT] 📊 Video info: ${duration.inSeconds}s, ${size.width}x${size.height}');

        if (!_isDisposed) {
          await controller.setVolume(0.0);
          await controller.pause();

          if (index == currentVideoIndex.value) {
            await controller.setLooping(true);
          }

          _activeControllers[index] = controller;
          _notifyControllerUpdate();

          // Auto-play if this is current video
          if (index == currentVideoIndex.value && !_isPlayingVideo) {
            Future.delayed(Duration(milliseconds: 50), () {
              if (!_isDisposed &&
                  currentVideoIndex.value == index &&
                  controller.value.isInitialized &&
                  !controller.value.isPlaying) {
                controller.setLooping(true);
                controller.setVolume(1.0);
                controller.play();
                isPlaying.value = true;
                userPaused.value = false;
                _markVideoStartedById(shorts[index].objectId);
                debugPrint(
                    '[SHORTS_OPT] ✅ Video $index auto-played after late init');
              }
            });
          }

          debugPrint('[SHORTS_OPT] ✅ Controller $index ready (MUTED, PAUSED)');
        } else {
          await controller.dispose();
        }
      } catch (e) {
        await controller.dispose().catchError((_) {});

        // Increment attempt counter
        _failedVideoAttempts[index] = attempts + 1;

        final isTimeout = e.toString().contains('timeout');
        final errorType = isTimeout ? 'TIMEOUT' : 'ERROR';

        debugPrint(
            '[SHORTS_OPT] ❌ Init failed for $index (attempt ${attempts + 1}, $errorType): $e');

        // Retry logic: try again if attempts remaining
        if (attempts + 1 < MAX_RETRY_ATTEMPTS) {
          // Shorter backoff for faster recovery
          final backoffDuration =
              Duration(milliseconds: 500 + (attempts * 500));
          debugPrint(
              '[SHORTS_OPT] ⏳ Retrying video $index after ${backoffDuration.inMilliseconds}ms...');

          Future.delayed(backoffDuration, () {
            if (!_isDisposed) {
              // Retry for any video, not just non-current
              _initializeController(index);
            }
          });
        } else {
          // Max retries exceeded
          debugPrint('[SHORTS_OPT] 🚫 Video $index failed max retries');

          if (index == currentVideoIndex.value && !_isDisposed) {
            debugPrint('[SHORTS_OPT] ⏭️  Auto-skipping to next video');
            _skipFailedVideo(index);
          }
        }
      }
    } catch (e) {
      debugPrint('[SHORTS_OPT] ❌ Unexpected error initializing $index: $e');
      _failedVideoAttempts[index] = MAX_RETRY_ATTEMPTS;
    } finally {
      _initializingIndices.remove(index);
    }
  }

  /// Skip failed video and play next valid one
  void _skipFailedVideo(int index) {
    if (_isDisposed || index != currentVideoIndex.value) return;

    final nextValid = _findNextValidVideo(index);
    if (nextValid != null) {
      debugPrint(
          '[SHORTS_OPT] ⏭️  Skipping failed video $index, jumping to $nextValid');
      Future.delayed(Duration(milliseconds: 300), () {
        if (!_isDisposed && currentVideoIndex.value == index) {
          playVideo(nextValid);
        }
      });
    } else if (hasMoreVideos) {
      // Load more videos if available
      debugPrint('[SHORTS_OPT] 📥 No more valid videos, loading more...');
      loadMoreVideos();
    } else {
      debugPrint('[SHORTS_OPT] 🚫 No more videos available');
    }
  }

  Future<void> _disposeController(int index) async {
    // Robust disposal: Remove from map FIRST, then dispose instance
    final controller = _activeControllers.remove(index);
    if (controller != null) {
      _notifyControllerUpdate();
    }

    // Also ensure it's not in initializing set
    if (_initializingIndices.contains(index)) {
      _initializingIndices.remove(index);
    }

    if (controller == null) return;

    try {
      if (controller.value.isInitialized) {
        await controller.setVolume(0.0);
        await controller.pause();
        await controller.setLooping(false);
      }
      await controller.dispose();
      debugPrint('[SHORTS_OPT] ✅ Controller $index disposed');
    } catch (e) {
      debugPrint('[SHORTS_OPT] ⚠️  Error disposing $index: $e');
    }
  }

  /// Dispose all controllers synchronously
  Future<void> _disposeAllControllers() async {
    final indices = _activeControllers.keys.toList();
    for (final index in indices) {
      await _disposeController(index);
    }
    _activeControllers.clear();
    debugPrint('[SHORTS_OPT] 🗑️  All controllers disposed');
  }

  // ═══════════════════════════════════════════════════════════
  // ▶️ PLAYBACK CONTROL
  // ═══════════════════════════════════════════════════════════

  /// Find next valid (non-permanently-failed) video index
  int? _findNextValidVideo(int startIndex) {
    for (int i = startIndex + 1; i < shorts.length; i++) {
      if (!isVideoFailed(i)) {
        return i;
      }
    }
    return null;
  }

  /// Play video at specific index
  Future<void> playVideo(int index) async {
    if (index < 0 ||
        index >= shorts.length ||
        _isDisposed ||
        !_isScreenVisible) {
      return;
    }

    // Check if video is permanently failed
    if (isVideoFailed(index)) {
      debugPrint('[SHORTS_OPT] ⏭️  Video $index permanently failed, skipping');
      _skipFailedVideo(index);
      return;
    }

    // Prevent rapid-fire calls
    if (_isPlayingVideo) {
      debugPrint(
          '[SHORTS_OPT] ⏸️  Ignoring playVideo($index) - already in progress');
      return;
    }

    try {
      _isPlayingVideo = true;
      debugPrint('[SHORTS_OPT] ▶️  Playing video $index');

      if (index != currentVideoIndex.value) {
        await onScrollPositionChanged(index);
        return;
      }

      final video = shorts[index];
      final videoId = video.objectId;

      var controller = _activeControllers[index];
      debugPrint(
          '[SHORTS_OPT] 🔍 Controller $index state: exists=${controller != null}, initialized=${controller?.value.isInitialized}, playing=${controller?.value.isPlaying}');

      if (controller == null || !controller.value.isInitialized) {
        await _initializeController(index);
        controller = _activeControllers[index];
      }

      if (controller != null && controller.value.isInitialized) {
        await controller.setLooping(true);
        await controller.setVolume(1.0);
        await controller.play();
        isPlaying.value = true;
        userPaused.value = false;
        _markVideoStartedById(videoId);
        debugPrint(
            '[SHORTS_OPT] ✅ Video $index playing with audio (looping enabled)');
      } else {
        debugPrint(
            '[SHORTS_OPT] ⚠️  Video $index controller still not ready after reinit');
      }

      // Load more if needed
      if (hasMoreVideos && index >= shorts.length - prefetchThreshold) {
        loadMoreVideos();
      }

      // Track view
      _trackView(video);
    } catch (e) {
      debugPrint('[SHORTS_OPT] ❌ Error playing video $index: $e');
    } finally {
      _isPlayingVideo = false;
    }
  }

  /// 🔥 STRICT SINGLE PLAYER MODE: Dispose everything, then create new
  Future<void> onScrollPositionChanged(int newIndex) async {
    if (_isDisposed || newIndex < 0 || newIndex >= shorts.length) return;

    final previousIndex = currentVideoIndex.value;
    if (newIndex == previousIndex) return; // No change

    debugPrint(
        '[SHORTS_OPT] 📍 Scroll position changed: $previousIndex → $newIndex');
    _logDiagnostics('scroll:$previousIndex->$newIndex');

    // 1. Update index immediately
    currentVideoIndex.value = newIndex;

    // 2. 🔥 AGGRESSIVE DISPOSAL: Identify ALL other controllers
    final toDispose =
        _activeControllers.keys.where((index) => index != newIndex).toList();

    for (final index in toDispose) {
      debugPrint('[SHORTS_OPT] 🗑️  Strict Disposing $index');
      await _disposeController(index);
      _logDiagnostics('disposed:$index');
    }

    // 4. 🔥 BUFFER SAFETY DELAY
    // Give the OS time to reclaim buffers from the disposed players.
    // This 300ms gap is masked by the Thumbnail in the View layer.
    await Future.delayed(Duration(milliseconds: 300));

    if (newIndex != currentVideoIndex.value) return; // Guard

    // 5. Initialize Current Video
    if (!_activeControllers.containsKey(newIndex)) {
      debugPrint('[SHORTS_OPT] ⏳ Initializing $newIndex (Strict Mode)...');
      await _initializeController(newIndex);

      if (newIndex != currentVideoIndex.value) return; // Guard
    }

    // 6. Play
    if (_activeControllers.containsKey(newIndex)) {
      final newController = _activeControllers[newIndex];
      if (newController != null && newController.value.isInitialized) {
        newController.setLooping(true);
        newController.setVolume(1.0);
        newController.play();
        isPlaying.value = true;
        userPaused.value = false;
        _markVideoStartedById(shorts[newIndex].objectId);
        debugPrint('[SHORTS_OPT] ✅ Video $newIndex playing');
        _logDiagnostics('playing:$newIndex');
      }
    }

    // Check load more
    if (hasMoreVideos && newIndex >= shorts.length - prefetchThreshold) {
      loadMoreVideos();
    }

    _trackView(shorts[newIndex]);
  }

  void _logDiagnostics(String reason) {
    final authorCacheSize = Get.isRegistered<PostsService>()
        ? Get.find<PostsService>().authorCacheSize
        : 0;
    final currentId = (currentVideoIndex.value >= 0 &&
            currentVideoIndex.value < shorts.length)
        ? shorts[currentVideoIndex.value].objectId
        : null;
    final startedFlag = hasVideoStartedById(currentId);
    debugPrint(
        '[SHORTS_DIAG] $reason | controllers=${_activeControllers.length} | authorCache=$authorCacheSize | videos=${shorts.length} | currentStarted=$startedFlag');
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
      if (controller != null &&
          controller.value.isInitialized &&
          !controller.value.isPlaying) {
        debugPrint(
            '[SHORTS_OPT] ▶️  Resuming current video ${currentVideoIndex.value}');
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

  bool _isValidId(String? id) => id != null && id.isNotEmpty;

  bool hasVideoStartedById(String? id) =>
      _isValidId(id) && (_videoStartedById[id] ?? false);

  void _markVideoStartedById(String? id) {
    if (!_isValidId(id)) return;
    if (_videoStartedById[id] == true) return;
    _videoStartedById[id!] = true;
    playbackVersionNotifier.value++;
  }

  ValueListenable<int> get playbackVersion => playbackVersionNotifier;
  ValueListenable<int> get controllerVersion => controllerVersionNotifier;

  void _notifyControllerUpdate() {
    controllerVersionNotifier.value++;
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

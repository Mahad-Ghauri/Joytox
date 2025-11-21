// 🚀 OPTIMIZED SHORTS VIEW - Production-Grade UI
// Fixes: Smooth scrolling, proper lifecycle, lazy loading
// Architecture: Reactive with GetX, proper disposal, visibility tracking

import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trace/helpers/quick_actions.dart';
import 'package:trace/home/a_shorts/shorts_optimized_controller.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/models/PostsModel.dart';
import '../../controllers/video_interactions_controller.dart';
import '../video/global_video_playeres.dart';
import '../../main.dart';

class ShortsOptimizedView extends StatefulWidget {
  final UserModel? currentUser;

  const ShortsOptimizedView({this.currentUser, super.key});

  @override
  State<ShortsOptimizedView> createState() => _ShortsOptimizedViewState();
}

class _ShortsOptimizedViewState extends State<ShortsOptimizedView>
    with RouteAware, WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late ShortsOptimizedController _controller;
  PageController? _pageController;
  bool _isDisposed = false;
  bool _initialPlaybackScheduled = false;

  // Animation controller for smooth transitions
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize fade animation for smooth transitions
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Get or create controller
    _controller = Get.isRegistered<ShortsOptimizedController>()
        ? Get.find<ShortsOptimizedController>()
        : Get.put(ShortsOptimizedController());

    // Register observers
    WidgetsBinding.instance.addObserver(this);

    // Mark screen as visible
    _controller.setScreenVisible(true);

    debugPrint('[SHORTS_VIEW] ✅ Initialized');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Subscribe to route observer
    final route = ModalRoute.of(context);
    if (route != null && route is PageRoute) {
      routeObserver.subscribe(this, route);
    }

    // Check visibility
    if (route != null && route.isCurrent) {
      _controller.setScreenVisible(true);
    } else {
      _controller.pauseAllVideos();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      debugPrint('[SHORTS_VIEW] 🔄 App lifecycle: $state - Pausing videos');
      _controller.pauseAllVideos();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('[SHORTS_VIEW] 🔄 App lifecycle: resumed - Resuming');
      _controller.setScreenVisible(true);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 ROUTE OBSERVER CALLBACKS
  // ═══════════════════════════════════════════════════════════

  @override
  void didPush() {
    debugPrint('[SHORTS_VIEW] 🔄 Route pushed');
    _controller.setScreenVisible(true);
    _fadeController.forward();
  }

  @override
  void didPopNext() {
    debugPrint('[SHORTS_VIEW] 🔄 Route popped next');
    _controller.setScreenVisible(true);
    _fadeController.forward();
  }

  @override
  void didPushNext() {
    debugPrint('[SHORTS_VIEW] 🔄 Route pushed next');
    _controller.pauseAllVideos();
  }

  @override
  void didPop() {
    debugPrint('[SHORTS_VIEW] 🔄 Route popped');
    _controller.pauseAllVideos();
  }

  @override
  void dispose() {
    _isDisposed = true;
    debugPrint('[SHORTS_VIEW] 🗑️  Disposing view');

    // Unregister observers
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);

    // Pause videos
    _controller.pauseAllVideos();

    // Dispose controllers
    _pageController?.dispose();
    _fadeController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        debugPrint('[SHORTS_VIEW] ⬅️  Back button pressed');
        _controller.pauseAllVideos();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Obx(() => _buildContent()),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ CONTENT BUILDER
  // ═══════════════════════════════════════════════════════════

  Widget _buildContent() {
    // Loading state
    if (_controller.isLoading.value && _controller.shorts.isEmpty) {
      return _buildLoadingState();
    }

    // Empty state
    if (!_controller.isLoading.value && _controller.shorts.isEmpty) {
      return QuickActions.noContentFound(context);
    }

    // Video feed
    return _buildVideoFeed();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          SizedBox(height: 16),
          Text(
            'Loading videos...',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoFeed() {
    // Initialize PageController if needed
    final initialPage = _controller.currentVideoIndex.value
        .clamp(0, _controller.shorts.length - 1);

    _pageController ??= PageController(initialPage: initialPage);

    if (!_initialPlaybackScheduled) {
      _initialPlaybackScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && mounted && _controller.shorts.isNotEmpty) {
          final currentPage = _pageController!.page?.round() ?? initialPage;
          _controller.onScrollPositionChanged(currentPage);
          _fadeController.forward();
        }
      });
    }

    final overlayAnimation = Listenable.merge([
      _controller.playbackVersionNotifier,
      _controller.controllerVersionNotifier,
    ]);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          // Video PageView - Instagram-style scrolling
          AnimatedBuilder(
            animation: overlayAnimation,
            builder: (_, __) => PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _controller.shorts.length,
              // 🔥 INSTAGRAM PHYSICS: Smooth snapping with momentum
              physics: PageScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              pageSnapping: true, // 🔥 Snap to pages
              onPageChanged: _onPageChanged,
              // 🔥 Keep adjacent pages alive for preloading
              allowImplicitScrolling: false,
              itemBuilder: (context, index) => _buildVideoItem(index),
            ),
          ),

          // Loading more indicator
          if (_controller.isLoadingMore.value)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Loading more...',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📹 VIDEO ITEM BUILDER
  // ═══════════════════════════════════════════════════════════

  Widget _buildVideoItem(int index) {
    if (index < 0 || index >= _controller.shorts.length) {
      return SizedBox.shrink();
    }

    final video = _controller.shorts[index];
    final videoId = video.objectId;

    // 🔥 Register video interactions controller ONCE
    final String tag = 'video_interactions_${video.objectId}';
    if (!Get.isRegistered<VideoInteractionsController>(tag: tag)) {
      Get.put(
        VideoInteractionsController(
          video: video,
          currentUser: widget.currentUser,
        ),
        tag: tag,
        permanent: true, // 🔥 Keep cached to prevent reloading
      );
    }

    // 🔥 Wrap in RepaintBoundary for better performance
    Widget buildVideoStack(
        String? videoId, CachedVideoPlayerPlusController? ctrl) {
      final value = ctrl?.value;
      final overlayVisible = _shouldShowThumbnailOverlay(videoId, value);
      final isInitialized = value?.isInitialized ?? false;
      final hasError = value?.hasError ?? false;

      return Stack(
        fit: StackFit.expand,
        children: [
          if (isInitialized)
            GlobalVideoPlayer(
              video: video,
              currentUser: widget.currentUser,
              externalController: ctrl,
            ),
          if (hasError)
            _buildVideoError(value?.errorDescription)
          else if (!isInitialized || overlayVisible)
            _buildLoadingVideo(video),
          if (_controller.showPlayPauseIcon.value)
            Center(
              child: AnimatedOpacity(
                opacity: _controller.showPlayPauseIcon.value ? 1.0 : 0.0,
                duration: Duration(milliseconds: 200),
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _controller.isPlaying.value
                        ? Icons.play_arrow
                        : Icons.pause,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return RepaintBoundary(
      key: ValueKey(
          'video_item_${video.objectId}_$index'), // 🔥 Unique key to prevent state recycling
      child: ValueListenableBuilder<int>(
        valueListenable: _controller.controllerVersion,
        builder: (_, __, ___) {
          final controller = _controller.getController(index);
          return GestureDetector(
            onTap: () async {
              await _controller.togglePlayPause();
            },
            child: controller != null
                ? ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (_, __, ___) => ValueListenableBuilder<int>(
                      valueListenable: _controller.playbackVersion,
                      builder: (_, __, ___) =>
                          buildVideoStack(videoId, controller),
                    ),
                  )
                : ValueListenableBuilder<int>(
                    valueListenable: _controller.playbackVersion,
                    builder: (_, __, ___) => buildVideoStack(videoId, null),
                  ),
          );
        },
      ),
    );
  }

  bool _shouldShowThumbnailOverlay(
      String? videoId, CachedVideoPlayerPlusValue? value) {
    if (_controller.hasVideoStartedById(videoId)) return false;
    if (value == null) return true;
    if (!value.isInitialized) return true;
    if (value.hasError) return false;
    if (_controller.userPaused.value) return false;
    final hasStarted = value.position > Duration.zero;
    if (value.isPlaying && hasStarted && !value.isBuffering) return false;
    return true;
  }

  Widget _buildLoadingVideo(PostsModel video) {
    final index = _controller.shorts.indexOf(video);
    final hasFailed = _controller.isVideoFailed(index);

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 🔥 Always show thumbnail first (instant feedback)
          if (video.getVideoThumbnail?.url != null)
            Image.network(
              video.getVideoThumbnail!.url!,
              fit: BoxFit.cover,
              // 🔥 Cache for instant loading
              cacheWidth: 1080,
              cacheHeight: 1920,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholder();
              },
              // 🔥 Show immediately, no fade
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                return child;
              },
            )
          else
            _buildPlaceholder(),

          // 🔥 Show error message if video failed, otherwise loading indicator
          Center(
            child: hasFailed
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.white70,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Video failed to load',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Swipe to next video',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                : Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white70),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoError(String? message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            SizedBox(height: 12),
            Text(
              message ?? 'Unable to play this video',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Swipe to try another video',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Icon(
          Icons.videocam,
          size: 80,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📄 PAGE CHANGE HANDLER
  // ═══════════════════════════════════════════════════════════

  void _onPageChanged(int index) {
    if (_isDisposed || index < 0 || index >= _controller.shorts.length) return;

    debugPrint('[SHORTS_VIEW] 📄 Page changed to $index');

    // 🔥 INSTANT VIDEO SWITCHING: Use onScrollPositionChanged for immediate response
    _controller.onScrollPositionChanged(index);

    // Update video interactions controller for the new video
    final video = _controller.shorts[index];
    final String newTag = 'video_interactions_${video.objectId}';

    if (!Get.isRegistered<VideoInteractionsController>(tag: newTag)) {
      Get.put(
        VideoInteractionsController(
          video: video,
          currentUser: widget.currentUser,
        ),
        tag: newTag,
        permanent: true, // Keep cached
      );
    }

    // Reset view progress for the new video
    try {
      final newController = Get.find<VideoInteractionsController>(tag: newTag);
      newController.resetViewProgress();

      // Update video progress listener
      final videoController = _controller.getController(index);
      if (videoController != null && videoController.value.isInitialized) {
        videoController.addListener(() {
          if (videoController.value.isPlaying) {
            if (Get.isRegistered<VideoInteractionsController>(tag: newTag)) {
              try {
                final currentController =
                    Get.find<VideoInteractionsController>(tag: newTag);
                currentController.updateVideoProgress(
                  videoController.value.position,
                  videoController.value.duration,
                );
              } catch (e) {
                // Ignore if controller was disposed
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[SHORTS_VIEW] ⚠️  Error updating interactions: $e');
    }
  }
}

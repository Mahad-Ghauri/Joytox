// ignore_for_file: must_be_immutable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trace/helpers/quick_actions.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:trace/home/a_shorts/shorts_cached_controller.dart';
import 'package:trace/models/UserModel.dart';
import '../../controllers/video_interactions_controller.dart';
import '../video/global_video_playeres.dart';
import '../../main.dart';

class ShortsCachedView extends StatefulWidget {
  final UserModel? currentUser;

  const ShortsCachedView({this.currentUser, super.key});

  @override
  State<ShortsCachedView> createState() => _ShortsCachedViewState();
}

class _ShortsCachedViewState extends State<ShortsCachedView>
    with RouteAware, WidgetsBindingObserver {
  late ShortsCachedController _controller;
  PageController? _pageController;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<ShortsCachedController>()
        ? Get.find<ShortsCachedController>()
        : Get.put(ShortsCachedController());
    
    WidgetsBinding.instance.addObserver(this);
    
    // Mark screen as visible
    _controller.setScreenVisible(true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Subscribe to route observer after route is available
    final route = ModalRoute.of(context);
    if (route != null && route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
    
    // Check if this route is still the current route
    if (route != null && route.isCurrent) {
      // Screen is visible
      if (!_controller.isScreenVisible) {
        _controller.setScreenVisible(true);
      }
    } else {
      // Screen is not visible - pause videos
      if (_controller.isScreenVisible) {
        _controller.pauseAllVideosOnNavigation();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _controller.pauseAllVideosOnNavigation();
    }
  }

  @override
  void didPush() {
    // Route was pushed onto navigator
    _controller.setScreenVisible(true);
  }

  @override
  void didPopNext() {
    // Route was popped and this route is now on top
    _controller.setScreenVisible(true);
  }

  @override
  void didPushNext() {
    // New route was pushed on top of this one
    _controller.pauseAllVideosOnNavigation();
  }

  @override
  void didPop() {
    // This route was popped
    _controller.pauseAllVideosOnNavigation();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _controller.pauseAllVideosOnNavigation();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Move all state-dependent UI under Obx so it rebuilds reactively
    return Obx(() {
      // Loading state
      if (_controller.isLoading.value && _controller.shorts.isEmpty) {
        return QuickHelp.appLoading();
      }

      // Empty state
      if (!_controller.isLoading.value && _controller.shorts.isEmpty) {
        return QuickActions.noContentFound(context);
      }

      // When data is available, set up page controller and interactions
      final initialPage =
          _controller.lastSavedIndex.value < _controller.shorts.length
              ? _controller.lastSavedIndex.value
              : 0;

      _pageController ??= PageController(
        initialPage: initialPage,
      );

      // Start playback after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && mounted) {
          _controller.playVideo(_pageController!.page?.toInt() ?? initialPage);
        }
      });

      final String tag =
          'video_interactions_${_controller.shorts[initialPage].objectId}';
      if (!Get.isRegistered<VideoInteractionsController>(tag: tag)) {
        Get.put(
          VideoInteractionsController(
            video: _controller.shorts[initialPage],
            currentUser: widget.currentUser,
          ),
          tag: tag,
        );
      }

      return WillPopScope(
        onWillPop: () async {
          _controller.saveLastIndex();
          _controller.pauseAllVideosOnNavigation();
          return true;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: () async {
              await _controller.togglePlayPause();
            },
            child: PageView.builder(
              itemCount: _controller.shorts.length,
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: (index) {
                _controller.lastSavedIndex.value = index;
                _controller.playVideo(index);

                // Update video interactions controller for the new video
                final String newTag =
                    'video_interactions_${_controller.shorts[index].objectId}';
                if (!Get.isRegistered<VideoInteractionsController>(
                    tag: newTag)) {
                  Get.put(
                    VideoInteractionsController(
                      video: _controller.shorts[index],
                      currentUser: widget.currentUser,
                    ),
                    tag: newTag,
                  );
                }

                // Reset view progress for the new video
                final newController =
                    Get.find<VideoInteractionsController>(tag: newTag);
                newController.resetViewProgress();
              },
              itemBuilder: (context, index) {
                var currentVideoController =
                    _controller.videoControllers[index];

                final String currentTag =
                    'video_interactions_${_controller.shorts[index].objectId}';
                _controller.videoControllers[index].addListener(() {
                  if (_controller.videoControllers[index].value.isPlaying) {
                    if (Get.isRegistered<VideoInteractionsController>(
                        tag: currentTag)) {
                      final currentController =
                          Get.find<VideoInteractionsController>(
                              tag: currentTag);
                      currentController.updateVideoProgress(
                        _controller.videoControllers[index].value.position,
                        _controller.videoControllers[index].value.duration,
                      );
                    }
                  }
                });

                if (currentVideoController.value.isInitialized) {
                  return GlobalVideoPlayer(
                    video: _controller.shorts[index],
                    currentUser: widget.currentUser,
                    externalController: currentVideoController,
                  );
                }
                return QuickHelp.appLoading();
              },
            ),
          ),
        ),
      );
    });
  }
}

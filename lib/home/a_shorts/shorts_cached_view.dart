// ignore_for_file: must_be_immutable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trace/helpers/quick_actions.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:trace/home/a_shorts/shorts_cached_controller.dart';
import 'package:trace/models/UserModel.dart';
import '../../controllers/video_interactions_controller.dart';
import '../video/global_video_playeres.dart';

class ShortsCachedView extends StatelessWidget {
  UserModel? currentUser;
  final ShortsCachedController _controller =
      Get.isRegistered<ShortsCachedController>()
          ? Get.find<ShortsCachedController>()
          : Get.put(ShortsCachedController());

  ShortsCachedView({this.currentUser, super.key});

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

      var pageController = PageController(
        initialPage: initialPage,
      );

      // Start playback after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.playVideo(pageController.page?.toInt() ?? initialPage);
      });

      final videoInteractionController = Get.put(
        VideoInteractionsController(
          video: _controller.shorts[initialPage],
          currentUser: currentUser,
        ),
      );

      return WillPopScope(
        onWillPop: () async {
          _controller.saveLastIndex();
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
              controller: pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: (index) {
                _controller.lastSavedIndex.value = index;
                _controller.playVideo(index);
                videoInteractionController.resetViewProgress();
              },
              itemBuilder: (context, index) {
                var currentVideoController =
                    _controller.videoControllers[index];

                _controller.videoControllers[index].addListener(() {
                  if (_controller.videoControllers[index].value.isPlaying) {
                    videoInteractionController.updateVideoProgress(
                      _controller.videoControllers[index].value.position,
                      _controller.videoControllers[index].value.duration,
                    );
                  }
                });

                if (currentVideoController.value.isInitialized) {
                  return GlobalVideoPlayer(
                    video: _controller.shorts[index],
                    currentUser: currentUser,
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

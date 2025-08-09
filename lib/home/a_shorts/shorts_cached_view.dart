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
  final ShortsCachedController _controller = Get.put(ShortsCachedController());

  ShortsCachedView({this.currentUser, super.key});


  @override
  Widget build(BuildContext context) {

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.shorts.isEmpty && !_controller.isLoading.value) {
        print(
            'ReelsView: Lista vazia no primeiro frame, forçando carregamento');
        //_controller.loadInitialVideos(forceRefresh: true);
      } else if ( _controller.shorts.isNotEmpty) {
        print('ReelsView: Iniciando reprodução automática');
        _controller.playCurrentVideo();
      }
    });


    if (_controller.isLoading.value && _controller.shorts.isEmpty) {
      return QuickHelp.appLoading();
    }

    if (!_controller.isLoading.value && _controller.shorts.isEmpty) {
      return QuickActions.noContentFound(context);
    }

    var pageController = PageController(
      initialPage: _controller.lastSavedIndex.value < _controller.shorts.length
          ? _controller.lastSavedIndex.value
          : 0,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.playVideo(pageController.page?.toInt() ?? 0);
    });

    final videoInteractionController = Get.put(VideoInteractionsController(
        video: _controller.shorts[_controller.lastSavedIndex.value < _controller.shorts.length
            ? _controller.lastSavedIndex.value
            : 0],
        currentUser: currentUser));

    return WillPopScope(
      onWillPop: () async{
        _controller.saveLastIndex();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Obx(() {
          return GestureDetector(
            onTap: () async{
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
                }),
          );
        }),
      ),
    );
  }
}

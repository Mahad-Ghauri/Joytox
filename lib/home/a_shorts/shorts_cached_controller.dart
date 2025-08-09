// ignore_for_file: unnecessary_null_comparison

import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../../models/PostsModel.dart';


class ShortsCachedController extends GetxController {
  RxList<PostsModel> shorts = <PostsModel>[].obs;
  RxBool isLoading = true.obs;

  int limit = 15;
  int limitBeforeMore = 3;

  var showPlayPauseIcon = false.obs;
  var isPlaying = true.obs;

  final int preloadCount = 5;

  //video Stuff
  var videoControllers = <CachedVideoPlayerPlusController>[].obs;
  var currentVideoIndex = 0.obs;

  var lastSavedIndex = 0.obs;


  @override
  void onInit() {
    super.onInit();
    queryInitialVideos();
  }

  @override
  void onClose() {
    disposeAllControllers();
    super.onClose();
  }


  //dispose all controllers
  void disposeAllControllers() {
    for (var controller in videoControllers) {
      controller.pause();
      controller.dispose();
    }
    videoControllers.clear();
  }

  //Get first videos
  Future<void> queryInitialVideos() async {
    QueryBuilder query = QueryBuilder(PostsModel())
      ..whereValueExists(PostsModel.keyVideo, true)
      ..includeObject([PostsModel.keyAuthor])
      ..orderByDescending(PostsModel.keyCreatedAt)
      ..setLimit(limit);

    ParseResponse response = await query.query();

    if(response.success && response.results != null) {
      List<PostsModel> loadedVideos = response.results!.map((e) => e as PostsModel).toList();
      shorts.value = loadedVideos;
      isLoading.value = false;
      _initializeVideoController();
    } else {
      isLoading.value = false;
    }
  }

  //Load more videos, when scroll reaches end
  Future<void> queryMoreVideos() async {
    if(isLoading.value) return; //avoid multiple calls

    isLoading.value = true;

    debugPrint("Get_more_videos_called :");
    QueryBuilder query = QueryBuilder(PostsModel())
      ..whereValueExists(PostsModel.keyVideo, true)
      ..includeObject([PostsModel.keyAuthor])
      ..orderByDescending(PostsModel.keyCreatedAt)
      ..setAmountToSkip(shorts.length)
      ..setLimit(limit);

    ParseResponse response = await query.query();

    if(response.success && response.results != null) {
      List<PostsModel> loadedVideos = response.results!.map((e) => e as PostsModel).toList();
      shorts.addAll(loadedVideos);
      isLoading.value = false;

      //initialize only 3-5 controllers, not all
      int videosToPreload = 5;
      for(int i = 0; i < loadedVideos.length && i < videosToPreload; i++) {
        _addVideoController(loadedVideos[i]);
      }

      // add empty controllers for the rest
      for(int i = videosToPreload; i < loadedVideos.length; i++) {
        _addEmptyController(loadedVideos[i]);
      }
    } else {
      isLoading.value = false;
    }
  }

  void saveViews(PostsModel video) {
    video.setViews = 1;
    video.save();
  }

  //Initialize video controllers for fast video playback
  void _initializeVideoController() {
    videoControllers.clear();

    // initialize only 3-5 controllers
    int initialVideosToLoad = 5;
    for(int i = 0; i < shorts.length && i < initialVideosToLoad; i++) {
      _addVideoController(shorts[i]);
    }

    // add empty controller for the rest
    for(int i = initialVideosToLoad; i < shorts.length; i++) {
      _addEmptyController(shorts[i]);
    }
  }

  //add not initialized controllers
  void _addEmptyController(PostsModel videoPost) {
    var controller = CachedVideoPlayerPlusController.networkUrl(
      Uri.parse(videoPost.getVideo!.url!),
      invalidateCacheIfOlderThan: const Duration(days: 2),
    );
    videoControllers.add(controller);
  }

  //Initialize video controllers for fast video playback
  void _addVideoController(PostsModel videoPost) async{
      var controller = CachedVideoPlayerPlusController.networkUrl(
        Uri.parse(videoPost.getVideo!.url!),
        invalidateCacheIfOlderThan: const Duration(days: 2),
      );
      videoControllers.add(controller);
      controller.initialize().then((_) async {
        debugPrint("controller initialized:");
        update();
      });
      controller.setLooping(true);
  }

  // to avoid memory crashes, release distant controllers
  void _releaseDistantControllers(int currentIndex) {

    final int keepRange = 5;

    for (int i = 0; i < videoControllers.length; i++) {
      if ((i < currentIndex - keepRange || i > currentIndex + keepRange) &&
          videoControllers[i].value.isInitialized) {
        videoControllers[i].pause();
        videoControllers[i].dispose();
        //create a new controller not initialized to use if needed
        videoControllers[i] = CachedVideoPlayerPlusController.networkUrl(
          Uri.parse(shorts[i].getVideo!.url!),
          invalidateCacheIfOlderThan: const Duration(days: 2),
        );
      }
    }
  }

  Future<bool> checkNextVideosReady(int currentIndex) async {
    int endIndex = currentIndex + preloadCount;
    if (endIndex > shorts.length) endIndex = shorts.length;

    List<Future<void>> initializationFutures = [];

    for (int i = currentIndex; i < endIndex; i++) {
      if (i < videoControllers.length && !videoControllers[i].value.isInitialized) {
        _addVideoController(shorts[i]);
        initializationFutures.add(videoControllers[i].initialize());
      }
    }

    if (initializationFutures.isNotEmpty) {
      try {
        await Future.wait(initializationFutures);
        debugPrint("novos_controladores_preica Next $preloadCount vídeos initialized successful");
        return true;
      } catch (e) {
        debugPrint("novos_controladores_preica Erros initializing next $preloadCount vídeos: $e");
        return false;
      }
    }

    return true;
  }

  void playVideo(int index) async {
    if (index < 0 || index >= videoControllers.length) return;

    int lastIndex = index - 1;
    if (currentVideoIndex.value < videoControllers.length &&
        !videoControllers[currentVideoIndex.value].value.isInitialized) {
      videoControllers[currentVideoIndex.value].pause();
    }

    if(lastIndex > -1) {
      videoControllers[lastIndex].pause();
    }

    /*if (!videoControllers[index].value.isInitialized) {
      videoControllers[index] = CachedVideoPlayerPlusController.networkUrl(
        Uri.parse(shorts[index].getVideo!.url!),
        invalidateCacheIfOlderThan: const Duration(days: 2),
      );
      await videoControllers[index].initialize();
    }*/

    currentVideoIndex.value = index;

    //clean memory for distant controllers
    _releaseDistantControllers(index);

    if (videoControllers[index].value.isInitialized) {
      videoControllers[index].play();
    }


    if (index + 1 < shorts.length && !videoControllers[index + 1].value.isInitialized) {
      int nextControllers = shorts.length > 5 ? 5 : shorts.length;
      for(int i = index + 1; i <= index + nextControllers; i++) {
        videoControllers[i] = CachedVideoPlayerPlusController.networkUrl(
          Uri.parse(shorts[i].getVideo!.url!),
          invalidateCacheIfOlderThan: const Duration(days: 2),
        );
        videoControllers[i].initialize();
      }
    }

    if (currentVideoIndex.value >= shorts.length - limitBeforeMore) {
      queryMoreVideos();
    }
  }

  Future<void> pauseAllVideos() async {
    try {
      for (final controller in videoControllers) {
        if (controller.value.isPlaying) {
          await controller.pause();
        }
      }
      isPlaying.value = false;
      Future.delayed(Duration(milliseconds: 1000)).then((val){
        showPlayPauseIcon.value = false;
      });
    } catch (e) {
      print("ReelsController: Erro ao pausar todos os vídeos: $e");
    }
  }

  Future<void> pauseVideo(int index) async {
    try {
      for (final controller in videoControllers) {
        if (controller.value.isPlaying) {
          await controller.pause();
        }
      }
      isPlaying.value = false;
      Future.delayed(Duration(milliseconds: 1000)).then((val){
        showPlayPauseIcon.value = false;
      });
    } catch (e) {
      print("ReelsController: Erro ao pausar todos os vídeos: $e");
    }
  }

  Future<void> togglePlayPause() async {
    try {
      final currentIndex = currentVideoIndex.value;
      if (currentIndex >= 0 && currentIndex < shorts.length) {
        final controller = await videoControllers[currentIndex];
        if (controller != null) {
          if (controller.value.isPlaying) {
            await controller.pause();
            isPlaying.value = false;
          } else {
            await controller.play();
            isPlaying.value = true;
          }

          showPlayPauseIcon.value = true;
          Future.delayed(Duration(milliseconds: 800), () {
            showPlayPauseIcon.value = false;
          });
        }
      }
    } catch (e) {
      print('ReelsController: Erro ao alternar reprodução: $e');
    }
  }


  Future<void> playCurrentVideo() async {
    try {
      final currentIndex = currentVideoIndex.value;
      if (currentIndex >= 0 && currentIndex < shorts.length) {
        debugPrint(
            'ReelsController: playing current video: position $currentIndex');

        await pauseAllVideos();

        final controller = await videoControllers[currentIndex];
        if (controller != null) {
          if (controller.value.position == Duration.zero ||
              controller.value.position >=
                  controller.value.duration - Duration(milliseconds: 200)) {
            await controller.seekTo(Duration.zero);
          }

          await controller.setVolume(1.0);

          await controller.play();
          isPlaying.value = true;

          await Future.delayed(Duration(milliseconds: 500));
          if (!controller.value.isPlaying && isPlaying.value) {
            print(
                "ReelsController: Vídeo não está reproduzindo, tentando recuperar");
            // Tentar reiniciar a reprodução
            await controller.seekTo(Duration.zero);
            await controller.play();
          }
        }
      }
    } catch (e) {
      print('ReelsController: could not pl: $e');
    }
  }

  void saveLastIndex() {

    lastSavedIndex.value = currentVideoIndex.value;


    if (currentVideoIndex.value < videoControllers.length) {
      try {
        videoControllers[currentVideoIndex.value].pause();
        debugPrint("video_error: salvou o index: ${currentVideoIndex.value}");
      } catch (e) {
        debugPrint("video_error: $e");
      }
    }
  }


}
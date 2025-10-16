// ignore_for_file: unnecessary_null_comparison

import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../../models/PostsModel.dart';

class ShortsCachedController extends GetxController {
  RxList<PostsModel> shorts = <PostsModel>[].obs;
  RxBool isLoading = true.obs;

  int limit = 10; // REDUCED from 15 to 10 - saves ~50MB per load
  int limitBeforeMore = 3;

  var showPlayPauseIcon = false.obs;
  var isPlaying = true.obs;
  // Tracks whether user explicitly paused to avoid auto-resume
  var userPaused = false.obs;

  final int preloadCount = 3; // REDUCED from 5 to 3 - saves ~30MB memory

  //video Stuff
  var videoControllers = <CachedVideoPlayerPlusController>[].obs;
  var currentVideoIndex = 0.obs;

  var lastSavedIndex = 0.obs;

  // FIX: Add disposal state tracking to prevent buffer issues
  bool _isDisposed = false;
  bool _isInitializing = false;

  @override
  void onInit() {
    super.onInit();
    queryInitialVideos();
  }

  @override
  void onClose() {
    // FIX: Comprehensive cleanup to prevent ImageReader buffer issues
    _isDisposed = true;
    disposeAllControllers();

    // Clear all lists to prevent memory leaks
    shorts.clear();
    videoControllers.clear();

    super.onClose();
    print('ShortsCachedController: Properly disposed all resources');
  }

  //dispose all controllers
  void disposeAllControllers() {
    try {
      // FIX: Proper sequential disposal to prevent ImageReader buffer overflow
      for (var controller in videoControllers) {
        if (controller.value.isInitialized) {
          controller.pause();
          // Add small delay to prevent buffer conflicts
          Future.delayed(Duration(milliseconds: 50), () {
            controller.dispose();
          });
        } else {
          // Dispose uninitialized controllers immediately
          controller.dispose();
        }
      }

      // Clear after disposal operations are queued
      Future.delayed(Duration(milliseconds: 100), () {
        videoControllers.clear();
      });
    } catch (e) {
      print('ShortsCachedController: Error disposing controllers: $e');
      // Force clear on error
      videoControllers.clear();
    }
  }

  //Get first videos
  Future<void> queryInitialVideos() async {
    debugPrint('ShortsCachedController: querying initial videos...');
    QueryBuilder query = QueryBuilder(PostsModel())
      ..whereValueExists(PostsModel.keyVideo, true)
      ..includeObject([PostsModel.keyAuthor])
      ..orderByDescending(PostsModel.keyCreatedAt)
      ..setLimit(limit);

    ParseResponse response = await query.query();
    debugPrint(
        'ShortsCachedController: query success=${response.success}, count=${response.count}, hasResults=${response.results != null}');

    if (response.success && response.results != null) {
      List<PostsModel> loadedVideos =
          response.results!.map((e) => e as PostsModel).toList();
      debugPrint(
          'ShortsCachedController: loaded ${loadedVideos.length} videos');
      if (loadedVideos.isNotEmpty) {
        for (final v in loadedVideos.take(3)) {
          debugPrint(
              'ShortsCachedController: sample video id=${v.objectId} url=${v.getVideo?.url} thumb=${v.getVideoThumbnail?.url}');
        }
      }
      shorts.value = loadedVideos;
      isLoading.value = false;
      _initializeVideoController();
    } else {
      isLoading.value = false;
      debugPrint(
          'ShortsCachedController: no results or error: ${response.error?.message}');
    }
  }

  //Load more videos, when scroll reaches end
  Future<void> queryMoreVideos() async {
    if (isLoading.value) return; //avoid multiple calls

    isLoading.value = true;

    debugPrint("Get_more_videos_called :");
    QueryBuilder query = QueryBuilder(PostsModel())
      ..whereValueExists(PostsModel.keyVideo, true)
      ..includeObject([PostsModel.keyAuthor])
      ..orderByDescending(PostsModel.keyCreatedAt)
      ..setAmountToSkip(shorts.length)
      ..setLimit(limit);

    ParseResponse response = await query.query();

    if (response.success && response.results != null) {
      List<PostsModel> loadedVideos =
          response.results!.map((e) => e as PostsModel).toList();
      shorts.addAll(loadedVideos);
      isLoading.value = false;

      //initialize only 2 controllers - REDUCED from 5 to 2 - saves memory
      int videosToPreload = 2;
      for (int i = 0; i < loadedVideos.length && i < videosToPreload; i++) {
        _addVideoController(loadedVideos[i]);
      }

      // add empty controllers for the rest
      for (int i = videosToPreload; i < loadedVideos.length; i++) {
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

    // initialize only 2 controllers - REDUCED from 5 to 2 - saves ~100MB
    int initialVideosToLoad = 2;
    for (int i = 0; i < shorts.length && i < initialVideosToLoad; i++) {
      _addVideoController(shorts[i]);
    }

    // add empty controller for the rest
    for (int i = initialVideosToLoad; i < shorts.length; i++) {
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
  void _addVideoController(PostsModel videoPost) async {
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
    if (_isDisposed || _isInitializing) return;

    final int keepRange = 2; // REDUCED from 5 to 2 - saves ~150MB memory

    try {
      for (int i = 0; i < videoControllers.length; i++) {
        if ((i < currentIndex - keepRange || i > currentIndex + keepRange) &&
            videoControllers[i].value.isInitialized) {
          // FIX: Proper async disposal to prevent ImageReader buffer issues
          final controllerToDispose = videoControllers[i];
          controllerToDispose.pause();

          // Dispose with delay to prevent buffer conflicts
          Future.delayed(Duration(milliseconds: 100), () {
            try {
              controllerToDispose.dispose();
            } catch (e) {
              print(
                  'ShortsCachedController: Error disposing distant controller $i: $e');
            }
          });

          // FIX: Create new controller with delay to prevent race conditions
          Future.delayed(Duration(milliseconds: 150), () {
            if (!_isDisposed && i < shorts.length) {
              try {
                videoControllers[i] =
                    CachedVideoPlayerPlusController.networkUrl(
                  Uri.parse(shorts[i].getVideo!.url!),
                  invalidateCacheIfOlderThan: const Duration(days: 2),
                );
              } catch (e) {
                print(
                    'ShortsCachedController: Error creating new controller $i: $e');
              }
            }
          });
        }
      }
    } catch (e) {
      print('ShortsCachedController: Error in _releaseDistantControllers: $e');
    }
  }

  Future<bool> checkNextVideosReady(int currentIndex) async {
    int endIndex = currentIndex + preloadCount;
    if (endIndex > shorts.length) endIndex = shorts.length;

    List<Future<void>> initializationFutures = [];

    for (int i = currentIndex; i < endIndex; i++) {
      if (i < videoControllers.length &&
          !videoControllers[i].value.isInitialized) {
        _addVideoController(shorts[i]);
        initializationFutures.add(videoControllers[i].initialize());
      }
    }

    if (initializationFutures.isNotEmpty) {
      try {
        await Future.wait(initializationFutures);
        debugPrint(
            "novos_controladores_preica Next $preloadCount vídeos initialized successful");
        return true;
      } catch (e) {
        debugPrint(
            "novos_controladores_preica Erros initializing next $preloadCount vídeos: $e");
        return false;
      }
    }

    return true;
  }

  void playVideo(int index) async {
    if (index < 0 || index >= videoControllers.length || _isDisposed) return;

    // FIX: Prevent concurrent initialization to avoid buffer overflow
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      // FIX: Single cleanup call instead of double call
      _releaseDistantControllers(index);

      // Pause previous videos
      int lastIndex = currentVideoIndex.value;
      if (lastIndex >= 0 &&
          lastIndex < videoControllers.length &&
          videoControllers[lastIndex].value.isInitialized) {
        await videoControllers[lastIndex].pause();
      }

      currentVideoIndex.value = index;

      // Play current video if initialized
      if (videoControllers[index].value.isInitialized) {
        await videoControllers[index].play();
      } else {
        // FIX: Safe controller initialization with error handling
        try {
          videoControllers[index] = CachedVideoPlayerPlusController.networkUrl(
            Uri.parse(shorts[index].getVideo!.url!),
            invalidateCacheIfOlderThan: const Duration(days: 2),
          );
          await videoControllers[index].initialize();
          if (!_isDisposed) {
            await videoControllers[index].play();
          }
        } catch (e) {
          print('ShortsCachedController: Error initializing video $index: $e');
        }
      }

      // FIX: Limit next controller preloading to prevent buffer overflow
      if (index + 1 < shorts.length &&
          index + 1 < videoControllers.length &&
          !videoControllers[index + 1].value.isInitialized) {
        // Only preload next 2 videos instead of 5 to prevent buffer issues
        int maxPreload = 2;
        int endIndex = (index + 1 + maxPreload).clamp(0, shorts.length);

        for (int i = index + 1;
            i < endIndex && i < videoControllers.length;
            i++) {
          if (!_isDisposed) {
            try {
              // Add delay between initializations to prevent buffer overflow
              await Future.delayed(Duration(milliseconds: 200));

              videoControllers[i] = CachedVideoPlayerPlusController.networkUrl(
                Uri.parse(shorts[i].getVideo!.url!),
                invalidateCacheIfOlderThan: const Duration(days: 2),
              );

              // Initialize without blocking
              videoControllers[i].initialize().catchError((e) {
                print('ShortsCachedController: Error preloading video $i: $e');
              });
            } catch (e) {
              print(
                  'ShortsCachedController: Error creating preload controller $i: $e');
              break; // Stop preloading on error
            }
          }
        }
      }

      if (currentVideoIndex.value >= shorts.length - limitBeforeMore) {
        queryMoreVideos();
      }
    } catch (e) {
      print('ShortsCachedController: Error in playVideo: $e');
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> pauseAllVideos() async {
    if (_isDisposed) return;

    try {
      // FIX: Safe pause with error handling for each controller
      for (final controller in videoControllers) {
        try {
          if (controller.value.isInitialized && controller.value.isPlaying) {
            await controller.pause();
          }
        } catch (e) {
          print(
              "ShortsCachedController: Error pausing individual controller: $e");
          // Continue with next controller
        }
      }

      if (!_isDisposed) {
        isPlaying.value = false;
        Future.delayed(Duration(milliseconds: 1000)).then((val) {
          if (!_isDisposed) {
            showPlayPauseIcon.value = false;
          }
        });
      }
    } catch (e) {
      print("ShortsCachedController: Error pausing all videos: $e");
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
      Future.delayed(Duration(milliseconds: 1000)).then((val) {
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
        final controller = videoControllers[currentIndex];
        if (controller.value.isPlaying) {
          await controller.pause();
          isPlaying.value = false;
          userPaused.value = true;
        } else {
          await controller.play();
          isPlaying.value = true;
          userPaused.value = false;
        }

        showPlayPauseIcon.value = true;
        Future.delayed(Duration(milliseconds: 800), () {
          showPlayPauseIcon.value = false;
        });
      }
    } catch (e) {
      print('ReelsController: Erro ao alternar reprodução: $e');
    }
  }

  Future<void> playCurrentVideo() async {
    try {
      // Don't auto-resume if the user explicitly paused
      if (userPaused.value) {
        return;
      }
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

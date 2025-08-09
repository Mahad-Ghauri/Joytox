// ignore_for_file: must_be_immutable

import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trace/models/PostsModel.dart';

import '../../models/UserModel.dart';
import '../../views/reels_interactions.dart';

class GlobalVideoPlayer extends StatelessWidget {
  UserModel? currentUser;
  PostsModel? video;
  CachedVideoPlayerPlusController? currentVideoController;

  GlobalVideoPlayer({
    this.video,
    this.currentUser,
    this.currentVideoController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if(currentVideoController!.value.isInitialized) {
       currentVideoController = CachedVideoPlayerPlusController.networkUrl(
        Uri.parse(video!.getVideo!.url!),
        invalidateCacheIfOlderThan: const Duration(days: 2),
      );
      currentVideoController!.initialize().then((_) async {
        debugPrint("controller initialized:");
      });
      currentVideoController!.setLooping(true);
    }

    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        AspectRatio(
          aspectRatio: currentVideoController!.value.aspectRatio,
          child: CachedVideoPlayerPlus(currentVideoController!),
        ),
        ReelsInteractions(
          postModel: video!,
          currentUser: currentUser ?? Get.find<UserModel>(),
        ),
      ],
    );
  }
}

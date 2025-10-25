// ignore_for_file: deprecated_member_use, unused_element

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:expandable_text/expandable_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:like_button/like_button.dart';
import 'package:trace/controllers/video_interactions_controller.dart';
import 'package:trace/ui/text_with_tap.dart';

import '../../../helpers/quick_actions.dart';
import '../../../helpers/quick_help.dart';
import '../../../models/PostsModel.dart';
import '../../../models/UserModel.dart';
import '../../../ui/container_with_corner.dart';
import '../../../utils/colors.dart';
import '../../../utils/text_sanitizer.dart';
import '../services/posts_service.dart';

class ReelsInteractions extends GetView<VideoInteractionsController> {
  final PostsModel postModel;
  final UserModel? currentUser;

  ReelsInteractions({
    required this.postModel,
    this.currentUser,
  }) {
    if (!Get.isRegistered<VideoInteractionsController>(
        tag: postModel.objectId)) {
      Get.put(
        VideoInteractionsController(
          video: postModel,
          currentUser: currentUser,
        ),
        tag: postModel.objectId,
      );
    }
  }

  /// Enhanced method to ensure author is loaded with proper error handling and UI updates
  void _ensureAuthorIsLoaded() {
    // Check if author is already loaded and has valid data
    if (postModel.getAuthor != null &&
        postModel.getAuthor!.getFullName != null) {
      print(
          'ReelsInteractions: Author already loaded for post ${postModel.objectId}: ${postModel.getAuthor!.getFullName}');
      return;
    }

    // Check if we have an author ID to fetch
    if (postModel.getAuthorId == null) {
      print('ReelsInteractions: No author ID for post ${postModel.objectId}');
      return;
    }

    print('ReelsInteractions: Fetching author for post ${postModel.objectId}');

    // Try to fetch author using PostsService
    if (Get.isRegistered<PostsService>()) {
      final postsService = Get.find<PostsService>();

      // Use async method with proper error handling
      postsService.fetchAuthorForPost(postModel).then((_) {
        print(
            'ReelsInteractions: Author fetch completed for post ${postModel.objectId}');

        // Force UI refresh after author is loaded
        if (postModel.getAuthor != null &&
            postModel.getAuthor!.getFullName != null) {
          print(
              'ReelsInteractions: Author loaded successfully: ${postModel.getAuthor!.getFullName}');
          // Trigger UI update by calling setState or using GetX reactive updates
          if (Get.isRegistered<VideoInteractionsController>(
              tag: postModel.objectId)) {
            final controller =
                Get.find<VideoInteractionsController>(tag: postModel.objectId);
            controller.update(); // Force controller update
            print(
                'ReelsInteractions: Controller updated for post ${postModel.objectId}');
          }
        } else {
          print(
              'ReelsInteractions: Failed to load author for post ${postModel.objectId} - author is null or has no name');
        }
      }).catchError((error) {
        print('ReelsInteractions: Error fetching author: $error');
      });
    } else {
      print('ReelsInteractions: PostsService not registered');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Refresh video data when widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<VideoInteractionsController>(
          tag: postModel.objectId)) {
        final controller =
            Get.find<VideoInteractionsController>(tag: postModel.objectId);
        print('=== REELS INTERACTIONS WIDGET BUILD ===');
        print('Post ID: ${postModel.objectId}');
        print('Current likes count: ${controller.likesCount.value}');
        print('Current comments count: ${controller.commentsCount.value}');
        print('Current saves count: ${controller.savesCount.value}');

        // Force refresh video data from server
        controller.refreshVideoData();

        print('=== REELS INTERACTIONS WIDGET BUILD END ===');
      }
    });

    // Enhanced author fetching logic
    _ensureAuthorIsLoaded();

    // Force refresh author data if needed
    if ((postModel.getAuthor == null ||
            postModel.getAuthor!.getFullName == null) &&
        postModel.getAuthorId != null) {
      // Try to fetch author again after a short delay
      Future.delayed(Duration(milliseconds: 500), () {
        _ensureAuthorIsLoaded();
      });
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _userNameAndTimeUploadedWidget(context),
                  SizedBox(height: 8.0),
                  _rainBowBrandWidget(),
                  SizedBox(height: 8.0),
                  if (postModel.getText != null &&
                      postModel.getText!.isNotEmpty)
                    _descriptionWidget(),
                  SizedBox(height: 8.0),
                ],
              ),
              _interactionsWidget(context),
            ],
          ),
        ),
      ],
    );
  }

  /// Enhanced avatar widget with better error handling and fallbacks
  Widget _buildAuthorAvatar(UserModel author) {
    try {
      // Check if author has valid avatar URL
      final avatarUrl = author.getAvatar?.url;
      final hasValidAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

      print('ReelsInteractions: Building avatar for ${author.getFullName}');
      print('ReelsInteractions: Avatar URL: $avatarUrl');
      print('ReelsInteractions: Has valid avatar: $hasValidAvatar');

      if (hasValidAvatar) {
        return QuickActions.avatarWidget(
          author,
          width: 45,
          height: 45,
          margin: EdgeInsets.only(bottom: 0, top: 0, left: 0, right: 5),
        );
      } else {
        // Show initials as fallback
        final displayName = author.getFullName ?? author.getFirstName ?? "U";
        return Container(
          width: 45,
          height: 45,
          margin: EdgeInsets.only(bottom: 0, top: 0, left: 0, right: 5),
          child: CircleAvatar(
            backgroundColor: Colors.grey.withOpacity(0.3),
            child: Text(
              _getInitials(displayName),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      print('ReelsInteractions: Error building avatar: $e');
      // Fallback to simple circle with initials
      return Container(
        width: 45,
        height: 45,
        margin: EdgeInsets.only(bottom: 0, top: 0, left: 0, right: 5),
        child: CircleAvatar(
          backgroundColor: Colors.grey.withOpacity(0.3),
          child: Icon(
            Icons.person,
            color: Colors.white70,
            size: 24,
          ),
        ),
      );
    }
  }

  /// Get initials from full name
  String _getInitials(String name) {
    if (name.isEmpty) return "U";

    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return (words[0][0] + words[1][0]).toUpperCase();
    } else {
      return words[0][0].toUpperCase();
    }
  }

  Widget _interactionsWidget(BuildContext context) {
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Like Button com feedback visual melhorado
          Obx(() => _buildInteractionButton(
                icon: controller.isLiked.value
                    ? Icons.favorite
                    : Icons.favorite_outline_outlined,
                color: controller.isLiked.value ? kRedColor1 : Colors.white,
                count: controller.likesCount.value,
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await controller.toggleLike();
                },
                showAnimation: true,
              )),

          // Save Button com feedback visual melhorado
          Visibility(
            visible: currentUser != null &&
                postModel.getAuthor != null &&
                currentUser!.objectId != postModel.getAuthor!.objectId,
            child: Column(
              children: [
                SizedBox(height: 10),
                Obx(() => _buildInteractionButton(
                      icon: controller.isSaved.value
                          ? Icons.bookmark
                          : Icons.bookmark_border_outlined,
                      color: controller.isSaved.value
                          ? kOrangeColor
                          : Colors.white,
                      count: controller.savesCount.value,
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await controller.toggleSave();
                      },
                      showAnimation: true,
                    )),
              ],
            ),
          ),

          // Comments Button com feedback visual melhorado
          SizedBox(height: 10),
          Obx(() => _buildInteractionButton(
                icon: Icons.comment,
                color: Colors.white,
                iconSize: 24,
                count: controller.commentsCount.value,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  controller.showComments(context);
                },
                showAnimation: false,
              )),
          SizedBox(height: 10),
          _buildInteractionButton(
            icon: Icons.download,
            color: Colors.white,
            iconSize: 24,
            count: null, // Download doesn't have a count
            onTap: () {
              HapticFeedback.mediumImpact();
              controller.downloadVideo(context);
            },
            showAnimation: false,
          ),
          SizedBox(height: 10),
          Obx(() => _buildInteractionButton(
                icon: Icons.remove_red_eye_sharp,
                color: Colors.white,
                iconSize: 24,
                count: controller.viewsCount.value,
                onTap: () {
                  HapticFeedback.mediumImpact();
                },
                showAnimation: false,
              )),

          SizedBox(height: 10),
          Obx(() => _buildInteractionButton(
                icon: Icons.share_outlined,
                color: Colors.white,
                iconSize: 24,
                count: controller.sharesCount.value,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  controller.sharePost(context);
                },
                showAnimation: false,
              )),

          // More Options Button com feedback visual melhorado
          SizedBox(height: 15),
          _buildInteractionButton(
            icon: Icons.more_horiz,
            color: Colors.white,
            onTap: () {
              HapticFeedback.mediumImpact();
              controller.openOptionsSheet(context);
            },
            showAnimation: false,
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required Color color,
    int? count,
    required VoidCallback onTap,
    bool showAnimation = false,
    double iconSize = 30.0,
  }) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: showAnimation
          ? LikeButton(
              size: iconSize,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              countPostion: CountPostion.top,
              circleColor: CircleColor(start: color, end: color),
              bubblesColor: BubblesColor(
                dotPrimaryColor: color,
                dotSecondaryColor: color,
              ),
              likeBuilder: (bool isLiked) => Icon(
                icon,
                color: color,
                size: iconSize,
              ),
              likeCount: count,
              countBuilder: (count, bool isLiked, String text) {
                return count == null
                    ? const SizedBox.shrink()
                    : Container(
                        margin: EdgeInsets.only(top: 4),
                        child: Text(
                          QuickHelp.convertNumberToK(count),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
              },
              onTap: (isLiked) async {
                onTap();
                return !isLiked;
              },
            )
          : GestureDetector(
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    Icon(icon, color: color, size: iconSize),
                    if (count != null)
                      Container(
                        margin: EdgeInsets.only(top: 4),
                        child: Text(
                          QuickHelp.convertNumberToK(count),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _descriptionWidget() {
    return Container(
      width: 220,
      child: ExpandableText(
        TextSanitizer.sanitizePostText(postModel.getText),
        expandText: tr('show_more'),
        collapseText: tr('show_less'),
        maxLines: 2,
        linkColor: Colors.blue,
        style: GoogleFonts.nunito(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _rainBowBrandWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.watch_later_outlined,
          color: Colors.white,
          size: 16,
        ),
        SizedBox(width: 8.0),
        Container(
          width: 220,
          child: Text(
            QuickHelp.getTimeAgoForFeed(postModel.createdAt!),
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _userNameAndTimeUploadedWidget(BuildContext context) {
    // Debug logging
    print(
        'ReelsInteractions: Author for post ${postModel.objectId}: ${postModel.getAuthor?.getFullName}');
    print('ReelsInteractions: Author ID: ${postModel.getAuthorId}');
    print(
        'ReelsInteractions: Author avatar: ${postModel.getAuthor?.getAvatar?.url}');

    // Always try to fetch author if not loaded or if author has no name
    if ((postModel.getAuthor == null ||
            postModel.getAuthor!.getFullName == null) &&
        postModel.getAuthorId != null) {
      _ensureAuthorIsLoaded();
    }

    // Get the current author data
    final author = postModel.getAuthor;

    // If author is null, show loading state
    if (author == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: postModel.getAuthorId != null
                ? CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  )
                : Icon(
                    Icons.person,
                    color: Colors.white70,
                    size: 24,
                  ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextWithTap(
                postModel.getAuthorId != null ? "Loading..." : "Unknown User",
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(1.0),
                fontSize: 15,
                marginLeft: 3,
              ),
            ],
          ),
        ],
      );
    }

    // Author is loaded, show the actual data
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Enhanced avatar widget with better error handling
        _buildAuthorAvatar(author),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextWithTap(
              author.getFullName ?? "Loading...",
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(1.0),
              fontSize: 15,
              marginLeft: 3,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  "assets/svg/ic_diamond.svg",
                  height: 20,
                ),
                TextWithTap(
                  "${author.getDiamondsTotal.toString()}",
                  color: Colors.white,
                  fontSize: 13,
                ),
                VerticalDivider(),
                SvgPicture.asset(
                  "assets/svg/ic_followers_active.svg",
                  height: 19,
                ),
                TextWithTap(
                  "${author.getFollowers?.length.toString() ?? "0"}",
                  color: Colors.white,
                  fontSize: 13,
                ),
              ],
            )
          ],
        ),
        Visibility(
          visible: currentUser != null &&
              author.objectId != null &&
              currentUser!.objectId != author.objectId,
          child: _followWidget(context),
        ),
      ],
    );
  }

  Widget _followWidget(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      margin: EdgeInsets.only(left: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.max,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Obx(() => LikeButton(
                  size: 37,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  countPostion: CountPostion.top,
                  circleColor:
                      CircleColor(start: kPrimaryColor, end: kPrimaryColor),
                  bubblesColor: BubblesColor(
                    dotPrimaryColor: kPrimaryColor,
                    dotSecondaryColor: kPrimaryColor,
                  ),
                  isLiked: controller.isFollowing.value,
                  likeCountAnimationType: LikeCountAnimationType.none,
                  likeBuilder: (bool isLiked) {
                    return ContainerCorner(
                      colors: [
                        isLiked ? Colors.black.withOpacity(0.4) : kPrimaryColor,
                        isLiked ? Colors.black.withOpacity(0.4) : kPrimaryColor
                      ],
                      child: ContainerCorner(
                        color: kTransparentColor,
                        height: 30,
                        width: 30,
                        child: Icon(
                          isLiked ? Icons.done : Icons.add,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      borderRadius: 50,
                      height: 40,
                      width: 40,
                    );
                  },
                  onTap: (isLiked) async {
                    await controller.toggleFollow();
                    return !isLiked;
                  },
                )),
          ),
        ],
      ),
    );
  }
}

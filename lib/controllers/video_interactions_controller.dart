// ignore_for_file: deprecated_member_use

import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:get/get.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trace/helpers/quick_actions.dart';
import 'package:trace/helpers/quick_cloud.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:trace/models/CommentsModel.dart';
import 'package:trace/models/NotificationsModel.dart';
import 'package:trace/models/PostsModel.dart';
import 'package:trace/models/ReportModel.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/home/feed/video_reels_comments_screen.dart';
import 'package:trace/controllers/reels_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trace/controllers/video_recommendation_controller.dart';
import 'package:trace/services/posts_service.dart';
import 'package:trace/home/profile/user_profile_screen.dart';

import '../app/setup.dart';
import '../services/deep_links_service.dart';

class VideoInteractionsController extends GetxController {
  final PostsModel video;
  final UserModel? currentUser;
  late final ReelsController _reelsController;
  final PostsService _postsService = Get.find<PostsService>();

  final RxBool isLiked = false.obs;
  final RxBool isSaved = false.obs;
  final RxBool isFollowing = false.obs;
  final RxInt likesCount = 0.obs;
  final RxInt savesCount = 0.obs;
  final RxInt commentsCount = 0.obs;
  final RxInt viewsCount = 0.obs;
  final RxInt sharesCount = 0.obs;
  final RxDouble videoProgress = 0.0.obs;
  bool viewCounted = false;

  VideoInteractionsController({
    required this.video,
    required this.currentUser,
  }) {
    if (Get.isRegistered<ReelsController>()) {
      _reelsController = Get.find<ReelsController>();
    }
  }

  @override
  void onInit() {
    super.onInit();
    _initializeValues();
    _loadCachedInteractions();
  }

  @override
  void onReady() {
    super.onReady();
    // Refresh video data when controller is ready
    refreshVideoData();
  }

  void _initializeValues() {
    print('=== VIDEO INTERACTIONS INITIALIZATION DEBUG ===');
    print('Video ID: ${video.objectId}');
    print('Video author: ${video.getAuthor?.getFullName}');
    print('Current user: ${currentUser?.getFullName}');
    print('Current user ID: ${currentUser?.objectId}');

    // Ensure we have valid user ID for comparison
    String? currentUserId = currentUser?.objectId;

    print('Video likes list: ${video.getLikes}');
    print('Video saves list: ${video.getSaves}');
    print('Video comments list: ${video.getComments}');

    if (currentUserId != null) {
      isLiked.value = video.getLikes.contains(currentUserId);
      isSaved.value = video.getSaves.contains(currentUserId);
      print('User ID found, checking likes/saves...');
    } else {
      isLiked.value = false;
      isSaved.value = false;
      print('No user ID found, setting likes/saves to false');
    }

    // Verificar se o autor e o usuário atual são válidos antes de acessar following
    if (video.getAuthor != null &&
        currentUser != null &&
        currentUser!.getFollowing != null) {
      isFollowing.value =
          currentUser!.getFollowing!.contains(video.getAuthor!.objectId);
      print('Following status: ${isFollowing.value}');
    } else {
      isFollowing.value = false;
      print('Following status set to false (missing data)');
    }

    likesCount.value = video.getLikes.length;
    savesCount.value = video.getSaves.length;
    viewsCount.value = video.getViews;
    sharesCount.value = video.getShares.length;

    // Initialize comments count with direct query
    _updateCommentsCount();

    print('=== INITIALIZATION RESULTS ===');
    print("Likes count: ${likesCount.value}");
    print("Saves count: ${savesCount.value}");
    print("Comments count: ${commentsCount.value}");
    print("Views count: ${viewsCount.value}");
    print("Shares count: ${sharesCount.value}");
    print("User liked: ${isLiked.value}");
    print("User saved: ${isSaved.value}");
    print("User following: ${isFollowing.value}");

    // Force UI refresh for all counts
    likesCount.refresh();
    savesCount.refresh();
    commentsCount.refresh();
    viewsCount.refresh();
    sharesCount.refresh();

    print('=== END INITIALIZATION DEBUG ===');
  }

  void updateVideoProgress(Duration position, Duration duration) {
    if (duration.inSeconds > 0) {
      videoProgress.value = position.inSeconds / duration.inSeconds;

      if (videoProgress.value >= 0.6 && !viewCounted) {
        _countView();
      }
    }
  }

  Future<void> _countView() async {
    try {
      if (currentUser != null &&
          !video.getViewers!.contains(currentUser!.objectId)) {
        video.setViewer = currentUser!.objectId!;

        video.setViews = video.getViews + 1;

        await video.save();

        _updateVideoInReels();

        viewCounted = true;

        _recordViewInteraction();
      }
    } catch (e) {
      print('Error counting view: $e');
    }
  }

  void _recordViewInteraction() {
    if (Get.isRegistered<VideoRecommendationController>()) {
      final recommendationController =
          Get.find<VideoRecommendationController>();
      recommendationController.recordInteraction(
        video: video,
        user: currentUser!,
      );
    }
  }

  void resetViewProgress() {
    videoProgress.value = 0.0;
    viewCounted = false;
  }

  Future<void> sharePost(BuildContext context) async {
    String linkToShare = await DeepLinksService.createLink(
      branchObject: DeepLinksService.branchObject(
        shareAction: DeepLinksService.keyPostShare,
        objectID: video.objectId!,
        imageURL: QuickHelp.getImageToShare(video),
        title: QuickHelp.getTitleToShare(video),
        description: video.getAuthor!.getFullName,
      ),
      branchProperties: DeepLinksService.linkProperties(
        channel: "link",
      ),
      context: context,
    );
    if (linkToShare.isNotEmpty) {
      Share.share(
        tr("share_post",
            namedArgs: {"link": linkToShare, "app_name": Setup.appName}),
      );
      sharesCount.value += 1;
      video.setShares = currentUser!.objectId!;
      video.save();
      _updateVideoInReels();
    }
  }

  void _loadCachedInteractions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedLikes = prefs.getStringList('cached_likes') ?? [];
      final cachedSaves = prefs.getStringList('cached_saves') ?? [];

      if (cachedLikes.contains(video.objectId)) {
        isLiked.value = true;
      }

      if (cachedSaves.contains(video.objectId)) {
        isSaved.value = true;
      }
    } catch (e) {
      print('Error loading cached interactions: $e');
    }
  }

  Future<void> _updateInteractionCache(
      String key, String videoId, bool add) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(key) ?? [];

      if (add) {
        cached.add(videoId);
      } else {
        cached.remove(videoId);
      }

      await prefs.setStringList(key, cached);
    } catch (e) {
      print('Error updating interaction cache: $e');
    }
  }

  Future<void> toggleLike() async {
    print('=== LIKE TOGGLE DEBUG START ===');
    print('Video ID: ${video.objectId}');
    print('User ID: ${currentUser?.objectId}');
    print('Current like state: ${isLiked.value}');
    print('Current likes count: ${likesCount.value}');
    print('Current likes list: ${video.getLikes}');

    try {
      if (isLiked.value) {
        print('Removing like...');
        video.removeLike = currentUser!.objectId!;
        await _deleteLikeNotification();
        await _updateInteractionCache('cached_likes', video.objectId!, false);
        print('Like removed from video model');
      } else {
        print('Adding like...');
        video.setLikes = currentUser!.objectId!;
        video.setLastLikeAuthor = currentUser!;
        await _createLikeNotification();
        await _updateInteractionCache('cached_likes', video.objectId!, true);
        print('Like added to video model');
      }

      print('Saving video to Parse...');
      ParseResponse saveResponse = await video.save();

      print('Video save response:');
      print('- Success: ${saveResponse.success}');
      print('- Error code: ${saveResponse.error?.code}');
      print('- Error message: ${saveResponse.error?.message}');

      if (saveResponse.success) {
        print('Video saved successfully, updating UI...');

        // Update the like state first
        isLiked.value = !isLiked.value;

        // Force update the likes count from the video model
        likesCount.value = video.getLikes.length;

        print('Like state updated: ${isLiked.value}');
        print('Likes count updated: ${likesCount.value}');
        print('Video likes list: ${video.getLikes}');

        // Force UI refresh
        likesCount.refresh();

        // Update the video in reels
        _updateVideoInReels();

        // Registrar interação para recomendações com peso
        _recordLikeInteraction(weight: isLiked.value ? 1.0 : -0.5);

        // Atualizar recomendações em tempo real
        _updateRecommendations();

        print(
            'Like toggled successfully. New like state: ${isLiked.value}, New like count: ${likesCount.value}');
        print('Updated likes list: ${video.getLikes}');
      } else {
        print('Error saving like: ${saveResponse.error?.message}');
        // Revert the like state if save failed
        isLiked.value = !isLiked.value;
        print('Reverted like state due to save failure');
      }
    } catch (e, stackTrace) {
      print('Error toggling like: $e');
      print('Stack trace: $stackTrace');
      // Revert the like state if error occurred
      isLiked.value = !isLiked.value;
      print('Reverted like state due to error');
    }
    print('=== LIKE TOGGLE DEBUG END ===');
  }

  Future<void> toggleSave() async {
    try {
      if (isSaved.value) {
        video.removeSave = currentUser!.objectId!;
        await _updateInteractionCache('cached_saves', video.objectId!, false);
      } else {
        video.setSaves = currentUser!.objectId!;
        await _updateInteractionCache('cached_saves', video.objectId!, true);
      }

      ParseResponse saveResponse = await video.save();

      if (saveResponse.success) {
        // Update the save state first
        isSaved.value = !isSaved.value;

        // Force update the saves count from the video model
        savesCount.value = video.getSaves.length;

        print('Save state updated: ${isSaved.value}');
        print('Saves count updated: ${savesCount.value}');
        print('Video saves list: ${video.getSaves}');

        // Force UI refresh
        savesCount.refresh();

        // Update the video in reels
        _updateVideoInReels();

        // Registrar interação para recomendações com peso maior
        _recordSaveInteraction(weight: isSaved.value ? 2.0 : -1.0);

        // Atualizar recomendações em tempo real
        _updateRecommendations();

        print('Save toggled successfully. New save count: ${savesCount.value}');
      } else {
        print('Error saving save: ${saveResponse.error?.message}');
        // Revert the save state if save failed
        isSaved.value = !isSaved.value;
      }
    } catch (e) {
      print('Error toggling save: $e');
      // Revert the save state if error occurred
      isSaved.value = !isSaved.value;
    }
  }

  Future<void> toggleFollow() async {
    try {
      if (isFollowing.value) {
        currentUser!.removeFollowing = video.getAuthor!.objectId!;
      } else {
        currentUser!.setFollowing = video.getAuthor!.objectId!;
      }

      await currentUser!.save();

      ParseResponse parseResponse = await QuickCloudCode.followUser(
        author: currentUser!,
        receiver: video.getAuthor!,
      );

      if (parseResponse.success) {
        QuickActions.createOrDeleteNotification(
          currentUser!,
          video.getAuthor!,
          NotificationsModel.notificationTypeFollowers,
        );
      }

      isFollowing.value = !isFollowing.value;
    } catch (e) {
      print('Error toggling follow: $e');
    }
  }

  Future<void> _createLikeNotification() async {
    await QuickActions.createOrDeleteNotification(
      currentUser!,
      video.getAuthor!,
      NotificationsModel.notificationTypeLikedReels,
      post: video,
    );
  }

  Future<void> _deleteLikeNotification() async {
    QueryBuilder<NotificationsModel> queryBuilder =
        QueryBuilder<NotificationsModel>(NotificationsModel())
          ..whereEqualTo(NotificationsModel.keyAuthor, currentUser)
          ..whereEqualTo(NotificationsModel.keyPost, video);

    ParseResponse parseResponse = await queryBuilder.query();
    if (parseResponse.success && parseResponse.results != null) {
      NotificationsModel notification = parseResponse.results!.first;
      await notification.delete();
    }
  }

  void _updateVideoInReels() {
    // Usar o PostsService para atualizar o vídeo
    _postsService.updatePost(video);

    // Manter a chamada ao ReelsController para compatibilidade
    if (Get.isRegistered<ReelsController>()) {
      _reelsController.updateVideo(video);
    }

    // Forçar atualização das variáveis reativas
    likesCount.refresh();
    savesCount.refresh();
    commentsCount.refresh();
    viewsCount.refresh();
    sharesCount.refresh();
  }

  // Method to refresh video data from server
  Future<void> refreshVideoData() async {
    try {
      print('=== REFRESHING VIDEO DATA FROM SERVER ===');
      print('Video ID: ${video.objectId}');
      print(
          'Before refresh - Likes: ${likesCount.value}, Comments: ${commentsCount.value}, Saves: ${savesCount.value}');

      await video.fetch();

      // Update all counts with fresh data
      likesCount.value = video.getLikes.length;
      savesCount.value = video.getSaves.length;
      viewsCount.value = video.getViews;
      sharesCount.value = video.getShares.length;

      // Query comments directly from Comments table
      await _updateCommentsCount();

      print(
          'After refresh - Likes: ${likesCount.value}, Comments: ${commentsCount.value}, Saves: ${savesCount.value}');
      print('Video likes list: ${video.getLikes}');
      print('Video saves list: ${video.getSaves}');

      // Force UI refresh for all counts
      likesCount.refresh();
      savesCount.refresh();
      commentsCount.refresh();
      viewsCount.refresh();
      sharesCount.refresh();

      // Update the video in reels
      _updateVideoInReels();

      print('=== VIDEO DATA REFRESH COMPLETE ===');
    } catch (e) {
      print('Error refreshing video data: $e');
    }
  }

  // Method to query comments count directly from Comments table
  Future<void> _updateCommentsCount() async {
    try {
      QueryBuilder<CommentsModel> queryBuilder =
          QueryBuilder<CommentsModel>(CommentsModel());
      queryBuilder.whereEqualTo(CommentsModel.keyPostId, video.objectId);

      ParseResponse response = await queryBuilder.query();

      if (response.success && response.results != null) {
        commentsCount.value = response.results!.length;
        print('Comments count updated from query: ${commentsCount.value}');
      } else {
        print('Failed to query comments: ${response.error?.message}');
        commentsCount.value = 0;
      }
    } catch (e) {
      print('Error querying comments: $e');
      commentsCount.value = 0;
    }
  }

  void _recordLikeInteraction({double weight = 1.0}) {
    if (Get.isRegistered<VideoRecommendationController>()) {
      final recommendationController =
          Get.find<VideoRecommendationController>();
      recommendationController.recordInteraction(
        video: video,
        user: currentUser!,
        liked: isLiked.value,
      );
    }
  }

  Future<void> downloadVideo(BuildContext context) async {
    try {
      // Verificar permissão de armazenamento
      if (QuickHelp.isAndroidPlatform()) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        int sdkInt = androidInfo.version.sdkInt;

        if (sdkInt >= 33) {
          if (!await Permission.photos.isGranted) {
            final status = await Permission.photos.request();
            if (!status.isGranted) {
              QuickHelp.showAppNotificationAdvanced(
                context: context,
                title: tr("permissions.photo_access_denied"),
                message: tr("permissions.photo_access_denied_explain"),
              );
              return;
            }
          }
        } else {
          if (!await Permission.storage.isGranted) {
            final status = await Permission.storage.request();
            if (!status.isGranted) {
              QuickHelp.showAppNotificationAdvanced(
                context: context,
                title: tr("permissions.storage_access_denied"),
                message: tr("permissions.storage_access_denied_explain"),
              );
              return;
            }
          }
        }
      }

      // Mostrar progresso
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: tr("download_video.downloading"),
        message: "15%",
        isError: false,
      );

      // Obter URL do vídeo
      String videoUrl = video.getVideo!.url!;

      // Salvar vídeo na galeria
      final success = await GallerySaver.saveVideo(videoUrl);

      if (success == true) {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("download_video.success_title"),
          message: tr("download_video.success_message"),
          isError: false,
        );
        savesCount.value += 1;
        video.setSaves = currentUser!.objectId!;
        video.save();
        _updateVideoInReels();
      } else {
        throw Exception(tr("download_video.failed"));
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: tr("error"),
        message: tr("download_video.error_message"),
      );
    }
  }

  void _recordSaveInteraction({double weight = 1.0}) {
    if (Get.isRegistered<VideoRecommendationController>()) {
      final recommendationController =
          Get.find<VideoRecommendationController>();
      recommendationController.recordInteraction(
        video: video,
        user: currentUser!,
        saved: isSaved.value,
      );
    }
  }

  void showComments(BuildContext context) {
    QuickHelp.goToNavigatorScreen(
      context,
      VideoReelsCommentScreen(
        currentUser: currentUser,
        post: video,
      ),
    );

    // Registrar interação para recomendações
    if (Get.isRegistered<VideoRecommendationController>()) {
      final recommendationController =
          Get.find<VideoRecommendationController>();
      recommendationController.recordInteraction(
        video: video,
        user: currentUser!,
        commented: true,
      );
    }
  }

  // Método para atualizar contagem de comentários quando um novo comentário é criado
  void updateCommentCount() {
    print('=== COMMENT COUNT UPDATE DEBUG ===');
    print('Video ID: ${video.objectId}');
    print('Current comments count: ${commentsCount.value}');

    // Update comments count with direct query
    _updateCommentsCount();

    print('Comments count updated: ${commentsCount.value}');

    // Force UI refresh
    commentsCount.refresh();

    // Update the video in reels
    _updateVideoInReels();

    print('=== COMMENT COUNT UPDATE DEBUG END ===');
  }

  void goToProfile(BuildContext context) {
    if (video.getAuthor!.objectId == currentUser!.objectId!) {
      // If it's the current user's own profile, navigate to their profile screen
      QuickHelp.goToNavigatorScreen(
        context,
        UserProfileScreen(
          currentUser: currentUser,
          mUser: currentUser,
          isFollowing: false, // User is following themselves
        ),
      );
    } else {
      // If it's another user's profile, navigate to their profile screen
      QuickHelp.goToNavigatorScreen(
        context,
        UserProfileScreen(
          currentUser: currentUser,
          mUser: video.getAuthor,
          isFollowing:
              currentUser!.getFollowing!.contains(video.getAuthor!.objectId),
        ),
      );
    }
  }

  void openOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (_) => _buildOptionsSheet(context),
    );
  }

  Widget _buildOptionsSheet(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25.0),
          topRight: Radius.circular(25.0),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentUser!.objectId != video.getAuthorId) ...[
              ListTile(
                leading:
                    Icon(Icons.report_problem_outlined, color: Colors.white),
                title: Text(
                  tr("feed.report_post",
                      namedArgs: {"name": video.getAuthor!.getFullName!}),
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => _showReportDialog(context),
              ),
              ListTile(
                leading: Icon(Icons.block, color: Colors.white),
                title: Text(
                  tr("feed.block_user",
                      namedArgs: {"name": video.getAuthor!.getFullName!}),
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => _showBlockDialog(context),
              ),
            ],
            if (currentUser!.objectId == video.getAuthorId ||
                currentUser!.isAdmin!) ...[
              ListTile(
                leading: Icon(Icons.delete, color: Colors.white),
                title: Text(
                  tr("feed.delete_post"),
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => _showDeleteDialog(context),
              ),
            ],
            if (currentUser!.isAdmin!) ...[
              ListTile(
                leading: Icon(Icons.person_off, color: Colors.white),
                title: Text(
                  tr("feed.suspend_user"),
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => _showSuspendDialog(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    Navigator.pop(context);
    QuickHelp.showDialogWithButtonCustom(
      context: context,
      title: tr("feed.report_post_title"),
      message: tr("feed.report_post_message"),
      cancelButtonText: tr("cancel"),
      confirmButtonText: tr("feed.report_confirm"),
      onPressed: () => _reportPost(context),
    );
  }

  void _showBlockDialog(BuildContext context) {
    Navigator.pop(context);
    QuickHelp.showDialogWithButtonCustom(
      context: context,
      title: tr("feed.block_user_title"),
      message: tr("feed.block_user_message",
          namedArgs: {"name": video.getAuthor!.getFullName!}),
      cancelButtonText: tr("cancel"),
      confirmButtonText: tr("feed.block_confirm"),
      onPressed: () => _blockUser(context),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    Navigator.pop(context);
    QuickHelp.showDialogWithButtonCustom(
      context: context,
      title: tr("feed.delete_post_alert"),
      message: tr("feed.delete_post_message"),
      cancelButtonText: tr("no"),
      confirmButtonText: tr("feed.yes_delete"),
      onPressed: () => _deletePost(context),
    );
  }

  void _showSuspendDialog(BuildContext context) {
    Navigator.pop(context);
    QuickHelp.showDialogWithButtonCustom(
      context: context,
      title: tr("feed.suspend_user_alert"),
      message: tr("feed.suspend_user_message"),
      cancelButtonText: tr("no"),
      confirmButtonText: tr("feed.yes_suspend"),
      onPressed: () => _suspendUser(context),
    );
  }

  Future<void> _reportPost(BuildContext context) async {
    Navigator.pop(context);
    QuickHelp.showLoadingDialog(context);

    try {
      ParseResponse parseResponse = await QuickActions.report(
        type: ReportModel.reportTypePost,
        message: "Reported post",
        accuser: currentUser!,
        accused: video.getAuthor!,
        postsModel: video,
      );

      QuickHelp.hideLoadingDialog(context);

      if (parseResponse.success) {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("feed.post_report_success_title"),
          message: tr("feed.post_report_success_message"),
          isError: false,
        );
      } else {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("error"),
          message: tr("try_again_later"),
        );
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      print('Error reporting post: $e');
    }
  }

  Future<void> _blockUser(BuildContext context) async {
    Navigator.pop(context);
    QuickHelp.showLoadingDialog(context);

    try {
      currentUser!.setBlockedUser = video.getAuthor!;
      currentUser!.setBlockedUserIds = video.getAuthor!.objectId!;

      ParseResponse response = await currentUser!.save();
      QuickHelp.hideLoadingDialog(context);

      if (response.success) {
        // Remover posts do usuário bloqueado
        _postsService.allPosts.removeWhere(
            (post) => post.getAuthorId == video.getAuthor!.objectId);
        _postsService.videoPosts.removeWhere(
            (video) => video.getAuthorId == video.getAuthor!.objectId);

        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("feed.block_success_title"),
          message: tr("feed.block_success_message"),
          isError: false,
        );
      } else {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("error"),
          message: tr("try_again_later"),
        );
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      print('Error blocking user: $e');
    }
  }

  Future<void> _deletePost(BuildContext context) async {
    Navigator.pop(context);
    QuickHelp.showLoadingDialog(context);

    try {
      ParseResponse parseResponse = await video.delete();
      QuickHelp.hideLoadingDialog(context);

      if (parseResponse.success) {
        // Remover o vídeo do PostsService
        _postsService.removePost(video.objectId!);

        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("deleted"),
          message: tr("feed.post_deleted"),
          user: video.getAuthor,
          isError: null,
        );
      } else {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("error"),
          message: tr("feed.post_not_deleted"),
          user: video.getAuthor,
          isError: true,
        );
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      print('Error deleting post: $e');
    }
  }

  Future<void> _suspendUser(BuildContext context) async {
    Navigator.pop(context);
    QuickHelp.showLoadingDialog(context);

    try {
      video.getAuthor!.setActivationStatus = true;
      ParseResponse parseResponse = await QuickCloudCode.suspendUSer(
        objectId: video.getAuthor!.objectId!,
      );

      QuickHelp.hideLoadingDialog(context);

      if (parseResponse.success) {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("suspended"),
          message: tr("feed.user_suspended"),
          user: video.getAuthor,
          isError: null,
        );
      } else {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("error"),
          message: tr("feed.user_not_suspended"),
          user: video.getAuthor,
          isError: true,
        );
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      print('Error suspending user: $e');
    }
  }

  Future<void> _updateRecommendations() async {
    if (Get.isRegistered<ReelsController>()) {
      // Atualizar feed com vídeos recomendados
      await _reelsController.updateRecommendedVideos();
    }
  }
}

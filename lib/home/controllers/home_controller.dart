import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:trace/models/MessageModel.dart';
import 'package:trace/models/NotificationsModel.dart';
import 'package:trace/models/OfficialAnnouncementModel.dart';
import 'package:trace/models/UserModel.dart';

import '../a_shorts/shorts_cached_controller.dart';

class HomeController extends GetxController {
  final UserModel? currentUser;
  late final PageController pageController;
  ShortsCachedController? _reelsController; // Made nullable and private
  String? _reelsControllerTag; // Store tag for cleanup

  RxInt selectedIndex = 2.obs;
  RxInt unreadMessageCount = 0.obs;
  RxBool isAdLoaded = false.obs;

  final officialAnnouncements = <String>[].obs;
  LiveQuery liveQuery = LiveQuery();
  Subscription? subscription;

  late QueryBuilder<NotificationsModel> notificationQueryBuilder;
  late QueryBuilder<MessageModel> messageQueryBuilder;
  late QueryBuilder<OfficialAnnouncementModel> officialAssistantQueryBuilder;

  final int initialTabIndex;
  bool _isDisposed = false;

  HomeController({
    required this.currentUser,
    required this.initialTabIndex,
  }) {
    // FIX: Initialize PageController safely to prevent multiple attachments
    if (!_isDisposed) {
      pageController = PageController(
        initialPage: initialTabIndex,
        keepPage: false, // Don't keep page state to prevent conflicts
      );
      selectedIndex.value = initialTabIndex;

      // FIX: Don't create reels controller immediately - lazy load only when needed
      // This improves login performance significantly
    }
  }

  // FIX: Lazy getter for reels controller - only create when actually needed
  ShortsCachedController get reelsController {
    if (_reelsController == null && !_isDisposed) {
      print('HomeController: Lazy loading reels controller...');
      _reelsControllerTag = 'reels_${DateTime.now().millisecondsSinceEpoch}';
      _reelsController =
          Get.put(ShortsCachedController(), tag: _reelsControllerTag!);
      print('HomeController: Reels controller loaded successfully');
    }
    return _reelsController!;
  }

  @override
  void onInit() {
    super.onInit();
    loadInitialData();
  }

  @override
  void onClose() {
    // FIX: Proper disposal to prevent PageController conflicts
    _isDisposed = true;

    try {
      if (pageController.hasClients) {
        pageController.dispose();
      }
    } catch (e) {
      print('HomeController: Error disposing PageController: $e');
    }

    try {
      if (subscription != null) {
        liveQuery.client.unSubscribe(subscription!);
        subscription = null;
      }
    } catch (e) {
      print('HomeController: Error disposing subscription: $e');
    }

    try {
      // Clean up lazy-loaded reels controller if it was created
      if (_reelsController != null && _reelsControllerTag != null) {
        if (Get.isRegistered<ShortsCachedController>(
            tag: _reelsControllerTag)) {
          Get.delete<ShortsCachedController>(
              tag: _reelsControllerTag, force: true);
        }
        _reelsController = null;
        _reelsControllerTag = null;
        print('HomeController: Lazy-loaded reels controller disposed');
      }
    } catch (e) {
      print('HomeController: Error disposing reels controller: $e');
    }

    super.onClose();
    print('HomeController: Properly disposed');
  }

  void loadInitialData() {
    loadUnreadCounts();
    checkUser();
  }

  Future<void> loadUnreadCounts() async {
    await getUnreadNotification();
    await getUnreadMessage();
    await getUnreadOfficial();
  }

  Future<void> getUnreadNotification() async {
    notificationQueryBuilder =
        QueryBuilder<NotificationsModel>(NotificationsModel())
          ..whereEqualTo(NotificationsModel.keyReceiver, currentUser)
          ..whereEqualTo(NotificationsModel.keyRead, false)
          ..whereNotEqualTo(NotificationsModel.keyAuthor, currentUser);

    setupNotificationLiveQuery();

    final ParseResponse response = await notificationQueryBuilder.query();
    if (response.success && response.count > 0) {
      unreadMessageCount += response.count;
    }
  }

  Future<void> getUnreadMessage() async {
    messageQueryBuilder = QueryBuilder<MessageModel>(MessageModel())
      ..whereEqualTo(MessageModel.keyReceiver, currentUser)
      ..whereEqualTo(MessageModel.keyRead, false)
      ..whereNotEqualTo(NotificationsModel.keyAuthor, currentUser);

    setupMessageLiveQuery();

    final ParseResponse response = await messageQueryBuilder.query();
    if (response.success && response.count > 0) {
      unreadMessageCount += response.count;
    }
  }

  Future<void> getUnreadOfficial() async {
    officialAssistantQueryBuilder =
        QueryBuilder<OfficialAnnouncementModel>(OfficialAnnouncementModel())
          ..whereNotEqualTo(NotificationsModel.keyAuthor, currentUser);

    setupOfficialLiveQuery();

    final ParseResponse response = await officialAssistantQueryBuilder.query();
    if (response.success && response.results != null) {
      for (OfficialAnnouncementModel announcement in response.results!) {
        if (!announcement.getViewedBy!.contains(currentUser!.objectId!)) {
          officialAnnouncements.add(announcement.objectId!);
        }
      }
      unreadMessageCount += officialAnnouncements.length;
    }
  }

  void setupNotificationLiveQuery() async {
    subscription = await liveQuery.client.subscribe(notificationQueryBuilder);

    subscription!.on(LiveQueryEvent.create, (NotificationsModel notification) {
      if (notification.getReceiver!.objectId == currentUser!.objectId) {
        unreadMessageCount++;
      }
    });

    subscription!.on(LiveQueryEvent.update, (NotificationsModel notification) {
      if (notification.getReceiver!.objectId == currentUser!.objectId &&
          notification.isRead!) {
        if (unreadMessageCount > 0) unreadMessageCount--;
      }
    });
  }

  void setupMessageLiveQuery() async {
    subscription = await liveQuery.client.subscribe(messageQueryBuilder);

    subscription!.on(LiveQueryEvent.create, (MessageModel message) {
      if (message.getReceiver!.objectId == currentUser!.objectId) {
        unreadMessageCount++;
      }
    });

    subscription!.on(LiveQueryEvent.update, (MessageModel message) {
      if (message.getReceiver!.objectId == currentUser!.objectId &&
          message.isRead!) {
        if (unreadMessageCount > 0) unreadMessageCount--;
      }
    });
  }

  void setupOfficialLiveQuery() async {
    subscription =
        await liveQuery.client.subscribe(officialAssistantQueryBuilder);

    subscription!.on(LiveQueryEvent.create,
        (OfficialAnnouncementModel announcement) {
      if (!announcement.getViewedBy!.contains(currentUser!.objectId!)) {
        officialAnnouncements.add(announcement.objectId!);
        unreadMessageCount++;
      }
    });

    subscription!.on(LiveQueryEvent.update,
        (OfficialAnnouncementModel announcement) {
      if (announcement.getViewedBy!.contains(currentUser!.objectId!)) {
        officialAnnouncements.remove(announcement.objectId);
        if (unreadMessageCount > 0) unreadMessageCount--;
      }
    });
  }

  void checkUser() async {
    if (currentUser != null) {
      try {
        await currentUser!.fetch();
        if (!currentUser!.getActivationStatus!) {
          print('User needs to activate account');
        }
      } catch (e) {
        print('Error fetching user: $e');
      }
    }
  }

  void onTabChanged(int index) {
    // FIX: Safety checks to prevent PageController conflicts
    if (_isDisposed || selectedIndex.value == index) return;

    try {
      // FIX: Handle leaving reels tab - pause videos
      if (selectedIndex.value == 0 && _reelsController != null) {
        _reelsController!.pauseAllVideos();
      }

      selectedIndex.value = index;

      // FIX: Handle entering reels tab - lazy load controller if needed
      if (index == 0) {
        // Access reelsController getter to trigger lazy loading if needed
        print(
            'HomeController: Switching to reels tab, ensuring controller is ready...');
        final controller = reelsController; // This will lazy load if needed

        // Resume playback if needed
        try {
          controller.playCurrentVideo();
        } catch (e) {
          print('HomeController: Error resuming video playback: $e');
        }
      }

      // FIX: Only jump to page if PageController is still valid
      if (pageController.hasClients && !_isDisposed) {
        pageController.jumpToPage(index);
      }
    } catch (e) {
      print('HomeController: Error changing tab: $e');
      // Just update selected index as fallback
      selectedIndex.value = index;
    }
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (selectedIndex.value == 0 && _reelsController != null) {
        try {
          _reelsController!.playCurrentVideo();
        } catch (e) {
          print("HomeController: Error resuming video: $e");
        }
      }
    } else if (state == AppLifecycleState.paused) {
      if (selectedIndex.value == 0 && _reelsController != null) {
        try {
          _reelsController!.pauseAllVideos();
        } catch (e) {
          print("HomeController: Error pausing videos: $e");
        }
      }
    }
  }
}

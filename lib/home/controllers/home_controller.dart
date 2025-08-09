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
  final PageController pageController;
  late final ShortsCachedController reelsController;

  RxInt selectedIndex = 2.obs;
  RxInt unreadMessageCount = 0.obs;
  RxBool isAdLoaded = false.obs;

  final officialAnnouncements = <String>[].obs;
  LiveQuery liveQuery = LiveQuery();
  Subscription? subscription;

  late QueryBuilder<NotificationsModel> notificationQueryBuilder;
  late QueryBuilder<MessageModel> messageQueryBuilder;
  late QueryBuilder<OfficialAnnouncementModel> officialAssistantQueryBuilder;

  HomeController({
    required this.currentUser,
    required int initialTabIndex,
  }) : pageController = PageController(initialPage: initialTabIndex) {
    selectedIndex.value = initialTabIndex;
    reelsController = Get.put(ShortsCachedController());
  }

  @override
  void onInit() {
    super.onInit();
    loadInitialData();
  }

  @override
  void onClose() {
    pageController.dispose();
    if (subscription != null) {
      liveQuery.client.unSubscribe(subscription!);
    }
    super.onClose();
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
    if (selectedIndex.value == index) return;

    if (selectedIndex.value == 0) {
      reelsController.pauseAllVideos();
    }

    selectedIndex.value = index;
    pageController.jumpToPage(index);
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (selectedIndex.value == 0) {
        try {
          reelsController.playCurrentVideo();
        } catch (e) {
          print("Erro ao reproduzir vídeo: $e");
        }
      }
    } else if (state == AppLifecycleState.paused) {
      if (selectedIndex.value == 0) {
        reelsController.pauseAllVideos();
      }
    }
  }
}

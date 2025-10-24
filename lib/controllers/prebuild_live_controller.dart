import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

import '../helpers/quick_actions.dart';
import '../models/GiftsModel.dart';
import '../models/GiftsSentModel.dart';
import '../models/LiveStreamingModel.dart';
import '../models/NotificationsModel.dart';
import '../models/UserModel.dart';
import '../helpers/quick_help.dart';
import '../helpers/quick_cloud.dart';

class PreBuildLiveController extends GetxController {
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final Rx<LiveStreamingModel?> liveStreaming = Rx<LiveStreamingModel?>(null);
  final RxBool isHost = false.obs;
  final RxString liveID = ''.obs;
  final RxString localUserID = ''.obs;

  // Estado da UI
  final RxBool following = false.obs;
  final RxInt tabIndex = 0.obs;
  final RxInt pagesIndex = 0.obs;
  final RxBool isSearching = false.obs;
  final RxBool imLiveInviter = false.obs;
  final RxString searchText = ''.obs;
  final RxString keyUpdate = ''.obs;

  // Estado da batalha
  final RxInt myBattlePoint = 0.obs;
  final RxInt hisBattlePoint = 0.obs;
  final RxInt repeatPkTimes = 0.obs;

  // Listas e dados
  final RxList<String> coHostsList = <String>[].obs;
  final RxList<String> invitedUsers = <String>[].obs;
  final RxList<GiftsModel> receivedGiftList = <GiftsModel>[].obs;

  // Notificadores
  final requestingHostsMapRequestIDNotifier =
      ValueNotifier<Map<String, List<String>>>({});
  final requestIDNotifier = ValueNotifier<String>('');
  final liveStateNotifier =
      ValueNotifier<ZegoLiveStreamingState>(ZegoLiveStreamingState.idle);

  @override
  void onInit() {
    super.onInit();
    setupStreamingLiveQuery();
    setupLiveGifts();
  }

  void initialize({
    required UserModel user,
    required LiveStreamingModel live,
    required String liveId,
    required String localId,
    bool isHostUser = false,
  }) {
    currentUser.value = user;
    liveStreaming.value = live;
    liveID.value = liveId;
    localUserID.value = localId;
    isHost.value = isHostUser;

    following.value = user.getFollowing!.contains(live.getAuthorId);
  }

  Future<void> setupStreamingLiveQuery() async {
    if (liveStreaming.value == null) return;

    QueryBuilder<LiveStreamingModel> query =
        QueryBuilder<LiveStreamingModel>(LiveStreamingModel());
    query.whereEqualTo(
        LiveStreamingModel.keyObjectId, liveStreaming.value!.objectId);
    query.includeObject([
      LiveStreamingModel.keyPrivateLiveGift,
      LiveStreamingModel.keyGiftSenders,
      LiveStreamingModel.keyGiftSendersAuthor,
      LiveStreamingModel.keyAuthor,
      LiveStreamingModel.keyInvitedPartyLive,
      LiveStreamingModel.keyInvitedPartyLiveAuthor,
    ]);

    final subscription = await LiveQuery().client.subscribe(query);

    subscription.on(LiveQueryEvent.update,
        (LiveStreamingModel newUpdatedLive) async {
      await newUpdatedLive.getAuthor!.fetch();
      liveStreaming.value = newUpdatedLive;

      if (newUpdatedLive.getRepeatBattleTimes! > 0 &&
          newUpdatedLive.getRepeatBattleTimes! > repeatPkTimes.value) {
        repeatPkTimes.value = newUpdatedLive.getRepeatBattleTimes!;
        initiateBattleTimer(durationMinutes: 5);
      }
    });
  }

  Future<void> setupLiveGifts() async {
    if (liveStreaming.value == null) return;

    QueryBuilder<GiftsSentModel> queryBuilder =
        QueryBuilder<GiftsSentModel>(GiftsSentModel());
    queryBuilder.whereEqualTo(
        GiftsSentModel.keyLiveId, liveStreaming.value!.objectId);
    queryBuilder.includeObject([GiftsSentModel.keyGift]);

    final subscription = await LiveQuery().client.subscribe(queryBuilder);

    subscription.on(LiveQueryEvent.create, (GiftsSentModel giftSent) async {
      await giftSent.getGift!.fetch();
      await giftSent.getReceiver!.fetch();
      await giftSent.getAuthor!.fetch();

      receivedGiftList.add(giftSent.getGift!);
    });
  }

  Future<void> followOrUnfollow() async {
    if (currentUser.value == null || liveStreaming.value == null) return;

    if (following.value) {
      currentUser.value!.removeFollowing = liveStreaming.value!.getAuthorId!;
      liveStreaming.value!.removeFollower = currentUser.value!.objectId!;
      following.value = false;
    } else {
      currentUser.value!.setFollowing = liveStreaming.value!.getAuthorId!;
      liveStreaming.value!.addFollower = currentUser.value!.objectId!;
      following.value = true;
    }

    await currentUser.value!.save();
    await liveStreaming.value!.save();

    final response = await QuickCloudCode.followUser(
      author: currentUser.value!,
      receiver: liveStreaming.value!.getAuthor!,
    );

    if (response.success) {
      // Enviar mensagem de follow
      QuickActions.createOrDeleteNotification(
        currentUser.value!,
        liveStreaming.value!.getAuthor!,
        NotificationsModel.notificationTypeFollowers,
      );
    }
  }

  void initiateBattleTimer({int durationMinutes = 5}) {
    // Implementar lógica do timer de batalha
    print(
        "⏰ [PK BATTLE] Controller initiating battle timer with duration: $durationMinutes minutes");
  }

  Future<void> sendGift(GiftsModel gift, UserModel receiver) async {
    if (currentUser.value == null || liveStreaming.value == null) return;

    final giftsSentModel = GiftsSentModel()
      ..setAuthor = currentUser.value!
      ..setAuthorId = currentUser.value!.objectId!
      ..setReceiver = receiver
      ..setReceiverId = receiver.objectId!
      ..setLiveId = liveStreaming.value!.objectId!
      ..setGift = gift
      ..setGiftId = gift.objectId!
      ..setCounterDiamondsQuantity = gift.getCoins!;

    await giftsSentModel.save();

    await QuickHelp.saveReceivedGifts(
      receiver: receiver,
      author: currentUser.value!,
      gift: gift,
    );

    await QuickHelp.saveCoinTransaction(
      receiver: receiver,
      author: currentUser.value!,
      amountTransacted: gift.getCoins!,
    );
  }

  @override
  void onClose() {
    // Limpar recursos e cancelar subscriptions
    super.onClose();
  }
}

// ignore_for_file: unused_element

part of 'gift_controller.dart';

mixin GiftService {
  final _giftServiceImpl = GiftServiceImpl();
  GiftServiceImpl get service => _giftServiceImpl;
}

class GiftServiceImpl {
  late int _appID;
  late String _localUserID;
  late String _localUserName;

  final List<StreamSubscription<dynamic>?> _subscriptions = [];

  final recvNotifier = ValueNotifier<ZegoGiftCommand?>(null);

  void init(
      {required int appID,
      required String localUserID,
      required String localUserName}) {
    _appID = appID;
    _localUserID = localUserID;
    _localUserName = localUserName;

    _subscriptions.add(ZEGOSDKManager()
        .zimService
        .onRoomCommandReceivedEventStreamCtrl
        .stream
        .listen((event) {
      onInRoomCommandMessageReceived(event);
    }));
  }

  void uninit() {
    for (final subscription in _subscriptions) {
      subscription?.cancel();
    }
    ZegoGiftController().destroyMediaPlayer();
  }

  Future<bool> sendGift({
    required String receiverId,
    required GiftsModel gift,
    int count = 1,
  }) async {
    try {
      // 1) Play Zego animation and notify with enriched protocol
      final item = queryGiftInItemList(gift.getName ?? '');
      final data = ZegoGiftCommand(
        appID: _appID,
        liveID: ZEGOSDKManager().expressService.currentRoomID,
        localUserID: _localUserID,
        localUserName: _localUserName,
        giftName: gift.getName ?? "Unknown",
        giftSourceURL: item?.sourceURL ?? 'assets/gift/${gift.getName}.mp4',
        giftType: item?.type.name ?? 'mp4',
        count: count,
      ).toJson();

      debugPrint("🎁 Sending gift animation: ${gift.getName}");
      ZEGOSDKManager().zimService.sendRoomCommand(data);

      // 2) Call Parse Cloud Function to handle billing (server side)
      final sendGiftFunction = ParseCloudFunction('send_gift');
      final response = await sendGiftFunction.execute(parameters: {
        "senderId": _localUserID,
        "receiverId": receiverId,
        "giftId": gift.objectId,
        "credits": gift.getCoins,
        "giftName": gift.getName,
        "count": count,
      });

      // response handling: ParseCloudFunction returns a ParseResponse-like object
      if (response.success == true) {
        debugPrint("✅ Parse confirmed gift sent: ${gift.getName}");
        // Update LeadersModel for the sender (gift giver ranking)
        try {
          final leadersQuery = QueryBuilder<LeadersModel>(LeadersModel());
          leadersQuery.whereEqualTo(LeadersModel.keyAuthorId, _localUserID);
          final leadersResp = await leadersQuery.query();

          // Total spent = gift price * count
          final int coinsSpent = ((gift.getCoins ?? 0) * count);

          if (leadersResp.success && leadersResp.results != null) {
            final LeadersModel leaders =
                leadersResp.results!.first as LeadersModel;
            // rank by total coins spent in this operation
            leaders.incrementDiamondsQuantity = coinsSpent;
            await leaders.save();
          } else {
            // Create new leaders entry for this sender
            final userQuery = QueryBuilder<UserModel>(UserModel.forQuery());
            userQuery.whereEqualTo(UserModel.keyUid, _localUserID);
            final userResp = await userQuery.query();

            final LeadersModel leaders = LeadersModel();
            if (userResp.success && userResp.results != null) {
              final user = userResp.results!.first as UserModel;
              leaders.setAuthor = user;
            }
            leaders.setAuthorId = _localUserID;
            leaders.setCounterDiamondsQuantity = coinsSpent;
            await leaders.save();
          }
        } catch (e) {
          debugPrint('⚠️ Failed to update LeadersModel: $e');
        }
        return true;
      } else {
        debugPrint("⚠️ Parse gift send failed: ${response.result ?? response}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ Error sending gift: $e");
      return false;
    }
  }

  Uint8List _stringToUint8List(String input) {
    final List<int> utf8Bytes = utf8.encode(input);
    final uint8List = Uint8List.fromList(utf8Bytes);
    return uint8List;
  }

  void onInRoomCommandMessageReceived(OnRoomCommandReceivedEvent event) {
    debugPrint('onInRoomCommandMessageReceived: ${event.command}');
    final message = event.command;
    final senderUserID = event.senderID;
    // You can display different animations according to gift-type
    if (senderUserID != _localUserID) {
      final gift = ZegoGiftCommand.fromJson(message);
      recvNotifier.value = gift;
    }
  }
}

class ZegoGiftCommand {
  int appID = 0;
  String liveID = '';
  String localUserID = '';
  String localUserName = '';
  String giftName;
  String giftSourceURL;
  String giftType;
  int count;

  ZegoGiftCommand({
    required this.appID,
    required this.liveID,
    required this.localUserID,
    required this.localUserName,
    required this.giftName,
    required this.giftSourceURL,
    required this.giftType,
    required this.count,
  });

  String toJson() => json.encode({
        'app_id': appID,
        'room_id': liveID,
        'user_id': localUserID,
        'user_name': localUserName,
        'gift_name': giftName,
        'gift_source_url': giftSourceURL,
        'gift_type': giftType,
        'count': count,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

  factory ZegoGiftCommand.fromJson(String jsonData) {
    var json = <String, dynamic>{};
    try {
      json = jsonDecode(jsonData) as Map<String, dynamic>? ?? {};
    } catch (e) {
      debugPrint('protocol data is not json:$jsonData');
    }
    return ZegoGiftCommand(
      appID: json['app_id'] ?? 0,
      liveID: json['room_id'] ?? '',
      localUserID: json['user_id'] ?? '',
      localUserName: json['user_name'] ?? '',
      giftName: json['gift_name'] ?? '',
      giftSourceURL: json['gift_source_url'] ?? '',
      giftType: json['gift_type'] ?? 'mp4',
      count: json['count'] ?? 1,
    );
  }
}

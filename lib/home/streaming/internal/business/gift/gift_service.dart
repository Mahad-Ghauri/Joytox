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
      // 1) Play Zego animation (same as before)
      final data = ZegoGiftCommand(
        appID: _appID,
        liveID: ZEGOSDKManager().expressService.currentRoomID,
        localUserID: _localUserID,
        localUserName: _localUserName,
        giftName: gift.getName ?? "Unknown",
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
      if (response?.success == true) {
        debugPrint("✅ Parse confirmed gift sent: ${gift.getName}");
        return true;
      } else {
        debugPrint(
            "⚠️ Parse gift send failed: ${response?.result ?? response}");
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

  ZegoGiftCommand({
    required this.appID,
    required this.liveID,
    required this.localUserID,
    required this.localUserName,
    required this.giftName,
  });

  String toJson() => json.encode({
        'app_id': appID,
        'room_id': liveID,
        'user_id': localUserID,
        'user_name': localUserName,
        'gift_name': giftName,
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
    );
  }
}

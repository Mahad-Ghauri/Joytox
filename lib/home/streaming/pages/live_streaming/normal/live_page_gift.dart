part of 'live_page.dart';

extension ZegoLivePageStateGiftExtension on ZegoNormalLivePageState {
  void initGift() {
    ZegoGiftController().service.recvNotifier.addListener(onGiftReceived);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      ZegoGiftController().service.init(
            appID: Setup.zegoLiveStreamAppID,
            localUserID: ZEGOSDKManager().currentUser!.userID,
            localUserName: 'user_${ZEGOSDKManager().currentUser!.userID}',
          );
    });
  }

  void uninitGift() {
    ZegoGiftController().clearPlayingList();
    ZegoGiftController().service.recvNotifier.removeListener(onGiftReceived);
    ZegoGiftController().service.uninit();
  }

  Widget giftForeground() {
    return ZegoGiftController().giftWidget;
  }

  Future<void> onGiftReceived() async {
    final receivedGiftCommand = ZegoGiftController().service.recvNotifier.value;
    if (receivedGiftCommand == null) {
      return;
    }

    // Prefer protocol-provided source URL/type if available
    final candidate = receivedGiftCommand.giftSourceURL.isNotEmpty == true
        ? receivedGiftCommand.giftSourceURL
        : 'assets/gift/${receivedGiftCommand.giftName}.mp4';

    final giftPath = await getPathFromAssetOrCache(candidate);
    ZegoGiftController().addToPlayingList(ZegoGiftData(giftPath: giftPath));
  }
}

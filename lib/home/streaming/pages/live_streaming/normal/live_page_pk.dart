part of 'live_page.dart';

extension ZegoLiveStreamingPKBattleManagerEventConv on ZegoNormalLivePageState {
  void listenPKEvents() {
    subscriptions.addAll([
      widget.liveStreamingManager.onPKBattleReceived.stream
          .listen(onPKRequestReceived),
      widget.liveStreamingManager.onPKBattleCancelStreamCtrl.stream
          .listen(onPKRequestCancelled),
      widget.liveStreamingManager.onPKBattleRejectedStreamCtrl.stream
          .listen(onPKRequestRejected),
      widget.liveStreamingManager.incomingPKRequestTimeoutStreamCtrl.stream
          .listen(onIncomingPKRequestTimeout),
      widget.liveStreamingManager.outgoingPKRequestAnsweredTimeoutStreamCtrl
          .stream
          .listen(onOutgoingPKRequestTimeout),
      widget.liveStreamingManager.onPKStartStreamCtrl.stream.listen(onPKStart),
      widget.liveStreamingManager.onPKEndStreamCtrl.stream.listen(onPKEnd),
      widget.liveStreamingManager.onPKUserConnectingCtrl.stream
          .listen(onPKUserConnecting),
    ]);
  }

  void onPKRequestReceived(PKBattleReceivedEvent event) {
    showPKDialog(event.requestID);
  }

  void onPKRequestRejected(PKBattleRejectedEvent event) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('pk request is rejected')));
  }

  void onPKRequestCancelled(PKBattleCancelledEvent event) {
    if (showingPKDialog) {
      Navigator.pop(context);
    }
  }

  void onIncomingPKRequestTimeout(IncomingPKRequestTimeoutEvent event) {
    if (showingPKDialog) {
      Navigator.pop(context);
    }
  }

  void onOutgoingPKRequestTimeout(OutgoingPKRequestTimeoutEvent event) {}

  void onPKUserConnecting(PKBattleUserConnectingEvent event) {
    // Remove auto-removal after 60s; keep PK running until manual action
  }

  void onPKStart(dynamic event) {
    //stop cohost
    if (!widget.liveStreamingManager.iamHost()) {
      widget.liveStreamingManager.endCoHost();
    }
    if (widget.liveStreamingManager.iamHost()) {
      ZEGOSDKManager()
          .zimService
          .roomRequestMapNoti
          .value
          .values
          .toList()
          .forEach((element) {
        refuseApplyCohost(element);
      });
    }

    // send timer command when PK starts (host sends)
    if (widget.liveStreamingManager.iamHost()) {
      final pkInfo = widget.liveStreamingManager.pkInfo;
      final duration = pkInfo?.durationMinutes ?? 5;
      final startTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final command =
          jsonEncode({'startTime': startTime, 'duration': duration * 60});
      prebuilt.ZegoUIKitPrebuiltLiveStreamingController().room.sendCommand(
            roomID: widget.roomID,
            command: Uint8List.fromList(utf8.encode(command)),
          );
    }
  }

  void onPKEnd(dynamic event) {
    if (showingPKDialog) {
      Navigator.pop(context);
    }
  }

  void showPKDialog(String requestID) {
    if (showingPKDialog) {
      return;
    }
    showingPKDialog = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('receive pk invitation'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Disagree'),
              onPressed: () {
                widget.liveStreamingManager.rejectPKStartRequest(requestID);
                Navigator.pop(context);
              },
            ),
            CupertinoDialogAction(
              child: const Text('Agree'),
              onPressed: () {
                widget.liveStreamingManager.acceptPKStartRequest(requestID);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    ).whenComplete(() => showingPKDialog = false);
  }
}

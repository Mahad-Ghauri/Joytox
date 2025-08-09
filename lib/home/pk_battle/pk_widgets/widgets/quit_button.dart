import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:trace/ui/text_with_tap.dart';
import 'package:trace/utils/colors.dart';

import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

class PKQuitButton extends StatefulWidget {
  final ValueNotifier<Map<String, List<String>>>
      requestingHostsMapRequestIDNotifier;
  final ValueNotifier<ZegoLiveStreamingState> liveStateNotifier;

  const PKQuitButton({
    Key? key,
    required this.liveStateNotifier,
    required this.requestingHostsMapRequestIDNotifier,
  }) : super(key: key);

  @override
  State<PKQuitButton> createState() => _PKQuitButtonState();
}

class _PKQuitButtonState extends State<PKQuitButton> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.liveStateNotifier,
      builder: (context, state, _) {
        if(ZegoLiveStreamingState.inPKBattle == state) {
          return SizedBox(
            height: 30,
            child: ElevatedButton(
              onPressed: ZegoLiveStreamingState.inPKBattle == state
                  ? () => quitPKBattle(context)
                  : null,
              child: TextWithTap("quit_".tr(), color: kPrimaryColor,),
            ),
          );
        }
        return SizedBox();
      },
    );
  }

  void quitPKBattle(context) {
    if (!ZegoUIKitPrebuiltLiveStreamingController().pk.isInPK) {
      return;
    }

    ZegoUIKitPrebuiltLiveStreamingController().pk.quit().then((ret) {
      if (ret.error != null) {
        showDialog(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: Text('quit_failed'.tr()),
              content: Text('error_msg'.tr(namedArgs: {"error": "${ret.error}"})),
              actions: [
                CupertinoDialogAction(
                  onPressed: Navigator.of(context).pop,
                  child: Text('ok_'.tr()),
                ),
              ],
            );
          },
        );
      } else {
        widget.requestingHostsMapRequestIDNotifier.value = {};
      }
    });
  }
}

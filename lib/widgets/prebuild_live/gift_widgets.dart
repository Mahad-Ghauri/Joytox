import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/svg.dart';
import '../../models/GiftsModel.dart';
import '../../models/UserModel.dart';
import '../../ui/container_with_corner.dart';
import '../../ui/text_with_tap.dart';
import '../../helpers/quick_actions.dart';
import 'package:easy_localization/easy_localization.dart';

class GiftSenderWidget extends StatelessWidget {
  final UserModel sender;
  final UserModel receiver;
  final GiftsModel gift;

  const GiftSenderWidget({
    Key? key,
    required this.sender,
    required this.receiver,
    required this.gift,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ContainerCorner(
          colors: [Colors.black26, Colors.transparent],
          borderRadius: 50,
          marginLeft: 5,
          marginRight: 10,
          marginBottom: 15,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QuickActions.avatarWidget(
                      sender,
                      width: 35,
                      height: 35,
                    ),
                    SizedBox(
                      width: 45,
                      child: TextWithTap(
                        sender.getFullName!,
                        fontSize: 8,
                        color: Colors.white,
                        marginTop: 2,
                        overflow: TextOverflow.ellipsis,
                        alignment: Alignment.center,
                      ),
                    ),
                  ],
                ),
                TextWithTap(
                  tr("sent_gift_to"),
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  marginRight: 5,
                  marginLeft: 5,
                  textItalic: true,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QuickActions.avatarWidget(
                      receiver,
                      width: 35,
                      height: 35,
                    ),
                    SizedBox(
                      width: 45,
                      child: TextWithTap(
                        receiver.getFullName!,
                        fontSize: 8,
                        color: Colors.white,
                        marginTop: 2,
                        overflow: TextOverflow.ellipsis,
                        alignment: Alignment.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 35,
                  height: 35,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: QuickActions.photosWidget(
                      gift.getPreview!.url,
                    ),
                  ),
                ),
                ContainerCorner(
                  color: Colors.transparent,
                  marginTop: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        "assets/svg/ic_coin_with_star.svg",
                        width: 10,
                        height: 10,
                      ),
                      TextWithTap(
                        gift.getCoins.toString(),
                        color: Colors.white,
                        fontSize: 10,
                        marginLeft: 5,
                        fontWeight: FontWeight.w900,
                      )
                    ],
                  ),
                ),
              ],
            ),
            TextWithTap(
              "x1",
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 25,
              marginLeft: 10,
              textItalic: true,
            ),
          ],
        )
      ],
    ).animate().slideX(
          duration: Duration(seconds: 2),
          delay: Duration(seconds: 0),
          begin: -5,
          end: 0,
        );
  }
}

class GiftButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isPrivateLive;

  const GiftButton({
    Key? key,
    required this.onPressed,
    required this.isPrivateLive,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        backgroundColor: Colors.black26,
      ),
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: Lottie.asset(
          "assets/lotties/ic_gift.json",
          height: 29,
        ),
      ),
    );
  }
}

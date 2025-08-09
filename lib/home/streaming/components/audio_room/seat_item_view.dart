import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../live_audio_room_manager.dart';

class ZegoSeatItemView extends StatelessWidget {
  const ZegoSeatItemView({
    super.key,
    required this.onPressed,
    required this.seatIndex,
  });

  final int seatIndex;
  final void Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZegoSDKUser?>(
      valueListenable: ZegoLiveAudioRoomManager().seatList[seatIndex].currentUser,
      builder: (context, user, _) {
        if (user != null) {
          return userSeatView(user);
        } else {
          return emptySeatView(context);
        }
      },
    );
  }

  Widget userSeatView(ZegoSDKUser userInfo) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          userAvatar(userInfo),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              userInfo.userName,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget userAvatar(ZegoSDKUser userInfo) {
    return SizedBox(
      width: 60,
      height: 60,
      child: ValueListenableBuilder<String?>(
        valueListenable: userInfo.avatarUrlNotifier,
        builder: (context, avatarUrl, child) {
          return ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(30)),
            child: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? CachedNetworkImage(
              imageUrl: avatarUrl,
              fit: BoxFit.cover,
              progressIndicatorBuilder: (context, url, _) =>
              const CupertinoActivityIndicator(),
              errorWidget: (context, url, error) => child!,
            )
                : child,
          );
        },
        child: Container(
          decoration: const BoxDecoration(color: Colors.grey),
          child: Center(
            child: SizedBox(
              height: 20,
              child: Text(
                userInfo.userID.substring(0, 1),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  decoration: TextDecoration.none,
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget emptySeatView(BuildContext context) {
    final seat = ZegoLiveAudioRoomManager().seatList[seatIndex];
    final currentUser = ZegoLiveAudioRoomManager().localUser;
    final isHost = currentUser != null && currentUser.userID == ZegoLiveAudioRoomManager().hostUserID;

    return ValueListenableBuilder<bool>(
      valueListenable: seat.isLocked,
      builder: (context, isLocked, _) {
        return GestureDetector(
          onTap: () {
            if (isHost) {
              seat.isLocked.value = !seat.isLocked.value;
            } else if (!isLocked) {
              onPressed();
            }
          },
          child: Column(
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: isLocked
                        ? Image.asset('assets/icons/seat_lock_icon.png', fit: BoxFit.fill)
                        : Image.asset('assets/icons/seat_icon_normal.png', fit: BoxFit.fill),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Icon(
                      isLocked ? Icons.lock : Icons.lock_open,
                      size: 14,
                      color: isHost ? Colors.red : Colors.transparent,
                    ),
                  ),
                ],
              ),
              const Text(''),
            ],
          ),
        );
      },
    );
  }
}

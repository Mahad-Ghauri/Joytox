import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:trace/ui/container_with_corner.dart';
import 'package:trace/ui/text_with_tap.dart';

import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import '../../prebuild_live/pk_timer.dart';

ZegoLiveStreamingPKBattleConfig pkConfig({
  required String liveId,
  required Widget pointsWidget,
  required Widget showWinnerAndLoser,
  required Widget victoryWidget,
}) {
  return ZegoLiveStreamingPKBattleConfig(
    mixerLayout: PKGridLayout(),
    // pKBattleViewTopPadding: 100,
    // hostReconnectingBuilder: (
    //   BuildContext context,
    //   ZegoUIKitUser? host,
    //   Map<String, dynamic> extraInfo,
    // ) {
    //   return const CircularProgressIndicator(
    //     backgroundColor: Colors.red,
    //     color: Colors.purple,
    //   );
    // },
    foregroundBuilder: (
      BuildContext context,
      List<ZegoUIKitUser?> hosts,
      Map<String, dynamic> extraInfo,
    ) {
      // 🚨 CRITICAL: Render widgets even when hosts.isEmpty
      // The widgets (BattleTimer, victoryWidget, showWinnerAndLoser) use controller data,
      // not the hosts list, so they can render independently
      debugPrint(
          '[PK_CONFIG_BUILDER] 🎨 foregroundBuilder called - hosts count: ${hosts.length}');

      Size size = MediaQuery.sizeOf(context);
      return SizedBox(
        width: size.width,
        child: Stack(
          alignment: AlignmentDirectional.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BattleTimer(
                  roomID: liveId,
                ),
                Image.asset(
                  "assets/images/live_pk_icon_vs.png",
                  height: 45,
                ),
              ],
            ),
            Positioned(top: 10, child: victoryWidget),
            showWinnerAndLoser
          ],
        ),
      );
    },
    topBuilder: (
      BuildContext context,
      List<ZegoUIKitUser?> hosts,
      Map<String, dynamic> extraInfo,
    ) {
      // 🚨 CRITICAL: Always return pointsWidget - it doesn't depend on hosts list
      // pointsWidget uses showGiftSendersController data which is independent of hosts
      debugPrint(
          '[PK_CONFIG_BUILDER] 🎨 topBuilder called - hosts count: ${hosts.length}, returning pointsWidget');
      return pointsWidget;
      /*Size size = MediaQuery.sizeOf(context);
      var pkColors = [kOrangedColor, kPurpleColor];
      var points = [myBattlePoints, hisBattlePoints];
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          hosts.length,
              (index) {
            return ContainerCorner(
              width: size.width / 2,
              height: 15,
              color: pkColors[index],
              borderWidth: 0,
              child: TextWithTap(
                "${points[index]} "+"coins_and_points_screen.points_".tr(),
                color: Colors.white,
                alignment: index == 1 ? Alignment.centerRight : Alignment.centerLeft,
                fontSize: 12,
                marginRight: index == 1 ? 10 : 0,
                marginLeft: index == 0 ? 10 : 0,
                fontWeight: FontWeight.w900,
              ),
            );
          },
        ),
      );*/
      // return PointsDisplay(roomID: liveId, hosts: hosts,);
    },
    bottomBuilder: (
      BuildContext context,
      List<ZegoUIKitUser?> hosts,
      Map<String, dynamic> extraInfo,
    ) {
      // 🚨 CRITICAL: Handle empty hosts gracefully - show connecting indicator
      // This ensures the builder doesn't disappear when hosts list is temporarily empty
      // and provides visual feedback that PK system is connecting
      debugPrint(
          '[PK_CONFIG_BUILDER] 🎨 bottomBuilder called - hosts count: ${hosts.length}');

      if (hosts.isNotEmpty) {
        debugPrint(
            '[PK_CONFIG_BUILDER] ✅ Hosts populated: ${hosts.map((h) => h?.name ?? 'null').join(', ')}');
      } else {
        // 🚨 CRITICAL: Hosts list is empty - this is expected for viewers joining mid-battle
        // Zego's PK system only populates hosts when PK is established through Zego signaling
        // (sendRequest/acceptRequest). Viewers joining after PK is established don't have this state.
        debugPrint(
            '[PK_CONFIG_BUILDER] ⚠️ bottomBuilder: hosts empty (expected for viewers joining mid-battle)');
        debugPrint(
            '[PK_CONFIG_BUILDER] ⚠️ Zego PK hosts list relies on signaling state, not just pkConfig');
        debugPrint(
            '[PK_CONFIG_BUILDER] ⚠️ Showing connecting indicator as fallback');
      }

      if (hosts.isEmpty) {
        // Show a connecting indicator when hosts are still loading
        // This provides user feedback that battle UI is initializing
        // NOTE: For viewers joining mid-battle, hosts may remain empty indefinitely
        // This is a Zego SDK limitation - PK hosts are only populated when PK is
        // established through Zego's signaling system (sendRequest/acceptRequest)
        return Container(
          height: 20,
          alignment: Alignment.center,
          child: Text(
            'Connecting...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        );
      }

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          hosts.length,
          (index) {
            return ContainerCorner(
              child: TextWithTap(
                hosts[index]?.name ?? "Unknown",
                color: Colors.white,
                fontSize: 10,
              ),
            );
          },
        ),
      );
    },
  );
}

/// two:
/// ┌───┬────┐
/// │😄 │ 😄 │
/// └───┴────┘
/// four:
/// ┌───┬───┐
/// │😄 │😄 │
/// ├───┼───┤
/// │😄 │   │
/// └───┴───┘
/// nine:
/// ┌───┬───┬───┐
/// │😄 │😄 │😄 │
/// ├───┼───┼───┤
/// │😄 │😄 │😄 │
/// ├───┼───┼───┤
/// │😄 │😄 │   │
/// └───┴───┴───┘
class PKGridLayout extends ZegoLiveStreamingPKMixerLayout {
  @override
  Size getResolution() => const Size(1080, 960);

  @override
  List<Rect> getRectList(
    int hostCount, {
    double scale = 1.0,
  }) {
    final resolution = getResolution();
    final rowCount = getRowCount(hostCount);
    final columnCount = getColumnCount(hostCount);
    final itemWidth = resolution.width / columnCount;
    final itemHeight = resolution.height / rowCount;

    final rectList = <Rect>[];
    var hostRowIndex = 0;
    var hostColumnIndex = 0;
    for (var hostIndex = 0; hostIndex < hostCount; ++hostIndex) {
      if (hostColumnIndex == columnCount) {
        hostColumnIndex = 0;
        hostRowIndex++;
      }

      rectList.add(
        Rect.fromLTWH(
          itemWidth * hostColumnIndex * scale,
          itemHeight * hostRowIndex * scale,
          itemWidth * scale,
          itemHeight * scale,
        ),
      );

      ++hostColumnIndex;
    }

    return rectList;
  }

  int getRowCount(int hostCount) {
    if (hostCount > 6) {
      return 3;
    }
    if (hostCount > 2) {
      return 2;
    }
    return 1;
  }

  int getColumnCount(int hostCount) {
    if (hostCount > 4) {
      return 3;
    }
    return 2;
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trace/models/UserModel.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';

import '../../controller/controller.dart';

class SeatOverlayWidget extends StatelessWidget {
  final UserModel currentUser;
  final bool isHost;
  final int numberOfSeats;
  final int totalChairs;
  final Function(int seatIndex) onSeatClicked;

  const SeatOverlayWidget({
    Key? key,
    required this.currentUser,
    required this.isHost,
    required this.numberOfSeats,
    required this.totalChairs,
    required this.onSeatClicked,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isHost) return SizedBox(); // Only show overlay for hosts

    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildSeatOverlays(context, constraints);
      },
    );
  }

  Widget _buildSeatOverlays(BuildContext context, BoxConstraints constraints) {
    List<Widget> overlays = [];
    int seatIndex = 0;

    // Calculate seat positions based on the layout configuration
    for (int rowIndex = 0; rowIndex < numberOfSeats; rowIndex++) {
      int seatsInRow;
      ZegoLiveAudioRoomLayoutAlignment alignment;
      double rowTopOffset;

      if (rowIndex == 0) {
        // Host row (1 seat, center)
        seatsInRow = 1;
        alignment = ZegoLiveAudioRoomLayoutAlignment.center;
        rowTopOffset = 80.0; // Approximate position
      } else {
        // Regular rows
        if (totalChairs == 20) {
          seatsInRow = 5;
          alignment = ZegoLiveAudioRoomLayoutAlignment.start;
        } else if (totalChairs == 24) {
          seatsInRow = 6;
          alignment = ZegoLiveAudioRoomLayoutAlignment.start;
        } else {
          seatsInRow = 4;
          alignment = ZegoLiveAudioRoomLayoutAlignment.spaceEvenly;
        }
        rowTopOffset = 80.0 + (rowIndex * 100.0); // Approximate row spacing
      }

      // Create overlays for each seat in this row
      for (int colIndex = 0;
          colIndex < seatsInRow && seatIndex < totalChairs;
          colIndex++) {
        final currentSeatIndex = seatIndex;

        Widget seatOverlay = _buildSeatClickArea(
          context: context,
          seatIndex: currentSeatIndex,
          rowIndex: rowIndex,
          colIndex: colIndex,
          seatsInRow: seatsInRow,
          alignment: alignment,
          constraints: constraints,
          rowTopOffset: rowTopOffset,
        );

        overlays.add(seatOverlay);
        seatIndex++;
      }
    }

    return Stack(children: overlays);
  }

  Widget _buildSeatClickArea({
    required BuildContext context,
    required int seatIndex,
    required int rowIndex,
    required int colIndex,
    required int seatsInRow,
    required ZegoLiveAudioRoomLayoutAlignment alignment,
    required BoxConstraints constraints,
    required double rowTopOffset,
  }) {
    // Calculate position based on alignment and row configuration
    double left = _calculateLeftPosition(
      colIndex: colIndex,
      seatsInRow: seatsInRow,
      alignment: alignment,
      totalWidth: constraints.maxWidth,
    );

    double seatSize = 80.0; // Approximate seat size

    return Positioned(
      left: left,
      top: rowTopOffset,
      child: GestureDetector(
        onTap: () {
          print("Seat $seatIndex clicked");
          onSeatClicked(seatIndex);
        },
        child: Container(
          width: seatSize,
          height: seatSize,
          decoration: BoxDecoration(
            // Visible container for debugging (make transparent later)
            color: Colors.red.withValues(alpha: 0.3),
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(40),
          ),
          child: Obx(() {
            final controller = Get.find<Controller>();
            final seatState = controller.getSeatState(seatIndex);

            // Show seat state indicators if needed
            if (seatState != null) {
              final isLocked = seatState['isLocked'] ?? false;
              final isMuted = seatState['isMuted'] ?? false;

              return Stack(
                children: [
                  // Lock indicator
                  if (isLocked)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.lock,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  // Mute indicator
                  if (isMuted)
                    Positioned(
                      bottom: 5,
                      right: 5,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.mic_off,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              );
            }

            return SizedBox();
          }),
        ),
      ),
    );
  }

  double _calculateLeftPosition({
    required int colIndex,
    required int seatsInRow,
    required ZegoLiveAudioRoomLayoutAlignment alignment,
    required double totalWidth,
  }) {
    double seatSize = 80.0;
    double padding = 20.0;
    double availableWidth = totalWidth - (2 * padding);

    switch (alignment) {
      case ZegoLiveAudioRoomLayoutAlignment.center:
        return (totalWidth - seatSize) / 2;

      case ZegoLiveAudioRoomLayoutAlignment.start:
        double spacing =
            (availableWidth - (seatsInRow * seatSize)) / (seatsInRow - 1);
        return padding + (colIndex * (seatSize + spacing));

      case ZegoLiveAudioRoomLayoutAlignment.spaceEvenly:
      default:
        if (seatsInRow == 1) {
          return (totalWidth - seatSize) / 2;
        }
        double spacing =
            (availableWidth - (seatsInRow * seatSize)) / (seatsInRow + 1);
        return padding + spacing + (colIndex * (seatSize + spacing));
    }
  }
}

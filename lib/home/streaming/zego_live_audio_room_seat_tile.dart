import 'package:flutter/material.dart';
import 'live_audio_room_manager.dart';

class ZegoLiveAudioRoomSeatTile extends StatelessWidget {
  final String userName;
  final bool isLocked;
  final VoidCallback? onLongPress; // ⬅️ NEW for host-only lock/unlock

  const ZegoLiveAudioRoomSeatTile({
    Key? key,
    required this.userName,
    this.isLocked = false,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        // ⬅️ Sirf host allowed hai
        if (ZegoLiveAudioRoomManager().roleNoti.value != ZegoLiveAudioRoomRole.host) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Only host can lock/unlock seats")),
          );
          return;
        }

        // Callback run karo agar diya gaya ho
        onLongPress?.call();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isLocked ? Colors.grey[300] : Colors.white,
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLocked ? Icons.lock : Icons.mic,
              size: 32,
              color: isLocked ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 4),
            Text(
              userName,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

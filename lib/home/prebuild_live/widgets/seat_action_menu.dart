import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trace/models/UserModel.dart';

import '../../../ui/container_with_corner.dart';
import '../../../ui/text_with_tap.dart';
import '../../../utils/colors.dart';
import '../../controller/controller.dart';

class SeatActionMenu extends StatelessWidget {
  final UserModel currentUser;
  final int seatIndex;
  final Function(String action, int seatIndex) onActionSelected;
  final VoidCallback onClose;

  const SeatActionMenu({
    Key? key,
    required this.currentUser,
    required this.seatIndex,
    required this.onActionSelected,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<Controller>();
    final size = MediaQuery.of(context).size;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      child: ContainerCorner(
        radiusTopRight: 20.0,
        radiusTopLeft: 20.0,
        color: kContentColorLightTheme,
        width: size.width,
        borderWidth: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextWithTap(
                    "Seat ${seatIndex + 1} Actions",
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),

            // Actions
            Obx(() {
              final seatState = controller.getSeatState(seatIndex);
              if (seatState == null) return SizedBox();

              final isLocked = seatState['isLocked'] ?? false;
              final isMuted = seatState['isMuted'] ?? false;
              final hasUser = seatState['userId'] != null;

              return Column(
                children: [
                  // Lock/Unlock Action
                  _buildActionItem(
                    icon: isLocked ? Icons.lock_open : Icons.lock,
                    title: isLocked ? "Unlock Seat" : "Lock Seat",
                    subtitle: isLocked
                        ? "Allow users to join this seat"
                        : "Prevent users from joining this seat",
                    onTap: () => onActionSelected(
                        isLocked ? 'unlock' : 'lock', seatIndex),
                  ),

                  // Mute/Unmute Action (only if seat has user)
                  if (hasUser)
                    _buildActionItem(
                      icon: isMuted ? Icons.mic : Icons.mic_off,
                      title: isMuted ? "Unmute Seat" : "Mute Seat",
                      subtitle: isMuted
                          ? "Unmute microphone for this seat"
                          : "Mute microphone for this seat",
                      onTap: () => onActionSelected(
                          isMuted ? 'unmute' : 'mute', seatIndex),
                    ),

                  // Invite Friends Action (only if seat is unlocked and empty)
                  if (!isLocked && !hasUser)
                    _buildActionItem(
                      icon: Icons.person_add,
                      title: "Invite Friends",
                      subtitle: "Invite friends/followers to this seat",
                      onTap: () => onActionSelected('invite', seatIndex),
                    ),

                  // Remove User Action (only if seat has user)
                  if (hasUser)
                    _buildActionItem(
                      icon: Icons.person_remove,
                      title: "Remove User",
                      subtitle: "Remove current user from this seat",
                      color: Colors.red,
                      onTap: () => onActionSelected('remove', seatIndex),
                    ),

                  SizedBox(height: 20),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ContainerCorner(
      marginLeft: 20,
      marginRight: 20,
      marginBottom: 15,
      borderRadius: 12,
      color: Colors.white.withValues(alpha: 0.1),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          children: [
            ContainerCorner(
              color: (color ?? kPrimaryColor).withValues(alpha: 0.2),
              borderRadius: 10,
              width: 40,
              height: 40,
              child: Icon(
                icon,
                color: color ?? kPrimaryColor,
                size: 20,
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWithTap(
                    title,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  SizedBox(height: 3),
                  TextWithTap(
                    subtitle,
                    fontSize: 12,
                    color: Colors.grey[400]!,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

void showSeatActionMenu({
  required BuildContext context,
  required UserModel currentUser,
  required int seatIndex,
  required Function(String action, int seatIndex) onActionSelected,
}) {
  print("showSeatActionMenu: Showing menu for seat $seatIndex"); // Debug log

  // Simple alert dialog for testing
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Seat ${seatIndex + 1} Actions"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.lock),
            title: Text("Lock Seat"),
            onTap: () {
              print("Lock action selected for seat $seatIndex");
              Navigator.of(context).pop();
              onActionSelected('lock', seatIndex);
            },
          ),
          ListTile(
            leading: Icon(Icons.lock_open),
            title: Text("Unlock Seat"),
            onTap: () {
              print("Unlock action selected for seat $seatIndex");
              Navigator.of(context).pop();
              onActionSelected('unlock', seatIndex);
            },
          ),
          ListTile(
            leading: Icon(Icons.mic_off),
            title: Text("Mute Seat"),
            onTap: () {
              print("Mute action selected for seat $seatIndex");
              Navigator.of(context).pop();
              onActionSelected('mute', seatIndex);
            },
          ),
          ListTile(
            leading: Icon(Icons.mic),
            title: Text("Unmute Seat"),
            onTap: () {
              print("Unmute action selected for seat $seatIndex");
              Navigator.of(context).pop();
              onActionSelected('unmute', seatIndex);
            },
          ),
          ListTile(
            leading: Icon(Icons.person_add),
            title: Text("Invite Friends"),
            onTap: () {
              print("Invite action selected for seat $seatIndex");
              Navigator.of(context).pop();
              onActionSelected('invite', seatIndex);
            },
          ),
          ListTile(
            leading: Icon(Icons.person_remove),
            title: Text("Remove User"),
            onTap: () {
              print("Remove action selected for seat $seatIndex");
              Navigator.of(context).pop();
              onActionSelected('remove', seatIndex);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Cancel"),
        ),
      ],
    ),
  );
}

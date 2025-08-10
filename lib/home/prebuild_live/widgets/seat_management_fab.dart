import 'package:flutter/material.dart';
import 'package:trace/models/UserModel.dart';

import '../../../ui/container_with_corner.dart';
import '../../../ui/text_with_tap.dart';
import '../../../utils/colors.dart';
import 'seat_action_menu.dart';

class SeatManagementFAB extends StatelessWidget {
  final UserModel currentUser;
  final bool isHost;
  final int totalSeats;
  final Function(String action, int seatIndex) onActionSelected;

  const SeatManagementFAB({
    Key? key,
    required this.currentUser,
    required this.isHost,
    required this.totalSeats,
    required this.onActionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print("SeatManagementFAB: build called, isHost: $isHost"); // Debug log

    // Show for testing - remove isHost check temporarily
    // if (!isHost) {
    //   print("SeatManagementFAB: Not a host, hiding FAB");
    //   return SizedBox(); // Only show for hosts
    // }

    print("SeatManagementFAB: Building FAB"); // Debug log

    return Positioned(
      bottom: 120,
      right: 20,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.red, // Make it obvious for testing
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () {
              print("SEAT FAB TAPPED!"); // Debug log
              _showSimpleAlert(context);
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chair,
                    color: Colors.white,
                    size: 28,
                  ),
                  Text(
                    "SEATS",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSimpleAlert(BuildContext context) {
    print("_showSimpleAlert: Showing simple alert"); // Debug log

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Seat Management"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Select a seat to manage:"),
            SizedBox(height: 10),
            for (int i = 0; i < totalSeats; i++)
              ListTile(
                title: Text("Seat ${i + 1}"),
                leading: Icon(Icons.chair),
                onTap: () {
                  Navigator.of(context).pop();
                  _showSeatActions(context, i);
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

  void _showSeatSelectionMenu(BuildContext context) {
    print(
        "_showSeatSelectionMenu: Showing seat selection for $totalSeats seats"); // Debug log

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) {
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
            width: MediaQuery.of(context).size.width,
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
                        "Select Seat to Manage",
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(Icons.close, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),

                // Seat grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: totalSeats,
                    itemBuilder: (context, index) {
                      return ContainerCorner(
                        borderRadius: 10,
                        color: Colors.white.withValues(alpha: 0.1),
                        onTap: () {
                          print("Seat ${index + 1} tapped"); // Debug log
                          Navigator.of(context).pop();
                          _showSeatActions(context, index);
                        },
                        child: Center(
                          child: TextWithTap(
                            "Seat ${index + 1}",
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSeatActions(BuildContext context, int seatIndex) {
    print("_showSeatActions: Showing actions for seat $seatIndex"); // Debug log

    showSeatActionMenu(
      context: context,
      currentUser: currentUser,
      seatIndex: seatIndex,
      onActionSelected: onActionSelected,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';
import 'package:trace/models/SeatInvitationModel.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/helpers/quick_actions.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:trace/ui/container_with_corner.dart';
import 'package:trace/ui/text_with_tap.dart';
import 'package:trace/utils/colors.dart';

class SeatInvitationDialog extends StatefulWidget {
  final SeatInvitationModel invitation;
  final UserModel currentUser;
  final Function(bool accepted) onResponse;

  const SeatInvitationDialog({
    Key? key,
    required this.invitation,
    required this.currentUser,
    required this.onResponse,
  }) : super(key: key);

  @override
  State<SeatInvitationDialog> createState() => _SeatInvitationDialogState();
}

class _SeatInvitationDialogState extends State<SeatInvitationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: QuickHelp.isDarkMode(context)
                      ? kContentColorLightTheme
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with invitation icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chair,
                          size: 40,
                          color: kPrimaryColor,
                        ),
                      ),

                      SizedBox(height: 20),

                      // Title
                      TextWithTap(
                        "seat_invitation.title".tr(),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: QuickHelp.isDarkMode(context)
                            ? Colors.white
                            : Colors.black,
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: 16),

                      // Inviter info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          QuickActions.avatarWidget(
                            widget.invitation.getInviter!,
                            width: 50,
                            height: 50,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextWithTap(
                                  widget.invitation.getInviter!.getFullName!,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: QuickHelp.isDarkMode(context)
                                      ? Colors.white
                                      : Colors.black,
                                ),
                                TextWithTap(
                                  "seat_invitation.host_label".tr(),
                                  fontSize: 12,
                                  color: kGrayColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20),

                      // Invitation message
                      ContainerCorner(
                        color: kPrimaryColor.withOpacity(0.1),
                        borderRadius: 12,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              TextWithTap(
                                "seat_invitation.message".tr(namedArgs: {
                                  "host": widget.invitation.getInviter!
                                          .getFirstName ??
                                      "Host",
                                  "seat":
                                      "${(widget.invitation.getSeatIndex ?? 0) + 1}",
                                }),
                                fontSize: 16,
                                textAlign: TextAlign.center,
                                color: QuickHelp.isDarkMode(context)
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              if (widget.invitation.getMessage != null &&
                                  widget.invitation.getMessage!.isNotEmpty) ...[
                                SizedBox(height: 8),
                                TextWithTap(
                                  '"${widget.invitation.getMessage!}"',
                                  fontSize: 14,
                                  textAlign: TextAlign.center,
                                  color: kGrayColor,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ContainerCorner(
                              height: 50,
                              borderRadius: 25,
                              color: kGrayColor.withOpacity(0.2),
                              onTap: () => _handleResponse(false),
                              child: Center(
                                child: TextWithTap(
                                  "seat_invitation.decline".tr(),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: kGrayColor,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ContainerCorner(
                              height: 50,
                              borderRadius: 25,
                              colors: [kPrimaryColor, kSecondaryColor],
                              onTap: () => _handleResponse(true),
                              child: Center(
                                child: TextWithTap(
                                  "seat_invitation.accept".tr(),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 12),

                      // Expiry info
                      if (widget.invitation.getExpiresAt != null)
                        TextWithTap(
                          "seat_invitation.expires_at".tr(namedArgs: {
                            "time": DateFormat('HH:mm').format(
                              widget.invitation.getExpiresAt!,
                            ),
                          }),
                          fontSize: 12,
                          color: kGrayColor,
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleResponse(bool accepted) async {
    try {
      QuickHelp.showLoadingDialog(context);

      if (accepted) {
        await widget.invitation.accept();

        // Move user to the invited seat
        await _moveToSeat();
      } else {
        await widget.invitation.decline();
      }

      QuickHelp.hideLoadingDialog(context);
      Navigator.of(context).pop();
      widget.onResponse(accepted);
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "error".tr(),
        message: "seat_invitation.response_failed".tr(),
        isError: true,
      );
      print("Error responding to seat invitation: $e");
    }
  }

  Future<void> _moveToSeat() async {
    try {
      // Get the seat index from the invitation
      final seatIndex = widget.invitation.getSeatIndex;

      print("🎧 [SEAT MOVE DEBUG] Starting seat move process");
      print("🎧 [SEAT MOVE DEBUG] Seat index from invitation: $seatIndex");

      if (seatIndex != null && seatIndex >= 0) {
        print(
            "🎧 [SEAT MOVE DEBUG] Valid seat index, attempting to take seat $seatIndex");

        // Add a small delay to ensure the invitation acceptance is processed
        await Future.delayed(Duration(milliseconds: 1000));

        // Use the Zego API to move user to the specific seat
        final controller = ZegoUIKitPrebuiltLiveAudioRoomController();
        print("🎧 [SEAT MOVE DEBUG] Controller obtained: true");

        // Check seat status before attempting to take it
        final currentUser = controller.seat.getUserByIndex(seatIndex);
        final emptySeats = controller.seat.getEmptySeats();
        final isRoomLocked = controller.seat.isRoomSeatLocked;

        print(
            "🎧 [SEAT MOVE DEBUG] Current user in seat $seatIndex: ${currentUser?.id ?? 'empty'}");
        print("🎧 [SEAT MOVE DEBUG] Empty seats: $emptySeats");
        print("🎧 [SEAT MOVE DEBUG] Room seats locked: $isRoomLocked");
        print(
            "🎧 [SEAT MOVE DEBUG] Local user is audience: ${controller.seat.localIsAudience}");
        print(
            "🎧 [SEAT MOVE DEBUG] Local user is speaker: ${controller.seat.localIsSpeaker}");

        // Try multiple approaches to move to the seat
        bool moveSuccess = false;

        // Approach 1: Check if there's a Zego invitation to accept
        print("🎧 [SEAT MOVE DEBUG] Approach 1: Trying acceptTakingInvitation");
        try {
          final invitationSuccess =
              await controller.seat.audience.acceptTakingInvitation(
            context: context,
            rootNavigator: false,
          );
          print(
              "🎧 [SEAT MOVE DEBUG] acceptTakingInvitation result: $invitationSuccess");

          if (invitationSuccess) {
            moveSuccess = true;
            print(
                "🎧 [SEAT MOVE DEBUG] ✅ Successfully accepted Zego invitation");
          }
        } catch (invitationError) {
          print(
              "🎧 [SEAT MOVE DEBUG] acceptTakingInvitation failed: $invitationError");
        }

        // Approach 2: If no Zego invitation, try direct seat taking
        if (!moveSuccess) {
          print("🎧 [SEAT MOVE DEBUG] Approach 2: Trying direct seat taking");
          try {
            final takeSuccess = await controller.seat.audience.take(seatIndex);
            print("🎧 [SEAT MOVE DEBUG] Direct take result: $takeSuccess");

            if (takeSuccess) {
              moveSuccess = true;
              print(
                  "🎧 [SEAT MOVE DEBUG] ✅ Successfully moved to seat $seatIndex via direct take");
            }
          } catch (takeError) {
            print(
                "🎧 [SEAT MOVE DEBUG] Direct take failed with error: $takeError");
          }
        }

        // Approach 3: If seat is locked, check if we can request access
        if (!moveSuccess && isRoomLocked) {
          print(
              "🎧 [SEAT MOVE DEBUG] Approach 3: Room is locked, trying applyToTake");
          try {
            if (controller.seat.localIsAudience) {
              final applySuccess = await controller.seat.audience.applyToTake();
              print("🎧 [SEAT MOVE DEBUG] Apply to take result: $applySuccess");

              if (applySuccess) {
                // Wait a bit and try to take the seat again
                await Future.delayed(Duration(milliseconds: 1000));
                final retryTakeSuccess =
                    await controller.seat.audience.take(seatIndex);
                print(
                    "🎧 [SEAT MOVE DEBUG] Retry take result: $retryTakeSuccess");

                if (retryTakeSuccess) {
                  moveSuccess = true;
                  print(
                      "🎧 [SEAT MOVE DEBUG] ✅ Successfully moved after apply");
                }
              }
            }
          } catch (applyError) {
            print("🎧 [SEAT MOVE DEBUG] Apply to take failed: $applyError");
          }
        }

        // Final result
        if (moveSuccess) {
          print(
              "🎧 [SEAT MOVE DEBUG] 🎉 FINAL SUCCESS: User moved to seat $seatIndex");
        } else {
          print(
              "🎧 [SEAT MOVE DEBUG] ❌ FINAL FAILURE: All approaches failed to move user to seat $seatIndex");
          print("🎧 [SEAT MOVE DEBUG] Possible reasons:");
          print("🎧 [SEAT MOVE DEBUG] - Seat is occupied by another user");
          print("🎧 [SEAT MOVE DEBUG] - Seat is locked by host");
          print("🎧 [SEAT MOVE DEBUG] - User doesn't have permission");
          print("🎧 [SEAT MOVE DEBUG] - Network/connection issues");
        }
      } else {
        print("🎧 [SEAT MOVE DEBUG] ❌ Invalid seat index: $seatIndex");
      }
    } catch (e) {
      print("🎧 [SEAT MOVE DEBUG] ❌ Error moving to seat: $e");
      print("🎧 [SEAT MOVE DEBUG] Error type: ${e.runtimeType}");
      print("🎧 [SEAT MOVE DEBUG] Stack trace: ${StackTrace.current}");
    }
  }
}

// Helper function to show seat invitation dialog
void showSeatInvitationDialog({
  required BuildContext context,
  required SeatInvitationModel invitation,
  required UserModel currentUser,
  required Function(bool accepted) onResponse,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => SeatInvitationDialog(
      invitation: invitation,
      currentUser: currentUser,
      onResponse: onResponse,
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/models/LiveStreamingModel.dart';
import 'package:trace/models/SeatInvitationModel.dart';
import 'package:trace/services/seat_invitation_service.dart';
import 'package:trace/services/seat_invitation_listener.dart';
import 'package:trace/home/prebuild_live/widgets/seat_invitation_dialog.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:trace/ui/container_with_corner.dart';
import 'package:trace/ui/text_with_tap.dart';
import 'package:trace/utils/colors.dart';

class TestSeatInvitationScreen extends StatefulWidget {
  final UserModel currentUser;

  const TestSeatInvitationScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<TestSeatInvitationScreen> createState() =>
      _TestSeatInvitationScreenState();
}

class _TestSeatInvitationScreenState extends State<TestSeatInvitationScreen> {
  final SeatInvitationService _invitationService = SeatInvitationService();
  final SeatInvitationListener _invitationListener = SeatInvitationListener();

  @override
  void initState() {
    super.initState();

    // Initialize the invitation listener
    _invitationListener.initialize(
      currentUser: widget.currentUser,
      context: context,
    );

    // Check for pending invitations
    _invitationListener.checkPendingInvitations();
  }

  @override
  void dispose() {
    _invitationListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QuickHelp.isDarkMode(context)
          ? kContentColorLightTheme
          : Colors.white,
      appBar: AppBar(
        backgroundColor: QuickHelp.isDarkMode(context)
            ? kContentColorLightTheme
            : Colors.white,
        title: TextWithTap(
          "Seat Invitation Test",
          color: QuickHelp.isDarkMode(context) ? Colors.white : Colors.black,
        ),
        centerTitle: true,
        leading: BackButton(
          color: kGrayColor,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Test invitation creation
              ContainerCorner(
                color: kPrimaryColor,
                borderRadius: 12,
                height: 60,
                onTap: _createTestInvitation,
                child: Center(
                  child: TextWithTap(
                    "Create Test Invitation",
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Show test invitation dialog
              ContainerCorner(
                color: kSecondaryColor,
                borderRadius: 12,
                height: 60,
                onTap: _showTestInvitationDialog,
                child: Center(
                  child: TextWithTap(
                    "Show Test Invitation Dialog",
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Check pending invitations
              ContainerCorner(
                color: kVioletColor,
                borderRadius: 12,
                height: 60,
                onTap: _checkPendingInvitations,
                child: Center(
                  child: TextWithTap(
                    "Check Pending Invitations",
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(height: 40),

              // Instructions
              ContainerCorner(
                color: kGrayColor.withOpacity(0.1),
                borderRadius: 12,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextWithTap(
                        "Test Instructions:",
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: QuickHelp.isDarkMode(context)
                            ? Colors.white
                            : Colors.black,
                      ),
                      SizedBox(height: 8),
                      TextWithTap(
                        "1. Create Test Invitation - Creates a mock invitation in the database",
                        fontSize: 14,
                        color: kGrayColor,
                      ),
                      SizedBox(height: 4),
                      TextWithTap(
                        "2. Show Test Dialog - Shows the invitation dialog UI",
                        fontSize: 14,
                        color: kGrayColor,
                      ),
                      SizedBox(height: 4),
                      TextWithTap(
                        "3. Check Pending - Checks for any pending invitations",
                        fontSize: 14,
                        color: kGrayColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createTestInvitation() async {
    try {
      QuickHelp.showLoadingDialog(context);

      // Create a mock live streaming model
      final mockLiveStreaming = LiveStreamingModel();
      mockLiveStreaming.setAuthor = widget.currentUser;
      mockLiveStreaming.setAuthorId = widget.currentUser.objectId!;
      mockLiveStreaming.setStreamingChannel =
          "test_room_${DateTime.now().millisecondsSinceEpoch}";
      mockLiveStreaming.setNumberOfChairs = 8;

      // Save the mock live streaming
      final liveResponse = await mockLiveStreaming.save();
      if (!liveResponse.success) {
        throw Exception("Failed to create mock live streaming");
      }

      // Create invitation to self (for testing)
      final invitation = await _invitationService.sendSeatInvitation(
        inviter: widget.currentUser,
        invitee: widget.currentUser, // Inviting self for testing
        liveStreaming: mockLiveStreaming,
        seatIndex: 1,
        customMessage: "This is a test invitation!",
      );

      QuickHelp.hideLoadingDialog(context);

      if (invitation != null) {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "Success",
          message: "Test invitation created successfully!",
        );
      } else {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "Error",
          message: "Failed to create test invitation",
          isError: true,
        );
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "Error",
        message: "Error creating test invitation: $e",
        isError: true,
      );
      print("Error creating test invitation: $e");
    }
  }

  void _showTestInvitationDialog() {
    // Create a mock invitation for UI testing
    final mockInvitation = SeatInvitationModel();
    mockInvitation.setInviter = widget.currentUser;
    mockInvitation.setInvitee = widget.currentUser;
    mockInvitation.setSeatIndex = 2;
    mockInvitation.setStatus = SeatInvitationModel.statusPending;
    mockInvitation.setExpiresAt = DateTime.now().add(Duration(minutes: 5));
    mockInvitation.setMessage = "This is a test invitation dialog!";

    showSeatInvitationDialog(
      context: context,
      invitation: mockInvitation,
      currentUser: widget.currentUser,
      onResponse: (accepted) {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: accepted ? "Accepted" : "Declined",
          message: "Test invitation ${accepted ? 'accepted' : 'declined'}",
        );
      },
    );
  }

  void _checkPendingInvitations() async {
    try {
      QuickHelp.showLoadingDialog(context);

      final pendingInvitations = await _invitationService.getPendingInvitations(
        widget.currentUser.objectId!,
      );

      QuickHelp.hideLoadingDialog(context);

      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "Pending Invitations",
        message: "Found ${pendingInvitations.length} pending invitations",
      );

      // Show each pending invitation
      for (final invitation in pendingInvitations) {
        if (invitation.isActive) {
          await Future.delayed(Duration(milliseconds: 500));
          showSeatInvitationDialog(
            context: context,
            invitation: invitation,
            currentUser: widget.currentUser,
            onResponse: (accepted) async {
              if (accepted) {
                await _invitationService.acceptInvitation(invitation);
              } else {
                await _invitationService.declineInvitation(invitation);
              }
            },
          );
        }
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "Error",
        message: "Error checking pending invitations: $e",
        isError: true,
      );
      print("Error checking pending invitations: $e");
    }
  }
}

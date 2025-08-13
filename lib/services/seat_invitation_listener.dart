import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:trace/models/SeatInvitationModel.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/services/seat_invitation_service.dart';
import 'package:trace/home/prebuild_live/widgets/seat_invitation_dialog.dart';

class SeatInvitationListener {
  static final SeatInvitationListener _instance =
      SeatInvitationListener._internal();
  factory SeatInvitationListener() => _instance;
  SeatInvitationListener._internal();

  Subscription? _invitationSubscription;
  final SeatInvitationService _invitationService = SeatInvitationService();
  UserModel? _currentUser;
  BuildContext? _context;

  // Initialize the listener
  void initialize({
    required UserModel currentUser,
    required BuildContext context,
  }) {
    _currentUser = currentUser;
    _context = context;
    _startListening();
  }

  // Start listening for seat invitations
  Future<void> _startListening() async {
    if (_currentUser == null) return;

    try {
      print(
          "🎧 Starting seat invitation listener for user: ${_currentUser!.objectId}");

      // Create live query for seat invitations
      final query = QueryBuilder<SeatInvitationModel>(SeatInvitationModel());
      query.whereEqualTo(
          SeatInvitationModel.keyInviteeId, _currentUser!.objectId!);
      query.whereEqualTo(
          SeatInvitationModel.keyStatus, SeatInvitationModel.statusPending);
      query.includeObject([
        SeatInvitationModel.keyInviter,
        SeatInvitationModel.keyLiveStreaming,
      ]);

      final liveQuery = LiveQuery();
      _invitationSubscription = await liveQuery.client.subscribe(query);

      // Handle new invitations
      _invitationSubscription!.on(LiveQueryEvent.create,
          (SeatInvitationModel invitation) {
        print("🎧 New seat invitation received: ${invitation.objectId}");
        _handleNewInvitation(invitation);
      });

      // Handle updated invitations
      _invitationSubscription!.on(LiveQueryEvent.update,
          (SeatInvitationModel invitation) {
        print(
            "🎧 Seat invitation updated: ${invitation.objectId} - Status: ${invitation.getStatus}");
        // Handle invitation updates if needed
      });

      // Handle deleted invitations
      _invitationSubscription!.on(LiveQueryEvent.delete,
          (SeatInvitationModel invitation) {
        print("🎧 Seat invitation deleted: ${invitation.objectId}");
        // Handle invitation deletion if needed
      });

      print("🎧 Seat invitation listener started successfully");
    } catch (e) {
      print("🎧 Error starting seat invitation listener: $e");
    }
  }

  // Handle new invitation
  void _handleNewInvitation(SeatInvitationModel invitation) async {
    if (_context == null || _currentUser == null) return;

    try {
      // Fetch complete invitation data
      await invitation.getInviter!.fetch();
      await invitation.getLiveStreaming!.fetch();

      // Check if invitation is still valid
      if (!invitation.isActive) {
        print("🎧 Invitation is no longer active, ignoring");
        return;
      }

      // Show invitation dialog
      if (_context!.mounted) {
        showSeatInvitationDialog(
          context: _context!,
          invitation: invitation,
          currentUser: _currentUser!,
          onResponse: (accepted) =>
              _handleInvitationResponse(invitation, accepted),
        );
      }
    } catch (e) {
      print("🎧 Error handling new invitation: $e");
    }
  }

  // Handle invitation response
  void _handleInvitationResponse(
      SeatInvitationModel invitation, bool accepted) async {
    try {
      if (accepted) {
        print("🎧 User accepted seat invitation: ${invitation.objectId}");

        // Accept the invitation
        final success = await _invitationService.acceptInvitation(invitation);
        if (success) {
          // Navigate to the audio room if not already there
          _navigateToAudioRoom(invitation);
        }
      } else {
        print("🎧 User declined seat invitation: ${invitation.objectId}");

        // Decline the invitation
        await _invitationService.declineInvitation(invitation);
      }
    } catch (e) {
      print("🎧 Error handling invitation response: $e");
    }
  }

  // Navigate to audio room
  void _navigateToAudioRoom(SeatInvitationModel invitation) {
    // This would need to be implemented based on your navigation structure
    // For now, just print the action
    print("🎧 Should navigate to audio room: ${invitation.getRoomId}");
    print("🎧 Should join seat: ${invitation.getSeatIndex}");

    // You might want to use Navigator or your routing system here
    // Example:
    // Navigator.of(_context!).pushNamed(
    //   '/audio-room',
    //   arguments: {
    //     'roomId': invitation.getRoomId,
    //     'seatIndex': invitation.getSeatIndex,
    //     'liveStreaming': invitation.getLiveStreaming,
    //   },
    // );
  }

  // Check for pending invitations on app start
  Future<void> checkPendingInvitations() async {
    if (_currentUser == null || _context == null) return;

    try {
      print("🎧 Checking for pending seat invitations...");

      final pendingInvitations = await _invitationService
          .getPendingInvitations(_currentUser!.objectId!);

      print("🎧 Found ${pendingInvitations.length} pending invitations");

      for (final invitation in pendingInvitations) {
        if (invitation.isActive && _context!.mounted) {
          // Show invitation dialog with a small delay to avoid overwhelming the user
          await Future.delayed(Duration(milliseconds: 500));

          showSeatInvitationDialog(
            context: _context!,
            invitation: invitation,
            currentUser: _currentUser!,
            onResponse: (accepted) =>
                _handleInvitationResponse(invitation, accepted),
          );
        }
      }
    } catch (e) {
      print("🎧 Error checking pending invitations: $e");
    }
  }

  // Update context (useful when navigating between screens)
  void updateContext(BuildContext context) {
    _context = context;
  }

  // Stop listening
  void stopListening() {
    print("🎧 Stopping seat invitation listener");
    if (_invitationSubscription != null) {
      LiveQuery().client.unSubscribe(_invitationSubscription!);
      _invitationSubscription = null;
    }
    _currentUser = null;
    _context = null;
  }

  // Dispose
  void dispose() {
    stopListening();
  }
}

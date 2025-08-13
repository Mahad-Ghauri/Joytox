import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:trace/models/SeatInvitationModel.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/models/LiveStreamingModel.dart';
import 'package:trace/models/NotificationsModel.dart';

class SeatInvitationService {
  static final SeatInvitationService _instance =
      SeatInvitationService._internal();
  factory SeatInvitationService() => _instance;
  SeatInvitationService._internal();

  // Create and send a seat invitation
  Future<SeatInvitationModel?> sendSeatInvitation({
    required UserModel inviter,
    required UserModel invitee,
    required LiveStreamingModel liveStreaming,
    required int seatIndex,
    String? customMessage,
  }) async {
    try {
      // Check if there's already a pending invitation for this seat
      final existingInvitation = await _getExistingInvitation(
        inviteeId: invitee.objectId!,
        liveStreamingId: liveStreaming.objectId!,
        seatIndex: seatIndex,
      );

      if (existingInvitation != null && existingInvitation.isActive) {
        print("Seat invitation already exists and is active");
        return null;
      }

      // Create new invitation
      final invitation = SeatInvitationModel();
      invitation.setInviter = inviter;
      invitation.setInviterId = inviter.objectId!;
      invitation.setInvitee = invitee;
      invitation.setInviteeId = invitee.objectId!;
      invitation.setLiveStreaming = liveStreaming;
      invitation.setLiveStreamingId = liveStreaming.objectId!;
      invitation.setSeatIndex = seatIndex;
      invitation.setStatus = SeatInvitationModel.statusPending;
      invitation.setRoomId = liveStreaming.getStreamingChannel!;

      // Set expiration time (5 minutes from now)
      invitation.setExpiresAt = DateTime.now().add(Duration(minutes: 5));

      if (customMessage != null && customMessage.isNotEmpty) {
        invitation.setMessage = customMessage;
      }

      // Save invitation
      final response = await invitation.save();
      if (!response.success) {
        print("Failed to save seat invitation: ${response.error}");
        return null;
      }

      // Send push notification to invitee
      await _sendInvitationNotification(invitation);

      // Create in-app notification
      await _createInAppNotification(invitation);

      print("Seat invitation sent successfully to ${invitee.getFullName}");
      return invitation;
    } catch (e) {
      print("Error sending seat invitation: $e");
      return null;
    }
  }

  // Get existing invitation
  Future<SeatInvitationModel?> _getExistingInvitation({
    required String inviteeId,
    required String liveStreamingId,
    required int seatIndex,
  }) async {
    try {
      final query = QueryBuilder<SeatInvitationModel>(SeatInvitationModel());
      query.whereEqualTo(SeatInvitationModel.keyInviteeId, inviteeId);
      query.whereEqualTo(
          SeatInvitationModel.keyLiveStreamingId, liveStreamingId);
      query.whereEqualTo(SeatInvitationModel.keySeatIndex, seatIndex);
      query.whereEqualTo(
          SeatInvitationModel.keyStatus, SeatInvitationModel.statusPending);
      query.orderByDescending(SeatInvitationModel.keyCreatedAt);
      query.setLimit(1);

      final response = await query.query();
      if (response.success &&
          response.results != null &&
          response.results!.isNotEmpty) {
        return response.results!.first as SeatInvitationModel;
      }
      return null;
    } catch (e) {
      print("Error getting existing invitation: $e");
      return null;
    }
  }

  // Send push notification (placeholder - implement when push notification service is available)
  Future<void> _sendInvitationNotification(
      SeatInvitationModel invitation) async {
    try {
      // TODO: Implement push notification when service is available
      print(
          "🎧 Push notification would be sent to ${invitation.getInvitee!.getFullName} for seat invitation");
    } catch (e) {
      print("Error sending invitation notification: $e");
    }
  }

  // Create in-app notification
  Future<void> _createInAppNotification(SeatInvitationModel invitation) async {
    try {
      final notification = NotificationsModel();
      notification.setAuthor = invitation.getInviter!;
      notification.setAuthorId = invitation.getInviterId!;
      notification.setReceiver = invitation.getInvitee!;
      notification.setReceiverId = invitation.getInviteeId!;
      notification.setNotificationType =
          NotificationsModel.notificationTypeSeatInvitation;
      notification.setMessage =
          "invited you to join seat ${(invitation.getSeatIndex ?? 0) + 1} in their audio room";
      notification.setRead = false;
      notification.setObjectId = invitation.objectId!;

      await notification.save();
    } catch (e) {
      print("Error creating in-app notification: $e");
    }
  }

  // Get pending invitations for a user
  Future<List<SeatInvitationModel>> getPendingInvitations(String userId) async {
    try {
      final query = QueryBuilder<SeatInvitationModel>(SeatInvitationModel());
      query.whereEqualTo(SeatInvitationModel.keyInviteeId, userId);
      query.whereEqualTo(
          SeatInvitationModel.keyStatus, SeatInvitationModel.statusPending);
      query.whereGreaterThan(SeatInvitationModel.keyExpiresAt, DateTime.now());
      query.includeObject([
        SeatInvitationModel.keyInviter,
        SeatInvitationModel.keyLiveStreaming,
      ]);
      query.orderByDescending(SeatInvitationModel.keyCreatedAt);

      final response = await query.query();
      if (response.success && response.results != null) {
        return response.results!.cast<SeatInvitationModel>();
      }
      return [];
    } catch (e) {
      print("Error getting pending invitations: $e");
      return [];
    }
  }

  // Accept invitation
  Future<bool> acceptInvitation(SeatInvitationModel invitation) async {
    try {
      final response = await invitation.accept();
      if (response.success) {
        // Mark notification as read
        await _markNotificationAsRead(invitation);
        return true;
      }
      return false;
    } catch (e) {
      print("Error accepting invitation: $e");
      return false;
    }
  }

  // Decline invitation
  Future<bool> declineInvitation(SeatInvitationModel invitation) async {
    try {
      final response = await invitation.decline();
      if (response.success) {
        // Mark notification as read
        await _markNotificationAsRead(invitation);
        return true;
      }
      return false;
    } catch (e) {
      print("Error declining invitation: $e");
      return false;
    }
  }

  // Mark notification as read
  Future<void> _markNotificationAsRead(SeatInvitationModel invitation) async {
    try {
      final query = QueryBuilder<NotificationsModel>(NotificationsModel());
      query.whereEqualTo(
          NotificationsModel.keyReceiverId, invitation.getInviteeId!);
      query.whereEqualTo(NotificationsModel.keyNotificationType,
          NotificationsModel.notificationTypeSeatInvitation);
      query.whereEqualTo(NotificationsModel.keyObjectId, invitation.objectId!);

      final response = await query.query();
      if (response.success &&
          response.results != null &&
          response.results!.isNotEmpty) {
        final notification = response.results!.first as NotificationsModel;
        notification.setRead = true;
        await notification.save();
      }
    } catch (e) {
      print("Error marking notification as read: $e");
    }
  }

  // Expire old invitations
  Future<void> expireOldInvitations() async {
    try {
      final query = QueryBuilder<SeatInvitationModel>(SeatInvitationModel());
      query.whereEqualTo(
          SeatInvitationModel.keyStatus, SeatInvitationModel.statusPending);
      query.whereLessThan(SeatInvitationModel.keyExpiresAt, DateTime.now());

      final response = await query.query();
      if (response.success && response.results != null) {
        for (final invitation
            in response.results!.cast<SeatInvitationModel>()) {
          await invitation.expire();
        }
      }
    } catch (e) {
      print("Error expiring old invitations: $e");
    }
  }

  // Get invitation by ID
  Future<SeatInvitationModel?> getInvitationById(String invitationId) async {
    try {
      final query = QueryBuilder<SeatInvitationModel>(SeatInvitationModel());
      query.whereEqualTo(SeatInvitationModel.keyObjectId, invitationId);
      query.includeObject([
        SeatInvitationModel.keyInviter,
        SeatInvitationModel.keyInvitee,
        SeatInvitationModel.keyLiveStreaming,
      ]);

      final response = await query.query();
      if (response.success &&
          response.results != null &&
          response.results!.isNotEmpty) {
        return response.results!.first as SeatInvitationModel;
      }
      return null;
    } catch (e) {
      print("Error getting invitation by ID: $e");
      return null;
    }
  }
}

import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:trace/models/UserModel.dart';
import 'package:trace/models/LiveStreamingModel.dart';

class SeatInvitationModel extends ParseObject implements ParseCloneable {
  static const String keyTableName = "SeatInvitation";

  SeatInvitationModel() : super(keyTableName);
  SeatInvitationModel.clone() : this();

  @override
  SeatInvitationModel clone(Map<String, dynamic> map) =>
      SeatInvitationModel.clone()..fromJson(map);

  static const String keyObjectId = "objectId";
  static const String keyCreatedAt = "createdAt";
  static const String keyUpdatedAt = "updatedAt";

  static const String keyInviter = "inviter";
  static const String keyInviterId = "inviterId";
  static const String keyInvitee = "invitee";
  static const String keyInviteeId = "inviteeId";
  static const String keyLiveStreaming = "liveStreaming";
  static const String keyLiveStreamingId = "liveStreamingId";
  static const String keySeatIndex = "seatIndex";
  static const String keyStatus =
      "status"; // pending, accepted, declined, expired
  static const String keyExpiresAt = "expiresAt";
  static const String keyRoomId = "roomId";
  static const String keyMessage = "message";

  // Status constants
  static const String statusPending = "pending";
  static const String statusAccepted = "accepted";
  static const String statusDeclined = "declined";
  static const String statusExpired = "expired";

  // Getters
  UserModel? get getInviter => get<UserModel>(keyInviter);
  String? get getInviterId => get<String>(keyInviterId);

  UserModel? get getInvitee => get<UserModel>(keyInvitee);
  String? get getInviteeId => get<String>(keyInviteeId);

  LiveStreamingModel? get getLiveStreaming =>
      get<LiveStreamingModel>(keyLiveStreaming);
  String? get getLiveStreamingId => get<String>(keyLiveStreamingId);

  int? get getSeatIndex => get<int>(keySeatIndex);
  String? get getStatus => get<String>(keyStatus);
  DateTime? get getExpiresAt => get<DateTime>(keyExpiresAt);
  String? get getRoomId => get<String>(keyRoomId);
  String? get getMessage => get<String>(keyMessage);

  // Setters
  set setInviter(UserModel inviter) => set<UserModel>(keyInviter, inviter);
  set setInviterId(String inviterId) => set<String>(keyInviterId, inviterId);

  set setInvitee(UserModel invitee) => set<UserModel>(keyInvitee, invitee);
  set setInviteeId(String inviteeId) => set<String>(keyInviteeId, inviteeId);

  set setLiveStreaming(LiveStreamingModel liveStreaming) =>
      set<LiveStreamingModel>(keyLiveStreaming, liveStreaming);
  set setLiveStreamingId(String liveStreamingId) =>
      set<String>(keyLiveStreamingId, liveStreamingId);

  set setSeatIndex(int seatIndex) => set<int>(keySeatIndex, seatIndex);
  set setStatus(String status) => set<String>(keyStatus, status);
  set setExpiresAt(DateTime expiresAt) =>
      set<DateTime>(keyExpiresAt, expiresAt);
  set setRoomId(String roomId) => set<String>(keyRoomId, roomId);
  set setMessage(String message) => set<String>(keyMessage, message);

  // Helper methods
  bool get isPending => getStatus == statusPending;
  bool get isAccepted => getStatus == statusAccepted;
  bool get isDeclined => getStatus == statusDeclined;
  bool get isExpired =>
      getStatus == statusExpired ||
      (getExpiresAt != null && DateTime.now().isAfter(getExpiresAt!));

  bool get isActive => isPending && !isExpired;

  // Accept invitation
  Future<ParseResponse> accept() async {
    setStatus = statusAccepted;
    return await save();
  }

  // Decline invitation
  Future<ParseResponse> decline() async {
    setStatus = statusDeclined;
    return await save();
  }

  // Expire invitation
  Future<ParseResponse> expire() async {
    setStatus = statusExpired;
    return await save();
  }
}

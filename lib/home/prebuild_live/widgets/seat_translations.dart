// Additional translation keys needed for seat actions feature
// Add these to your translation files (en.json, etc.)

/*
{
  "seat_actions": {
    "title": "Seat {seat} Actions",
    "lock": "Lock Seat",
    "unlock": "Unlock Seat", 
    "lock_desc": "Prevent users from joining this seat",
    "unlock_desc": "Allow users to join this seat",
    "mute": "Mute Seat",
    "unmute": "Unmute Seat",
    "mute_desc": "Mute microphone for this seat",
    "unmute_desc": "Unmute microphone for this seat", 
    "invite_friends": "Invite Friends",
    "invite_friends_desc": "Invite friends/followers to this seat",
    "remove_user": "Remove User",
    "remove_user_desc": "Remove current user from this seat",
    "locked": "Seat Locked",
    "unlocked": "Seat Unlocked",
    "muted": "Seat Muted", 
    "unmuted": "Seat Unmuted",
    "removed": "User Removed",
    "seat_locked_success": "Seat {seat} has been locked successfully",
    "seat_unlocked_success": "Seat {seat} has been unlocked successfully",
    "seat_muted_success": "Seat {seat} has been muted successfully",
    "seat_unmuted_success": "Seat {seat} has been unmuted successfully",
    "user_removed_success": "User removed from seat {seat} successfully",
    "action_failed": "Action failed. Please try again."
  },
  "invite_friends": {
    "title": "Invite to Seat {seat}",
    "followers": "Followers",
    "following": "Following", 
    "no_followers": "No followers found",
    "no_following": "No following found",
    "invite": "Invite",
    "invited": "User Invited",
    "invitation_sent": "{name} has been invited to seat {seat}",
    "invitation_failed": "Failed to send invitation"
  },
  "invite_to_seat": "{name} has been invited to join seat {seat}!"
}
*/

// Note: Add these keys to your existing translation files:
// - assets/translations/en.json
// - assets/translations/[other_languages].json

class SeatTranslations {
  // This class serves as documentation for the required translation keys
  // The actual translations should be added to your JSON files

  static const String seatActionsTitle = "seat_actions.title";
  static const String seatActionsLock = "seat_actions.lock";
  static const String seatActionsUnlock = "seat_actions.unlock";
  static const String seatActionsMute = "seat_actions.mute";
  static const String seatActionsUnmute = "seat_actions.unmute";
  static const String seatActionsInviteFriends = "seat_actions.invite_friends";
  static const String seatActionsRemoveUser = "seat_actions.remove_user";

  static const String inviteFriendsTitle = "invite_friends.title";
  static const String inviteFriendsFollowers = "invite_friends.followers";
  static const String inviteFriendsFollowing = "invite_friends.following";
  static const String inviteFriendsInvite = "invite_friends.invite";

  static const String inviteToSeat = "invite_to_seat";
}

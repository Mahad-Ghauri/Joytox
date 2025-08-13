# Seat Invitation System Implementation

## Overview
This document describes the complete implementation of the seat invitation system for audio rooms in the Trace app. The system allows hosts to invite users to specific seats in their audio rooms, and users receive in-app invitations that they can accept or decline.

## Components Created

### 1. Models
- **`SeatInvitationModel`** (`lib/models/SeatInvitationModel.dart`)
  - Represents a seat invitation in the database
  - Contains inviter, invitee, seat index, status, expiration time
  - Includes helper methods for accepting/declining invitations

### 2. Services
- **`SeatInvitationService`** (`lib/services/seat_invitation_service.dart`)
  - Handles creation and management of seat invitations
  - Sends push notifications and creates in-app notifications
  - Manages invitation lifecycle (pending, accepted, declined, expired)

- **`SeatInvitationListener`** (`lib/services/seat_invitation_listener.dart`)
  - Listens for incoming seat invitations using Parse Live Query
  - Automatically shows invitation dialogs when invitations are received
  - Handles invitation responses and navigation

### 3. UI Components
- **`SeatInvitationDialog`** (`lib/home/prebuild_live/widgets/seat_invitation_dialog.dart`)
  - Beautiful animated dialog for displaying seat invitations
  - Shows inviter information, seat number, and custom message
  - Provides accept/decline buttons with proper feedback

### 4. Integration
- **Updated `PrebuildAudioRoomScreen`**
  - Integrated seat invitation services
  - Modified `inviteUserToSeat` method to use the new invitation system
  - Added proper initialization and cleanup of invitation listener

### 5. Database Schema
- **Updated `NotificationsModel`**
  - Added `notificationTypeSeatInvitation` constant
  - Added message and objectId fields for seat invitation notifications

- **Updated `main.dart`**
  - Added `SeatInvitationModel` to the Parse subclass map

### 6. Translations
- **Updated `en.json`**
  - Added complete translation keys for seat invitations
  - Includes dialog text, success/error messages, and seat actions

### 7. Testing
- **`TestSeatInvitationScreen`** (`lib/home/prebuild_live/test_seat_invitation_screen.dart`)
  - Test screen for verifying the invitation system
  - Allows creating test invitations and checking pending invitations

## How It Works

### 1. Invitation Flow
1. **Host invites user**: Host clicks on a seat and selects "Invite" action
2. **Invitation created**: `SeatInvitationService.sendSeatInvitation()` creates invitation in database
3. **Notification sent**: Push notification and in-app notification are created
4. **Live query triggers**: `SeatInvitationListener` detects new invitation via Parse Live Query
5. **Dialog shown**: Invitation dialog is automatically displayed to the invitee
6. **User responds**: User can accept or decline the invitation
7. **Response processed**: Invitation status is updated, and appropriate actions are taken

### 2. Key Features
- **Real-time invitations**: Uses Parse Live Query for instant delivery
- **Expiration handling**: Invitations expire after 5 minutes
- **Duplicate prevention**: Prevents multiple invitations for the same seat
- **Offline support**: Checks for pending invitations on app start
- **Beautiful UI**: Animated dialog with smooth transitions
- **Proper cleanup**: Automatic cleanup of expired invitations

### 3. Database Structure
```
SeatInvitation {
  inviter: UserModel (pointer)
  inviterId: String
  invitee: UserModel (pointer)
  inviteeId: String
  liveStreaming: LiveStreamingModel (pointer)
  liveStreamingId: String
  seatIndex: Number
  status: String (pending, accepted, declined, expired)
  expiresAt: Date
  roomId: String
  message: String (optional)
}
```

## Usage Instructions

### For Hosts (Inviting Users)
1. In an audio room, click on an empty seat
2. Select "Invite" from the seat action menu
3. Choose a user from the invite friends sheet
4. The invitation is automatically sent to the selected user

### For Users (Receiving Invitations)
1. When invited, an invitation dialog will automatically appear
2. The dialog shows the host's information and seat number
3. Click "Accept" to join the seat or "Decline" to reject
4. If accepted, the user should be navigated to the audio room (navigation logic needs to be implemented)

## Implementation Status

### ✅ Completed
- [x] SeatInvitationModel with all required fields
- [x] SeatInvitationService for invitation management
- [x] SeatInvitationListener for real-time invitation detection
- [x] SeatInvitationDialog with beautiful UI
- [x] Integration with PrebuildAudioRoomScreen
- [x] Database schema updates
- [x] Translation keys
- [x] Test screen for verification

### 🔄 Needs Implementation
- [ ] Navigation logic when invitation is accepted (currently just prints debug message)
- [ ] Integration with the main app navigation system
- [ ] Seat state synchronization when user joins/leaves
- [ ] Error handling for edge cases (user offline, room closed, etc.)
- [ ] Admin controls for managing invitations

### 🧪 Testing Required
- [ ] Test invitation creation and delivery
- [ ] Test invitation acceptance/decline flow
- [ ] Test expiration handling
- [ ] Test with multiple users in real audio room
- [ ] Test offline/online scenarios

## Files Modified/Created

### New Files
1. `lib/models/SeatInvitationModel.dart`
2. `lib/services/seat_invitation_service.dart`
3. `lib/services/seat_invitation_listener.dart`
4. `lib/home/prebuild_live/widgets/seat_invitation_dialog.dart`
5. `lib/home/prebuild_live/test_seat_invitation_screen.dart`

### Modified Files
1. `lib/main.dart` - Added SeatInvitationModel to subclass map
2. `lib/models/NotificationsModel.dart` - Added seat invitation notification type
3. `lib/home/prebuild_live/prebuild_audio_room_screen.dart` - Integrated invitation system
4. `assets/translations/en.json` - Added translation keys

## Next Steps

1. **Test the system**: Use the `TestSeatInvitationScreen` to verify functionality
2. **Implement navigation**: Add proper navigation logic when invitations are accepted
3. **Add to main app**: Integrate the test screen into the main app for easy access
4. **Real-world testing**: Test with multiple users in actual audio rooms
5. **Polish UI**: Add more animations and improve user experience
6. **Error handling**: Add comprehensive error handling for edge cases

## Notes

- The system uses Parse Live Query for real-time functionality
- Invitations expire after 5 minutes to prevent spam
- The system prevents duplicate invitations for the same seat
- All UI text is properly localized using the translation system
- The implementation follows the existing app architecture and patterns

This seat invitation system provides a complete solution for inviting users to audio room seats with real-time delivery, beautiful UI, and proper database management.
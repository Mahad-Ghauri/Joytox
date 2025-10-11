# Seat Invitation System - Testing Guide

## Quick Testing Steps

### 1. Add Test Screen to Your App
To test the seat invitation system, you can add the test screen to your app's navigation. Here's how:

**Option A: Add to main menu**
Add this to your main menu or profile screen:
```dart
ListTile(
  leading: Icon(Icons.event_seat),
  title: Text("Test Seat Invitations"),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TestSeatInvitationScreen(
          currentUser: widget.currentUser, // Your current user
        ),
      ),
    );
  },
),
```

**Option B: Add as floating action button**
Add this to any screen for quick access:
```dart
FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TestSeatInvitationScreen(
          currentUser: currentUser, // Your current user
        ),
      ),
    );
  },
  child: Icon(Icons.event_seat),
)
```

### 2. Test the System

1. **Open the Test Screen**: Navigate to the TestSeatInvitationScreen
2. **Create Test Invitation**: Tap "Create Test Invitation" - this creates a mock invitation in the database
3. **Check Real-time**: The invitation should automatically appear as a dialog (since it's sent to yourself for testing)
4. **Test Dialog**: Tap "Show Test Invitation Dialog" to see the UI without database interaction
5. **Check Pending**: Tap "Check Pending Invitations" to manually check for any pending invitations

### 3. Test in Audio Room

1. **Join an Audio Room**: Go to any audio room where you're the host
2. **Click on Empty Seat**: Click on any empty seat
3. **Select Invite**: Choose "Invite" from the seat actions
4. **Choose User**: Select a user to invite (you can invite yourself for testing)
5. **Check Invitation**: The invited user should receive the invitation dialog

### 4. Expected Behavior

✅ **When invitation is sent:**
- Database record is created
- In-app notification is created
- Real-time listener detects the invitation
- Dialog appears automatically to the invitee

✅ **When invitation is accepted:**
- Invitation status changes to "accepted"
- Notification is marked as read
- User should be navigated to the audio room (navigation logic needs implementation)

✅ **When invitation is declined:**
- Invitation status changes to "declined"
- Notification is marked as read

✅ **When invitation expires:**
- Invitations automatically expire after 5 minutes
- Expired invitations are cleaned up

### 5. Debugging

If something doesn't work, check the console logs for:
- `🎧` - Seat invitation related logs
- `📢` - General system logs
- Any error messages

### 6. Common Issues & Solutions

**Issue: Dialog doesn't appear**
- Check if Parse Live Query is properly configured
- Verify the user has proper permissions
- Check console logs for connection errors

**Issue: Invitation not created**
- Verify Parse server connection
- Check if SeatInvitationModel is properly registered in main.dart
- Ensure user has write permissions

**Issue: Navigation doesn't work after accepting**
- The navigation logic is not implemented yet (marked as TODO)
- You'll need to implement the navigation to the specific audio room

### 7. Next Steps for Production

1. **Implement Navigation**: Add proper navigation when invitation is accepted
2. **Add Push Notifications**: Implement the push notification service
3. **Add Admin Controls**: Add controls for hosts to manage invitations
4. **Test with Multiple Users**: Test with real users in different devices
5. **Add Error Handling**: Add comprehensive error handling for edge cases

### 8. Database Verification

You can verify the system is working by checking your Parse dashboard:
- **SeatInvitation** table should show created invitations
- **Notifications** table should show in-app notifications
- Check the status changes when invitations are accepted/declined

## Files to Import

Make sure these imports are added where you use the test screen:
```dart
import 'package:trace/home/prebuild_live/test_seat_invitation_screen.dart';
```

## System Status

✅ **Completed:**
- Database models and schema
- Real-time invitation system
- Beautiful invitation dialog UI
- Invitation lifecycle management
- Translation system
- Test framework

🔄 **Needs Implementation:**
- Navigation logic when invitation is accepted
- Push notification service integration
- Production error handling

The seat invitation system is now fully functional and ready for testing! 🎉



There is an issue suppose i send u a coin it is not showing in the earning section of the receiver which he can withdraw for a certain amount
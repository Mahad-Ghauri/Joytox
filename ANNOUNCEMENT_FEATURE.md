# Live Audio Room Announcement Feature

## Overview

The announcement feature allows hosts in live audio rooms to send important messages to all participants. These announcements appear as overlay notifications with priority-based behavior and auto-dismiss functionality.

## Features

### ✅ Host-Only Functionality
- Only room hosts can send announcements
- Announcement button appears in the host control bar
- Integrated with existing ZegoUIKit infrastructure

### ✅ Priority System
- **High Priority**: Pins automatically after auto-dismiss timer
- **Medium Priority**: Standard behavior with orange indicator
- **Normal Priority**: Default behavior with blue indicator  
- **Low Priority**: Standard behavior with green indicator

### ✅ Auto-Dismiss & Pinning
- Configurable duration (5-60 seconds)
- High priority announcements auto-pin after timer
- Manual pin/unpin functionality
- Slide-down animation with smooth transitions

### ✅ Queue Management
- Multiple announcements display in priority order
- Automatic sorting by priority and timestamp
- Individual dismiss controls for each announcement

### ✅ Localization Support
- Full translation support for all UI elements
- Integrated with existing easy_localization system
- Supports multiple languages

## Implementation Details

### Files Created/Modified

#### New Files:
1. `lib/home/prebuild_live/widgets/announcement_dialog.dart` - Dialog for creating announcements
2. `lib/home/prebuild_live/widgets/announcement_overlay_widget.dart` - Overlay display widget
3. `test/announcement_test.dart` - Unit tests

#### Modified Files:
1. `lib/home/prebuild_live/prebuild_audio_room_screen.dart` - Main integration
2. `lib/models/LiveMessagesModel.dart` - Data model extensions
3. `lib/home/controller/controller.dart` - State management
4. `assets/translations/en.json` - Localization keys

### Data Model

```dart
class LiveMessagesModel {
  static final String messageTypeAnnouncement = "ANNOUNCEMENT";
  static final String keyAnnouncementTitle = "announcementTitle";
  static final String keyAnnouncementPriority = "announcementPriority";
  static final String keyAnnouncementDuration = "announcementDuration";
  
  // Getters and setters for announcement fields
  String? get getAnnouncementTitle;
  String? get getAnnouncementPriority;
  int? get getAnnouncementDuration;
}
```

### UI Components

#### Announcement Dialog
- Title input (max 50 characters)
- Message input (max 200 characters)
- Priority selection dropdown
- Duration selection dropdown
- Form validation
- Theme-aware styling

#### Announcement Overlay
- Priority-based color coding
- Auto-dismiss timers
- Pin/unpin functionality
- Smooth animations
- Queue management

### Integration Points

#### ZegoUIKit Integration
```dart
config: widget.isHost!
  ? (ZegoUIKitPrebuiltLiveAudioRoomConfig.host()
    ..bottomMenuBar.hostExtendButtons = [announcementButton, giftButton])
```

#### Parse Backend Integration
```dart
LiveMessagesModel announcementMessage = LiveMessagesModel();
announcementMessage.setMessageType = LiveMessagesModel.messageTypeAnnouncement;
// Set other fields and save to Parse
```

## Usage

### For Hosts:
1. Tap the announcement button (📢) in the control bar
2. Fill in the announcement dialog:
   - Enter a title (required)
   - Enter a message (required)
   - Select priority level
   - Choose display duration
3. Tap "Send Announcement"
4. Announcement appears for all participants

### For Participants:
1. Announcements appear as overlay notifications
2. Can dismiss manually by tapping the X button
3. High priority announcements auto-pin after timer
4. Multiple announcements stack in priority order

## Priority Behavior

| Priority | Color | Icon | Auto-Pin | Behavior |
|----------|-------|------|----------|----------|
| High | Red | ⚠️ | Yes | Pins after auto-dismiss |
| Medium | Orange | ⚠️ | No | Standard auto-dismiss |
| Normal | Blue | ℹ️ | No | Standard auto-dismiss |
| Low | Green | ⬇️ | No | Standard auto-dismiss |

## Localization Keys

```json
{
  "announcement_dialog_title": "Send Announcement",
  "announcement_title_label": "Title",
  "announcement_title_hint": "Enter announcement title...",
  "announcement_title_required": "Title is required",
  "announcement_message_label": "Message",
  "announcement_message_hint": "Enter your announcement message...",
  "announcement_message_required": "Message is required",
  "announcement_priority_label": "Priority",
  "announcement_duration_label": "Duration",
  "announcement_send_button": "Send Announcement",
  "announcement_sent_title": "Announcement Sent",
  "announcement_sent_message": "Your announcement has been sent to all participants",
  "announcement_send_failed": "Failed to send announcement. Please try again.",
  "announcement_just_now": "Just now",
  "announcement_minutes_ago": "{minutes}m ago"
}
```

## Technical Architecture

### State Management
- Uses GetX for reactive state management
- ValueNotifier for announcement list updates
- Controller integration for seat and announcement management

### Animation System
- Slide-down entrance animations
- Smooth dismiss transitions
- Priority-based visual indicators
- Auto-dismiss timers with visual feedback

### Data Flow
1. Host creates announcement in dialog
2. Data saved to Parse backend
3. Local state updated immediately
4. ZIM message sent for real-time delivery
5. Overlay displays with animations
6. Auto-dismiss or manual dismiss handling

## Testing

Run the announcement tests:
```bash
flutter test test/announcement_test.dart
```

Tests cover:
- Model constants validation
- Data transformation
- Priority system validation
- Duration constraints

## Future Enhancements

### Potential Improvements:
1. **Rich Text Support**: Markdown or HTML formatting
2. **Media Attachments**: Images or audio clips
3. **Scheduled Announcements**: Time-based delivery
4. **Announcement History**: Persistent storage and replay
5. **User Targeting**: Send to specific user groups
6. **Analytics**: Track announcement engagement
7. **Templates**: Pre-defined announcement templates

### Performance Optimizations:
1. **Lazy Loading**: Load announcements on demand
2. **Caching**: Cache frequent announcements
3. **Compression**: Optimize data transfer
4. **Batching**: Group multiple announcements

## Troubleshooting

### Common Issues:

1. **Announcement button not visible**
   - Ensure user is the room host
   - Check `widget.isHost!` condition

2. **Announcements not appearing**
   - Verify Parse backend connection
   - Check ZIM message delivery
   - Validate announcement data structure

3. **Animation issues**
   - Ensure proper AnimationController disposal
   - Check widget lifecycle management
   - Verify animation duration settings

4. **Localization not working**
   - Confirm translation keys exist
   - Check easy_localization setup
   - Verify language file loading

## Security Considerations

1. **Host Validation**: Server-side verification of host status
2. **Rate Limiting**: Prevent announcement spam
3. **Content Filtering**: Validate announcement content
4. **Permission Checks**: Verify user permissions before sending

## Conclusion

The announcement feature provides a robust, scalable solution for host-to-participant communication in live audio rooms. It integrates seamlessly with the existing codebase while maintaining performance and user experience standards.
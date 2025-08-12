# Room Background Themes Feature

## Overview
This feature allows hosts to dynamically change the background theme of audio rooms during live sessions. The theme changes are synchronized in real-time to all participants in the room.

## Current Themes
- **Default**: Original audio room background
- **Forest**: Misty forest landscape with gradient sky
- **Gradient**: Smooth pastel gradient background

## How to Add New Themes

### Step 1: Add Background Image
1. Place your background image in `assets/images/backgrounds/`
2. Name it following the pattern: `theme_[name].[extension]`
   - Example: `theme_ocean.png`, `theme_sunset.jpg`

### Step 2: Update Controller
1. Open `lib/home/controller/controller.dart`
2. Add your theme name to the `availableThemes` list:
```dart
var availableThemes = <String>[
  'theme_default',
  'theme_forest', 
  'theme_gradient',
  'theme_ocean',     // Add new theme here
  'theme_sunset',    // Add another theme here
].obs;
```

### Step 3: Update Theme Path Logic (if needed)
1. If your theme uses a different file extension (not .png), update the `getThemePath` method in `controller.dart`:
```dart
String getThemePath(String theme) {
  // Handle special cases
  if (theme == 'theme_gradient') {
    return "assets/images/backgrounds/$theme.jpg";
  }
  if (theme == 'theme_ocean') {
    return "assets/images/backgrounds/$theme.webp";
  }
  // Default to PNG
  return "assets/images/backgrounds/$theme.png";
}
```

### Step 4: Update Theme Display Names (Optional)
1. Open `lib/home/prebuild_live/room_theme_selector.dart`
2. Add your theme to the `_getThemeDisplayName` method:
```dart
String _getThemeDisplayName(String theme) {
  switch (theme) {
    case 'theme_default':
      return "Default";
    case 'theme_forest':
      return "Forest";
    case 'theme_gradient':
      return "Gradient";
    case 'theme_ocean':        // Add new theme
      return "Ocean";
    case 'theme_sunset':       // Add another theme
      return "Sunset";
    default:
      return theme.replaceAll('theme_', '').replaceAll('_', ' ').toUpperCase();
  }
}
```

### Step 5: Update Assets (if needed)
1. If you added a new directory or special asset structure, update `pubspec.yaml`:
```yaml
assets:
  - assets/images/backgrounds/
  - assets/images/special_themes/  # If you create a new directory
```

## Technical Details

### Architecture
- **Model**: `LiveStreamingModel` stores the selected theme in `keyRoomTheme` field
- **Controller**: `Controller` manages theme state and available themes list
- **UI**: `RoomThemeSelector` provides the theme selection interface
- **Sync**: Real-time synchronization via Parse LiveQuery for non-host participants

### File Structure
```
lib/
├── models/LiveStreamingModel.dart          # Theme storage
├── home/controller/controller.dart         # Theme state management
├── home/prebuild_live/
│   ├── prebuild_audio_room_screen.dart    # Main audio room with dynamic background
│   └── room_theme_selector.dart           # Theme selection widget
assets/images/backgrounds/
├── theme_default.png                      # Default theme
├── theme_forest.png                       # Forest theme
└── theme_gradient.jpg                     # Gradient theme
```

### Key Features
- ✅ **Host-Only Control**: Only hosts can change themes
- ✅ **Real-Time Sync**: All participants see theme changes instantly
- ✅ **Fallback Support**: Graceful fallback to default theme if loading fails
- ✅ **Extensible**: Easy to add new themes without code changes
- ✅ **Performance**: Optimized image loading and caching
- ✅ **Persistence**: Theme selection is saved to backend

### Performance Considerations
- **Image Size**: Keep background images under 500KB for optimal performance
- **Resolution**: Recommended resolution: 1080x1920 (9:16 aspect ratio)
- **Format**: PNG for images with transparency, JPG for solid backgrounds
- **Caching**: Images are cached automatically by Flutter's asset system

### Testing
1. **Host Flow**: Test theme selection and application as host
2. **Participant Flow**: Test real-time theme updates as participant
3. **Network Issues**: Test fallback behavior with poor connectivity
4. **Performance**: Test with multiple theme switches during active session

## Usage Instructions

### For Hosts
1. Join an audio room as host
2. Look for the palette icon (🎨) in the bottom menu
3. Tap to open theme selector
4. Select desired theme from grid
5. Tap "Apply Theme" to update room background
6. All participants will see the new theme instantly

### For Participants
- Participants will automatically see theme changes made by the host
- A notification will appear when the host changes the theme
- No action required from participants

## Troubleshooting

### Theme Not Loading
- Check if image file exists in `assets/images/backgrounds/`
- Verify file extension matches the `getThemePath` logic
- Run `flutter clean` and `flutter pub get` to refresh assets

### Theme Not Syncing
- Ensure Parse LiveQuery is properly configured
- Check network connectivity
- Verify `LiveStreamingModel.keyRoomTheme` field is being saved

### Performance Issues
- Reduce image file sizes
- Check for memory leaks in theme switching
- Monitor network usage during theme changes

## Future Enhancements
- [ ] Theme categories (Nature, Abstract, Seasonal, etc.)
- [ ] Custom theme upload by hosts
- [ ] Theme preview before applying
- [ ] Animated theme transitions
- [ ] Theme scheduling (auto-change based on time)
- [ ] User-specific theme preferences
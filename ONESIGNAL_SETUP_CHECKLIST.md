# OneSignal Setup Checklist

## 🔧 Dashboard Configuration

### 1. App Settings
- [ ] App ID: `6bba40d5-5f22-439b-b8b1-3652dbc8c182`
- [ ] App Name: Joytox
- [ ] Platform: Android & iOS

### 2. Android Configuration
- [ ] **Google Services File**: Upload `android/app/google-services.json`
- [ ] **Default Notification Icon**: Upload app icon (24x24dp)
- [ ] **Accent Color**: Set to your brand color
- [ ] **Sound**: Enabled
- [ ] **Vibration**: Enabled
- [ ] **Notification Channel**: `high_importance_channel`

### 3. iOS Configuration
- [ ] **GoogleService-Info.plist**: Upload `ios/GoogleService-Info.plist`
- [ ] **Default Notification Icon**: Upload app icon
- [ ] **Sound**: Enabled
- [ ] **Badge**: Enabled
- [ ] **APNs Certificate**: Uploaded and valid

### 4. Notification Channels (Android)
- [ ] Channel ID: `high_importance_channel`
- [ ] Channel Name: "High Importance Notifications"
- [ ] Importance: High
- [ ] Sound: Enabled
- [ ] Vibration: Enabled

## 🧪 Testing Steps

### 1. Device Registration Test
1. Install app on physical device
2. Open app and log in
3. Check console logs for OneSignal ID
4. Go to OneSignal Dashboard → Audience → All Users
5. Verify device appears in the list

### 2. Permission Test
1. Uninstall and reinstall app
2. Launch app
3. Grant notification permission when prompted
4. Check debug screen: `/   `-debug`

### 3. Notification Test
1. From OneSignal Dashboard → Messages → New Push
2. Select "All Users" as audience
3. Send test message
4. Verify notification appears on device

## 🐛 Common Issues & Solutions

### Issue: 0 Recipients
**Causes:**
- OneSignal not initialized properly
- Notification permission denied
- Firebase files not uploaded
- App not opened after install

**Solutions:**
1. Check console logs for OneSignal initialization
2. Verify notification permissions
3. Upload correct Firebase files
4. Test on physical device (not emulator)

### Issue: Notifications Not Received
**Causes:**
- Device not registered
- Permission denied
- App in foreground (notifications may not show)
- Battery optimization blocking notifications

**Solutions:**
1. Check device registration in dashboard
2. Verify notification permissions
3. Test with app in background/closed
4. Disable battery optimization for your app

### Issue: Permission Dialog Not Appearing
**Causes:**
- OneSignal not initialized early enough
- Permission already denied
- Testing on emulator

**Solutions:**
1. Check early initialization in main.dart
2. Clear app data and reinstall
3. Test on physical device
4. Check device notification settings

## 📱 Debug Commands

### Check Registration Status
```dart
// Navigate to debug screen
Navigator.pushNamed(context, "/onesignal-debug");
```

### Force Re-registration
```dart
// In debug screen, tap "Force Initialize OneSignal"
```

### Check Console Logs
Look for these logs:
```
🚀 Early OneSignal initialization starting...
📱 Early notification permission granted: true
🆔 OneSignal ID after early init: [some-id]
✅ OneSignal early initialization and registration successful
```

## 🎯 Expected Results

After proper setup:
- [ ] OneSignal dashboard shows registered devices
- [ ] Notification permission dialog appears on first launch
- [ ] Test notifications are received
- [ ] Console logs show successful initialization
- [ ] Debug screen shows all green values

## 📞 Support

If issues persist:
1. Check OneSignal documentation
2. Verify Firebase configuration
3. Test on different devices
4. Check OneSignal dashboard logs

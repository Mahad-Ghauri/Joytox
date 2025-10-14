import 'package:flutter/material.dart';
import 'package:trace/helpers/quick_help.dart';
import 'package:trace/services/firebase_notification_service.dart';
import 'package:trace/models/UserModel.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';

class FirebaseDebugScreen extends StatefulWidget {
  const FirebaseDebugScreen({Key? key}) : super(key: key);

  @override
  _FirebaseDebugScreenState createState() => _FirebaseDebugScreenState();
}

class _FirebaseDebugScreenState extends State<FirebaseDebugScreen> {
  Map<String, dynamic> debugInfo = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _runDebug();
  }

  Future<void> _runDebug() async {
    setState(() => isLoading = true);

    try {
      final info = await FirebaseNotificationService.getNotificationStatus();
      setState(() {
        debugInfo = info;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        debugInfo = {'error': e.toString()};
        isLoading = false;
      });
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() => isLoading = true);

    try {
      UserModel? currentUser = await ParseUser.currentUser() as UserModel?;
      if (currentUser != null) {
        // Send test notification to self
        await FirebaseNotificationService.sendTestNotification(
            currentUser, currentUser);
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "Success",
          message: "Test notification sent!",
          isError: false,
        );
      } else {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "Error",
          message: "No current user found",
          isError: true,
        );
      }

      // Refresh debug info
      await _runDebug();
    } catch (e) {
      setState(() => isLoading = false);
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "Error",
        message: "Error: $e",
        isError: true,
      );
    }
  }

  Future<void> _getFCMToken() async {
    setState(() => isLoading = true);

    try {
      String? token = await FirebaseNotificationService.getFCMToken();
      if (token != null) {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "FCM Token",
          message: "Token: ${token.substring(0, 50)}...",
          isError: false,
        );
      } else {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "Error",
          message: "No FCM token available",
          isError: true,
        );
      }

      // Refresh debug info
      await _runDebug();
    } catch (e) {
      setState(() => isLoading = false);
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "Error",
        message: "Error: $e",
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Firebase Debug"),
        backgroundColor:
            QuickHelp.isDarkMode(context) ? Colors.black : Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _runDebug,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildActionButtons(),
                  SizedBox(height: 20),
                  _buildDebugInfo(),
                  SizedBox(height: 20),
                  _buildInstructions(),
                ],
              ),
            ),
    );
  }

  Widget _buildActionButtons() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Actions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _getFCMToken,
              child: Text("Get FCM Token"),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _sendTestNotification,
              child: Text("Send Test Notification"),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _runDebug,
              child: Text("Refresh Debug Info"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Debug Information",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            ...debugInfo.entries
                .map((entry) => _buildInfoRow(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String key, dynamic value) {
    Color valueColor = Colors.black;
    if (key.contains('error') || key.contains('Error')) {
      valueColor = Colors.red;
    } else if (key.contains('success') ||
        key.contains('true') ||
        key.contains('Token') ||
        key.contains('authorized')) {
      valueColor = Colors.green;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$key:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.toString(),
              style: TextStyle(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Firebase FCM Status",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text("1. Check if Firebase is properly configured"),
            Text("2. Verify notification permissions are granted"),
            Text("3. Ensure FCM token is generated"),
            Text("4. Check Firebase Console for message delivery"),
            Text("5. Test on physical device (not emulator)"),
            Text("6. Verify google-services.json is properly configured"),
            SizedBox(height: 10),
            Text(
              "Expected Values:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text("• hasPermission: true"),
            Text("• isInitialized: true"),
            Text("• authorizationStatus: AuthorizationStatus.authorized"),
            Text("• fcmToken: [should have a value]"),
          ],
        ),
      ),
    );
  }
}

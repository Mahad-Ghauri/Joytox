// Flutter imports:
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Project imports:
import '../../models/LiveStreamingModel.dart';
import '../../models/UserModel.dart';
import '../controller/controller.dart';
import '../../ui/container_with_corner.dart';
import '../../ui/text_with_tap.dart';
import '../../utils/colors.dart';
import '../../helpers/quick_help.dart';

class RoomThemeSelector extends StatefulWidget {
  final UserModel currentUser;
  final LiveStreamingModel liveStreaming;
  final Function(String) onThemeSelected;

  const RoomThemeSelector({
    Key? key,
    required this.currentUser,
    required this.liveStreaming,
    required this.onThemeSelected,
  }) : super(key: key);

  @override
  State<RoomThemeSelector> createState() => _RoomThemeSelectorState();
}

class _RoomThemeSelectorState extends State<RoomThemeSelector> {
  final Controller controller = Get.find<Controller>();

  @override
  void initState() {
    super.initState();
    // Initialize current theme from live streaming model
    controller.selectedRoomTheme.value =
        widget.liveStreaming.getRoomTheme ?? 'theme_default';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: QuickHelp.isDarkMode(context)
            ? kContentColorLightTheme
            : kContentColorDarkTheme,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextWithTap(
                  "Select Room Theme",
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: QuickHelp.isDarkMode(context)
                      ? Colors.white
                      : Colors.black,
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: QuickHelp.isDarkMode(context)
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // Theme Grid
          Expanded(
            child: Obx(() => GridView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: controller.availableThemes.length,
                  itemBuilder: (context, index) {
                    final theme = controller.availableThemes[index];
                    final isSelected =
                        controller.selectedRoomTheme.value == theme;

                    return _buildThemeCard(theme, isSelected);
                  },
                )),
          ),

          // Apply Button
          Container(
            padding: EdgeInsets.all(20),
            child: ContainerCorner(
              height: 50,
              width: double.infinity,
              borderRadius: 25,
              colors: [kPrimaryColor, kSecondaryColor],
              onTap: _applyTheme,
              child: Center(
                child: TextWithTap(
                  "Apply Theme",
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(String theme, bool isSelected) {
    return GestureDetector(
      onTap: () => controller.updateRoomTheme(theme),
      child: ContainerCorner(
        borderRadius: 15,
        borderWidth: isSelected ? 3 : 1,
        borderColor:
            isSelected ? kPrimaryColor : Colors.grey.withValues(alpha: 0.3),
        child: Stack(
          children: [
            // Theme Preview
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: Image.asset(
                  controller.getThemePath(theme),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.withValues(alpha: 0.3),
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 40,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Theme Name Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  ),
                ),
                child: TextWithTap(
                  _getThemeDisplayName(theme),
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Selection Indicator
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getThemeDisplayName(String theme) {
    switch (theme) {
      case 'theme_default':
        return "Default";
      case 'theme_forest':
        return "Forest";
      case 'theme_gradient':
        return "Gradient";
      default:
        return theme
            .replaceAll('theme_', '')
            .replaceAll('_', ' ')
            .toUpperCase();
    }
  }

  void _applyTheme() async {
    try {
      final selectedTheme = controller.selectedRoomTheme.value;

      // Update the live streaming model
      widget.liveStreaming.setRoomTheme = selectedTheme;

      // Save to backend
      final response = await widget.liveStreaming.save();

      if (response.success) {
        // Call the callback to update the UI
        widget.onThemeSelected(selectedTheme);

        // Show success message
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "Theme Applied",
          message: "Room theme has been updated successfully!",
          isError: false,
        );

        // Close the selector
        Navigator.of(context).pop();
      } else {
        // Show error message
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "Error",
          message: "Failed to apply theme. Please try again.",
          isError: true,
        );
      }
    } catch (e) {
      print("Error applying theme: $e");
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "Error",
        message: "Failed to apply theme. Please try again.",
        isError: true,
      );
    }
  }
}

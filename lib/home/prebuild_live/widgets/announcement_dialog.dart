import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../utils/colors.dart';
import '../../../helpers/quick_help.dart';
import '../../../ui/text_with_tap.dart';
import '../../../ui/container_with_corner.dart';

class AnnouncementDialog extends StatefulWidget {
  final Function(String title, String message, String priority, int duration)
      onSend;

  const AnnouncementDialog({
    Key? key,
    required this.onSend,
  }) : super(key: key);

  @override
  State<AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<AnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedPriority = 'Normal';
  int _selectedDuration = 10;

  final List<String> _priorities = ['Low', 'Normal', 'Medium', 'High'];
  final List<int> _durations = [5, 10, 15, 20, 30, 45, 60];

  bool get _isFormValid {
    return _titleController.text.trim().isNotEmpty &&
        _messageController.text.trim().isNotEmpty &&
        _selectedPriority.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
    _messageController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = QuickHelp.isDarkMode(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      backgroundColor:
          isDark ? kContentColorLightTheme : kContentColorDarkTheme,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.campaign, color: kPrimaryColor, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextWithTap(
                        "Announcement".tr(),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Title Field
                _buildLabel("Title".tr(), isDark),
                _buildTextField(
                  controller: _titleController,
                  hint: "announcement_title_hint".tr(),
                  maxLength: 50,
                  isDark: isDark,
                  validatorText: "announcement_title_required".tr(),
                ),
                const SizedBox(height: 14),

                // Message Field
                _buildLabel("Message".tr(), isDark),
                _buildTextField(
                  controller: _messageController,
                  hint: "announcement_message_hint".tr(),
                  maxLength: 200,
                  maxLines: 3,
                  isDark: isDark,
                  validatorText: "announcement_message_required".tr(),
                ),
                const SizedBox(height: 16),

                // Priority and Duration Row - FIXED
                Row(
                  children: [
                    Flexible(
                      flex: 3,
                      child: _buildDropdown<String>(
                        label: "Priority_label".tr(),
                        value: _selectedPriority,
                        items: _priorities.map((priority) {
                          return DropdownMenuItem(
                            value: priority,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _getPriorityIcon(priority),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    priority,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPriority = value!;
                          });
                        },
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      flex: 2,
                      child: _buildDropdown<int>(
                        label: "Duration_label".tr(),
                        value: _selectedDuration,
                        items: _durations.map((duration) {
                          return DropdownMenuItem(
                            value: duration,
                            child: Text("${duration}s"),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDuration = value!;
                          });
                        },
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildButton(
                        text: "cancel".tr(),
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        textColor: isDark ? Colors.white70 : Colors.black87,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildButton(
                        text: "Send".tr(),
                        color: _isFormValid
                            ? kPrimaryColor
                            : (isDark
                                ? Colors.grey[600]!
                                : Colors.grey[400]!),
                        textColor: Colors.white,
                        onPressed: _isFormValid ? _sendAnnouncement : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return TextWithTap(
      text,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white70 : Colors.black87,
      marginBottom: 8,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    required bool isDark,
    required String validatorText,
    int maxLines = 1,
  }) {
    return ContainerCorner(
      borderRadius: 12,
      color: isDark ? Colors.grey[800] : Colors.grey[100],
      child: TextFormField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: isDark ? Colors.white38 : Colors.black38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          counterText: "${controller.text.length}/$maxLength",
          counterStyle: TextStyle(
            color: isDark ? Colors.white54 : Colors.black54,
            fontSize: 12,
          ),
        ),
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return validatorText;
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isDark),
        ContainerCorner(
          borderRadius: 12,
          color: isDark ? Colors.grey[800] : Colors.grey[100],
          child: DropdownButtonFormField<T>(
            value: value,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            dropdownColor: isDark ? Colors.grey[800] : Colors.grey[100],
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required Color textColor,
    required VoidCallback? onPressed,
  }) {
    return ContainerCorner(
      borderRadius: 12,
      color: color,
      child: TextButton(
        onPressed: onPressed,
        child: TextWithTap(
          text,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _getPriorityIcon(String priority) {
    Color color;
    IconData icon;
    switch (priority) {
      case 'High':
        color = Colors.red;
        icon = Icons.priority_high;
        break;
      case 'Medium':
        color = Colors.orange;
        icon = Icons.warning;
        break;
      case 'Normal':
        color = Colors.blue;
        icon = Icons.info;
        break;
      case 'Low':
        color = Colors.green;
        icon = Icons.low_priority;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
    }
    return Icon(icon, color: color, size: 16);
  }

  void _sendAnnouncement() {
    if (_formKey.currentState!.validate() && _isFormValid) {
      widget.onSend(
        _titleController.text.trim(),
        _messageController.text.trim(),
        _selectedPriority,
        _selectedDuration,
      );
      Navigator.of(context).pop();
    }
  }
}
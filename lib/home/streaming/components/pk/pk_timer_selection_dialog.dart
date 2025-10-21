import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PKTimerSelectionDialog extends StatefulWidget {
  const PKTimerSelectionDialog({super.key});

  @override
  State<PKTimerSelectionDialog> createState() => _PKTimerSelectionDialogState();
}

class _PKTimerSelectionDialogState extends State<PKTimerSelectionDialog> {
  int selectedDuration = 3; // Default to 3 minutes
  final List<int> durationOptions = [3, 10, 15]; // Duration options in minutes

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('Select Battle Duration'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: durationOptions.map((duration) {
          return CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 8),
            onPressed: () {
              setState(() {
                selectedDuration = duration;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$duration minutes',
                  style: TextStyle(
                    fontSize: 16,
                    color: selectedDuration == duration
                        ? CupertinoColors.activeBlue
                        : CupertinoColors.label,
                    fontWeight: selectedDuration == duration
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                if (selectedDuration == duration)
                  const Icon(
                    CupertinoIcons.checkmark,
                    color: CupertinoColors.activeBlue,
                    size: 20,
                  ),
              ],
            ),
          );
        }).toList(),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(selectedDuration),
          child: const Text('Start Battle'),
        ),
      ],
    );
  }
}

// Extension to show the dialog easily
extension PKTimerSelectionDialogExtension on BuildContext {
  Future<int?> showPKTimerSelectionDialog() {
    return showCupertinoDialog<int>(
      context: this,
      barrierDismissible: true,
      builder: (context) => const PKTimerSelectionDialog(),
    );
  }
}

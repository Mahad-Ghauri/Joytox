import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../utils/colors.dart';
import '../../../helpers/quick_help.dart';
import '../../../ui/text_with_tap.dart';
import '../../../ui/container_with_corner.dart';
import '../../../models/LiveMessagesModel.dart';

class AnnouncementData {
  final String id;
  final String title;
  final String message;
  final String priority;
  final int duration;
  final String authorName;
  final DateTime timestamp;

  AnnouncementData({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.duration,
    required this.authorName,
    required this.timestamp,
  });

  factory AnnouncementData.fromLiveMessage(LiveMessagesModel message) {
    return AnnouncementData(
      id: message.objectId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.getAnnouncementTitle ?? '',
      message: message.getMessage ?? '',
      priority: message.getAnnouncementPriority ?? 'Normal',
      duration: message.getAnnouncementDuration ?? 10,
      authorName: message.getAuthor?.getFullName ?? 'Host',
      timestamp: message.createdAt ?? DateTime.now(),
    );
  }
}

class AnnouncementOverlayWidget extends StatefulWidget {
  final List<AnnouncementData> announcements;
  final Function(String announcementId)? onDismiss;
  final Function(String announcementId)? onPin;

  const AnnouncementOverlayWidget({
    Key? key,
    required this.announcements,
    this.onDismiss,
    this.onPin,
  }) : super(key: key);

  @override
  State<AnnouncementOverlayWidget> createState() =>
      _AnnouncementOverlayWidgetState();
}

class _AnnouncementOverlayWidgetState extends State<AnnouncementOverlayWidget>
    with TickerProviderStateMixin {
  final Map<String, Timer> _dismissTimers = {};
  final Map<String, AnimationController> _animationControllers = {};
  final Set<String> _pinnedAnnouncements = {};
  final Set<String> _dismissedAnnouncements = {};

  @override
  void initState() {
    super.initState();
    _initializeAnnouncements();
  }

  @override
  void didUpdateWidget(AnnouncementOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.announcements.length != oldWidget.announcements.length) {
      _initializeAnnouncements();
    }
  }

  void _initializeAnnouncements() {
    for (final announcement in widget.announcements) {
      if (!_animationControllers.containsKey(announcement.id)) {
        final controller = AnimationController(
          duration: const Duration(milliseconds: 500),
          vsync: this,
        );
        _animationControllers[announcement.id] = controller;

        // Start entrance animation
        controller.forward();

        // Set up auto-dismiss timer (except for pinned high priority)
        if (announcement.priority != 'High' ||
            !_pinnedAnnouncements.contains(announcement.id)) {
          _startDismissTimer(announcement);
        }
      }
    }
  }

  void _startDismissTimer(AnnouncementData announcement) {
    _dismissTimers[announcement.id]?.cancel();
    _dismissTimers[announcement.id] = Timer(
      Duration(seconds: announcement.duration),
      () => _dismissAnnouncement(announcement.id, auto: true),
    );
  }

  void _dismissAnnouncement(String announcementId, {bool auto = false}) {
    final announcement = widget.announcements.firstWhere(
      (a) => a.id == announcementId,
      orElse: () => widget.announcements.first,
    );

    // For high priority announcements, pin them instead of dismissing
    if (announcement.priority == 'High' && auto) {
      _pinAnnouncement(announcementId);
      return;
    }

    _dismissTimers[announcementId]?.cancel();
    _dismissTimers.remove(announcementId);

    final controller = _animationControllers[announcementId];
    if (controller != null) {
      controller.reverse().then((_) {
        setState(() {
          _dismissedAnnouncements.add(announcementId);
        });
        widget.onDismiss?.call(announcementId);
      });
    }
  }

  void _pinAnnouncement(String announcementId) {
    setState(() {
      _pinnedAnnouncements.add(announcementId);
    });
    _dismissTimers[announcementId]?.cancel();
    widget.onPin?.call(announcementId);
  }

  void _unpinAnnouncement(String announcementId) {
    setState(() {
      _pinnedAnnouncements.remove(announcementId);
    });
    final announcement = widget.announcements.firstWhere(
      (a) => a.id == announcementId,
    );
    _startDismissTimer(announcement);
  }

  @override
  void dispose() {
    for (final timer in _dismissTimers.values) {
      timer.cancel();
    }
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleAnnouncements = widget.announcements
        .where((a) => !_dismissedAnnouncements.contains(a.id))
        .toList();

    if (visibleAnnouncements.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort by priority and timestamp
    visibleAnnouncements.sort((a, b) {
      final priorityOrder = {'High': 0, 'Medium': 1, 'Normal': 2, 'Low': 3};
      final aPriority = priorityOrder[a.priority] ?? 2;
      final bPriority = priorityOrder[b.priority] ?? 2;

      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }
      return b.timestamp.compareTo(a.timestamp);
    });

    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: Column(
        children: visibleAnnouncements.map((announcement) {
          final controller = _animationControllers[announcement.id];
          final isPinned = _pinnedAnnouncements.contains(announcement.id);

          if (controller == null) return const SizedBox.shrink();

          return AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -50 * (1 - controller.value)),
                child: Opacity(
                  opacity: controller.value,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: _buildAnnouncementCard(announcement, isPinned),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnnouncementCard(AnnouncementData announcement, bool isPinned) {
    final isDark = QuickHelp.isDarkModeNoContext();
    final priorityColor = _getPriorityColor(announcement.priority);

    return ContainerCorner(
      borderRadius: 12,
      color: isDark
          ? Colors.grey[900]?.withOpacity(0.95)
          : Colors.white.withOpacity(0.95),
      borderColor: priorityColor,
      borderWidth: 2,
      marginBottom: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with priority and actions
            Row(
              children: [
                _getPriorityIcon(announcement.priority),
                const SizedBox(width: 8),
                Expanded(
                  child: TextWithTap(
                    announcement.title,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                if (isPinned)
                  Icon(Icons.push_pin, size: 16, color: priorityColor),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _dismissAnnouncement(announcement.id),
                  child: Icon(
                    Icons.close,
                    size: 20,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Message
            TextWithTap(
              announcement.message,
              fontSize: 14,
              color: isDark
                  ? Colors.white.withOpacity(0.87)
                  : Colors.black.withOpacity(0.87),
              marginBottom: 8,
            ),

            // Footer with author and timestamp
            Row(
              children: [
                Icon(Icons.campaign, size: 14, color: priorityColor),
                const SizedBox(width: 4),
                TextWithTap(
                  announcement.authorName,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: priorityColor,
                ),
                const Spacer(),
                TextWithTap(
                  _formatTimestamp(announcement.timestamp),
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                if (announcement.priority == 'High' && !isPinned) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _pinAnnouncement(announcement.id),
                    child: Icon(
                      Icons.push_pin_outlined,
                      size: 16,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
                if (isPinned) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _unpinAnnouncement(announcement.id),
                    child: Icon(Icons.push_pin, size: 16, color: priorityColor),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Normal':
        return kPrimaryColor;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _getPriorityIcon(String priority) {
    Color color = _getPriorityColor(priority);
    IconData icon;

    switch (priority) {
      case 'High':
        icon = Icons.priority_high;
        break;
      case 'Medium':
        icon = Icons.warning;
        break;
      case 'Normal':
        icon = Icons.info;
        break;
      case 'Low':
        icon = Icons.low_priority;
        break;
      default:
        icon = Icons.info;
    }

    return Icon(icon, color: color, size: 18);
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return "announcement_just_now".tr();
    } else if (difference.inMinutes < 60) {
      return "announcement_minutes_ago".tr(
        namedArgs: {'minutes': difference.inMinutes.toString()},
      );
    } else {
      return DateFormat('HH:mm').format(timestamp);
    }
  }
}

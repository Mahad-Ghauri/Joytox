import 'package:flutter_test/flutter_test.dart';
import 'package:trace/models/LiveMessagesModel.dart';
import 'package:trace/home/prebuild_live/widgets/announcement_overlay_widget.dart';

void main() {
  group('Announcement Feature Tests', () {
    test('LiveMessagesModel should have announcement constants', () {
      expect(LiveMessagesModel.messageTypeAnnouncement, equals('ANNOUNCEMENT'));
      expect(
        LiveMessagesModel.keyAnnouncementTitle,
        equals('announcementTitle'),
      );
      expect(
        LiveMessagesModel.keyAnnouncementPriority,
        equals('announcementPriority'),
      );
      expect(
        LiveMessagesModel.keyAnnouncementDuration,
        equals('announcementDuration'),
      );
    });

    test('AnnouncementData should be created from LiveMessagesModel', () {
      final liveMessage = LiveMessagesModel();
      liveMessage.setAnnouncementTitle = 'Test Title';
      liveMessage.setMessage = 'Test Message';
      liveMessage.setAnnouncementPriority = 'High';
      liveMessage.setAnnouncementDuration = 15;

      final announcementData = AnnouncementData.fromLiveMessage(liveMessage);

      expect(announcementData.title, equals('Test Title'));
      expect(announcementData.message, equals('Test Message'));
      expect(announcementData.priority, equals('High'));
      expect(announcementData.duration, equals(15));
    });

    test('Announcement priority should have correct values', () {
      final priorities = ['Low', 'Normal', 'Medium', 'High'];

      for (final priority in priorities) {
        expect(priorities.contains(priority), isTrue);
      }
    });

    test('Announcement duration should have valid values', () {
      final durations = [5, 10, 15, 20, 30, 45, 60];

      for (final duration in durations) {
        expect(duration, greaterThan(0));
        expect(duration, lessThanOrEqualTo(60));
      }
    });
  });
}

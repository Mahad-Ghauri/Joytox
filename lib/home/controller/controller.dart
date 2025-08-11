import 'package:get/get.dart';
import 'package:trace/models/GiftsModel.dart';
import 'package:trace/models/UserModel.dart';

import '../../app/Config.dart';

class Controller extends GetxController {
  var countryCode = Config.initialCountry.obs;
  var emptyField = true.obs;
  var shareMediaFiles = false.obs;
  var isBattleLive = false.obs;
  var searchText = "".obs;
  var diamondsCounter = "0".obs;
  var battleTimer = 0.obs;
  var hisBattlePoints = 0.obs;
  var myBattlePoints = 0.obs;
  var myBattleVictories = 0.obs;
  var hisBattleVictories = 0.obs;
  var showBattleWinner = false.obs;
  var isPrivateLive = false.obs;
  var isFollowing = false.obs;

  // Per-seat state management
  var selectedSeatIndex = (-1).obs;

  var showSeatMenu = false.obs;

  var receivedGiftList = <GiftsModel>[].obs;
  var giftSenderList = <UserModel>[].obs;
  var giftReceiverList = <UserModel>[].obs;

  // Seat management state
  var seatStates = <int, Map<String, dynamic>>{}.obs;

  // Announcement management state
  var activeAnnouncements = <String>[].obs;
  var pinnedAnnouncements = <String>[].obs;

  updateCountryCode(String code) {
    countryCode.value = code;
  }

  updateSearchField(String text) {
    emptyField.value = text.isEmpty;
  }

  // Seat management methods
  void initializeSeatStates(int totalSeats) {
    seatStates.clear();
    for (int i = 0; i < totalSeats; i++) {
      seatStates[i] = {
        'isLocked': false,
        'isMuted': false,
        'userId': null,
        'userName': null,
      };
    }
  }

  void updateSeatState(int seatIndex, String key, dynamic value) {
    if (!seatStates.containsKey(seatIndex)) {
      seatStates[seatIndex] = {
        'isLocked': false,
        'isMuted': false,
        'userId': null,
        'userName': null,
      };
    }
    seatStates[seatIndex]![key] = value;
    seatStates.refresh();
  }

  Map<String, dynamic>? getSeatState(int seatIndex) {
    return seatStates[seatIndex];
  }

  void lockSeat(int seatIndex) {
    updateSeatState(seatIndex, 'isLocked', true);
  }

  void unlockSeat(int seatIndex) {
    updateSeatState(seatIndex, 'isLocked', false);
  }

  void muteSeat(int seatIndex) {
    updateSeatState(seatIndex, 'isMuted', true);
  }

  void unmuteSeat(int seatIndex) {
    updateSeatState(seatIndex, 'isMuted', false);
  }

  void selectSeat(int seatIndex) {
    selectedSeatIndex.value = seatIndex;
    showSeatMenu.value = true;
  }

  void closeSeatMenu() {
    showSeatMenu.value = false;
    selectedSeatIndex.value = -1;
  }

  // Announcement management methods
  void addAnnouncement(String announcementId) {
    if (!activeAnnouncements.contains(announcementId)) {
      activeAnnouncements.add(announcementId);
    }
  }

  void removeAnnouncement(String announcementId) {
    activeAnnouncements.remove(announcementId);
    pinnedAnnouncements.remove(announcementId);
  }

  void pinAnnouncement(String announcementId) {
    if (!pinnedAnnouncements.contains(announcementId)) {
      pinnedAnnouncements.add(announcementId);
    }
  }

  void unpinAnnouncement(String announcementId) {
    pinnedAnnouncements.remove(announcementId);
  }

  bool isAnnouncementPinned(String announcementId) {
    return pinnedAnnouncements.contains(announcementId);
  }

  void clearAllAnnouncements() {
    activeAnnouncements.clear();
    pinnedAnnouncements.clear();
  }
}

import 'package:get/get.dart';
import 'package:trace/app/config.dart';
import 'package:trace/models/GiftsModel.dart';
import 'package:trace/models/UserModel.dart';

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

  // Room theme management state
  var selectedRoomTheme = 'theme_default'.obs;
  var availableThemes =
      <String>['theme_default', 'theme_forest', 'theme_gradient'].obs;

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
        'isLocked': i == 0, // Host seat (index 0) is locked by default
        'isMuted': false,
        'userId': null,
        'userName': null,
      };
    }
  }

  void updateSeatState(int seatIndex, String key, dynamic value) {
    print("🔧 updateSeatState($seatIndex, '$key', $value)");

    if (!seatStates.containsKey(seatIndex)) {
      print("🔧 Creating new seat state for index $seatIndex");
      seatStates[seatIndex] = {
        'isLocked': false,
        'isMuted': false,
        'userId': null,
        'userName': null,
      };
    }

    print("🔧 BEFORE update: ${seatStates[seatIndex]}");

    // Create a new map to ensure reactivity
    Map<String, dynamic> newSeatState = Map.from(seatStates[seatIndex]!);
    newSeatState[key] = value;
    seatStates[seatIndex] = newSeatState;

    print("🔧 AFTER update: ${seatStates[seatIndex]}");
    print("🔧 Triggering refresh for seat $seatIndex only");

    // Force update for this specific seat
    seatStates.refresh();
  }

  Map<String, dynamic>? getSeatState(int seatIndex) {
    final state = seatStates[seatIndex];
    print("🔍 getSeatState($seatIndex): $state");
    return state;
  }

  // Add method to check if seat is locked
  bool isSeatLocked(int seatIndex) {
    final state = getSeatState(seatIndex);
    final isLocked = state?['isLocked'] ?? false;
    print("🔍 isSeatLocked($seatIndex): $isLocked");
    return isLocked;
  }

  // Add method to validate seat states
  void validateSeatStates() {
    print("🔍 SEAT STATES VALIDATION:");
    seatStates.forEach((index, state) {
      print("🔍 Seat $index: $state");
    });
  }

  void lockSeat(int seatIndex) {
    print(
        "🔒 Controller.lockSeat($seatIndex) - BEFORE: ${seatStates[seatIndex]}");
    updateSeatState(seatIndex, 'isLocked', true);
    print(
        "🔒 Controller.lockSeat($seatIndex) - AFTER: ${seatStates[seatIndex]}");
    print("🔒 All seat states: $seatStates");
  }

  void unlockSeat(int seatIndex) {
    print(
        "🔓 Controller.unlockSeat($seatIndex) - BEFORE: ${seatStates[seatIndex]}");
    updateSeatState(seatIndex, 'isLocked', false);
    print(
        "🔓 Controller.unlockSeat($seatIndex) - AFTER: ${seatStates[seatIndex]}");
    print("🔓 All seat states: $seatStates");
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

  // Theme management methods
  void updateRoomTheme(String theme) {
    if (availableThemes.contains(theme)) {
      selectedRoomTheme.value = theme;
    }
  }

  String getThemePath(String theme) {
    // Check if it's a jpg or png file
    if (theme == 'theme_gradient') {
      return "assets/images/backgrounds/$theme.jpg";
    }
    return "assets/images/backgrounds/$theme.png";
  }

  void addNewTheme(String themeName) {
    if (!availableThemes.contains(themeName)) {
      availableThemes.add(themeName);
    }
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

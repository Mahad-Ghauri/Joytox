import 'dart:convert';

import 'package:flutter/foundation.dart';

class PKExtendedData {
  String? roomID;
  String? userName;
  int type = 91000;
  String userID = '';
  bool autoAccept = false;
  int? durationMinutes;

  static const START_PK = 91000;

  static PKExtendedData? parse(String extendedData) {
    late Map<String, dynamic> extendedDataMap;
    try {
      extendedDataMap = jsonDecode(extendedData);
    } catch (e) {
      debugPrint('parse json fail');
      return null;
    }
    if (extendedDataMap.keys.contains('type')) {
      final type = extendedDataMap['type'] as int;
      if (type == START_PK) {
        final data = PKExtendedData()
          ..type = type
          ..roomID = extendedDataMap['room_id'] as String
          ..userName = extendedDataMap['user_name'] as String;
        if (extendedDataMap.keys.contains('user_id')) {
          data.userID = extendedDataMap['user_id'] as String;
        }
        if (extendedDataMap.keys.contains('auto_accept')) {
          data.autoAccept = extendedDataMap['auto_accept'] as bool;
        }
        if (extendedDataMap.keys.contains('duration')) {
          final dynamic dur = extendedDataMap['duration'];
          if (dur is int) {
            data.durationMinutes = dur;
          } else if (dur is String) {
            data.durationMinutes = int.tryParse(dur);
          }
        }
        return data;
      }
    }
    return null;
  }

  String? toJsonString() {
    final map = <String, dynamic>{};
    map['room_id'] = roomID;
    map['user_name'] = userName;
    map['type'] = type;
    if (userID.isNotEmpty) {
      map['user_id'] = userID;
    }
    map['auto_accept'] = autoAccept;
    if (durationMinutes != null && durationMinutes! > 0) {
      map['duration'] = durationMinutes;
    }
    return jsonEncode(map);
  }
}

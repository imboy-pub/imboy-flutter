import 'dart:convert' as json;

import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';
import 'package:ntp/ntp.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// from https://github.com/ducafecat/flutter_ducafecat_news_getx/blob/master/lib/common/services/storage.dart
class StorageService extends GetxService {
  static StorageService get to => Get.find();
  late final SharedPreferences _prefs;

  Future<StorageService> init() async {
    _prefs = await SharedPreferences.getInstance();
    return this;
  }

  Future<bool> setString(String key, String value) async {
    return await _prefs.setString(key, value);
  }

  Future<bool> setMap(String key, Map<String, dynamic> value) async {
    return await _prefs.setString(key, json.jsonEncode(value));
  }

  Future<bool> setBool(String key, bool value) async {
    return await _prefs.setBool(key, value);
  }

  Future<bool> setList(String key, List<String> value) async {
    return await _prefs.setStringList(key, value);
  }

  String getString(String key) {
    return _prefs.getString(key) ?? '';
  }

  Map<String, dynamic> getMap(String key) {
    String val = getString(key);
    if (val == '') {
      return {};
    }
    return json.jsonDecode(val);
  }

  bool getBool(String key) {
    return _prefs.getBool(key) ?? false;
  }

  List<String> getList(String key) {
    return _prefs.getStringList(key) ?? [];
  }

  Future<bool> remove(String key) async {
    return await _prefs.remove(key);
  }

  Future<int> ntpOffset() async {
    String key = "ntp_offset";
    String? val = _prefs.getString(key);
    // debugPrint("> on currentTimeMillis val1 ${val}");
    // val = null;
    int offset = 0;
    if (val == null) {
      try {
        offset = await NTP.getNtpOffset(
          localTime: Jiffy.now().dateTime,
          lookUpAddress: 'time5.cloud.tencent.com',
        );
        // debugPrint("> on currentTimeMillis offset2 ${offset}");
        String dt = Jiffy.now().format(pattern: 'y-MM-dd HH:mm:ss');
        val = '$dt$offset';
        // debugPrint("> on currentTimeMillis val2 ${val}");
        _prefs.setString(key, val);
        // ignore: empty_catches
      } catch (e) {}
    } else {
      // 2022-01-23 00:30:35 字符串的长度刚好19位
      offset = Jiffy.now().diff(
        Jiffy.parse(val.substring(0, 19)),
        unit: Unit.second,
      ) as int;
      if (offset > 3600) {
        await _prefs.remove(key);
        return ntpOffset();
      }
    }
    return offset;
  }
}

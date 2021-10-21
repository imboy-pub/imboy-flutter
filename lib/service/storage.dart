import 'package:get/get.dart';
import 'dart:convert' as JSON;
import 'package:shared_preferences/shared_preferences.dart';

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
    return await _prefs.setString(key, JSON.jsonEncode(value));
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
      return Map();
    }
    return JSON.jsonDecode(val);
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
}

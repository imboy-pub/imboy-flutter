import 'dart:convert' as json;

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// from https://github.com/ducafecat/flutter_ducafecat_news_getx/blob/master/lib/common/services/storage.dart
class StorageService extends GetxService {
  static late final SharedPreferences to;

  static Future<SharedPreferences> init() async =>
      to = await SharedPreferences.getInstance();

  Future<bool> setString(String key, String value) async {
    return await StorageService.to.setString(key, value);
  }

  static Future<bool> setMap(String key, Map<String, dynamic> value) async {
    return await StorageService.to.setString(key, json.jsonEncode(value));
  }

  static Map<String, dynamic> getMap(String key) {
    String? val = StorageService.to.getString(key);
    if (val == '' || val == null) {
      return {};
    }
    return json.jsonDecode(val);
  }

  Future<bool> setBool(String key, bool value) async {
    return await StorageService.to.setBool(key, value);
  }

  Future<bool> setList(String key, List<String> value) async {
    return await StorageService.to.setStringList(key, value);
  }

  String getString(String key) {
    return StorageService.to.getString(key) ?? '';
  }

  bool getBool(String key) {
    return StorageService.to.getBool(key) ?? false;
  }

  List<String> getList(String key) {
    return StorageService.to.getStringList(key) ?? [];
  }

  Future<bool> remove(String key) async {
    return await StorageService.to.remove(key);
  }
}

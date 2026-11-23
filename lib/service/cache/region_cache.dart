import 'package:imboy/service/web_writer_gate.dart';

import 'dart:convert';

import 'package:geo_regions/geo_regions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_preferences.dart';

import 'package:imboy/component/helper/datetime.dart';

/// 地区缓存管理类
///
/// 用途：集中管理地区选择相关的本地缓存操作
/// 包括：选中地区、地区路径、地区列表数据、数据版本等
class RegionCache {
  static const String _keySelectedRegion = 'region_selected';
  static const String _keyRegionPath = 'region_path';
  static const String _keyRegionList = 'region_list';
  static const String _keyDataVersion = 'region_data_version';
  static const String _keyLastUpdateTime = 'region_last_update_time';

  static const legacySelectionPreferenceKey = 'geo_legacy_selection';

  /// 保存同一账号会话已提交的 legacy 值和原始路径分段。
  static Future<void> saveSelection(
    AccountPreferences preferences,
    String value,
    List<String> path,
  ) => preferences.writeList(legacySelectionPreferenceKey, [value, ...path]);

  /// 账号缓存只补充与当前资料精确匹配的路径。
  static List<String>? readSelectionPath(
    AccountPreferences preferences,
    String profileRegion,
  ) {
    if (profileRegion.isEmpty) return null;
    try {
      final saved = preferences.readList(legacySelectionPreferenceKey);
      if (saved.length < 2 || saved.first != profileRegion) return null;
      final path = saved.sublist(1);
      return path.join(' ') == profileRegion ? path : null;
    } on TypeError {
      return null;
    }
  }

  /// 读取尚无归属的旧值供诊断，编辑器不消费它。
  static Future<String> loadSelectedRegion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedRegion) ?? '';
  }

  /// 读取尚无归属的旧路径供诊断，编辑器不消费它。
  static Future<List<String>> loadRegionPath() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyRegionPath) ?? '';
    if (s.isEmpty) return [];
    return s.split(' ').where((e) => e.trim().isNotEmpty).toList();
  }

  /// 保存地区列表数据
  /// 参数：list 地区数据列表（从 region.json 或服务器获取）
  /// 返回：`Future<void>`
  /// 异常：JSON 序列化异常或 SharedPreferences 操作异常
  static Future<void> saveRegionList(List<dynamic> list) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(list);
    requireWebWriter();
    await prefs.setString(_keyRegionList, json);

    // 同时更新最后更新时间
    requireWebWriter();
    await prefs.setInt(_keyLastUpdateTime, DateTimeHelper.millisecond());
  }

  /// 加载地区列表数据
  /// 参数：无
  /// 返回：`Future<List<dynamic>>` 地区数据列表，无缓存或解析失败时返回空列表
  /// 异常：JSON 解析异常时返回空列表
  static Future<List<dynamic>> loadRegionList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyRegionList);
    if (jsonStr == null) return [];
    try {
      return jsonDecode(jsonStr) as List<dynamic>;
    } catch (e) {
      return [];
    }
  }

  /// 保存地区数据版本号（后端对接占位方法）
  /// 用途：记录当前缓存数据对应的服务器版本，用于版本比较
  /// 参数：version 版本号字符串（格式待后端 API 确认，建议使用语义化版本如 "1.0.0" 或时间戳）
  /// 返回：`Future<void>`
  /// 异常：SharedPreferences 操作异常
  ///
  /// 注意：版本号格式需要与后端 API 对齐，当前实现为通用字符串存储
  static Future<void> saveDataVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    requireWebWriter();
    await prefs.setString(_keyDataVersion, version);
  }

  /// 获取地区数据版本号（后端对接占位方法）
  /// 用途：获取当前缓存数据的版本号，用于与服务器版本比较
  /// 参数：无
  /// 返回：`Future<String>` 版本号字符串，无缓存时返回空字符串
  /// 异常：SharedPreferences 操作异常
  ///
  /// 注意：返回值格式取决于 saveDataVersion 的存储格式
  static Future<String> getDataVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDataVersion) ?? '';
  }

  /// 获取最后更新时间
  /// 用途：获取地区数据最后更新的时间戳，用于判断数据新鲜度
  /// 参数：无
  /// 返回：`Future<int>` 时间戳（毫秒），无记录时返回 0
  /// 异常：SharedPreferences 操作异常
  static Future<int> getLastUpdateTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastUpdateTime) ?? 0;
  }

  /// 清除可重建的公共地区资源缓存。
  /// 参数：无
  /// 返回：`Future<void>`
  /// 异常：SharedPreferences 操作异常
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    requireWebWriter();
    await Future.wait([
      prefs.remove(_keyRegionList),
      prefs.remove(_keyDataVersion),
      prefs.remove(_keyLastUpdateTime),
    ]);
  }

  /// 检查缓存是否过期
  /// 用途：根据最后更新时间判断缓存是否需要刷新
  /// 参数：maxAgeHours 最大缓存时间（小时），默认 24 小时
  /// 返回：`Future<bool>` 是否过期
  /// 异常：无
  ///
  /// 过期策略说明：
  /// - 默认 24 小时过期，适合地区数据变化不频繁的场景
  /// - 如需更激进的更新策略，可传入较小的 maxAgeHours 值
  /// - 建议结合后端版本号比较实现增量更新
  static Future<bool> isCacheExpired({int maxAgeHours = 24}) async {
    final lastUpdate = await getLastUpdateTime();
    if (lastUpdate == 0) return true; // 无更新记录视为过期

    final now = DateTimeHelper.millisecond();
    final maxAge = maxAgeHours * 60 * 60 * 1000; // 转换为毫秒

    return (now - lastUpdate) > maxAge;
  }

  /// 获取缓存统计信息
  /// 用途：提供缓存状态的调试信息
  /// 参数：无
  /// 返回：`Future<Map<String, dynamic>>` 缓存统计信息
  /// 异常：无
  static Future<Map<String, dynamic>> getCacheStats() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedRegion = prefs.getString(_keySelectedRegion) ?? '';
    final regionPath = prefs.getString(_keyRegionPath) ?? '';
    final regionListJson = prefs.getString(_keyRegionList) ?? '';
    final dataVersion = prefs.getString(_keyDataVersion) ?? '';
    final lastUpdateTime = prefs.getInt(_keyLastUpdateTime) ?? 0;

    return {
      'hasSelectedRegion': selectedRegion.isNotEmpty,
      'hasRegionPath': regionPath.isNotEmpty,
      'hasRegionList': regionListJson.isNotEmpty,
      'regionListSize': regionListJson.length,
      'dataVersion': dataVersion,
      'lastUpdateTime': lastUpdateTime,
      'lastUpdateDate': lastUpdateTime > 0
          ? DateTime.fromMillisecondsSinceEpoch(lastUpdateTime).toString()
          : 'Never',
      'isCacheExpired': await isCacheExpired(),
    };
  }
}

/// Capture once for each page/session so delayed writes cannot cross accounts.
class AccountGeoSelectionCache {
  AccountGeoSelectionCache() : _preferences = AccountPreferences.capture();

  static const preferenceKey = 'geo_structured_selection';
  final AccountPreferences _preferences;

  GeoSelection? read() {
    if (_preferences.owner.uid.isEmpty) return null;
    final saved = _preferences.readList(preferenceKey);
    return saved.isEmpty ? null : parseSelection(jsonDecode(saved.single));
  }

  Future<void> write(GeoSelection selection) async {
    if (_preferences.owner.uid.isEmpty) {
      throw StateError('Geo selection requires an authenticated account');
    }
    await _preferences.writeList(preferenceKey, [
      jsonEncode(selection.toMap()),
    ]);
  }
}

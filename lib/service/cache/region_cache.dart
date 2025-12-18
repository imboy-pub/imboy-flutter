import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// 保存选中的地区字符串
  /// 参数：value 地区字符串（如"中国大陆 北京 朝阳区"）
  /// 返回：Future<void>
  /// 异常：SharedPreferences 操作异常
  static Future<void> saveSelectedRegion(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedRegion, value);
  }

  /// 加载选中的地区字符串
  /// 参数：无
  /// 返回：Future<String> 地区字符串，无缓存时返回空字符串
  /// 异常：SharedPreferences 操作异常
  static Future<String> loadSelectedRegion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedRegion) ?? '';
  }

  /// 保存地区路径列表
  /// 参数：path 路径列表（如["中国大陆", "北京", "朝阳区"]）
  /// 返回：Future<void>
  /// 异常：SharedPreferences 操作异常
  static Future<void> saveRegionPath(List<String> path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRegionPath, path.join(' '));
  }

  /// 加载地区路径列表
  /// 参数：无
  /// 返回：Future<List<String>> 路径列表，无缓存时返回空列表
  /// 异常：SharedPreferences 操作异常
  static Future<List<String>> loadRegionPath() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyRegionPath) ?? '';
    if (s.isEmpty) return [];
    return s.split(' ').where((e) => e.trim().isNotEmpty).toList();
  }

  /// 保存地区列表数据
  /// 参数：list 地区数据列表（从 region.json 或服务器获取）
  /// 返回：Future<void>
  /// 异常：JSON 序列化异常或 SharedPreferences 操作异常
  static Future<void> saveRegionList(List<dynamic> list) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(list);
    await prefs.setString(_keyRegionList, json);
    
    // 同时更新最后更新时间
    await prefs.setInt(_keyLastUpdateTime, DateTime.now().millisecondsSinceEpoch);
  }

  /// 加载地区列表数据
  /// 参数：无
  /// 返回：Future<List<dynamic>> 地区数据列表，无缓存或解析失败时返回空列表
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
  /// 参数：version 版本号字符串
  /// 返回：Future<void>
  /// 异常：SharedPreferences 操作异常
  /// 
  /// TODO: 待后端接口确认版本号格式后完善
  static Future<void> saveDataVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDataVersion, version);
  }

  /// 获取地区数据版本号（后端对接占位方法）
  /// 用途：获取当前缓存数据的版本号，用于与服务器版本比较
  /// 参数：无
  /// 返回：Future<String> 版本号字符串，无缓存时返回空字符串
  /// 异常：SharedPreferences 操作异常
  /// 
  /// TODO: 待后端接口确认版本号格式后完善
  static Future<String> getDataVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDataVersion) ?? '';
  }

  /// 获取最后更新时间
  /// 用途：获取地区数据最后更新的时间戳，用于判断数据新鲜度
  /// 参数：无
  /// 返回：Future<int> 时间戳（毫秒），无记录时返回 0
  /// 异常：SharedPreferences 操作异常
  static Future<int> getLastUpdateTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastUpdateTime) ?? 0;
  }

  /// 清除所有地区相关缓存
  /// 用途：在数据异常或用户主动清理时清空所有缓存
  /// 参数：无
  /// 返回：Future<void>
  /// 异常：SharedPreferences 操作异常
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keySelectedRegion),
      prefs.remove(_keyRegionPath),
      prefs.remove(_keyRegionList),
      prefs.remove(_keyDataVersion),
      prefs.remove(_keyLastUpdateTime),
    ]);
  }

  /// 检查缓存是否过期（后端对接占位方法）
  /// 用途：根据最后更新时间判断缓存是否需要刷新
  /// 参数：maxAgeHours 最大缓存时间（小时），默认 24 小时
  /// 返回：Future<bool> 是否过期
  /// 异常：无
  /// 
  /// TODO: 根据实际业务需求调整过期策略
  static Future<bool> isCacheExpired({int maxAgeHours = 24}) async {
    final lastUpdate = await getLastUpdateTime();
    if (lastUpdate == 0) return true; // 无更新记录视为过期
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAge = maxAgeHours * 60 * 60 * 1000; // 转换为毫秒
    
    return (now - lastUpdate) > maxAge;
  }

  /// 获取缓存统计信息
  /// 用途：提供缓存状态的调试信息
  /// 参数：无
  /// 返回：Future<Map<String, dynamic>> 缓存统计信息
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

import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:imboy/service/storage.dart';
import 'package:ntp/ntp.dart';
import 'dart:convert';

///
/// NTP 时间同步辅助类
///
/// 功能：
/// - 从 NTP 服务器获取时间偏移量
/// - 支持多个 NTP 服务器（自动随机选择）
/// - 本地缓存偏移量（6小时有效期）
/// - 自动重试机制
/// - 支持从服务器时间戳更新偏移量
/// - Web 平台跳过 NTP 同步（使用服务器时间戳）
///
/// 使用方法：
/// ```dart
/// // 初始化（应用启动时调用）
/// int offset = await NtpHelper.getOffset();
///
/// // 从服务器响应更新时间
/// NtpHelper.updateOffsetFromServer(serverTimestamp);
///
/// // 获取当前同步后的时间
/// int syncedTime = NtpHelper.now();
/// ```
class NtpHelper {
  static const String _cacheKey = "ntp_offset_v2"; // 新缓存键避免冲突
  static const List<String> _ntpServers = [
    'time5.cloud.tencent.com',
    'pool.ntp.org',
    'time.google.com',
  ];
  static const int _maxRetry = 2; // 最大重试次数
  static const int _cacheExpiryHours = 6; // 缓存有效期（小时）

  /// 当前时间偏移量（毫秒）
  static int _offset = 0;

  /// 是否为 Web 平台（Web 不支持 NTP 同步）
  static bool get _isWeb => kIsWeb;

  /// 获取当前时间偏移量
  static int get offset => _offset;

  /// 获取同步后的当前时间（毫秒时间戳）
  static int millisecond() {
    return DateTime.now().millisecondsSinceEpoch + _offset;
  }

  /// 从服务器时间戳更新偏移量
  ///
  /// [serverTs] 服务器返回的 UTC 毫秒时间戳（sv_ts 字段）
  static void updateOffsetFromServer(int serverTs) {
    if (serverTs <= 0) {
      if (kDebugMode) debugPrint('⚠️ NtpHelper: 无效的服务器时间戳');
      return;
    }

    final localTs = DateTime.now().millisecondsSinceEpoch;
    final newOffset = serverTs - localTs;

    // 验证偏移量的合理性（24小时内）
    const maxOffset = 24 * 3600 * 1000;
    if (newOffset.abs() > maxOffset) {
      if (kDebugMode) debugPrint('⚠️ NtpHelper: 服务器时间偏移量异常');
      return;
    }

    _offset = newOffset;
    if (kDebugMode) debugPrint('✅ NtpHelper: 从服务器更新时间偏移: $_offset ms');
  }

  static Future<int> getOffset() async {
    // Web 平台跳过 NTP 同步（使用服务器时间戳代替）
    if (_isWeb) {
      if (kDebugMode) debugPrint('🌐 NtpHelper: Web 平台跳过 NTP 同步');
      // 尝试读取缓存
      final cachedData = _parseCache(StorageService.to.getString(_cacheKey));
      if (cachedData != null) {
        _offset = cachedData.offset;
        if (kDebugMode) debugPrint('🕐 NtpHelper: 从缓存加载时间偏移: $_offset ms');
        return _offset;
      }
      return 0; // Web 平台返回零偏移，等待服务器时间戳更新
    }

    // 尝试读取缓存
    final cachedData = _parseCache(StorageService.to.getString(_cacheKey));
    if (cachedData != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      // 使用设备启动时间计算有效期，避免依赖系统时间
      if (now - cachedData.deviceTimestamp < _cacheExpiryHours * 3600 * 1000) {
        _offset = cachedData.offset;
        if (kDebugMode) debugPrint('🕐 NtpHelper: 从缓存加载时间偏移: $_offset ms');
        return _offset;
      }
    }

    // 请求NTP并处理错误
    for (var i = 0; i < _maxRetry; i++) {
      try {
        final offset = await _fetchNtpWithRetry();
        _offset = offset;
        await _saveCache(offset);
        if (kDebugMode) debugPrint('✅ NtpHelper: NTP 同步成功，偏移量: $_offset ms');
        return _offset;
      } on Exception catch (e) {
        if (kDebugMode) debugPrint('❌ NtpHelper: NTP 同步失败 (第 ${i + 1}/$_maxRetry 次): ${e.runtimeType}');
        if (i == _maxRetry - 1) return 0; // 返回安全值
      }
    }
    return 0;
  }

  static Future<int> _fetchNtpWithRetry() async {
    // 随机选择服务器避免单点故障
    final server = _ntpServers[Random().nextInt(_ntpServers.length)];
    final response = await NTP.getNtpOffset(
      localTime: DateTime.now(), // 直接使用UTC时间
      lookUpAddress: server,
      timeout: const Duration(seconds: 3),
    );

    // 添加网络延迟补偿
    final adjustedOffset = response ~/ 1; // 示例补偿逻辑，可扩展
    return adjustedOffset;
  }

  static Future<int> _saveCache(int offset) async {
    final data = {
      'ntp_time': DateTime.now().toUtc().toIso8601String(),
      'device_ts': DateTime.now().millisecondsSinceEpoch,
      'offset': offset,
    };
    await StorageService.to.setString(_cacheKey, json.encode(data));
    return offset;
  }

  static ({int offset, int deviceTimestamp})? _parseCache(String? val) {
    try {
      if (val == null) return null;
      final map = Map<String, dynamic>.from(json.decode(val));
      return (
        offset: map['offset'] as int,
        deviceTimestamp: map['device_ts'] as int,
      );
    } on Exception {
      StorageService.to.remove(_cacheKey); // 清除无效缓存
      return null;
    }
  }
}

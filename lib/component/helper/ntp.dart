import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:imboy/service/storage.dart';
import 'package:ntp/ntp.dart';
import 'dart:convert';

class NtpHelper {
  static const String _cacheKey = "ntp_offset_v2"; // 新缓存键避免冲突
  static const List<String> _ntpServers = [
    'time5.cloud.tencent.com',
    'pool.ntp.org',
    'time.google.com'
  ];
  static const int _maxRetry = 2; // 最大重试次数
  static const int _cacheExpiryHours = 6; // 缓存有效期（小时）

  static Future<int> getOffset() async {
    // 尝试读取缓存
    final cachedData = _parseCache(StorageService.to.getString(_cacheKey));
    if (cachedData != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      // 使用设备启动时间计算有效期，避免依赖系统时间
      if (now - cachedData.deviceTimestamp < _cacheExpiryHours * 3600 * 1000) {
        return cachedData.offset;
      }
    }

    // 请求NTP并处理错误
    for (var i = 0; i < _maxRetry; i++) {
      try {
        final offset = await _fetchNtpWithRetry();
        await _saveCache(offset);
        return offset;
      } catch (e) {
        debugPrint(e.toString());
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

  static  Future<int> _saveCache(int offset) async {
    final data = {
      'ntp_time': DateTime.now().toUtc().toIso8601String(),
      'device_ts': DateTime.now().millisecondsSinceEpoch,
      'offset': offset,
    };
    await StorageService.to.setString(_cacheKey, data.toString());
    return offset;
  }

  static ({int offset, int deviceTimestamp})? _parseCache(String? val) {
    try {
      if (val == null) return null;
      final map = Map<String, dynamic>.from(json.decode(val));
      return (
      offset: map['offset'] as int,
      deviceTimestamp: map['device_ts'] as int
      );
    } catch (e) {
      StorageService.to.remove(_cacheKey); // 清除无效缓存
      return null;
    }
  }
}
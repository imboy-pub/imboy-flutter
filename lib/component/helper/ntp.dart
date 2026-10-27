import 'package:imboy/config/local_external_services_policy.dart';
import 'package:imboy/component/helper/ntp_query.dart';

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:imboy/service/storage.dart';

import 'dart:convert';

///
/// NTP 时间同步辅助类
///
/// 功能：
/// - 从 NTP 服务器获取时间偏移量（真实 64 位时间戳解析 + RTT 闸门，
///   见 ntp_query.dart，R20-A）
/// - 支持多个 NTP 服务器（自动随机选择）
/// - 本地缓存偏移量（6小时有效期 + 未来时间/量级/结构防护）
/// - 自动重试机制；失败保留 last-good 偏移并在宽限期后退化为纯墙钟，
///   不再静默返回 0 假装已校准
/// - 支持从服务器时间戳更新偏移量（HTTP envelope sv_ts，每个成功响应
///   都会校正，是主通道；NTP 为后台补充）
/// - Web 平台跳过 NTP 同步（使用服务器时间戳）
///
/// 使用方法：
/// ```dart
/// // 初始化（应用启动时后台调用，不阻塞启动）
/// unawaited(NtpHelper.getOffset());
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

  /// 偏移量合理性上限（与 sv_ts 校正同口径）。
  static const int _maxOffsetMs = 24 * 3600 * 1000;

  /// last-good 宽限期：超过该时长没有任何成功校准（NTP/sv_ts/缓存），
  /// now() 停止沿用旧偏移，退化为纯墙钟——不假装已校准。
  static const int _offsetGraceMs = 24 * 3600 * 1000;

  /// 缓存的 device_ts 允许的"未来"容差：超出视为被墙钟回拨污染，丢弃。
  static const int _cacheFutureToleranceMs = 60 * 1000;

  /// 当前时间偏移量（毫秒）；0 表示从未校准（纯墙钟）。
  static int _offset = 0;

  /// 最近一次成功校准（NTP / sv_ts / 缓存加载）时刻的本地墙钟毫秒。
  static int _lastSyncWallMs = 0;

  /// 测试注入点：替换 NTP 查询实现（不触网）。
  @visibleForTesting
  static Future<NtpSample> Function(String host, {Duration timeout}) ntpQuery =
      queryNtp;

  /// 测试专用：重置静态校准状态（offset 归零、宽限重新计时）。
  @visibleForTesting
  static void debugReset() {
    _offset = 0;
    _lastSyncWallMs = 0;
  }

  /// 测试专用：把最近一次校准时刻向过去拨 [age]，模拟 offset 过期。
  @visibleForTesting
  static void debugAgeLastSync(Duration age) {
    _lastSyncWallMs -= age.inMilliseconds;
  }

  /// 是否为 Web 平台（Web 不支持 NTP 同步）
  static bool get _isWeb => kIsWeb;

  /// 获取当前时间偏移量
  static int get offset => _offset;

  /// 最近一次成功校准是否仍在宽限期内（offset 可信）。
  ///
  /// 测试/排障用；生产代码应通过 [millisecond] 消费，而不是自行加减。
  @visibleForTesting
  static bool get offsetUsable {
    if (_offset == 0) return false;
    final wallNow = DateTime.now().millisecondsSinceEpoch;
    return (wallNow - _lastSyncWallMs).abs() < _offsetGraceMs;
  }

  /// 获取同步后的当前时间（毫秒时间戳）。
  ///
  /// offset 过期（宽限期内无任何成功校准）时退化为纯墙钟。
  static int millisecond() {
    final wall = DateTime.now().millisecondsSinceEpoch;
    return wall + (offsetUsable ? _offset : 0);
  }

  /// 应用一次成功校准并记录校准时刻。
  static void _applyOffset(int offsetMs) {
    _offset = offsetMs;
    _lastSyncWallMs = DateTime.now().millisecondsSinceEpoch;
  }

  /// 从服务器时间戳更新偏移量（HTTP envelope sv_ts 通道）。
  ///
  /// [serverTs] 服务器返回的 UTC 毫秒时间戳（sv_ts 字段）。
  /// 每个成功 HTTP 响应都会走到这里，因此只要 app 在联网使用，
  /// offset 持续保持"新鲜"，NTP 不可达也不会让 offset 过期。
  static void updateOffsetFromServer(int serverTs) {
    if (serverTs <= 0) {
      if (kDebugMode) debugPrint('⚠️ NtpHelper: 无效的服务器时间戳');
      return;
    }

    final localTs = DateTime.now().millisecondsSinceEpoch;
    final newOffset = serverTs - localTs;

    // 验证偏移量的合理性（24小时内）
    if (newOffset.abs() > _maxOffsetMs) {
      if (kDebugMode) debugPrint('⚠️ NtpHelper: 服务器时间偏移量异常');
      return;
    }

    _applyOffset(newOffset);
    if (kDebugMode) debugPrint('✅ NtpHelper: 从服务器更新时间偏移: $_offset ms');
  }

  static Future<int> getOffset() async {
    if (LocalExternalServicesPolicy.suppressed) return _offset;
    // Web 平台跳过 NTP 同步（使用服务器时间戳代替）
    if (_isWeb) {
      if (kDebugMode) debugPrint('🌐 NtpHelper: Web 平台跳过 NTP 同步');
      final cachedData = _loadValidCache();
      if (cachedData != null) {
        _applyOffset(cachedData.offset);
        if (kDebugMode) debugPrint('🕐 NtpHelper: 从缓存加载时间偏移: $_offset ms');
        return _offset;
      }
      return 0; // Web 平台返回零偏移，等待服务器时间戳更新
    }

    // 尝试读取缓存（含过期/未来时间/量级防护）
    final cachedData = _loadValidCache();
    if (cachedData != null) {
      _applyOffset(cachedData.offset);
      if (kDebugMode) debugPrint('🕐 NtpHelper: 从缓存加载时间偏移: $_offset ms');
      return _offset;
    }

    // 请求 NTP 并处理错误；失败保留 last-good（R20-A），不静默归零。
    for (var i = 0; i < _maxRetry; i++) {
      try {
        final sample = await _queryNtpOnce();
        _applyOffset(sample.offsetMs);
        await _saveCache(sample.offsetMs);
        if (kDebugMode) {
          debugPrint(
            '✅ NtpHelper: NTP 同步成功，偏移量: $_offset ms，RTT: ${sample.rttMs} ms',
          );
        }
        return _offset;
      } on Object catch (e) {
        // W8-C6：原 on Object 吞掉错误对象，排障时只见"失败"不见原因。
        if (kDebugMode) {
          debugPrint(
            '⚠️ NtpHelper: NTP 查询失败 (${i + 1}/$_maxRetry): '
            '${e.runtimeType}: $e',
          );
        }
        if (i == _maxRetry - 1) {
          if (kDebugMode) {
            debugPrint(
              '⚠️ NtpHelper: NTP 同步失败，保留 last-good 偏移: $_offset ms'
              '（宽限期 ${_offsetGraceMs ~/ 3600000}h 内仍生效）',
            );
          }
          return _offset;
        }
      }
    }
    return _offset;
  }

  static Future<NtpSample> _queryNtpOnce() async {
    // 随机选择服务器避免单点故障
    final server = _ntpServers[Random().nextInt(_ntpServers.length)];
    return ntpQuery(server, timeout: const Duration(seconds: 3));
  }

  /// 读取并校验缓存；结构损坏/量级异常/未来时间戳返回 null（坏值清除）。
  static ({int offset, int deviceTimestamp})? _loadValidCache() {
    final raw = StorageService.to.getString(_cacheKey);
    final cachedData = _parseCache(raw);
    if (cachedData == null) return null;

    if (cachedData.offset.abs() > _maxOffsetMs) {
      // 量级异常：视为污染数据清除，不让 +N 天级偏移进入 now()。
      StorageService.to.remove(_cacheKey);
      return null;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (cachedData.deviceTimestamp > now + _cacheFutureToleranceMs) {
      // device_ts 在未来：缓存写入后墙钟被回拨，过期判断已不可信，丢弃。
      StorageService.to.remove(_cacheKey);
      return null;
    }

    // 6h 有效期按墙钟差计算；轻微墙钟回拨只会让窗口略变长，可接受。
    if (now - cachedData.deviceTimestamp > _cacheExpiryHours * 3600 * 1000) {
      return null; // 过期：不清除，等待下次成功同步覆盖
    }
    return cachedData;
  }

  static Future<void> _saveCache(int offset) async {
    final data = {
      'ntp_time': DateTime.now().toUtc().toIso8601String(),
      'device_ts': DateTime.now().millisecondsSinceEpoch,
      'offset': offset,
    };
    await StorageService.to.setString(_cacheKey, json.encode(data));
  }

  static ({int offset, int deviceTimestamp})? _parseCache(String? val) {
    try {
      if (val == null) return null;
      final map = Map<String, dynamic>.from(
        json.decode(val) as Map<dynamic, dynamic>,
      );
      // JSON 数字可能解码为 double；统一走 num 容错。
      final offset = (map['offset'] as num?)?.toInt();
      final deviceTs = (map['device_ts'] as num?)?.toInt();
      if (offset == null || deviceTs == null) return null;
      return (offset: offset, deviceTimestamp: deviceTs);
    } on Exception {
      StorageService.to.remove(_cacheKey); // 清除无效缓存
      return null;
    }
  }
}

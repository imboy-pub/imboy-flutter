import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

import 'message_s2c.dart';

/// 离线消息处理服务
class MessageOfflineService {
  /// 单例实例
  static MessageOfflineService? _instance;

  /// 获取单例实例
  static MessageOfflineService get instance {
    _instance ??= MessageOfflineService._internal();
    return _instance!;
  }

  /// 私有构造函数
  MessageOfflineService._internal() {
    onInit();
  }

  static const int _maxPullCount = 20;
  static const Duration _pagePullDelay = Duration(milliseconds: 300);
  static const Duration _minPullInterval = Duration(milliseconds: 1200);
  static const Duration _idlePullCooldown = Duration(seconds: 5);
  static const Duration _maxFailureBackoff = Duration(seconds: 30);

  /// 游标：各类消息最后一条消息的时间戳（毫秒）
  ///
  /// 协议一致性修复 D4：服务端 /v1/msg/offline 支持通过 c2c_last_msg_at、
  /// c2g_last_msg_at、s2c_last_msg_at 参数做增量拉取，返回值中 next_last_msg_at
  /// 字段即为下次请求时应传入的游标值。客户端保存游标并在每次请求时携带，
  /// 避免每次全量拉取带来的性能压力。
  int _c2cLastMsgAt = 0;
  int _c2gLastMsgAt = 0;
  int _s2cLastMsgAt = 0;

  /// 离线消息拉取请求事件的订阅
  StreamSubscription<OfflineMessagesPullRequestedEvent>?
  _pullRequestedSubscription;

  /// 当前正在执行的拉取任务（用于并发合并）
  Future<bool>? _inFlightPull;

  /// 拉取过程中收到新请求时，标记完成后补拉一次
  bool _hasPendingPullRequest = false;

  /// 下次允许拉取的时间点（用于节流和失败退避）
  DateTime? _nextAllowedPullAt;

  /// 连续失败次数（指数退避）
  int _consecutivePullFailures = 0;

  // ==================== 拉取埋点指标 ====================
  int _requestedTotal = 0;
  int _forceRequestedTotal = 0;
  int _mergedTotal = 0;
  int _skippedCooldownTotal = 0;
  int _executedTotal = 0;
  int _succeededTotal = 0;
  int _failedTotal = 0;
  int _httpRequestsTotal = 0;
  int _fetchedMessagesTotal = 0;

  DateTime? _lastPullStartedAt;
  DateTime? _lastPullFinishedAt;
  String? _lastSource;
  String? _lastReason;
  String _lastResult = 'none';
  int _lastPullHttpRequests = 0;
  int _lastPullFetchedMessages = 0;

  /// 初始化服务（订阅事件）
  void onInit() {
    _pullRequestedSubscription ??=
        AppEventBus.on<OfflineMessagesPullRequestedEvent>().listen((event) {
          // 异步处理，避免阻塞事件总线
          Future.microtask(() async {
            await requestPull(source: event.source, reason: event.reason);
          });
        });
  }

  /// 释放资源（取消订阅）
  void onDispose() {
    _pullRequestedSubscription?.cancel();
    _pullRequestedSubscription = null;
    _inFlightPull = null;
    _hasPendingPullRequest = false;
    // 重置游标，避免单例重建后使用旧游标（D4 修复）
    _c2cLastMsgAt = 0;
    _c2gLastMsgAt = 0;
    _s2cLastMsgAt = 0;
    _instance = null;
  }

  /// 离线消息拉取指标快照（用于排障与监控）
  Map<String, dynamic> getPullStats() {
    final now = DateTime.now();
    final nextAllowedAt = _nextAllowedPullAt;
    final nextAllowedInMs = nextAllowedAt == null
        ? 0
        : nextAllowedAt.isAfter(now)
        ? nextAllowedAt.difference(now).inMilliseconds
        : 0;

    return {
      'requested_total': _requestedTotal,
      'force_requested_total': _forceRequestedTotal,
      'merged_total': _mergedTotal,
      'skipped_cooldown_total': _skippedCooldownTotal,
      'executed_total': _executedTotal,
      'succeeded_total': _succeededTotal,
      'failed_total': _failedTotal,
      'http_requests_total': _httpRequestsTotal,
      'fetched_messages_total': _fetchedMessagesTotal,
      'in_flight': _inFlightPull != null,
      'pending_pull_request': _hasPendingPullRequest,
      'consecutive_failures': _consecutivePullFailures,
      'next_allowed_pull_at': _toIsoString(nextAllowedAt),
      'next_allowed_in_ms': nextAllowedInMs,
      'last_source': _lastSource,
      'last_reason': _lastReason,
      'last_result': _lastResult,
      'last_pull_started_at': _toIsoString(_lastPullStartedAt),
      'last_pull_finished_at': _toIsoString(_lastPullFinishedAt),
      'last_pull_http_requests': _lastPullHttpRequests,
      'last_pull_fetched_messages': _lastPullFetchedMessages,
    };
  }

  /// 主动打印离线拉取指标快照
  void logPullStats({String tag = 'snapshot'}) {
    _logPullMetrics(tag);
  }

  /// 离线消息拉取统一入口
  ///
  /// 策略：
  /// 1. 并发合并：同一时刻只允许一个拉取任务执行。
  /// 2. 频率控制：短时间重复触发会被跳过，避免高频请求。
  /// 3. 失败退避：连续失败时指数退避，降低无效重试压力。
  Future<bool> requestPull({
    required String source,
    String? reason,
    bool force = false,
  }) async {
    final now = DateTime.now();

    _requestedTotal++;
    if (force) {
      _forceRequestedTotal++;
    }
    _lastSource = source;
    _lastReason = reason;

    // 有拉取进行中：合并请求，等待当前任务结束
    if (_inFlightPull != null) {
      _mergedTotal++;
      _hasPendingPullRequest = true;
      _lastResult = 'merged';
      iPrint('离线消息拉取请求已合并（进行中） source=$source reason=${reason ?? "-"}');
      _logPullMetrics('merged');
      return _inFlightPull!;
    }

    // 冷却期内：跳过本次请求
    if (!force &&
        _nextAllowedPullAt != null &&
        now.isBefore(_nextAllowedPullAt!)) {
      final waitMs = _nextAllowedPullAt!.difference(now).inMilliseconds;
      _skippedCooldownTotal++;
      _lastResult = 'skipped_cooldown';
      _lastPullHttpRequests = 0;
      _lastPullFetchedMessages = 0;
      _lastPullFinishedAt = DateTime.now();
      iPrint('离线消息拉取请求过于频繁，跳过本次 source=$source wait_ms=$waitMs');
      _logPullMetrics('skipped_cooldown', extra: {'wait_ms': waitMs});
      return true;
    }

    _executedTotal++;
    _lastResult = 'running';
    _lastPullStartedAt = DateTime.now();

    final pullFuture = _pullOfflineMessagesInternal(
      source: source,
      reason: reason,
    );
    _inFlightPull = pullFuture;

    try {
      return await pullFuture;
    } finally {
      _inFlightPull = null;

      // 如果拉取期间又来了新请求，则补拉一次（force=true，确保不会被冷却窗口吞掉）
      if (_hasPendingPullRequest) {
        _hasPendingPullRequest = false;
        unawaited(
          requestPull(
            source: 'merged_pending',
            reason: '拉取过程中收到新的离线拉取请求',
            force: true,
          ),
        );
      }
    }
  }

  /// 拉取离线消息（兼容旧调用）
  Future<bool> pullOfflineMessages() {
    return requestPull(source: 'direct_call', reason: '兼容旧调用');
  }

  Future<bool> _pullOfflineMessagesInternal({
    required String source,
    String? reason,
  }) async {
    try {
      iPrint('开始拉取离线消息 source=$source reason=${reason ?? "-"}');

      bool hasMore = true;
      int pullCount = 0;
      int totalFetched = 0;
      int currentPullHttpRequests = 0;

      // 本次拉取周期内使用的游标（拉取过程中持续更新）
      int localC2cLastMsgAt = _c2cLastMsgAt;
      int localC2gLastMsgAt = _c2gLastMsgAt;
      int localS2cLastMsgAt = _s2cLastMsgAt;

      while (hasMore && pullCount < _maxPullCount) {
        pullCount++;
        iPrint(
          '第 $pullCount 次拉取离线消息 c2c_cursor=$localC2cLastMsgAt '
          'c2g_cursor=$localC2gLastMsgAt s2c_cursor=$localS2cLastMsgAt',
        );

        // 调用 /msg/offline 接口，携带游标参数实现增量拉取（D4 修复）
        final queryParams = <String, dynamic>{};
        if (localC2cLastMsgAt > 0) {
          queryParams['c2c_last_msg_at'] = localC2cLastMsgAt;
        }
        if (localC2gLastMsgAt > 0) {
          queryParams['c2g_last_msg_at'] = localC2gLastMsgAt;
        }
        if (localS2cLastMsgAt > 0) {
          queryParams['s2c_last_msg_at'] = localS2cLastMsgAt;
        }

        currentPullHttpRequests++;
        _httpRequestsTotal++;
        final resp = await HttpClient.client.get(
          API.msgOffline,
          queryParameters: queryParams.isEmpty ? null : queryParams,
        );

        if (resp.code != 0) {
          _failedTotal++;
          _lastResult = 'failed_code';
          _lastPullFinishedAt = DateTime.now();
          _lastPullHttpRequests = currentPullHttpRequests;
          _lastPullFetchedMessages = totalFetched;
          _markPullFailure();
          iPrint('拉取离线消息失败: ${resp.msg}');
          _logPullMetrics('failed_code', extra: {'resp_code': resp.code});
          EasyLoading.showError(
            '${t.common.pullOfflineMessagesFailed}: ${resp.msg}',
          );
          return false;
        }

        final payload = resp.payload is Map<String, dynamic>
            ? resp.payload as Map<String, dynamic>
            : <String, dynamic>{};

        bool overallHasMore = false;
        int currentBatchFetched = 0;

        // 处理 C2C 离线消息
        currentBatchFetched += await _processTypeBatch(
          payload: payload,
          typeKey: 'c2c',
          chatType: 'C2C',
        );
        if (_hasMore(payload['c2c'])) {
          overallHasMore = true;
        }
        // 更新 C2C 游标（D4 修复）
        final nextC2c = _extractNextCursor(payload['c2c']);
        if (nextC2c != null && nextC2c > localC2cLastMsgAt) {
          localC2cLastMsgAt = nextC2c;
        }

        // 处理 C2G 离线消息
        currentBatchFetched += await _processTypeBatch(
          payload: payload,
          typeKey: 'c2g',
          chatType: 'C2G',
        );
        if (_hasMore(payload['c2g'])) {
          overallHasMore = true;
        }
        // 更新 C2G 游标（D4 修复）
        final nextC2g = _extractNextCursor(payload['c2g']);
        if (nextC2g != null && nextC2g > localC2gLastMsgAt) {
          localC2gLastMsgAt = nextC2g;
        }

        // 处理 S2C 离线消息
        currentBatchFetched += await _processTypeBatch(
          payload: payload,
          typeKey: 's2c',
          chatType: 'S2C',
        );
        if (_hasMore(payload['s2c'])) {
          overallHasMore = true;
        }
        // 更新 S2C 游标（D4 修复）
        final nextS2c = _extractNextCursor(payload['s2c']);
        if (nextS2c != null && nextS2c > localS2cLastMsgAt) {
          localS2cLastMsgAt = nextS2c;
        }

        totalFetched += currentBatchFetched;
        hasMore = overallHasMore;

        iPrint(
          '离线消息批次处理完成 pull=$pullCount fetched=$currentBatchFetched has_more=$hasMore',
        );

        if (hasMore) {
          // 短暂延迟，避免分页场景下连续高频请求
          await Future<dynamic>.delayed(_pagePullDelay);
        }
      }

      // 拉取成功后持久化游标（D4 修复）：只向前推进，不回退
      if (localC2cLastMsgAt > _c2cLastMsgAt) {
        _c2cLastMsgAt = localC2cLastMsgAt;
      }
      if (localC2gLastMsgAt > _c2gLastMsgAt) {
        _c2gLastMsgAt = localC2gLastMsgAt;
      }
      if (localS2cLastMsgAt > _s2cLastMsgAt) {
        _s2cLastMsgAt = localS2cLastMsgAt;
      }

      _succeededTotal++;
      _fetchedMessagesTotal += totalFetched;
      _lastResult = 'success';
      _lastPullFinishedAt = DateTime.now();
      _lastPullHttpRequests = currentPullHttpRequests;
      _lastPullFetchedMessages = totalFetched;
      _markPullSuccess(totalFetched: totalFetched);
      iPrint('离线消息拉取完成 total_pull=$pullCount total_fetched=$totalFetched');
      _logPullMetrics(
        'success',
        extra: {
          'current_pull_http_requests': currentPullHttpRequests,
          'current_pull_fetched_messages': totalFetched,
        },
      );
      return true;
    } on Object catch (e) {
      _failedTotal++;
      _lastResult = 'failed_exception';
      _lastPullFinishedAt = DateTime.now();
      _markPullFailure();
      iPrint('拉取离线消息异常: $e');
      _logPullMetrics('failed_exception');
      EasyLoading.showError('${t.common.pullOfflineMessagesAbnormal}: $e');
      return false;
    }
  }

  Future<int> _processTypeBatch({
    required Map<String, dynamic> payload,
    required String typeKey,
    required String chatType,
  }) async {
    final section = payload[typeKey];
    if (section is! Map) {
      return 0;
    }

    final rawList = section['list'];
    if (rawList is! List || rawList.isEmpty) {
      return 0;
    }

    await _processOfflineMessages(rawList, chatType);
    return rawList.length;
  }

  bool _hasMore(dynamic section) {
    if (section is! Map) {
      return false;
    }
    return section['has_more'] == true;
  }

  /// 从服务端响应 section 中提取下一次请求的游标值（D4 修复）
  ///
  /// 服务端在每个 section（c2c/c2g/s2c）中返回 next_last_msg_at 字段，
  /// 客户端应在下次拉取时将其作为对应的 *_last_msg_at 参数传入，
  /// 实现增量拉取，避免重复获取已处理的消息。
  ///
  /// 返回 null 表示 section 无效或未携带游标。
  int? _extractNextCursor(dynamic section) {
    if (section is! Map) return null;
    final raw = section['next_last_msg_at'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  void _markPullSuccess({required int totalFetched}) {
    _consecutivePullFailures = 0;
    final cooldown = totalFetched == 0 ? _idlePullCooldown : _minPullInterval;
    _nextAllowedPullAt = DateTime.now().add(cooldown);
  }

  void _markPullFailure() {
    _consecutivePullFailures += 1;

    int backoffSeconds = 1 << (_consecutivePullFailures - 1);
    if (backoffSeconds < 2) {
      backoffSeconds = 2;
    }
    if (backoffSeconds > _maxFailureBackoff.inSeconds) {
      backoffSeconds = _maxFailureBackoff.inSeconds;
    }

    _nextAllowedPullAt = DateTime.now().add(Duration(seconds: backoffSeconds));
  }

  String? _toIsoString(DateTime? time) {
    return time?.toIso8601String();
  }

  void _logPullMetrics(String tag, {Map<String, dynamic>? extra}) {
    final snapshot = getPullStats();
    final merged = extra == null ? snapshot : {...snapshot, ...extra};
    iPrint('[OFFLINE_PULL_METRICS][$tag] $merged');
  }

  /// 处理离线消息
  Future<void> _processOfflineMessages(
    List<dynamic> messages,
    String type,
  ) async {
    if (messages.isEmpty) {
      return;
    }

    iPrint('开始处理 $type 离线消息，共 ${messages.length} 条');

    try {
      // 转换消息数据格式，避免修改原始数据
      final processedMessages = <Map<String, dynamic>>[];
      for (final msg in messages) {
        if (msg is Map<String, dynamic>) {
          // 创建新的消息副本，避免修改原始数据
          final msgCopy = Map<String, dynamic>.from(msg);
          msgCopy['type'] = type;
          processedMessages.add(msgCopy);
        }
      }

      // 使用静态方法批量插入消息
      final msgIds =
          await MessageRepo(
            tableName: MessageRepo.getTableName(type),
          ).batchInsertOfflineMessages(
            processedMessages,
            onS2CMessage: (msgData) async {
              // 处理 S2C 消息
              await MessageS2CService.switchS2C(msgData);
            },
          );

      if (msgIds != null && msgIds.isNotEmpty) {
        // 发送确认消息
        await _sendOfflineAck(type, msgIds);
      }
      iPrint('$type 离线消息处理完成');
    } on Object catch (e) {
      iPrint('处理 $type 离线消息失败: $e');
      rethrow;
    }
  }

  /// 发送离线消息确认
  Future<void> _sendOfflineAck(String type, List<String> msgIds) async {
    try {
      final resp = await HttpClient.client.post(
        API.msgOfflineAck,
        data: {'type': type, 'msg_ids': msgIds},
      );
      if (resp.code != 0) {
        iPrint('发送离线消息确认失败: ${resp.msg}');
      }
    } on Object catch (e, s) {
      iPrint('发送离线消息确认异常: $e $s');
    }
  }
}

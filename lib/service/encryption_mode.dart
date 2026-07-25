/// 三层加密模式定义
///
/// 对应后端 imboy_policy 的 storage_mode 和 e2ee_mode:
/// - plaintext: 明文传输��不加密
/// - compliance_e2ee: AES key 双加密（接收方公钥 + 合规公钥）
/// - strict_e2ee: 仅接收方公钥加密（现有 E2EE 逻辑）
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

/// 加密模式枚举
enum EncryptionMode {
  /// 明文传输
  plaintext,

  /// 合规端到端加密（双密钥: 接收方 + 合规方）
  complianceE2ee,

  /// 严格端到端加密（仅接收方密钥）
  strictE2ee,
}

/// 加密模式工具类
extension EncryptionModeExt on EncryptionMode {
  /// 转为后端 API 字符串
  String toApiString() {
    switch (this) {
      case EncryptionMode.plaintext:
        return 'plaintext';
      case EncryptionMode.complianceE2ee:
        return 'compliance_e2ee';
      case EncryptionMode.strictE2ee:
        return 'secure_e2ee';
    }
  }

  /// 从后端 API 字符串解析
  static EncryptionMode fromApiString(String? value) {
    switch (value) {
      case 'compliance_e2ee':
        return EncryptionMode.complianceE2ee;
      case 'secure_e2ee':
        return EncryptionMode.strictE2ee;
      case 'plaintext':
      default:
        return EncryptionMode.plaintext;
    }
  }

  /// 是否需要加密
  bool get requiresEncryption =>
      this == EncryptionMode.complianceE2ee ||
      this == EncryptionMode.strictE2ee;

  /// 是否需要合规密钥
  bool get requiresComplianceKey => this == EncryptionMode.complianceE2ee;

  /// 显示名称
  String get displayName {
    switch (this) {
      case EncryptionMode.plaintext:
        return '标准模式';
      case EncryptionMode.complianceE2ee:
        return '合规加密';
      case EncryptionMode.strictE2ee:
        return '端到端加密';
    }
  }

  /// 锁图标（用于 UI 展示三种模式）
  String get lockIcon {
    switch (this) {
      case EncryptionMode.plaintext:
        return '🔓'; // 开锁
      case EncryptionMode.complianceE2ee:
        return '🔐'; // 带钥匙的锁
      case EncryptionMode.strictE2ee:
        return '🔒'; // 关锁
    }
  }
}

/// 全局加密模式服务
///
/// 从后端 /api/v1/app/policy API 获取当前部署的加密策略，
/// 供 E2EEService 和消息发送流程参考。
///
/// ## 拉取失败的语义（fail-closed，勿改成 fail-open）
///
/// - **从未成功拉取过**：`isInitialized == false`，[PolicyGate] 对 C2C/C2G
///   一律拒发。因为此时无法证明本部署是明文部署，放行等于可能把本该加密的
///   消息以明文发出。失败会进入有界退避重试，不再是"一次失败永久卡死"。
/// - **曾经成功拉取过**：保留上次成功的 mode 继续用（既有行为）。
///   风险有界：过期 policy 的唯一危险方向是"部署刚从 plaintext 升到 strict、
///   而本进程还缓存着 plaintext"，此时服务端 fail-closed 门会拒收明文；
///   且每次冷启动都会重新拉取。是否给缓存 policy 加 TTL（过期后回到
///   fail-closed）属于产品/安全决策，未在本层擅自改变。
class EncryptionModeService {
  EncryptionModeService._();

  static EncryptionMode _current = EncryptionMode.plaintext;
  static bool _initialized = false;

  /// 拉取失败后的退避序列，末位为稳态间隔。
  ///
  /// 首档刻意很短（1s）：策略未就绪时用户会立刻再点一次发送，
  /// 该次点击即触发重拉，网络恢复后第二次点击就能发出去。
  static const List<Duration> _retryBackoff = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 2),
  ];

  static int _consecutiveFailures = 0;
  static DateTime? _nextAttemptAt;
  static Future<void>? _inFlight;

  /// 当前生效的加密模式
  static EncryptionMode get current => _current;

  /// 是否已初始化
  static bool get isInitialized => _initialized;

  /// 从后端 policy API 刷新加密模式。
  ///
  /// 在 AppFeatureRegistry.refresh() 之后调用。
  ///
  /// - [force]（默认 true）：忽略退避窗口，用于 App 启动/用户显式刷新。
  /// - `force: false`：仅在退避窗口到期后才真正发起请求，用于发送路径
  ///   被 fail-closed 拦下时的按需重拉，避免离线时每次点击都打 policy 端点。
  ///
  /// 并发去重：同一时刻只有一个请求在飞，其余调用共享同一个 Future。
  static Future<void> refresh({bool force = true}) async {
    final Future<void>? inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    if (!force && !_backoffElapsed()) return;

    final Future<void> future = _doRefresh();
    _inFlight = future;
    try {
      await future;
    } finally {
      _inFlight = null;
    }
  }

  /// 策略未就绪时由 [PolicyGate] 调用：按退避窗口发起一次后台重拉。
  ///
  /// 安全语义不变：本次发送**仍然**被 fail-closed 拒掉，这里只是让"下一次"
  /// 尝试有机会拿到策略——消除"启动时一次拉取失败 = 本进程内永久发不出消息"
  /// 这种无谓阻断，而不是放开闸门。
  static void requestRefreshIfStale() {
    if (_initialized) return;
    unawaited(refresh(force: false));
  }

  static bool _backoffElapsed() {
    final DateTime? next = _nextAttemptAt;
    return next == null || !DateTime.now().isBefore(next);
  }

  static Future<void> _doRefresh() async {
    try {
      final Map<String, dynamic> capabilities = await _fetchCapabilities();
      final storageMode = capabilities['storage_mode']?.toString() ?? '';
      final e2eeMode = capabilities['e2ee_mode']?.toString() ?? '';

      // 决定加密模式：e2ee_mode 优先级高于 storage_mode
      if (e2eeMode == 'required' || storageMode == 'secure_e2ee') {
        _current = EncryptionMode.strictE2ee;
      } else if (e2eeMode == 'compliance' || storageMode == 'compliance_e2ee') {
        _current = EncryptionMode.complianceE2ee;
      } else {
        _current = EncryptionMode.plaintext;
      }

      _initialized = true;
      _consecutiveFailures = 0;
      _nextAttemptAt = null;
    } on Object catch (_) {
      // 拉取失败一律不动 _current / _initialized：
      // - 从未成功过 → _initialized 仍为 false，PolicyGate 继续 fail-closed
      //   拒发 C2C/C2G（ADR 14 §S1.1）。绝不因为"拉不到"就按 plaintext 放行。
      // - 曾经成功过 → 沿用上次成功的 policy 而非降级为明文（既有行为，
      //   见类文档"过期 policy 复用"一节）。
      // 只累计失败次数并推迟下次尝试，形成有界退避而非永久卡死。
      _consecutiveFailures++;
      final int idx = _consecutiveFailures - 1 < _retryBackoff.length
          ? _consecutiveFailures - 1
          : _retryBackoff.length - 1;
      _nextAttemptAt = DateTime.now().add(_retryBackoff[idx]);
    }
  }

  /// 测试注入点：返回 policy 的 capabilities；抛异常表示拉取失败。
  @visibleForTesting
  static Future<Map<String, dynamic>> Function()? debugFetcher;

  static Future<Map<String, dynamic>> _fetchCapabilities() async {
    final Future<Map<String, dynamic>> Function()? override = debugFetcher;
    if (override != null) return override();

    final IMBoyHttpResponse response = await HttpClient.client.get(
      API.appPolicy,
    );
    // 非 200 / 响应体不合法也算拉取失败：走退避重试，而不是像旧实现那样
    // 静默 return 让 _initialized 永远停在 false 且无人重试。
    if (!response.ok || response.payload is! Map) {
      throw StateError('policy_fetch_failed');
    }
    final data = response.payload as Map;
    final Object? capabilities = data['capabilities'];
    return capabilities is Map
        ? Map<String, dynamic>.from(capabilities)
        : <String, dynamic>{};
  }

  /// 测试专用：直接设置策略状态（fail-closed 门测试用），并复位重试状态。
  @visibleForTesting
  static void debugSet({
    required EncryptionMode mode,
    required bool initialized,
  }) {
    _current = mode;
    _initialized = initialized;
    _consecutiveFailures = 0;
    _nextAttemptAt = null;
    _inFlight = null;
  }
}

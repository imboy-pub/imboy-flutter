/// 三层加密模式定义
///
/// 对应后端 imboy_policy 的 storage_mode 和 e2ee_mode:
/// - plaintext: 明文传输��不加密
/// - compliance_e2ee: AES key 双加密（接收方公钥 + 合规公钥）
/// - strict_e2ee: 仅接收方公钥加密（现有 E2EE 逻辑）
library;

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
/// 从后端 /v1/app/policy API 获取当前部署的加密策略，
/// 供 E2EEService 和消息发送流程参考。
class EncryptionModeService {
  EncryptionModeService._();

  static EncryptionMode _current = EncryptionMode.plaintext;
  static bool _initialized = false;

  /// 当前生效的加密模式
  static EncryptionMode get current => _current;

  /// 是否已初始化
  static bool get isInitialized => _initialized;

  /// 从后端 policy API 刷新加密模式
  /// 在 AppFeatureRegistry.refresh() 之后调用
  static Future<void> refresh() async {
    try {
      final IMBoyHttpResponse response = await HttpClient.client.get(
        API.appPolicy,
      );
      if (!response.ok || response.payload is! Map) {
        return;
      }

      final data = response.payload as Map;
      final capabilities = data['capabilities'] as Map? ?? {};
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
    } catch (e) {
      // 策略加载失败时，保留上次成功的模式而非静默降级为明文
      // 如果从未成功初始化过，保持 plaintext 但标记为未初始化，
      // 后续发送消息时应检查 _initialized 状态
      // _initialized 保持 false，强制下次重新加载
    }
  }
}

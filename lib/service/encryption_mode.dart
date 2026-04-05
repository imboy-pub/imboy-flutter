/// 三层加密模式定义
///
/// 对应后端 imboy_policy 的 storage_mode 和 e2ee_mode:
/// - plaintext: 明文传输，不加密
/// - compliance_e2ee: AES key 双加密（接收方公钥 + 合规公钥）
/// - strict_e2ee: 仅接收方公钥加密（现有 E2EE 逻辑）
library;

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

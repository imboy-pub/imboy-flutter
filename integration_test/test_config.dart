// DEPRECATED: 此文件已无活跃引用，请勿新增依赖。
// 配置改用 integration_test/flows/test_utils.dart 中的 FlowConfig。
// flutter test integration_test/e2e_chat_test.dart \
//   --dart-define=TEST_PHONE=13800138000 \
//   --dart-define=TEST_PASSWORD=test123456

/// 测试配置类
class TestConfig {
  TestConfig._();

  /// 测试手机号
  ///
  /// 通过 --dart-define=TEST_PHONE=xxx 设置
  static String get testPhone {
    return const String.fromEnvironment('TEST_PHONE', defaultValue: '');
  }

  /// 测试密码
  ///
  /// 通过 --dart-define=TEST_PASSWORD=xxx 设置
  static String get testPassword {
    return const String.fromEnvironment('TEST_PASSWORD', defaultValue: '');
  }

  /// 测试验证码（如果使用验证码登录）
  ///
  /// 通过 --dart-define=TEST_CODE=xxx 设置
  static String get testCode {
    return const String.fromEnvironment('TEST_CODE', defaultValue: '');
  }

  /// 检查测试账号是否已配置
  ///
  /// 至少需要配置手机号和密码（或验证码）
  static bool get isConfigured {
    return testPhone.isNotEmpty &&
        (testPassword.isNotEmpty || testCode.isNotEmpty);
  }

  /// 获取配置状态描述
  static String get configStatus {
    if (!testPhone.isNotEmpty) {
      return '未配置 TEST_PHONE';
    }
    if (testPassword.isEmpty && testCode.isEmpty) {
      return '未配置 TEST_PASSWORD 或 TEST_CODE';
    }
    return '配置完成: phone=${_maskPhone(testPhone)}';
  }

  /// 脱敏手机号
  static String _maskPhone(String phone) {
    if (phone.length < 7) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }

  /// 打印配置帮助信息
  static void printHelp() {
    print('''
========================================
  集成测试配置说明
========================================

测试需要配置测试账号，有以下两种方式：

方式 1：使用环境变量（推荐）
----------------------------------------
flutter test integration_test/e2e_chat_test.dart \\
  --dart-define=TEST_PHONE=13800138000 \\
  --dart-define=TEST_PASSWORD=test123456

方式 2：使用验证码登录
----------------------------------------
flutter test integration_test/e2e_chat_test.dart \\
  --dart-define=TEST_PHONE=13800138000 \\
  --dart-define=TEST_CODE=123456

当前配置状态：$configStatus
========================================
''');
  }
}

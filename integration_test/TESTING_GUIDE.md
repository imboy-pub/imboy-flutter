# IM Boy 自动化测试指南

## 📋 概述

本指南描述了 IM Boy 应用的自动化测试框架，支持 **macOS**、**iOS** 和 **Android** 平台。

## 🎯 测试框架能力

| 功能 | 描述 | 状态 |
|------|------|------|
| **模拟真人操作** | 点击、滑动、输入、等待 | ✅ |
| **自动截图** | 每个步骤自动截图 | ✅ |
| **日志记录** | 详细记录操作和错误 | ✅ |
| **HTML 报告** | 生成美观的测试报告 | ✅ |
| **错误捕获** | 自动捕获异常和堆栈 | ✅ |
| **智能等待** | 自动等待元素出现 | ✅ |

## 🚀 快速开始

### 1. 运行所有测试

```bash
# macOS
cd /Users/leeyi/project/imboy.pub/imboyapp
flutter test integration_test --dart-define=APP_ENV=local_office -d macos

# iOS (需要连接设备或模拟器)
flutter test integration_test --dart-define=APP_ENV=local_office -d iphone

# Android (需要连接设备或模拟器)
flutter test integration_test --dart-define=APP_ENV=local_office -d android
```

### 2. 运行单个测试文件

```bash
# 演示测试（验证框架）
flutter test integration_test/simple_demo_test.dart --dart-define=APP_ENV=local_office -d macos

# 单聊功能测试
flutter test integration_test/chat/c2c_chat_test.dart --dart-define=APP_ENV=local_office -d macos

# 群组聊天测试
flutter test integration_test/chat/group_chat_test.dart --dart-define=APP_ENV=local_office -d macos

# 会话管理测试
flutter test integration_test/chat/conversation_test.dart --dart-define=APP_ENV=local_office -d macos

# 好友管理测试
flutter test integration_test/contact/friend_management_test.dart --dart-define=APP_ENV=local_office -d macos

# 增强框架示例
flutter test integration_test/enhanced_chat_test.dart --dart-define=APP_ENV=local_office -d macos
```

### 3. 运行全部测试

```bash
# 运行全功能测试套件
flutter test integration_test/all_tests.dart --dart-define=APP_ENV=local_office -d macos

# 或运行整个测试目录
flutter test integration_test --dart-define=APP_ENV=local_office -d macos
```

### 3. 查看测试报告

测试完成后，报告会生成在 `test_output/` 目录：

```bash
# 在浏览器中打开 HTML 报告
open test_output/report.html
```

## 📁 文件结构

```
integration_test/
├── helper/
│   ├── test_enhanced_helper.dart    # 增强测试辅助类
│   └── test_html_reporter.dart      # HTML 报告生成器
├── enhanced_chat_test.dart           # 增强聊天测试示例
├── simulate_chat_v2.dart             # 原始聊天模拟测试
├── app_simple_test.dart              # 简单应用测试
├── login_test.dart                   # 登录测试
└── TESTING_GUIDE.md                  # 本文档
```

## 💡 编写新测试

### 可用的测试文件

| 文件 | 功能 | 平台 |
|------|------|------|
| `simple_demo_test.dart` | 演示测试（验证框架） | macOS |
| `chat/c2c_chat_test.dart` | 单聊功能测试 | macOS |
| `chat/group_chat_test.dart` | 群组聊天测试 | macOS |
| `chat/conversation_test.dart` | 会话管理测试 | macOS |
| `contact/friend_management_test.dart` | 好友管理测试 | macOS |
| `all_tests.dart` | 全功能测试套件 | macOS |
| `enhanced_chat_test.dart` | 增强框架示例 | macOS |

### 测试模板

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/main.dart' as app;
import 'helper/test_enhanced_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('我的测试', (WidgetTester tester) async {
    // 创建测试辅助类
    final helper = EnhancedTestHelper(tester);
    helper.startSession('my_test', 'macOS');

    try {
      // 步骤 1: 启动应用
      await helper.step(
        'launch',
        '启动应用',
        action: () async {
          app.main();
          await helper.waitForLoad();
        },
      );

      // 步骤 2: 执行操作
      await helper.step(
        'tap_button',
        '点击按钮',
        action: () async {
          final button = find.text('按钮文本');
          await helper.tap(button);
        },
      );

      // 步骤 3: 输入文本
      await helper.step(
        'enter_text',
        '输入文本',
        action: () async {
          final input = find.byType(TextField);
          await helper.enterText(input, 'Hello World');
        },
      );

      // 标记测试通过
      await helper.finishSession(passed: true);

    } catch (e) {
      // 标记测试失败
      await helper.finishSession(passed: false);
      rethrow;
    }
  });
}
```

### 常用操作

```dart
// 等待元素出现
final button = find.text('按钮');
await helper.waitFor(button, timeout: Duration(seconds: 10));

// 点击元素
await helper.tap(button);

// 输入文本
final input = find.byType(TextField);
await helper.enterText(input, '文本内容');

// 滑动列表
final list = find.byType(ListView);
await helper.scroll(list, delta: Offset(0, -500));

// 截图
await helper.screenshot('步骤名称');

// 查找元素
find.text('文本')              // 按文本查找
find.byType(Button)           // 按类型查找
find.byIcon(Icons.send)       // 按图标查找
```

## 📊 测试报告

### HTML 报告特性

- 📈 测试概览统计
- 🎨 美观的 UI 设计
- 🖼️ 截图展示
- 🔍 错误详情
- 📱 响应式设计

### 报告内容

- 总测试数
- 通过/失败统计
- 每个测试的详细步骤
- 每步的截图
- 错误堆栈信息

## 🔧 故障排查

### 编译时间过长

首次编译 macOS 应用需要 10-15 分钟，这是正常的。后续编译会快很多。

### Widget 找不到

1. 增加等待时间
2. 检查 Widget 树结构
3. 使用更通用的选择器

### 测试超时

```dart
// 增加超时时间
await helper.waitFor(finder, timeout: Duration(seconds: 30));
```

### 截图失败

确保 `test_output/screenshots` 目录存在并有写入权限。

## 🎯 下一步

1. 为核心功能编写更多测试
2. 添加 CI/CD 集成
3. 增加测试覆盖率
4. 添加性能测试

## 📝 相关文档

- [Flutter Testing 文档](https://docs.flutter.dev/cookbook/testing)
- [Integration Testing 文档](https://docs.flutter.dev/cookbook/testing/integration/introduction)
- [Widget Testing 文档](https://docs.flutter.dev/cookbook/testing/widget/introduction)

# IM Boy Flutter 集成测试

## 概述

这是 IM Boy Flutter App 的集成测试套件，使用 Flutter 官方的 `integration_test` 框架。

## 测试文件

| 文件 | 描述 |
|------|------|
| `app_simple_test.dart` | 基础应用启动和组件测试 |
| `login_test.dart` | 登录流程测试 |
| `chat_test.dart` | 聊天功能测试 |
| `e2e_chat_test.dart` | 端到端聊天测试 |

## 运行测试

### 运行所有测试

```bash
# macOS
flutter test integration_test --dart-define=APP_ENV=local_office -d macos

# iPhone
flutter test integration_test --dart-define=APP_ENV=local_office -d 00008140-000E30561E32801C

# Chrome
flutter test integration_test --dart-define=APP_ENV=local_office -d chrome
```

### 运行单个测试文件

```bash
# 运行基础测试
flutter test integration_test/app_simple_test.dart --dart-define=APP_ENV=local_office -d macos

# 运行登录测试
flutter test integration_test/login_test.dart --dart-define=APP_ENV=local_office -d macos

# 运行聊天测试
flutter test integration_test/chat_test.dart --dart-define=APP_ENV=local_office -d macos

# 运行端到端测试
flutter test integration_test/e2e_chat_test.dart --dart-define=APP_ENV=local_office -d macos
```

## 测试输出

测试运行时会：
1. 启动应用
2. 执行测试步骤
3. 输出日志信息
4. 验证结果
5. 生成测试报告

## 编写新测试

### 测试模板

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:imboy/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('测试组名称', () {
    testWidgets('测试名称', (WidgetTester tester) async {
      // 启动应用
      app.main();
      await tester.pumpAndSettle();

      // 等待加载
      await tester.pump(const Duration(seconds: 2));

      // 执行测试操作
      final button = find.text('按钮文本');
      if (tester.any(button)) {
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      // 验证结果
      expect(find.text('期望文本'), findsOneWidget);
    });
  });
}
```

## 常用操作

### 查找 Widget

```dart
// 按文本查找
find.text('文本')

// 按类型查找
find.byType(Scaffold)

// 按图标查找
find.byIcon(Icons.send)

// 按文本包含查找
find.textContaining('部分文本')
```

### 操作 Widget

```dart
// 点击
await tester.tap(finder);

// 输入文本
await tester.enterText(finder, '文本');

// 滚动
await tester.drag(finder, Offset(0, -500));

// 等待
await tester.pumpAndSettle();
await tester.pump(const Duration(seconds: 2));
```

### 验证结果

```dart
// 验证存在
expect(finder, findsOneWidget);
expect(finder, findsWidgets);
expect(finder, findsNothing);

// 验证文本
expect(find.text('期望文本'), findsOneWidget);
```

## 故障排查

### 测试超时

增加等待时间：
```dart
await tester.pump(const Duration(seconds: 5));
```

### Widget 找不到

1. 检查 Widget 树结构
2. 使用更通用的选择器
3. 增加等待时间

### 构建失败

1. 运行 `flutter clean`
2. 运行 `flutter pub get`
3. 重新运行测试

## 相关文档

- [Flutter Testing 文档](https://docs.flutter.dev/cookbook/testing)
- [Integration Testing 文档](https://docs.flutter.dev/cookbook/testing/integration/introduction)
- [Widget Testing 文档](https://docs.flutter.dev/cookbook/testing/widget/introduction)

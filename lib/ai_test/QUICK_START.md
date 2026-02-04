# AI 测试框架 - 快速入门指南

> 🚀 5 分钟上手 AI 测试框架

## 前置要求

- Flutter SDK 3.0+
- Dart SDK 3.0+
- 基本的 Flutter/Dart 知识

## 快速安装

### 1. 添加依赖

在 `pubspec.yaml` 中添加：

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter

  # AI 测试框架已包含在 imboy 包中
```

### 2. 导入框架

```dart
// 在测试文件中导入
import 'package:imboy/ai_test/orchestration/test_orchestrator.dart';
import 'package:imboy/ai_test/orchestration/test_execution_result.dart';
```

## 场景 1: 从零开始创建 AI 测试

### 目标
用自然语言描述测试需求，让 AI 自动生成并执行测试。

### 代码

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/ai_test/orchestration/test_orchestrator.dart';

void main() {
  test('AI 自动生成并执行测试', () async {
    // 1. 创建测试任务（使用自然语言描述）
    final task = const TestTask(
      id: 'user_login',
      description: '用户登录功能测试',
      intent: '''
        作为一个用户，
        我想要使用用户名 "testuser" 和密码 "password123" 登录，
        以便访问系统的个人中心页面
      ''',
      priority: 0.9,
    );

    // 2. 初始化 AI 测试编排器
    final orchestrator = AITestOrchestrator(
      config: const TestConfiguration.quick,
    );

    // 3. 执行测试
    final result = await orchestrator.executeTask(task);

    // 4. 验证结果
    expect(result.isSuccess, isTrue);
    print('✅ 测试通过！');
    print('执行时间: ${result.duration.inSeconds}秒');

    await orchestrator.dispose();
  });
}
```

### 运行

```bash
flutter test test/ai_test/quick_start_example1.dart
```

## 场景 2: 批量测试多个功能

### 目标
一次性测试多个功能模块。

### 代码

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/ai_test/orchestration/test_orchestrator.dart';

void main() {
  test('批量执行多个测试', () async {
    // 1. 定义测试任务列表
    final tasks = [
      const TestTask(
        id: 'auth_login',
        description: '用户登录',
        intent: '验证用户登录功能',
        priority: 0.9,
        tags: ['auth', 'critical'],
      ),
      const TestTask(
        id: 'auth_register',
        description: '用户注册',
        intent: '验证用户注册功能',
        priority: 0.8,
        tags: ['auth'],
      ),
      const TestTask(
        id: 'chat_send',
        description: '发送消息',
        intent: '验证消息发送功能',
        priority: 0.7,
        tags: ['chat'],
      ),
      const TestTask(
        id: 'profile_update',
        description: '更新资料',
        intent: '验证用户资料更新功能',
        priority: 0.6,
        tags: ['profile'],
      ),
    ];

    // 2. 初始化编排器
    final orchestrator = AITestOrchestrator(
      config: const TestConfiguration.full,
    );

    // 3. 批量执行
    final results = await orchestrator.executeTasks(tasks);

    // 4. 输出结果
    print('═════════════════════════════');
    print('   测试执行报告');
    print('═════════════════════════════');

    for (final result in results) {
      final status = result.isSuccess ? '✅' : '❌';
      print('$status ${result.taskDescription}');
      print('   耗时: ${result.duration.inMilliseconds}ms');
      print('   成功率: ${(result.successRate * 100).toStringAsFixed(0)}%');
      print('');
    }

    // 5. 生成报告
    final report = await orchestrator.generateReport();
    print('总体成功率: ${(report.summary['successRate'] as double * 100).toStringAsFixed(0)}%');

    await orchestrator.dispose();
  });
}
```

## 场景 3: 模拟真实用户行为

### 目标
使用人类行为模拟器进行更真实的测试。

### 代码

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/ai_test/human_simulation/human_simulator.dart';
import 'package:imboy/ai_test/human_simulation/session_simulator.dart';

void main() {
  group('人类行为模拟测试', () {
    test('新手用户登录流程', () async {
      // 1. 创建新手用户模拟器
      final simulator = HumanSimulator(
        config: UserBehaviorConfig.noviceUser,
      );
      final session = UserSessionSimulator(simulator: simulator);

      // 2. 执行登录场景
      final result = await session.runScenario(SessionScenario.login);

      // 3. 验证结果
      expect(result.goalCompleted, isTrue);
      expect(result.actions, isNotEmpty);

      // 4. 输出详情
      print('═════════════════════════════');
      print('   新手用户登录测试报告');
      print('═════════════════════════════');
      print('场景: ${result.scenario.name}');
      print('执行动作: ${result.actions.length}');
      print('成功动作: ${result.successCount}');
      print('失败动作: ${result.failureCount}');
      print('成功率: ${(result.successRate * 100).toStringAsFixed(0)}%');
      print('总耗时: ${result.duration.inSeconds}秒');

      // 5. 分析动作详情
      for (final action in result.actions) {
        final status = action.succeeded ? '✅' : '❌';
        print('$status ${action.type.name}: ${action.targetElement ?? inputData(action)}');
      }
    });

    test('专家用户快速操作', () async {
      // 创建专家用户模拟器
      final simulator = HumanSimulator(
        config: UserBehaviorConfig.expertUser,
      );
      final session = UserSessionSimulator(simulator: simulator);

      // 执行发送消息场景
      final result = await session.runScenario(SessionScenario.sendMessage);

      // 专家用户应该更快完成
      expect(result.duration.inSeconds, lessThan(10));
      expect(result.successRate, greaterThan(0.8));

      print('专家用户耗时: ${result.duration.inSeconds}秒');
      print('专家用户成功率: ${(result.successRate * 100).toStringAsFixed(0)}%');
    });
  });
}

String inputData(UserAction action) {
  return action.inputData ?? action.expectedResult ?? '';
}
```

## 场景 4: 生成可视化测试报告

### 目标
生成 HTML 格式的测试报告，方便查看和分享。

### 代码

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/ai_test/orchestration/test_orchestrator.dart';
import 'package:imboy/ai_test/orchestration/report_generator.dart';

void main() {
  test('生成 HTML 测试报告', () async {
    // 1. 准备测试数据
    final orchestrator = AITestOrchestrator(
      config: const TestConfiguration.full,
    );

    final results = await orchestrator.executeTasks([
      const TestTask(
        id: 'test1',
        description: '测试用例 1',
        intent: '验证功能 1',
      ),
      const TestTask(
        id: 'test2',
        description: '测试用例 2',
        intent: '验证功能 2',
      ),
    ]);

    // 2. 生成报告
    final report = await orchestrator.generateReport(
      results: results,
      includeDetails: true,
    );

    // 3. 导出为 HTML
    final generator = ReportGenerator();
    final htmlReport = await generator.exportToFile(
      report,
      'test_reports/ai_test_report',
      ReportFormat.html,
    );

    // 4. 打开报告
    print('✅ HTML 报告已生成: ${htmlReport.path}');

    // 在浏览器中打开（可选）
    // Process.run('open', [htmlReport.path]);

    await orchestrator.dispose();
  });
}
```

### 报告示例

生成的 HTML 报告包含：
- 📊 测试摘要（总数、通过、失败、成功率）
- 💡 智能建议
- 📋 详细测试结果
- 📈 性能分析

## 场景 5: 自愈测试

### 目标
使用自愈引擎自动修复测试失败。

### 代码

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/ai_test/healing/self_healing_engine.dart';
import 'package:imboy/ai_test/orchestration/test_execution_result.dart';

void main() {
  test('自愈引擎示例', () async {
    final engine = SelfHealingEngine();

    // 模拟一个测试失败
    final failure = TestError(
      type: TestErrorType.execution,
      message: '元素未找到: #login-button',
      stackTrace: '''
  at WidgetTester.pump (package:flutter_test/src/widget_tester.dart)
  at main.<anonymous closure> (test/app_test.dart:25)
      ''',
    );

    // 执行自愈
    final result = await engine.heal(
      failure,
      context: {
        'page': 'login',
        'attemptedSelector': '#login-button',
        'availableSelectors': [
          '#btn-login',
          '[data-testid="login-button"]',
          '.login-btn',
        ],
      },
    );

    // 验证自愈结果
    print('═════════════════════════════');
    print('   自愈引擎报告');
    print('═════════════════════════════');
    print('原始错误: ${result.originalError.message}');
    print('自愈成功: ${result.success}');
    print('解决方案: ${result.solution}');
    print('应用的修复: ${result.appliedFix}');
    print('置信度: ${(result.confidence * 100).toStringAsFixed(0)}%');
    print('需要人工干预: ${result.needsHumanIntervention ? '是' : '否'}');

    if (result.success) {
      print('✅ 测试已自动修复！');
    } else {
      print('⚠️  需要人工处理');
    }
  });
}
```

## 配置预设

### 快速测试（开发阶段）

```dart
final config = const TestConfiguration.quick;
```

- 仅启用核心功能
- 较短的超时时间
- 无详细报告

### 完整测试（CI/CD）

```dart
final config = const TestConfiguration.full;
```

- 启用所有功能
- 较长的超时时间
- 生成详细报告
- 更高的覆盖率目标

### 自定义配置

```dart
final config = const TestConfiguration(
  enableIntentParser: true,
  enableSelfHealing: true,
  enableKnowledgeBase: false,  // 禁用知识库
  enablePathExplorer: true,
  enableHumanSimulation: false,  // 禁用人类模拟
  maxExecutionTime: 180,
  concurrency: 5,
  coverageGoal: 0.75,
);
```

## 常见问题

### Q: 如何提高测试成功率？

A:
1. 使用更明确的自然语言描述测试意图
2. 启用自愈引擎自动修复问题
3. 使用人类模拟器发现真实用户问题

### Q: 测试执行太慢怎么办？

A:
1. 使用 `TestConfiguration.quick` 快速配置
2. 调整 `concurrency` 参数增加并发数
3. 减少启用功能的数量

### Q: 如何调试测试失败？

A:
1. 查看 `TestExecutionResult.errors` 获取详细错误信息
2. 使用 `generateDetailedReport()` 生成详细报告
3. 检查 `performanceMetrics` 分析性能瓶颈

## 下一步

- 📖 阅读 [完整 API 文档](./lib/ai_test/README.md)
- 💡 查看 [示例代码](./lib/ai_test/examples/)
- 🧪 运行 [单元测试](../../test/ai_test/)

---

**祝测试愉快！** 🎉

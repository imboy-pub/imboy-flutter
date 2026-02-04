# AI 测试框架 (AI Testing Framework)

> 🤖 基于 AI 的智能测试自动化框架 - 让测试更智能、更高效

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-brightgreen.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)](https://dart.dev/)

## 📋 目录

- [概述](#概述)
- [核心特性](#核心特性)
- [快速开始](#快速开始)
- [架构设计](#架构设计)
- [使用指南](#使用指南)
- [API 文档](#api-文档)
- [示例代码](#示例代码)
- [测试覆盖](#测试覆盖)
- [贡献指南](#贡献指南)

## 概述

AI 测试框架是一个基于 Dart/Flutter 的智能测试自动化解决方案，通过整合 AI 能力大幅提升测试效率和可维护性。

### 主要优势

- 🎯 **AI 驱动的测试生成** - 从自然语言描述自动生成测试用例
- 🔧 **自愈能力** - 自动识别并修复常见的测试失败
- 📊 **智能路径探索** - 自动发现和优化测试路径
- 🧠 **知识积累** - 从测试历史中学习，持续优化
- 👤 **人类行为模拟** - 模拟真实用户行为进行测试
- 📈 **全面报告** - 多格式测试报告和性能分析

## 核心特性

### 1. AI 意图解析器 (Intent Parser)

将用户需求转换为可执行的测试用例：

```dart
final parser = IntentParser();
final testCases = await parser.parseFromUserStory(
  '用户能够使用正确的用户名和密码登录系统',
);
```

### 2. 自愈引擎 (Self-Healing Engine)

自动识别并修复测试失败：

```dart
final engine = SelfHealingEngine();
final result = await engine.heal(
  failure,
  context: {'selector': '#login-btn'},
);
```

### 3. 路径探索器 (Path Explorer)

智能发现应用的测试路径：

```dart
final explorer = PathExplorer(coverageTracker: tracker);
final result = explorer.explore(
  startingPoint: 'home-page',
);
```

### 4. 人类模拟器 (Human Simulator)

模拟真实用户行为：

```dart
final simulator = HumanSimulator(
  config: UserBehaviorConfig.normalUser,
);
await simulator.tap(targetElement: '#submit-btn');
await simulator.typeText(
  targetElement: '#username',
  text: 'testuser',
);
```

### 5. 测试编排器 (Test Orchestrator)

统一的测试执行引擎：

```dart
final orchestrator = AITestOrchestrator(
  config: TestConfiguration.full,
);
final result = await orchestrator.executeTask(task);
```

## 快速开始

### 安装

```yaml
dependencies:
  imboy:
    path: ../imboy
```

### 基础使用

```dart
// 1. 创建测试任务
final task = const TestTask(
  id: 'login_test',
  description: '用户登录测试',
  intent: '验证用户可以使用正确的用户名和密码登录',
);

// 2. 初始化编排器
final orchestrator = AITestOrchestrator(
  config: TestConfiguration.quick,
);

// 3. 执行测试
final result = await orchestrator.executeTask(task);

// 4. 生成报告
final report = await orchestrator.generateReport();
print(report.summary);
```

### 运行测试

```bash
# 运行所有 AI 测试
flutter test test/ai_test/

# 运行特定模块测试
flutter test test/ai_test/intent/
flutter test test/ai_test/healing/
flutter test test/ai_test/orchestration/

# 运行集成测试
flutter test test/ai_test/orchestration_unit_test.dart
```

## 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    AI 测试框架架构                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │          Test Orchestrator (编排器)                  │  │
│  │  • 统一执行入口                                      │  │
│  │  • 配置管理                                         │  │
│  │  • 结果聚合                                         │  │
│  └─────────────────────────────────────────────────────┘  │
│                          │                                 │
│  ┌──────────┬──────────┬──────────┬──────────┬─────────┐  │
│  │          │          │          │          │         │  │
│  ▼          ▼          ▼          ▼          ▼         ▼  │
│ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ │
│ │ Intent │ │Self-   │ │Path    │ │Human   │ │Know-   │ │
│ │Parser  │ │Healing │ │Explorer│ │Simulator│ ledge  │ │
│ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              核心服务层                             │  │
│  │  • Performance Monitor  • Report Generator          │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 使用指南

### 完整测试流程示例

```dart
import 'package:imboy/ai_test/orchestration/test_orchestrator.dart';

void main() async {
  // 1. 初始化编排器
  final orchestrator = AITestOrchestrator(
    config: const TestConfiguration(
      enableIntentParser: true,
      enableSelfHealing: true,
      enablePathExplorer: true,
      enableHumanSimulation: true,
      coverageGoal: 0.8,
    ),
  );

  // 2. 创建测试任务
  final tasks = [
    const TestTask(
      id: 'login',
      description: '用户登录',
      intent: '验证用户登录功能',
      priority: 0.9,
      tags: ['auth', 'critical'],
    ),
    const TestTask(
      id: 'message',
      description: '发送消息',
      intent: '验证消息发送功能',
      priority: 0.8,
      tags: ['chat'],
    ),
  ];

  // 3. 批量执行测试
  final results = await orchestrator.executeTasks(tasks);

  // 4. 生成报告
  final report = await orchestrator.generateReport(
    results: results,
    includeDetails: true,
  );

  // 5. 导出报告
  await orchestrator.exportReport(
    report,
    format: ReportFormat.html,
  );

  // 6. 获取建议
  final suggestions = orchestrator.getSuggestions();
  for (final suggestion in suggestions) {
    print('💡 $suggestion');
  }

  // 7. 清理
  await orchestrator.dispose();
}
```

### 自定义用户行为配置

```dart
final config = UserBehaviorConfig(
  typingSpeed: 8,          // 打字速度（字符/秒）
  readingSpeed: 80,        // 阅读速度（毫秒/字符）
  errorRate: 0.02,         // 错误率 2%
  misclickRate: 0.01,      // 误点击率 1%
  attentionLevel: 0.9,     // 注意力集中度
);

final expertSimulator = HumanSimulator(config: config);
```

### 创建自定义测试场景

```dart
final customScenario = SessionScenario(
  name: '自定义场景',
  description: '用户浏览商品并添加到购物车',
  initialState: UserState(
    currentIntent: UserIntent.browse,
    mood: 0.7,
  ),
  targetIntent: UserIntent.browse,
  expectedSteps: 6,
  priority: 0.8,
);
```

## API 文档

详细的 API 文档请参考：

- [IntentParser API](./lib/ai_test/intent/intent_parser.dart)
- [SelfHealingEngine API](./lib/ai_test/healing/self_healing_engine.dart)
- [PathExplorer API](./lib/ai_test/path_exploration/path_explorer.dart)
- [HumanSimulator API](./lib/ai_test/human_simulation/human_simulator.dart)
- [AITestOrchestrator API](./lib/ai_test/orchestration/test_orchestrator.dart)
- [ReportGenerator API](./lib/ai_test/orchestration/report_generator.dart)

## 示例代码

### 示例 1: 简单的意图解析

```dart
import 'package:imboy/ai_test/intent/intent_parser.dart';

Future<void> example1() async {
  final parser = IntentParser();

  final userStory = '''
  作为一名用户，
  我想要登录系统，
  以便访问我的个人信息
  ''';

  final testCases = await parser.parseFromUserStory(userStory);

  for (final testCase in testCases) {
    print('测试: ${testCase.name}');
    print('描述: ${testCase.description}');
    print('步骤数: ${testCase.steps.length}');
  }
}
```

### 示例 2: 使用自愈引擎

```dart
import 'package:imboy/ai_test/healing/self_healing_engine.dart';

Future<void> example2() async {
  final engine = SelfHealingEngine();

  final failure = TestError(
    type: TestErrorType.execution,
    message: '元素未找到: #login-btn',
    stackTrace: '  at Test.main',
  );

  final result = await engine.heal(
    failure,
    context: {
      'page': 'login',
      'availableSelectors': ['#btn-login', '[data-testid="login"]'],
    },
  );

  if (result.success) {
    print('✅ 自愈成功: ${result.appliedFix}');
  } else {
    print('❌ 自愈失败: ${result.originalError.message}');
  }
}
```

### 示例 3: 人类模拟测试

```dart
import 'package:imboy/ai_test/human_simulation/human_simulator.dart';
import 'package:imboy/ai_test/human_simulation/session_simulator.dart';

Future<void> example3() async {
  // 创建新手用户模拟器
  final novice = HumanSimulator(
    config: UserBehaviorConfig.noviceUser,
  );

  final session = UserSessionSimulator(simulator: novice);

  // 执行登录场景
  final result = await session.runScenario(SessionScenario.login);

  print('场景: ${result.scenario.name}');
  print('动作数: ${result.actions.length}');
  print('成功率: ${(result.successRate * 100).toStringAsFixed(0)}%');
  print('耗时: ${result.duration.inSeconds}秒');
}
```

### 示例 4: 生成测试报告

```dart
import 'package:imboy/ai_test/orchestration/test_orchestrator.dart';
import 'package:imboy/ai_test/orchestration/report_generator.dart';

Future<void> example4() async {
  final orchestrator = AITestOrchestrator();

  // 执行测试...
  final results = await orchestrator.executeTasks([
    const TestTask(
      id: 'test1',
      description: '测试1',
      intent: '意图1',
    ),
  ]);

  // 生成报告
  final report = await orchestrator.generateReport(
    results: results,
    includeDetails: true,
  );

  // 导出多种格式
  final generator = ReportGenerator();

  // JSON
  final json = generator.exportToJson(report);
  print('JSON: ${json.length} 字符');

  // Markdown
  final markdown = generator.exportToMarkdown(report);
  print('Markdown: ${markdown.length} 字符');

  // HTML
  final html = generator.exportToHtml(report);
  print('HTML: ${html.length} 字符');

  await orchestrator.dispose();
}
```

## 测试覆盖

```
总测试数: 150+
├── 意图解析: 15+ 测试
├── 自愈引擎: 20+ 测试
├── 知识库: 25+ 测试
├── 路径探索: 30+ 测试
├── 人类模拟: 29 测试
└── 编排系统: 36 测试
```

## 配置选项

### TestConfiguration

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `enableIntentParser` | bool | true | 启用 AI 意图解析 |
| `enableSelfHealing` | bool | true | 启用自愈引擎 |
| `enableKnowledgeBase` | bool | true | 启用知识库 |
| `enablePathExplorer` | bool | true | 启用路径探索 |
| `enableHumanSimulation` | bool | true | 启用人类模拟 |
| `maxExecutionTime` | int | 300 | 最大执行时间（秒） |
| `concurrency` | int | 3 | 并发测试数 |
| `coverageGoal` | double | 0.8 | 覆盖率目标 (0.0-1.0) |

### UserBehaviorConfig

| 选项 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `typingSpeed` | int | 5 | 打字速度（字符/秒） |
| `readingSpeed` | int | 100 | 阅读速度（毫秒/字符） |
| `errorRate` | double | 0.05 | 错误率 (0.0-1.0) |
| `misclickRate` | double | 0.02 | 误点击率 (0.0-1.0) |
| `attentionLevel` | double | 0.85 | 注意力集中度 (0.0-1.0) |

## 性能指标

- **平均测试执行时间**: ~3-5 秒/测试
- **意图解析响应**: <1 秒
- **自愈成功率**: >70%
- **路径探索效率**: >100 路径/分钟

## 贡献指南

欢迎贡献！请查看 [CONTRIBUTING.md](CONTRIBUTING.md) 了解详情。

### 开发环境

```bash
# 获取代码
git clone https://github.com/your-repo/imboy.git

# 安装依赖
flutter pub get

# 运行测试
flutter test

# 代码检查
flutter analyze
```

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 联系方式

- 项目主页: https://github.com/your-repo/imboy
- 问题反馈: https://github.com/your-repo/imboy/issues
- 邮箱: your-email@example.com

---

**Happy Testing! 🚀**

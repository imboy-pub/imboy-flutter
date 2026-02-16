/// AI 测试框架 - Imboy E2EE 功能真实场景测试
///
/// 使用 Imboy 项目的实际 E2EE 密钥恢复功能需求作为测试场景
/// 验证 AI 测试框架在实际项目中的应用效果
///
/// 运行方式：
/// ```bash
/// flutter test integration_test/ai_imboy_e2ee_test.dart --dart-define=APP_ENV=local_office -d macos
/// ```
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/ai_test/utils/ai_test_helper.dart';

/// Imboy E2EE 功能的用户故事（来自项目实际需求）
const imboyE2EEUserStories = {
  // 场景 1: 本地备份导出/导入
  'local_backup': '''
## 用户故事：本地备份导出/导入

作为用户，我希望能够在更换设备时恢复我的端到端加密密钥，
这样我就不需要重新设置加密功能，也不会丢失历史消息。

**验收条件**:
1. 用户可以导出加密密钥为本地备份文件
2. 用户可以设置备份密码保护备份文件
3. 用户可以从备份文件导入密钥
4. 错误密码时显示友好的错误提示
5. 备份文件使用 .imboy_backup 格式

**前置条件**:
- 用户已登录
- 用户已启用端到端加密
''',

  // 场景 2: 设备间传输
  'device_transfer': '''
## 用户故事：设备间传输

作为用户，我希望能够直接从旧设备传输密钥到新设备，
这样我就可以更方便地在新设备上使用端到端加密功能。

**验收条件**:
1. 旧设备可以创建传输会话
2. 新设备可以扫描二维码接受传输
3. 传输会话在 5 分钟后自动过期
4. 传输成功后两台设备都显示成功状态
5. 过期的会话无法被接受

**前置条件**:
- 用户在两台设备上登录同一账号
- 两台设备都有网络连接
- 旧设备上有有效的加密密钥
''',

  // 场景 3: 社交恢复 - 创建分片
  'social_recovery_create': '''
## 用户故事：社交恢复 - 创建密钥分片

作为用户，我希望能够将我的加密密钥分片存储在可信好友那里，
这样即使我丢失了所有设备，我也可以通过好友恢复我的密钥。

**验收条件**:
1. 用户可以选择 3-5 个可信好友作为代理
2. 系统使用 Shamir Secret Sharing 算法创建密钥分片
3. 分片通过 WebSocket 直接发送给代理（不存储在服务器）
4. 分片使用代理的公钥加密
5. 用户可以设置恢复阈值（至少需要 2 个分片）
6. 每个分片只能使用一次

**前置条件**:
- 用户已登录并启用端到端加密
- 用户至少有 3 个好友
- 所有好友都已启用端到端加密
''',

  // 场景 4: 社交恢复 - 恢复密钥
  'social_recovery_restore': '''
## 用户故事：社交恢复 - 恢复密钥

作为用户，我希望能够在丢失密钥时通过可信好友恢复我的加密密钥，
这样我就可以重新访问我的历史消息。

**验收条件**:
1. 用户可以查看可用的密钥分片
2. 用户需要收集至少阈值数量的分片
3. 用户通过 WebSocket 向代理请求解密分片
4. 代理使用私钥解密分片并返回
5. 收集足够分片后可以重组密钥
6. 已使用的分片标记为"已使用"状态

**前置条件**:
- 用户已创建密钥分片
- 用户丢失了本地密钥（创建了新密钥）
- 至少有阈值数量的代理在线
''',

  // 场景 5: 综合测试
  'comprehensive': '''
## 用户故事：E2EE 密钥恢复完整流程

作为用户，我希望能够在不同场景下灵活地恢复我的端到端加密密钥，
包括本地备份、设备间传输和社交恢复三种方式。

**验收条件**:
1. 三种恢复方式都能正常工作
2. 每种方式都有清晰的错误处理
3. 密钥永远不会在服务器上明文存储
4. 所有敏感数据都经过加密传输
5. UI 交互流畅，操作流程清晰
6. 网络异常时有友好的错误提示

**边界情况**:
- 参数验证（总分片数必须 > 恢复阈值）
- 网络中断时的处理
- 并发操作时的防重复提交
- 会话过期后的正确处理

**前置条件**:
- 用户已登录
- 用户已启用端到端加密
''',
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI 测试框架 - Imboy E2EE 真实场景', () {
    late AITestHelper helper;

    setUpAll(() async {
      helper = AITestHelper();
      print('\n🔐 Imboy E2EE 功能测试');
      print('═' * 70);
    });

    testWidgets('场景 1：本地备份功能测试用例生成', (WidgetTester tester) async {
      print('\n📝 场景 1：本地备份导出/导入');
      print('─' * 70);

      final userStory = imboyE2EEUserStories['local_backup']!;
      print('用户故事：');
      print('${userStory.substring(0, 200)}...');

      // AI 生成测试用例
      print('\n🤖 AI 正在生成测试用例...');
      final tests = await helper.fromString(userStory);

      print('✅ 生成了 ${tests.length} 个测试用例\n');

      // 验证生成的测试用例
      for (final test in tests) {
        print('  测试: ${test.name}');
        print('  类型: ${test.type} | 优先级: ${test.priority}');
        print('  步骤数: ${test.steps.length}');
        print('  描述: ${test.description}');
        print('');
      }

      // 质量验证
      final issues = helper.validateQuality(tests);
      if (issues.isEmpty) {
        print('✅ 质量验证通过');
      } else {
        print('⚠️ 质量问题：');
        for (final issue in issues) {
          print('  - $issue');
        }
      }

      // 统计信息
      final stats = helper.statistics(tests);
      print('\n📊 测试统计：');
      print('  总数: ${stats['total']}');
      print('  平均步骤数: ${stats['average_steps'].toStringAsFixed(1)}');
      print('  按类型: ${stats['by_type']}');
      print('  按优先级: ${stats['by_priority']}');

      expect(tests.length, greaterThan(0), reason: '应该生成至少一个测试用例');
    });

    testWidgets('场景 2：设备间传输功能测试用例生成', (WidgetTester tester) async {
      print('\n📝 场景 2：设备间传输');
      print('─' * 70);

      final userStory = imboyE2EEUserStories['device_transfer']!;
      final tests = await helper.fromString(userStory);

      print('✅ 生成了 ${tests.length} 个测试用例');
      helper.printSummary(tests);

      // 验证关键测试点
      final testNames = tests.map((t) => t.name.toLowerCase()).toList();
      final hasTransferTest = testNames.any((name) =>
          name.contains('传输') || name.contains('transfer') || name.contains('会话'));
      final hasTimeoutTest = testNames.any((name) =>
          name.contains('过期') || name.contains('timeout') || name.contains('expire'));

      expect(hasTransferTest, isTrue, reason: '应包含传输相关测试');
      expect(hasTimeoutTest, isTrue, reason: '应包含过期相关测试');
      expect(tests.length, greaterThan(1), reason: '应生成多个测试用例');
    });

    testWidgets('场景 3：社交恢复创建分片测试', (WidgetTester tester) async {
      print('\n📝 场景 3：社交恢复 - 创建密钥分片');
      print('─' * 70);

      final userStory = imboyE2EEUserStories['social_recovery_create']!;
      final tests = await helper.fromString(userStory);

      print('✅ 生成了 ${tests.length} 个测试用例');

      // 验证测试覆盖关键点
      final testDescriptions = tests.map((t) => t.description.toLowerCase()).toList();
      final hasShardTest = testDescriptions.any((desc) =>
          desc.contains('分片') || desc.contains('shard') || desc.contains('好友'));
      final hasEncryptionTest = testDescriptions.any((desc) =>
          desc.contains('加密') || desc.contains('encrypt') || desc.contains('公钥'));

      expect(hasShardTest, isTrue, reason: '应包含分片创建测试');
      expect(hasEncryptionTest, isTrue, reason: '应包含加密相关测试');
    });

    testWidgets('场景 4：社交恢复密钥恢复测试', (WidgetTester tester) async {
      print('\n📝 场景 4：社交恢复 - 恢复密钥');
      print('─' * 70);

      final userStory = imboyE2EEUserStories['social_recovery_restore']!;
      final tests = await helper.fromString(userStory);

      print('✅ 生成了 ${tests.length} 个测试用例');

      // 验证边界情况测试
      final edgeCases = tests.where((t) => t.type == 'edge').toList();
      final errorCases = tests.where((t) => t.type == 'error').toList();

      print('  边界测试: ${edgeCases.length} 个');
      print('  错误测试: ${errorCases.length} 个');

      expect(edgeCases.length + errorCases.length, greaterThan(0),
          reason: '应包含边界或错误情况测试');
    });

    testWidgets('场景 5：综合测试用例生成', (WidgetTester tester) async {
      print('\n📝 场景 5：综合测试');
      print('─' * 70);

      final userStory = imboyE2EEUserStories['comprehensive']!;
      final tests = await helper.fromString(userStory);

      print('✅ 生成了 ${tests.length} 个测试用例\n');

      // 分析测试覆盖范围
      final coverage = <String, int>{};
      for (final test in tests) {
        final desc = test.description.toLowerCase();
        if (desc.contains('备份') || desc.contains('backup')) {
          coverage['本地备份'] = (coverage['本地备份'] ?? 0) + 1;
        }
        if (desc.contains('传输') || desc.contains('transfer')) {
          coverage['设备传输'] = (coverage['设备传输'] ?? 0) + 1;
        }
        if (desc.contains('社交') || desc.contains('分片') || desc.contains('社交恢复')) {
          coverage['社交恢复'] = (coverage['社交恢复'] ?? 0) + 1;
        }
        if (desc.contains('错误') || desc.contains('异常') || desc.contains('网络')) {
          coverage['错误处理'] = (coverage['错误处理'] ?? 0) + 1;
        }
      }

      print('📊 测试覆盖范围：');
      coverage.forEach((key, value) {
        print('  $key: $value 个测试');
      });

      // 验证三种恢复方式都有覆盖
      expect(coverage['本地备份'], greaterThan(0), reason: '应覆盖本地备份');
      expect(coverage['设备传输'], greaterThan(0), reason: '应覆盖设备传输');
      expect(coverage['社交恢复'], greaterThan(0), reason: '应覆盖社交恢复');
    });

    testWidgets('批量生成：所有场景一起测试', (WidgetTester tester) async {
      print('\n📝 批量生成：所有场景');
      print('═' * 70);

      final allTests = <String, List>{};
      var totalCount = 0;

      for (final entry in imboyE2EEUserStories.entries) {
        final scenario = entry.key;
        final userStory = entry.value;
        print('\n处理场景: $scenario');

        try {
          final tests = await helper.fromString(userStory);
          allTests[scenario] = tests;
          totalCount += tests.length;
          print('  ✓ 生成 ${tests.length} 个测试用例');
        } catch (e) {
          print('  ✗ 生成失败: $e');
        }
      }

      print('\n${'═' * 70}');
      print('📊 总体统计');
      print('  总场景数: ${allTests.length}');
      print('  总测试数: $totalCount');
      print('  平均每场景: ${(totalCount / allTests.length).toStringAsFixed(1)} 个测试');

      // 导出所有测试用例
      const outputPath = 'test_output/imboy_e2ee_tests.json';
      try {
        await helper.generateAndExport(
          imboyE2EEUserStories['comprehensive']!,
          outputPath,
        );
        print('\n✅ 所有测试已导出到: $outputPath');
      } catch (e) {
        print('\n⚠️ 导出失败: $e');
      }

      expect(totalCount, greaterThan(5), reason: '应生成至少 5 个测试用例');
    });

    testWidgets('性能测试：测试生成速度', (WidgetTester tester) async {
      print('\n⚡ 性能测试');
      print('═' * 70);

      final userStory = imboyE2EEUserStories['local_backup']!;
      final iterations = 5;
      final times = <Duration>[];

      print('运行 $iterations 次迭代...\n');

      for (var i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();
        await helper.fromString(userStory);
        stopwatch.stop();

        times.add(stopwatch.elapsed);
        print('  迭代 ${i + 1}: ${stopwatch.elapsedMilliseconds} ms');
      }

      final totalMs = times.fold<int>(0, (sum, t) => sum + t.inMilliseconds);
      final avgTimeMs = totalMs / times.length;
      final maxTimeMs = times.map((t) => t.inMilliseconds).reduce((a, b) => a > b ? a : b);
      final minTimeMs = times.map((t) => t.inMilliseconds).reduce((a, b) => a < b ? a : b);

      print('\n📊 性能统计：');
      print('  平均时间: ${avgTimeMs.toStringAsFixed(0)} ms');
      print('  最大时间: $maxTimeMs ms');
      print('  最小时间: $minTimeMs ms');
      print('  目标: < 30000 ms/用例');
      print('  状态: ${avgTimeMs < 30000 ? '✅ 达标' : '⚠️ 需优化'}');

      expect(avgTimeMs, lessThan(30000), reason: '平均生成时间应小于 30 秒');
    });
  });

  tearDownAll(() {
    print('\n${'═' * 70}');
    print('✅ Imboy E2EE 功能测试完成');
    print('═' * 70);
  });
}

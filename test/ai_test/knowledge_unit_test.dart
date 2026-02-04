/// 知识库系统单元测试
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/ai_test/knowledge/test_history.dart';
import 'package:imboy/ai_test/knowledge/similarity_matcher.dart';
import 'package:imboy/ai_test/knowledge/pattern_learner.dart';
import 'package:imboy/ai_test/knowledge/knowledge_base.dart';

void main() {
  group('知识库系统 - 单元测试', () {
    late TestHistoryStorage history;
    late SimilarityMatcher matcher;
    late PatternLearner learner;
    late KnowledgeBase knowledgeBase;

    setUp(() {
      history = TestHistoryStorage();
      matcher = SimilarityMatcher(history: history);
      learner = PatternLearner(
        history: history,
        config: LearningConfig.fastConfig,
      );
      // 为测试启用模式学习和相似度匹配
      knowledgeBase = KnowledgeBase(
        history: history,
        similarityMatcher: matcher,
        patternLearner: learner,
        config: const KnowledgeBaseConfig(
          enablePatternLearning: true,
          enableSimilarityMatching: true,
          autoLearn: false,
          learnInterval: 10,
          maxRecords: 1000,
        ),
      );
    });

    group('TestHistoryStorage', () {
      test('添加测试记录', () {
        final record = TestExecutionRecord.success(
          testName: '登录测试',
          duration: 1500,
          tags: ['auth', 'login'],
        );

        history.addRecord(record);

        expect(history.getRecords().length, equals(1));
        expect(history.getRecords().first.testName, '登录测试');
      });

      test('区分成功和失败记录', () {
        history.addRecord(TestExecutionRecord.success(
          testName: '成功测试',
          duration: 1000,
        ));

        history.addRecord(TestExecutionRecord.failure(
          testName: '失败测试',
          duration: 2000,
          failureMessage: 'Element not found',
        ));

        expect(history.getSuccessRecords().length, equals(1));
        expect(history.getFailureRecords().length, equals(1));
      });

      test('按测试名称过滤', () {
        history.addRecord(TestExecutionRecord.success(
          testName: '测试A',
          duration: 1000,
        ));

        history.addRecord(TestExecutionRecord.success(
          testName: '测试B',
          duration: 1000,
        ));

        history.addRecord(TestExecutionRecord.success(
          testName: '测试A',
          duration: 1500,
        ));

        final results = history.getRecordsByTestName('测试A');
        expect(results.length, equals(2));
      });

      test('按标签过滤', () {
        history.addRecord(TestExecutionRecord.success(
          testName: '测试1',
          duration: 1000,
          tags: ['auth', 'login'],
        ));

        history.addRecord(TestExecutionRecord.success(
          testName: '测试2',
          duration: 1000,
          tags: ['network'],
        ));

        final authTests = history.getRecordsByTag('auth');
        expect(authTests.length, equals(1));
      });

      test('获取统计信息', () {
        history.addRecord(TestExecutionRecord.success(
          testName: '成功测试',
          duration: 1000,
        ));

        history.addRecord(TestExecutionRecord.failure(
          testName: '失败测试',
          duration: 2000,
          failureMessage: 'Error',
        ));

        final stats = history.getStatistics();
        expect(stats['total'], equals(2));
        expect(stats['success'], equals(1));
        expect(stats['failure'], equals(1));
        expect(stats['successRate'], equals(50));
      });

      test('获取失败频率最高的测试', () {
        history.addRecord(TestExecutionRecord.failure(
          testName: '不稳定的测试',
          duration: 1000,
          failureMessage: 'Error 1',
        ));

        history.addRecord(TestExecutionRecord.failure(
          testName: '不稳定的测试',
          duration: 1000,
          failureMessage: 'Error 2',
        ));

        history.addRecord(TestExecutionRecord.failure(
          testName: '稳定的测试',
          duration: 1000,
          failureMessage: 'Error',
        ));

        final frequentFailures = history.getMostFailingTests(5);
        expect(frequentFailures.first['testName'], '不稳定的测试');
        expect(frequentFailures.first['failureCount'], equals(2));
      });

      test('JSON 序列化', () {
        history.addRecord(TestExecutionRecord.success(
          testName: '测试',
          duration: 1000,
        ));

        final json = history.exportToJson();
        expect(json, isNotEmpty);
        expect(json.contains('"testName":'), isTrue);

        final restored = TestHistoryStorage.fromJson(json);
        expect(restored.getRecords().length, equals(1));
      });
    });

    group('SimilarityMatcher', () {
      test('查找相似的失败记录', () {
        // 添加历史记录
        history.addRecord(TestExecutionRecord.failure(
          testName: '登录按钮测试',
          duration: 2000,
          failureMessage: 'Element not found: #login-button',
          healingSessionId: 'session_1',
        ));

        history.addRecord(TestExecutionRecord.failure(
          testName: '提交按钮测试',
          duration: 1500,
          failureMessage: 'TimeoutException: Waiting exceeded',
        ));

        history.addRecord(TestExecutionRecord.failure(
          testName: '输入框测试',
          duration: 1000,
          failureMessage: 'Element not found: #username-input',
        ));

        // 测试相似度匹配
        final matches = matcher.findSimilarFailures(
          testName: '登录测试',
          errorMessage: 'Element not found: #login-button',
          minScore: 0.3,
        );

        expect(matches, isNotEmpty);
        expect(matches.first.score, greaterThanOrEqualTo(0.3));
      });

      test('查找成功解决方案', () {
        // 添加失败的记录
        history.addRecord(TestExecutionRecord.failure(
          testName: '登录测试',
          duration: 2000,
          failureMessage: 'TimeoutException',
          healingSessionId: 'session_1',
        ));

        // 添加后续成功记录
        final laterTime = DateTime.now().add(const Duration(seconds: 30));
        history.addRecord(TestExecutionRecord(
          id: 'test_2',
          testName: '登录测试',
          timestamp: laterTime,
          success: true,
          duration: 1000,
        ));

        final solutions = matcher.findSuccessfulSolutions('TimeoutException');
        expect(solutions, isNotEmpty);
      });
    });

    group('PatternLearner', () {
      test('学习失败模式', () {
        // 添加足够的历史数据以触发学习
        for (var i = 0; i < 5; i++) {
          history.addRecord(TestExecutionRecord.failure(
            testName: '超时测试_$i',
            duration: 5000,
            failureMessage: 'TimeoutException: Element did not appear',
          ));
        }

        final patterns = learner.learnFromHistory();
        expect(patterns, isNotEmpty);

        // 应该学到超时模式
        final timeoutPatterns = patterns.where((p) =>
            p.name.contains('超时') || p.name.contains('Timeout'));
        expect(timeoutPatterns, isNotEmpty);
      });

      test('匹配模式', () {
        // 添加数据并学习
        for (var i = 0; i < 5; i++) {
          history.addRecord(TestExecutionRecord.failure(
            testName: '网络测试_$i',
            duration: 3000,
            failureMessage: 'SocketException: Connection refused',
          ));
        }

        learner.learnFromHistory();

        // 测试模式匹配
        final matched = learner.matchPatterns('SocketException: Connection refused');
        expect(matched, isNotEmpty);

        // 测试推荐策略
        final strategy = learner.getRecommendedStrategy('SocketException: Connection refused');
        expect(strategy, isNotNull);
        expect(strategy, contains('retry'));
      });

      test('模式摘要', () {
        learner.learnFromHistory();
        learner.printPatternSummary();
      });
    });

    group('KnowledgeBase', () {
      test('记录测试执行', () {
        knowledgeBase.recordTestExecution(
          testName: '测试用例1',
          success: true,
          duration: 1200,
          tags: ['smoke'],
        );

        expect(knowledgeBase.history.getRecords().length, equals(1));
      });

      test('查询知识库 - 相似度匹配', () {
        // 添加一个有愈合会话的失败记录
        final pastTime = DateTime.now().subtract(const Duration(seconds: 5));
        final failureRecord = TestExecutionRecord(
          id: 'test_old',
          testName: '登录测试',
          timestamp: pastTime,
          success: false,
          duration: 2000,
          failureMessage: 'Element not found: #login-btn',
          healingSessionId: 'session_123',
        );
        knowledgeBase.history.addRecord(failureRecord);

        // 添加后续的成功记录
        final successRecord = TestExecutionRecord(
          id: 'test_success',
          testName: '登录测试',
          timestamp: DateTime.now(),
          success: true,
          duration: 1500,
        );
        knowledgeBase.history.addRecord(successRecord);

        // 查询
        final result = knowledgeBase.query(
          testName: '登录测试',
          errorMessage: 'Element not found: #login-btn',
        );

        // 应该能找到推荐解决方案（基于历史成功记录）
        expect(result.recommendedSolutions, isNotEmpty);
      });

      test('获取推荐修复方案 - 基于模式', () {
        // 添加足够的相同类型失败以触发模式学习
        for (var i = 0; i < 5; i++) {
          knowledgeBase.recordTestExecution(
            testName: '网络测试',
            success: false,
            duration: 3000,
            failureMessage: 'SocketException: Connection refused',
          );
        }

        // 添加后续的成功记录，提高成功率
        for (var i = 0; i < 3; i++) {
          knowledgeBase.recordTestExecution(
            testName: '网络测试',
            success: true,
            duration: 1500,
          );
        }

        // 手动触发学习
        final patterns = knowledgeBase.learn();
        print('学到的模式数: ${patterns.length}');
        for (final p in patterns) {
          print('  模式: ${p.name}, 关键词: ${p.triggerKeywords}, 策略: ${p.recommendedStrategy}');
        }

        // 验证学到了模式
        expect(patterns, isNotEmpty);

        // 检查模式匹配
        final matched = learner.matchPatterns('SocketException: Connection refused');
        print('匹配的模式数: ${matched.length}');

        // 获取推荐修复方案
        final strategy = learner.getRecommendedStrategy('SocketException: Connection refused');
        print('推荐策略: $strategy');

        final fixes = knowledgeBase.getRecommendedFixes('SocketException: Connection refused');
        print('修复方案: $fixes');
        expect(fixes, isNotEmpty);
        expect(fixes.first, contains('retry'));
      });

      test('统计信息', () {
        knowledgeBase.recordTestExecution(
          testName: '测试',
          success: true,
          duration: 1000,
        );

        final stats = knowledgeBase.getStatistics();
        expect(stats['history'], isNotNull);
        // 验证历史记录总数
        expect(stats['history']['total'], equals(1));
        expect(stats['history']['success'], equals(1));
      });

      test('打印状态', () {
        knowledgeBase.printStatus();
      });

      test('JSON 导入导出', () {
        knowledgeBase.recordTestExecution(
          testName: '测试',
          success: true,
          duration: 1000,
        );

        final json = knowledgeBase.exportToJson();
        expect(json, isNotEmpty);

        // 验证 JSON 格式
        expect(json.contains('"history":'), isTrue);
        expect(json.contains('"patterns":'), isTrue);
        expect(json.contains('"statistics":'), isTrue);
      });
    });
  });

  group('知识库系统 - 集成测试', () {
    test('完整的知识库流程', () {
      // 创建带有快速学习配置的 PatternLearner
      final testHistory = TestHistoryStorage();
      final testLearner = PatternLearner(
        history: testHistory,
        config: LearningConfig.fastConfig,
      );
      final testMatcher = SimilarityMatcher(history: testHistory);

      final kb = KnowledgeBase(
        history: testHistory,
        similarityMatcher: testMatcher,
        patternLearner: testLearner,
        config: const KnowledgeBaseConfig(
          enablePatternLearning: true,
          enableSimilarityMatching: true,
          autoLearn: false,
          learnInterval: 10,
          maxRecords: 50000,
        ),
      );

      // 1. 记录多次测试执行 - 相同类型的失败和成功
      for (var i = 0; i < 5; i++) {
        kb.recordTestExecution(
          testName: '超时测试',
          success: false,
          duration: 5000,
          failureMessage: 'TimeoutException: Element did not appear',
          testType: 'integration',
          tags: ['ui', 'timeout'],
        );
      }

      // 添加后续的成功记录
      for (var i = 0; i < 5; i++) {
        kb.recordTestExecution(
          testName: '超时测试',
          success: true,
          duration: 1500,
          testType: 'integration',
          tags: ['ui', 'timeout'],
        );
      }

      // 2. 手动学习
      final patterns = kb.learn();
      print('学到的模式数: ${patterns.length}');
      for (final p in patterns) {
        print('  模式: ${p.name}, 置信度: ${p.confidence}, 策略: ${p.recommendedStrategy}');
      }

      // 3. 验证学到了模式
      expect(patterns, isNotEmpty);

      // 4. 获取推荐修复方案
      final fixes = kb.getRecommendedFixes('TimeoutException: Element did not appear');
      print('推荐修复方案: $fixes');
      expect(fixes, isNotEmpty);

      // 5. 验证统计信息
      final stats = kb.getStatistics();
      expect(stats['history']['total'], equals(10));
      expect(stats['patterns']['total'], greaterThan(0));
    });

    test('持续学习场景', () {
      final kb = KnowledgeBase(
        config: KnowledgeBaseConfig(
          autoLearn: true,
          learnInterval: 3, // 每 3 次执行学习一次
        ),
      );

      // 执行多次测试，触发自动学习
      for (var i = 0; i < 10; i++) {
        kb.recordTestExecution(
          testName: '测试_$i',
          success: i < 8, // 大部分成功
          duration: 1000,
          failureMessage: i < 8 ? null : 'Error $i',
        );
      }

      // 验证自动学习
      expect(kb.getStatistics()['executionCount'], greaterThan(0));

      kb.printStatus();
    });
  });
}

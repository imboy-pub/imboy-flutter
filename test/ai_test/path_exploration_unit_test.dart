/// 路径探索系统单元测试
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/ai_test/path_exploration/test_path.dart';
import 'package:imboy/ai_test/path_exploration/coverage_tracker.dart';
import 'package:imboy/ai_test/path_exploration/path_explorer.dart';

void main() {
  group('路径探索系统 - 单元测试', () {
    late CoverageTracker tracker;
    late PathExplorer explorer;

    setUp(() {
      tracker = CoverageTracker();
      explorer = PathExplorer(coverageTracker: tracker);
    });

    group('TestPathStep', () {
      test('创建步骤', () {
        final step = TestPathStep(
          id: 'step_1',
          description: '点击按钮',
          targetSelector: '#submit-btn',
          actionType: PathActionType.tap,
        );

        expect(step.id, 'step_1');
        expect(step.description, '点击按钮');
        expect(step.actionType, PathActionType.tap);
      });

      test('JSON 序列化', () {
        final step = TestPathStep(
          id: 'step_1',
          description: '输入文本',
          targetSelector: '#username',
          actionType: PathActionType.enterText,
          expectedResult: '输入成功',
        );

        final json = step.toJson();
        expect(json['id'], 'step_1');
        expect(json['actionType'], 'enterText');

        final restored = TestPathStep.fromJson(json);
        expect(restored.id, step.id);
        expect(restored.actionType, step.actionType);
      });

      test('创建副本', () {
        final step = TestPathStep(
          id: 'step_1',
          description: '原始步骤',
          actionType: PathActionType.tap,
        );

        final copy = step.copyWith(
          description: '修改后的步骤',
          weight: 0.8,
        );

        expect(copy.id, step.id);
        expect(copy.description, '修改后的步骤');
        expect(copy.weight, 0.8);
      });
    });

    group('TestPath', () {
      test('创建路径', () {
        final path = TestPath(
          id: 'path_1',
          name: '登录流程',
          description: '用户登录测试路径',
          steps: [
            TestPathStep(
              id: 'step_1',
              description: '输入用户名',
              actionType: PathActionType.enterText,
            ),
            TestPathStep(
              id: 'step_2',
              description: '输入密码',
              actionType: PathActionType.enterText,
            ),
            TestPathStep(
              id: 'step_3',
              description: '点击登录',
              actionType: PathActionType.tap,
            ),
          ],
          type: TestPathType.critical,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(path.id, 'path_1');
        expect(path.name, '登录流程');
        expect(path.stepCount, 3);
        expect(path.requiredStepCount, 3);
        expect(path.type, TestPathType.critical);
        expect(path.canExecute, isTrue);
      });

      test('计算路径权重', () {
        final highPriorityPath = TestPath(
          id: 'path_1',
          name: '高优先级路径',
          description: '描述',
          steps: const [],
          priority: 0.9,
          coverageContribution: 0.5,
          type: TestPathType.critical,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // 权重计算: priority*0.4 + coverage*0.3 + stepWeight*0.2 + typeBonus*0.1
        // 0.9*0.4 + 0.5*0.3 + 0*0.2 + 1.0*0.1 = 0.36 + 0.15 + 0 + 0.1 = 0.61
        expect(highPriorityPath.weight, greaterThan(0.5));

        final lowPriorityPath = TestPath(
          id: 'path_2',
          name: '低优先级路径',
          description: '描述',
          steps: const [],
          priority: 0.2,
          coverageContribution: 0.1,
          type: TestPathType.exploratory,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // 0.2*0.4 + 0.1*0.3 + 0*0.2 + 0.4*0.1 = 0.08 + 0.03 + 0 + 0.04 = 0.15
        expect(highPriorityPath.weight, greaterThan(lowPriorityPath.weight));
      });

      test('路径状态转换', () {
        final path = TestPath(
          id: 'path_1',
          name: '测试路径',
          description: '描述',
          steps: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(path.status, PathStatus.pending);

        final completedPath = path.completed();
        expect(completedPath.status, PathStatus.completed);
        expect(completedPath.isCompleted, isTrue);

        final failedPath = path.failed();
        expect(failedPath.status, PathStatus.failed);
      });

      test('JSON 序列化', () {
        final path = TestPath(
          id: 'path_1',
          name: '测试路径',
          description: '描述',
          steps: [
            TestPathStep(
              id: 'step_1',
              description: '步骤1',
              actionType: PathActionType.tap,
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final json = path.toJson();
        expect(json['id'], 'path_1');
        expect(json['steps'], isNotEmpty);

        final restored = TestPath.fromJson(json);
        expect(restored.id, path.id);
        expect(restored.stepCount, path.stepCount);
      });
    });

    group('TestPathSet', () {
      test('添加和管理路径', () {
        final pathSet = TestPathSet();

        final path1 = TestPath(
          id: 'path_1',
          name: '路径1',
          description: '描述1',
          steps: const [],
          modules: ['auth'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final path2 = TestPath(
          id: 'path_2',
          name: '路径2',
          description: '描述2',
          steps: const [],
          modules: ['profile'],
          status: PathStatus.completed,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        pathSet.addPath(path1);
        pathSet.addPath(path2);

        expect(pathSet.getPaths().length, equals(2));
        expect(pathSet.getPathsByModule('auth').length, equals(1));
        expect(pathSet.getCompletedPaths().length, equals(1));
      });

      test('按优先级排序', () {
        final pathSet = TestPathSet();

        pathSet.addPath(TestPath(
          id: 'path_1',
          name: '低优先级',
          description: '描述',
          steps: const [],
          priority: 0.3,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        pathSet.addPath(TestPath(
          id: 'path_2',
          name: '高优先级',
          description: '描述',
          steps: const [],
          priority: 0.9,
          type: TestPathType.critical,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        final sorted = pathSet.getPathsByPriority();
        expect(sorted.first.name, '高优先级');
        expect(sorted.last.name, '低优先级');
      });

      test('计算统计信息', () {
        final pathSet = TestPathSet();

        pathSet.addPath(TestPath(
          id: 'path_1',
          name: '路径1',
          description: '描述',
          steps: [
            TestPathStep(
              id: 'step_1',
              description: '步骤1',
              actionType: PathActionType.tap,
            ),
            TestPathStep(
              id: 'step_2',
              description: '步骤2',
              actionType: PathActionType.enterText,
            ),
          ],
          type: TestPathType.critical,
          status: PathStatus.completed,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        pathSet.addPath(TestPath(
          id: 'path_2',
          name: '路径2',
          description: '描述',
          steps: const [],
          status: PathStatus.pending,
          type: TestPathType.userFlow,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        final stats = pathSet.getStatistics();
        expect(stats['totalPaths'], equals(2));
        expect(stats['completed'], equals(1));
        expect(stats['completionRate'], equals(50));
        expect(stats['totalSteps'], equals(2));
      });
    });

    group('PathStatistics', () {
      test('初始状态', () {
        final stats = const PathStatistics();

        expect(stats.executionCount, equals(0));
        expect(stats.successRate, equals(0.0));
      });

      test('记录执行', () {
        final stats = const PathStatistics();

        final afterSuccess = stats.withExecution(success: true, duration: 1000);
        expect(afterSuccess.executionCount, equals(1));
        expect(afterSuccess.successCount, equals(1));
        expect(afterSuccess.successRate, equals(1.0));
        expect(afterSuccess.avgDuration, equals(1000));

        final afterFailure = afterSuccess.withExecution(success: false, duration: 2000);
        expect(afterFailure.executionCount, equals(2));
        expect(afterFailure.successCount, equals(1));
        expect(afterFailure.failureCount, equals(1));
        expect(afterFailure.successRate, equals(0.5));
        expect(afterFailure.avgDuration, equals(1500));
      });
    });

    group('CoverageTracker', () {
      test('注册和追踪元素', () {
        tracker.registerElement(
          module: 'auth',
          selector: '#login-btn',
          elementType: 'button',
        );

        tracker.recordVisit(
          pathId: 'path_1',
          selector: '#login-btn',
          interactionType: 'tap',
        );

        final coverage = tracker.getModuleCoverage('auth');
        expect(coverage, isNotNull);
        expect(coverage?.totalElements, equals(1));
        expect(coverage?.coveredElements, equals(1));
      });

      test('记录路径执行', () {
        tracker.registerElement(
          module: 'profile',
          selector: '#username-input',
          elementType: 'input',
        );

        tracker.registerElement(
          module: 'profile',
          selector: '#save-btn',
          elementType: 'button',
        );

        final path = TestPath(
          id: 'path_1',
          name: '更新资料',
          description: '描述',
          steps: [
            TestPathStep(
              id: 'step_1',
              description: '输入用户名',
              targetSelector: '#username-input',
              actionType: PathActionType.enterText,
            ),
            TestPathStep(
              id: 'step_2',
              description: '点击保存',
              targetSelector: '#save-btn',
              actionType: PathActionType.tap,
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        tracker.recordPathExecution(path);

        final moduleCoverage = tracker.getModuleCoverage('profile');
        expect(moduleCoverage?.coveredElements, equals(2));
      });

      test('计算总体覆盖率', () {
        tracker.registerElement(
          module: 'auth',
          selector: '#login-btn',
          elementType: 'button',
        );

        tracker.registerElement(
          module: 'auth',
          selector: '#username-input',
          elementType: 'input',
        );

        tracker.recordVisit(
          pathId: 'path_1',
          selector: '#login-btn',
          interactionType: 'tap',
        );

        final overall = tracker.calculateOverallCoverage();
        expect(overall.total, equals(2));
        expect(overall.covered, equals(1));
        expect(overall.coveragePercent, equals(50));
      });

      test('获取低覆盖率模块', () {
        tracker.registerElement(
          module: 'high-coverage',
          selector: '#element-1',
          elementType: 'button',
        );

        tracker.registerElement(
          module: 'high-coverage',
          selector: '#element-2',
          elementType: 'button',
        );

        tracker.recordVisit(
          pathId: 'path_1',
          selector: '#element-1',
          interactionType: 'tap',
        );

        tracker.recordVisit(
          pathId: 'path_1',
          selector: '#element-2',
          interactionType: 'tap',
        );

        tracker.registerElement(
          module: 'low-coverage',
          selector: '#element-3',
          elementType: 'button',
        );

        tracker.registerElement(
          module: 'low-coverage',
          selector: '#element-4',
          elementType: 'button',
        );

        tracker.registerElement(
          module: 'low-coverage',
          selector: '#element-5',
          elementType: 'button',
        );

        tracker.recordVisit(
          pathId: 'path_1',
          selector: '#element-3',
          interactionType: 'tap',
        );

        final lowCoverage = tracker.getLowCoverageModules(threshold: 0.5);
        expect(lowCoverage, contains('low-coverage'));
        expect(lowCoverage, isNot(contains('high-coverage')));
      });

      test('覆盖率目标检查', () {
        // 注册多个元素但只访问部分
        tracker.registerElement(
          module: 'auth',
          selector: '#login-btn',
          elementType: 'button',
        );

        tracker.registerElement(
          module: 'auth',
          selector: '#username-input',
          elementType: 'input',
        );

        tracker.registerElement(
          module: 'auth',
          selector: '#password-input',
          elementType: 'input',
        );

        // 只访问第一个元素，覆盖率为 33%
        tracker.recordVisit(
          pathId: 'path_1',
          selector: '#login-btn',
          interactionType: 'tap',
        );

        expect(tracker.meetsCoverageGoal(threshold: 0.5), isFalse);
        expect(tracker.meetsCoverageGoal(threshold: 0.3), isTrue);
      });
    });

    group('PathExplorer', () {
      test('基本路径探索', () {
        tracker.registerElement(
          module: 'auth',
          selector: '#element_0',
          elementType: 'button',
        );

        final result = explorer.explore(
          startingPoint: 'home',
        );

        expect(result.paths, isNotEmpty);
        expect(result.exploredNodes, greaterThan(0));
        expect(result.coverageInfo, isNotNull);
      });

      test('快速探索配置', () {
        final quickExplorer = PathExplorer(
          coverageTracker: tracker,
          config: ExplorationConfig.quickConfig,
        );

        final result = quickExplorer.explore(startingPoint: 'home');

        expect(result.paths.length, lessThan(30));
        expect(result.duration, lessThan(15000));
      });

      test('探索结果统计', () {
        final result = explorer.explore(startingPoint: 'home');

        final summary = result.getSummary();
        expect(summary['totalPaths'], greaterThan(0));
        expect(summary['exploredNodes'], greaterThan(0));
        expect(summary['completed'], isTrue);
      });

      test('路径类型分布', () {
        final result = explorer.explore(startingPoint: 'home');

        final summary = result.getSummary();
        final byType = summary['byType'] as Map<String, dynamic>;

        expect(byType, isNotNull);
        expect(byType.keys, contains('userFlow'));
      });
    });

    group('集成测试', () {
      test('完整的探索流程', () {
        // 注册应用元素
        tracker.registerElement(
          module: 'auth',
          selector: '#login-btn',
          elementType: 'button',
        );

        tracker.registerElement(
          module: 'auth',
          selector: '#username-input',
          elementType: 'input',
        );

        tracker.registerElement(
          module: 'auth',
          selector: '#password-input',
          elementType: 'input',
        );

        // 探索路径
        final result = explorer.explore(
          startingPoint: 'login-page',
          context: {'page': 'login'},
        );

        print('探索结果: ${result.getSummary()}');

        // 验证
        expect(result.paths, isNotEmpty);
        expect(result.exploredNodes, greaterThan(0));

        // 执行一些路径
        for (final path in result.paths.take(3)) {
          tracker.recordPathExecution(path);
        }

        // 检查覆盖率
        final coverage = tracker.calculateOverallCoverage();
        print('覆盖率: ${coverage.coveragePercent}%');
        expect(coverage.covered, greaterThan(0));
      });

      test('覆盖率优化探索', () {
        // 注册多个元素
        for (var i = 0; i < 10; i++) {
          tracker.registerElement(
            module: 'test',
            selector: '#element-$i',
            elementType: 'button',
          );
        }

        final result = explorer.explore(
          startingPoint: 'test-page',
        );

        // 应该生成一些针对未覆盖元素的路径
        expect(result.paths, isNotEmpty);

        final summary = result.getSummary();
        print('覆盖率优化探索结果: $summary');
      });
    });
  });
}

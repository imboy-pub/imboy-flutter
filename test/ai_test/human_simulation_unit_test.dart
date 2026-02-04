/// 人类模拟系统单元测试
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/ai_test/human_simulation/human_simulator.dart';
import 'package:imboy/ai_test/human_simulation/session_simulator.dart';

void main() {
  group('人类模拟系统 - 单元测试', () {
    late HumanSimulator simulator;
    late UserSessionSimulator sessionSimulator;

    setUp(() {
      simulator = HumanSimulator();
      sessionSimulator = UserSessionSimulator(simulator: simulator);
    });

    group('UserBehaviorConfig', () {
      test('默认配置', () {
        final config = UserBehaviorConfig.normalUser;

        expect(config.typingSpeed, equals(5));
        expect(config.errorRate, equals(0.05));
        expect(config.attentionLevel, equals(0.85));
      });

      test('新手用户配置', () {
        final config = UserBehaviorConfig.noviceUser;

        expect(config.typingSpeed, lessThan(UserBehaviorConfig.normalUser.typingSpeed));
        expect(config.errorRate, greaterThan(UserBehaviorConfig.normalUser.errorRate));
        expect(config.attentionLevel, lessThan(UserBehaviorConfig.normalUser.attentionLevel));
      });

      test('专家用户配置', () {
        final config = UserBehaviorConfig.expertUser;

        expect(config.typingSpeed, greaterThan(UserBehaviorConfig.normalUser.typingSpeed));
        expect(config.errorRate, lessThan(UserBehaviorConfig.normalUser.errorRate));
        expect(config.attentionLevel, equals(0.98));
      });
    });

    group('UserState', () {
      test('创建空闲状态', () {
        final state = UserState.idle();

        expect(state.currentIntent, equals(UserIntent.explore));
        expect(state.mood, equals(0.8));
        expect(state.fatigue, equals(0.0));
      });

      test('状态检查', () {
        final tiredState = UserState(
          currentIntent: UserIntent.browse,
          fatigue: 0.8,
          lastActiveAt: DateTime.now(),
        );

        expect(tiredState.isTired, isTrue);
        expect(tiredState.isDistracted, isFalse);

        final distractedState = UserState(
          currentIntent: UserIntent.browse,
          mood: 0.3,
          lastActiveAt: DateTime.now(),
        );

        expect(distractedState.isTired, isFalse);
        expect(distractedState.isDistracted, isTrue);
      });

      test('状态更新', () {
        final state = UserState(
          currentIntent: UserIntent.login,
          lastActiveAt: DateTime.now(),
        );

        final updated = state.copyWith(
          mood: 0.5,
          isInHurry: true,
        );

        expect(updated.mood, equals(0.5));
        expect(updated.isInHurry, isTrue);
        expect(state.mood, equals(0.8)); // 原状态不变
      });
    });

    group('UserAction', () {
      test('创建点击动作', () {
        final action = UserAction.tap(target: '#submit-btn');

        expect(action.type, equals(UserActionType.tap));
        expect(action.targetElement, equals('#submit-btn'));
        expect(action.succeeded, isTrue);
      });

      test('创建输入动作', () {
        final action = UserAction.input(
          target: '#username',
          text: 'testuser',
        );

        expect(action.type, equals(UserActionType.input));
        expect(action.inputData, equals('testuser'));
      });

      test('JSON 序列化', () {
        final action = UserAction.tap(target: '#login-btn');

        final json = action.toJson();
        expect(json['type'], equals('tap'));
        expect(json['targetElement'], equals('#login-btn'));
      });
    });

    group('HumanSimulator', () {
      test('模拟思考延迟', () async {
        final delay = await simulator.think();

        expect(delay.inMilliseconds, greaterThan(0));
        expect(delay.inMilliseconds, lessThan(2000));
      });

      test('模拟打字', () async {
        final result = await simulator.typeText(
          targetElement: '#input',
          text: 'hello',
        );

        expect(result.success, isTrue);
        expect(result.duration, greaterThan(0));
        expect(simulator.actionHistory, isNotEmpty);
      });

      test('模拟点击', () async {
        final result = await simulator.tap(targetElement: '#button');

        expect(result.success, isTrue);
        expect(result.actualAction, isNotNull);
        expect(result.actualAction?.type, equals(UserActionType.tap));
      });

      test('模拟滚动', () async {
        final result = await simulator.scroll(direction: 'down');

        expect(result.success, isTrue);
        expect(result.duration, greaterThan(0));
      });

      test('模拟等待', () async {
        final result = await simulator.wait();

        expect(result.success, isTrue);
        expect(result.duration, greaterThan(400));
      });

      test('模拟犹豫', () async {
        final result = await simulator.hesitate();

        expect(result.success, isTrue);
        expect(result.actualAction?.type, equals(UserActionType.hesitate));
      });

      test('状态管理', () {
        expect(simulator.state.fatigue, equals(0.0));

        simulator.increaseFatigue(0.3);
        expect(simulator.state.fatigue, moreOrLessEquals(0.3));

        simulator.increaseFatigue(0.8); // 超过1.0会被限制
        expect(simulator.state.fatigue, equals(1.0));
        expect(simulator.state.isTired, isTrue);

        simulator.changeMood(-0.5);
        expect(simulator.state.mood, moreOrLessEquals(0.3));
      });

      test('获取行为摘要', () {
        simulator.updateState(intent: UserIntent.login);

        final summary = simulator.getSummary();

        expect(summary['currentState']['intent'], equals('login'));
        expect(summary['totalActions'], equals(0));
      });
    });

    group('SessionScenario', () {
      test('预定义场景', () {
        expect(SessionScenario.login.name, equals('用户登录'));
        expect(SessionScenario.login.targetIntent, equals(UserIntent.login));
        expect(SessionScenario.login.requiresLogin, isFalse);

        expect(SessionScenario.sendMessage.requiresLogin, isTrue);
        expect(SessionScenario.sendMessage.priority, equals(0.8));
      });
    });

    group('UserSessionSimulator', () {
      test('执行探索场景', () async {
        final result = await sessionSimulator.runScenario(SessionScenario.explore);

        expect(result, isNotNull);
        expect(result.actions, isNotEmpty);
        expect(result.duration.inMilliseconds, greaterThan(0));
      });

      test('执行登录场景', () async {
        final result = await sessionSimulator.runScenario(SessionScenario.login);

        expect(result.scenario.name, equals('用户登录'));
        expect(result.actions, isNotEmpty);
        // 登录场景有多个步骤
        expect(result.actions.length, greaterThan(2));
      });

      test('执行浏览场景', () async {
        final result = await sessionSimulator.runScenario(SessionScenario.browseContent);

        expect(result.goalCompleted, isTrue);
        expect(result.actions.any((a) => a.type == UserActionType.scroll), isTrue);
      });

      test('批量执行场景', () async {
        final scenarios = [
          SessionScenario.explore,
          SessionScenario.browseContent,
        ];

        final results = await sessionSimulator.runScenarios(scenarios);

        expect(results.length, equals(2));
        expect(results.every((r) => r.actions.isNotEmpty), isTrue);
      });

      test('生成随机场景', () {
        final scenario = sessionSimulator.generateRandomScenario();

        expect(scenario, isNotNull);
        expect(scenario.name, isNotEmpty);
      });

      test('会话结果统计', () async {
        final result = await sessionSimulator.runScenario(SessionScenario.explore);

        expect(result.successCount + result.failureCount, equals(result.actions.length));
        expect(result.successRate, greaterThanOrEqualTo(0.0));
        expect(result.successRate, lessThanOrEqualTo(1.0));
      });
    });

    group('集成测试', () {
      test('完整的用户会话模拟', () async {
        // 模拟新手用户
        final noviceSimulator = HumanSimulator(
          config: UserBehaviorConfig.noviceUser,
        );
        final noviceSession = UserSessionSimulator(simulator: noviceSimulator);

        final result = await noviceSession.runScenario(SessionScenario.login);

        print('新手登录结果: ${result.toJson()}');

        // 验证结果
        expect(result.actions, isNotEmpty);
        expect(result.scenario.name, equals('用户登录'));

        // 新手用户可能有更多失败动作
        final failureRate = result.failureCount / result.actions.length;
        print('新手用户失败率: ${(failureRate * 100).toStringAsFixed(0)}%');
      });

      test('专家用户快速操作', () async {
        // 模拟专家用户
        final expertSimulator = HumanSimulator(
          config: UserBehaviorConfig.expertUser,
        );
        final expertSession = UserSessionSimulator(simulator: expertSimulator);

        final result = await expertSession.runScenario(SessionScenario.sendMessage);

        print('专家发送消息结果: ${result.toJson()}');

        // 专家用户应该更快完成
        expect(result.duration.inMilliseconds, lessThan(10000));

        // 专家用户应该有更高的成功率
        expect(result.successRate, greaterThan(0.7));
      });

      test('疲劳用户行为', () async {
        final tiredSimulator = HumanSimulator();

        // 增加疲劳度
        tiredSimulator.increaseFatigue(0.8);

        final result = await tiredSimulator.tap(targetElement: '#button');

        // 疲劳用户的操作应该更慢
        expect(result.duration, greaterThan(300));
      });

      test('紧急状态行为', () async {
        final urgentSimulator = HumanSimulator();

        urgentSimulator.updateState(isInHurry: true);

        final startTime = DateTime.now();
        await urgentSimulator.think();
        final duration = DateTime.now().difference(startTime);

        // 紧急状态下的思考时间应该更短
        expect(duration.inMilliseconds, lessThan(1000));
      });

      test('复杂会话序列', () async {
        final results = <SessionResult>[];

        // 执行多个场景序列
        final scenarios = [
          SessionScenario.login,
          SessionScenario.sendMessage,
          SessionScenario.browseContent,
        ];

        for (final scenario in scenarios) {
          final result = await sessionSimulator.runScenario(scenario);
          results.add(result);

          // 模拟用户稍微疲劳
          simulator.increaseFatigue(0.05); // 减少疲劳增加量
        }

        print('会话序列结果:');
        for (final result in results) {
          print('  ${result.scenario.name}: ${result.actions.length} 动作, '
                '${result.goalCompleted ? "完成" : "未完成"}, '
                '${result.duration.inSeconds}s');
        }

        // 验证所有场景都执行了
        expect(results.length, equals(3));
        expect(results.every((r) => r.actions.isNotEmpty), isTrue);

        // 验证成功率
        final overallSuccessRate = results.fold<double>(0, (sum, r) => sum + r.successRate) / results.length;
        print('总体成功率: ${(overallSuccessRate * 100).toStringAsFixed(0)}%');
        expect(overallSuccessRate, greaterThan(0.5)); // 至少50%成功率
      });
    });
  });
}

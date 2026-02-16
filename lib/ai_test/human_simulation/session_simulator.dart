/// 用户会话模拟器 - 模拟完整的用户会话
library;

import 'dart:async';
import 'dart:math';
import 'human_simulator.dart';

/// 会话场景
class SessionScenario {
  /// 场景名称
  final String name;

  /// 场景描述
  final String description;

  /// 初始状态
  final UserState initialState;

  /// 目标意图
  final UserIntent targetIntent;

  /// 预期步骤数
  final int expectedSteps;

  /// 超时时间
  final Duration timeout;

  /// 是否需要登录
  final bool requiresLogin;

  /// 场景优先级 (0.0 - 1.0)
  final double priority;

  const SessionScenario({
    required this.name,
    required this.description,
    required this.initialState,
    required this.targetIntent,
    this.expectedSteps = 5,
    this.timeout = const Duration(minutes: 5),
    this.requiresLogin = false,
    this.priority = 0.5,
  });

  /// 常见场景
  static final login = SessionScenario(
    name: '用户登录',
    description: '用户打开应用并登录',
    initialState: UserState(
      currentIntent: UserIntent.login,
      mood: 0.7,
    ),
    targetIntent: UserIntent.login,
    expectedSteps: 3,
    requiresLogin: false,
    priority: 0.9,
  );

  static final sendMessage = SessionScenario(
    name: '发送消息',
    description: '用户发送消息给好友',
    initialState: UserState(
      currentIntent: UserIntent.sendMessage,
      mood: 0.8,
    ),
    targetIntent: UserIntent.sendMessage,
    expectedSteps: 4,
    requiresLogin: true,
    priority: 0.8,
  );

  static final browseContent = SessionScenario(
    name: '浏览内容',
    description: '用户随意浏览应用内容',
    initialState: UserState(
      currentIntent: UserIntent.browse,
      mood: 0.6,
      fatigue: 0.2,
    ),
    targetIntent: UserIntent.browse,
    expectedSteps: 8,
    requiresLogin: true,
    priority: 0.5,
  );

  static final searchContent = SessionScenario(
    name: '搜索内容',
    description: '用户搜索特定内容',
    initialState: UserState(
      currentIntent: UserIntent.search,
      mood: 0.7,
      isInHurry: true,
    ),
    targetIntent: UserIntent.search,
    expectedSteps: 4,
    requiresLogin: true,
    priority: 0.6,
  );

  static final explore = SessionScenario(
    name: '随机探索',
    description: '用户随机探索应用功能',
    initialState: UserState(
      currentIntent: UserIntent.explore,
      mood: 0.5,
      fatigue: 0.1,
    ),
    targetIntent: UserIntent.explore,
    expectedSteps: 10,
    requiresLogin: false,
    priority: 0.3,
  );
}

/// 会话结果
class SessionResult {
  /// 场景
  final SessionScenario scenario;

  /// 执行的动作
  final List<UserAction> actions;

  /// 是否完成目标
  final bool goalCompleted;

  /// 执行时间
  final Duration duration;

  /// 成功的动作数
  final int successCount;

  /// 失败的动作数
  final int failureCount;

  /// 是否超时
  final bool timedOut;

  /// 额外信息
  final Map<String, dynamic> metadata;

  const SessionResult({
    required this.scenario,
    required this.actions,
    required this.goalCompleted,
    required this.duration,
    this.successCount = 0,
    this.failureCount = 0,
    this.timedOut = false,
    this.metadata = const {},
  });

  /// 获取成功率
  double get successRate => actions.isEmpty
      ? 1.0
      : successCount / actions.length;

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'scenario': scenario.name,
      'actions': actions.map((a) => a.toJson()).toList(),
      'goalCompleted': goalCompleted,
      'duration': duration.inMilliseconds,
      'successCount': successCount,
      'failureCount': failureCount,
      'successRate': successRate,
      'timedOut': timedOut,
      'metadata': metadata,
    };
  }

  @override
  String toString() =>
      'SessionResult(${scenario.name}, ${actions.length} actions, ${goalCompleted ? "完成" : "未完成"})';
}

/// 用户会话模拟器
class UserSessionSimulator {
  final HumanSimulator _simulator;
  final Random _random;

  UserSessionSimulator({
    HumanSimulator? simulator,
    Random? random,
  })  : _simulator = simulator ?? HumanSimulator(),
        _random = random ?? Random();

  /// 执行场景
  Future<SessionResult> runScenario(SessionScenario scenario) async {
    final startTime = DateTime.now();
    final actions = <UserAction>[];
    var successCount = 0;
    var failureCount = 0;
    var goalCompleted = false;
    var timedOut = false;

    // 设置初始状态
    _simulator.updateState(
      intent: scenario.initialState.currentIntent,
      mood: scenario.initialState.mood,
      fatigue: scenario.initialState.fatigue,
      isInHurry: scenario.initialState.isInHurry,
    );

    try {
      // 超时控制
      final timeoutFuture = Future.delayed(scenario.timeout).then((_) => null);
      final sessionFuture = _executeSession(scenario, actions);

      final result = await Future.any([
        sessionFuture,
        timeoutFuture.then((_) => false),
      ]);

      if (result == false) {
        timedOut = true;
      } else {
        goalCompleted = result;
      }

    } catch (e) {
      // 会话执行出错
    }

    final duration = DateTime.now().difference(startTime);

    // 统计结果
    for (final action in actions) {
      if (action.succeeded) {
        successCount++;
      } else {
        failureCount++;
      }
    }

    return SessionResult(
      scenario: scenario,
      actions: actions,
      goalCompleted: goalCompleted,
      duration: duration,
      successCount: successCount,
      failureCount: failureCount,
      timedOut: timedOut,
    );
  }

  /// 执行会话
  Future<bool> _executeSession(
    SessionScenario scenario,
    List<UserAction> actions,
  ) async {
    final intent = scenario.targetIntent;

    switch (intent) {
      case UserIntent.login:
        return await _executeLoginScenario(scenario, actions);
      case UserIntent.sendMessage:
        return await _executeSendMessageScenario(scenario, actions);
      case UserIntent.browse:
        return await _executeBrowseScenario(scenario, actions);
      case UserIntent.search:
        return await _executeSearchScenario(scenario, actions);
      case UserIntent.explore:
        return await _executeExploreScenario(scenario, actions);
      default:
        return await _executeGenericScenario(scenario, actions);
    }
  }

  /// 执行登录场景
  Future<bool> _executeLoginScenario(
    SessionScenario scenario,
    List<UserAction> actions,
  ) async {
    // 1. 点击登录按钮
    final loginResult = await _simulator.tap(targetElement: '#login-button');
    actions.addAll(_simulator.actionHistory.skip(actions.length));

    if (!loginResult.success) {
      return false;
    }

    // 2. 输入用户名
    final usernameResult = await _simulator.typeText(
      targetElement: '#username-input',
      text: 'testuser',
    );
    actions.addAll(_simulator.actionHistory.skip(actions.length));

    if (!usernameResult.success && _random.nextDouble() > 0.5) {
      return false;
    }

    // 3. 输入密码
    final passwordResult = await _simulator.typeText(
      targetElement: '#password-input',
      text: 'password123',
    );
    actions.addAll(_simulator.actionHistory.skip(actions.length));

    if (!passwordResult.success) {
      return false;
    }

    // 4. 点击提交
    final submitResult = await _simulator.tap(targetElement: '#submit-button');
    actions.addAll(_simulator.actionHistory.skip(actions.length));

    return submitResult.success;
  }

  /// 执行发送消息场景
  Future<bool> _executeSendMessageScenario(
    SessionScenario scenario,
    List<UserAction> actions,
  ) async {
    // 1. 点击聊天对象
    final chatResult = await _simulator.tap(targetElement: '#chat-item-1');
    actions.addAll(_simulator.actionHistory.skip(actions.length));

    if (!chatResult.success) {
      return false;
    }

    // 2. 等待聊天页面加载
    await _simulator.wait(duration: const Duration(milliseconds: 500));

    // 3. 点击输入框
    final inputResult = await _simulator.tap(targetElement: '#message-input');
    actions.addAll(_simulator.actionHistory.skip(actions.length));

    if (!inputResult.success) {
      return false;
    }

    // 4. 输入消息
    final messageResult = await _simulator.typeText(
      targetElement: '#message-input',
      text: '这是一条测试消息',
    );
    actions.addAll(_simulator.actionHistory.skip(actions.length));

    if (!messageResult.success) {
      return false;
    }

    // 5. 点击发送
    final sendResult = await _simulator.tap(targetElement: '#send-button');
    actions.addAll(_simulator.actionHistory.skip(actions.length));

    return sendResult.success;
  }

  /// 执行浏览场景
  Future<bool> _executeBrowseScenario(
    SessionScenario scenario,
    List<UserAction> actions,
  ) async {
    // 随机浏览一些内容
    final scrollCount = 3 + _random.nextInt(5);

    for (var i = 0; i < scrollCount; i++) {
      // 滚动
      await _simulator.scroll(direction: 'down');
      actions.addAll(_simulator.actionHistory.skip(actions.length));

      // 偶尔停顿
      if (_random.nextDouble() < 0.3) {
        await _simulator.wait();
        actions.addAll(_simulator.actionHistory.skip(actions.length));
      }

      // 偶尔点击内容
      if (_random.nextDouble() < 0.2) {
        final tapResult = await _simulator.tap(targetElement: '#content-item-$i');
        actions.addAll(_simulator.actionHistory.skip(actions.length));

        if (tapResult.success) {
          await _simulator.wait();
          actions.addAll(_simulator.actionHistory.skip(actions.length));

          // 返回
          await _simulator.tap(targetElement: '#back-button');
          actions.addAll(_simulator.actionHistory.skip(actions.length));
        }
      }
    }

    return true;
  }

  /// 执行搜索场景
  Future<bool> _executeSearchScenario(
    SessionScenario scenario,
    List<UserAction> actions,
  ) async {
    // 1. 点击搜索框
    final searchResult = await _simulator.tap(targetElement: '#search-input');
    actions.addAll(_simulator.actionHistory.skip(actions.length));

    if (!searchResult.success) {
      return false;
    }

    // 2. 输入搜索关键词
    final keywordResult = await _simulator.typeText(
      targetElement: '#search-input',
      text: '测试搜索',
    );
    actions.addAll(_simulator.actionHistory.skip(actions.length));

    if (!keywordResult.success) {
      return false;
    }

    // 3. 等待搜索结果
    await _simulator.wait(duration: const Duration(milliseconds: 1000));
    actions.addAll(_simulator.actionHistory.skip(actions.length));

    // 4. 查看结果（滚动）
    await _simulator.scroll(direction: 'down', amount: 0.3);
    actions.addAll(_simulator.actionHistory.skip(actions.length));

    return true;
  }

  /// 执行探索场景
  Future<bool> _executeExploreScenario(
    SessionScenario scenario,
    List<UserAction> actions,
  ) async {
    // 随机探索各种功能
    final actionCount = 5 + _random.nextInt(10);

    for (var i = 0; i < actionCount; i++) {
      final actionType = _random.nextInt(5);

      switch (actionType) {
        case 0: // 点击
          await _simulator.tap(targetElement: '#random-element-$i');
          break;
        case 1: // 滚动
          await _simulator.scroll(direction: _random.nextBool() ? 'up' : 'down');
          break;
        case 2: // 等待
          await _simulator.wait();
          break;
        case 3: // 犹豫
          await _simulator.hesitate();
          break;
        case 4: // 导航
          await _simulator.tap(targetElement: '#nav-item-$i');
          break;
      }

      actions.addAll(_simulator.actionHistory.skip(actions.length));

      // 偶尔增加疲劳度
      if (_random.nextDouble() < 0.1) {
        _simulator.increaseFatigue(0.05);
      }
    }

    return true;
  }

  /// 执行通用场景
  Future<bool> _executeGenericScenario(
    SessionScenario scenario,
    List<UserAction> actions,
  ) async {
    // 执行一些随机动作
    final actionCount = scenario.expectedSteps;

    for (var i = 0; i < actionCount; i++) {
      await _simulator.tap(targetElement: '#element-$i');
      actions.addAll(_simulator.actionHistory.skip(actions.length));
      await _simulator.think();
    }

    return true;
  }

  /// 批量执行场景
  Future<List<SessionResult>> runScenarios(List<SessionScenario> scenarios) async {
    final results = <SessionResult>[];

    for (final scenario in scenarios) {
      final result = await runScenario(scenario);
      results.add(result);

      // 清理历史
      _simulator.clearHistory();
    }

    return results;
  }

  /// 获取模拟器
  HumanSimulator get simulator => _simulator;

  /// 生成随机场景
  SessionScenario generateRandomScenario() {
    final scenarioTypes = [
      SessionScenario.login,
      SessionScenario.sendMessage,
      SessionScenario.browseContent,
      SessionScenario.searchContent,
      SessionScenario.explore,
    ];

    return scenarioTypes[_random.nextInt(scenarioTypes.length)];
  }
}

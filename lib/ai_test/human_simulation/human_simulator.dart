/// 人类行为模拟器 - 模拟真实用户的测试行为
library;

import 'dart:math';
import 'dart:async';

/// 用户行为配置
class UserBehaviorConfig {
  /// 打字速度（字符/秒）
  final int typingSpeed;

  /// 阅读速度（毫秒/字符）
  final int readingSpeed;

  /// 思考延迟范围（毫秒）
  final Duration minThinkingDelay;
  final Duration maxThinkingDelay;

  /// 错误率 (0.0 - 1.0)
  final double errorRate;

  /// 误点击率 (0.0 - 1.0)
  final double misclickRate;

  /// 注意力集中度 (0.0 - 1.0)
  final double attentionLevel;

  /// 是否启用随机行为
  final bool enableRandomBehavior;

  const UserBehaviorConfig({
    this.typingSpeed = 5,
    this.readingSpeed = 100,
    this.minThinkingDelay = const Duration(milliseconds: 200),
    this.maxThinkingDelay = const Duration(milliseconds: 1500),
    this.errorRate = 0.05,
    this.misclickRate = 0.02,
    this.attentionLevel = 0.85,
    this.enableRandomBehavior = true,
  });

  /// 正常用户配置
  static const normalUser = UserBehaviorConfig();

  /// 新手用户配置
  static const noviceUser = UserBehaviorConfig(
    typingSpeed: 3,
    readingSpeed: 150,
    minThinkingDelay: Duration(milliseconds: 500),
    maxThinkingDelay: Duration(milliseconds: 3000),
    errorRate: 0.15,
    misclickRate: 0.08,
    attentionLevel: 0.6,
  );

  /// 专家用户配置
  static const expertUser = UserBehaviorConfig(
    typingSpeed: 10,
    readingSpeed: 50,
    minThinkingDelay: Duration(milliseconds: 50),
    maxThinkingDelay: Duration(milliseconds: 300),
    errorRate: 0.01,
    misclickRate: 0.005,
    attentionLevel: 0.98,
  );
}

/// 用户意图
enum UserIntent {
  /// 登录
  login,

  /// 注册
  register,

  /// 发送消息
  sendMessage,

  /// 浏览内容
  browse,

  /// 搜索
  search,

  /// 设置
  settings,

  /// 退出
  logout,

  /// 随机探索
  explore,
}

/// 用户状态
class UserState {
  /// 当前意图
  final UserIntent currentIntent;

  /// 当前页面
  final String? currentPage;

  /// 心情状态 (0.0 - 1.0)
  final double mood;

  /// 疲劳度 (0.0 - 1.0)
  final double fatigue;

  /// 是否着急
  final bool isInHurry;

  /// 最后活动时间
  final DateTime lastActiveAt;

  UserState({
    required this.currentIntent,
    this.currentPage,
    this.mood = 0.8,
    this.fatigue = 0.0,
    this.isInHurry = false,
    DateTime? lastActiveAt,
  }) : lastActiveAt = lastActiveAt ?? DateTime.now();

  /// 创建空闲状态
  factory UserState.idle() {
    return UserState(
      currentIntent: UserIntent.explore,
      mood: 0.8,
      fatigue: 0.0,
    );
  }

  /// 更新状态
  UserState copyWith({
    UserIntent? currentIntent,
    String? currentPage,
    double? mood,
    double? fatigue,
    bool? isInHurry,
    DateTime? lastActiveAt,
  }) {
    return UserState(
      currentIntent: currentIntent ?? this.currentIntent,
      currentPage: currentPage ?? this.currentPage,
      mood: mood ?? this.mood,
      fatigue: fatigue ?? this.fatigue,
      isInHurry: isInHurry ?? this.isInHurry,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  /// 是否疲劳
  bool get isTired => fatigue > 0.7;

  /// 是否分心
  bool get isDistracted => mood < 0.5;
}

/// 用户动作
class UserAction {
  /// 动作 ID
  final String id;

  /// 动作类型
  final UserActionType type;

  /// 目标元素
  final String? targetElement;

  /// 输入数据
  final String? inputData;

  /// 预期结果
  final String? expectedResult;

  /// 执行时间戳
  final DateTime timestamp;

  /// 是否成功
  final bool succeeded;

  /// 错误信息
  final String? errorMessage;

  const UserAction({
    required this.id,
    required this.type,
    this.targetElement,
    this.inputData,
    this.expectedResult,
    required this.timestamp,
    this.succeeded = true,
    this.errorMessage,
  });

  /// 创建点击动作
  factory UserAction.tap({
    required String target,
    String? expectedResult,
  }) {
    return UserAction(
      id: 'action_${DateTime.now().millisecondsSinceEpoch}',
      type: UserActionType.tap,
      targetElement: target,
      expectedResult: expectedResult,
      timestamp: DateTime.now(),
    );
  }

  /// 创建输入动作
  factory UserAction.input({
    required String target,
    required String text,
  }) {
    return UserAction(
      id: 'action_${DateTime.now().millisecondsSinceEpoch}',
      type: UserActionType.input,
      targetElement: target,
      inputData: text,
      timestamp: DateTime.now(),
    );
  }

  /// 创建滚动动作
  factory UserAction.scroll({
    required String direction,
    double amount = 0.5,
  }) {
    return UserAction(
      id: 'action_${DateTime.now().millisecondsSinceEpoch}',
      type: UserActionType.scroll,
      inputData: '$direction:$amount',
      timestamp: DateTime.now(),
    );
  }

  /// 创建等待动作
  factory UserAction.wait({required Duration duration}) {
    return UserAction(
      id: 'action_${DateTime.now().millisecondsSinceEpoch}',
      type: UserActionType.wait,
      inputData: duration.inMilliseconds.toString(),
      timestamp: DateTime.now(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'targetElement': targetElement,
      'inputData': inputData,
      'expectedResult': expectedResult,
      'timestamp': timestamp.toIso8601String(),
      'succeeded': succeeded,
      'errorMessage': errorMessage,
    };
  }

  @override
  String toString() =>
      'UserAction(${type.name}, ${targetElement ?? inputData}, ${succeeded ? "成功" : "失败"})';
}

/// 用户动作类型
enum UserActionType {
  /// 点击
  tap,

  /// 输入
  input,

  /// 滚动
  scroll,

  /// 等待
  wait,

  /// 滑动
  swipe,

  /// 长按
  longPress,

  /// 双击
  doubleTap,

  /// 缩放
  pinch,

  /// 导航
  navigate,

  /// 后退
  back,

  /// 验证
  verify,

  /// 思考
  think,

  /// 错误
  error,

  /// 犹豫
  hesitate,
}

/// 动作执行结果
class ActionResult {
  /// 动作是否成功
  final bool success;

  /// 执行耗时（毫秒）
  final int duration;

  /// 实际执行的动作（可能与计划不同）
  final UserAction? actualAction;

  /// 错误信息
  final String? error;

  const ActionResult({
    required this.success,
    required this.duration,
    this.actualAction,
    this.error,
  });

  /// 创建成功结果
  const ActionResult.success({required int duration, UserAction? actualAction})
      : this(
          success: true,
          duration: duration,
          actualAction: actualAction,
        );

  /// 创建失败结果
  const ActionResult.failure({required int duration, String? error})
      : this(
          success: false,
          duration: duration,
          error: error,
        );
}

/// 人类模拟器
class HumanSimulator {
  final UserBehaviorConfig _config;
  final Random _random;
  UserState _state;

  /// 执行历史
  final List<UserAction> _actionHistory = [];

  HumanSimulator({
    UserBehaviorConfig? config,
    Random? random,
    UserState? state,
  })  : _config = config ?? UserBehaviorConfig.normalUser,
        _random = random ?? Random(),
        _state = state ?? UserState.idle();

  /// 获取当前状态
  UserState get state => _state;

  /// 获取执行历史
  List<UserAction> get actionHistory => List.unmodifiable(_actionHistory);

  /// 模拟用户思考延迟
  Future<Duration> think({bool inHurry = false}) async {
    var baseDelay = _random.nextInt(
      _config.maxThinkingDelay.inMilliseconds - _config.minThinkingDelay.inMilliseconds,
    ) + _config.minThinkingDelay.inMilliseconds;

    // 如果着急，减少延迟
    if (inHurry || _state.isInHurry) {
      baseDelay = (baseDelay * 0.5).round();
    }

    // 如果疲劳，增加延迟
    if (_state.isTired) {
      baseDelay = (baseDelay * 1.5).round();
    }

    // 如果分心，增加延迟
    if (_state.isDistracted) {
      baseDelay = (baseDelay * 2.0).round();
    }

    final delay = Duration(milliseconds: baseDelay);
    await Future.delayed(delay);

    return delay;
  }

  /// 模拟打字
  Future<ActionResult> typeText({
    required String targetElement,
    required String text,
    bool hasErrors = false,
  }) async {
    final startTime = DateTime.now();

    // 决定是否会产生错误
    final willMakeError = hasErrors || (_random.nextDouble() < _config.errorRate);

    String actualText = text;
    String? error;

    if (willMakeError) {
      actualText = _introduceTypo(text);
      error = '输入错误: $actualText';
    }

    // 计算打字时间
    final charCount = actualText.length;
    final typingTime = Duration(
      milliseconds: (charCount * 1000 / _config.typingSpeed).round(),
    );

    // 模拟逐字符输入
    final chars = actualText.split('');
    for (var i = 0; i < chars.length; i++) {
      await Future.delayed(
        Duration(milliseconds: (1000 / _config.typingSpeed).round()),
      );

      // 偶尔停顿思考
      if (_random.nextDouble() < 0.1) {
        await think();
      }
    }

    final action = UserAction(
      id: 'action_${DateTime.now().millisecondsSinceEpoch}',
      type: UserActionType.input,
      targetElement: targetElement,
      inputData: actualText,
      timestamp: DateTime.now(),
      succeeded: !willMakeError,
      errorMessage: error,
    );

    _actionHistory.add(action);

    final duration = DateTime.now().difference(startTime).inMilliseconds;

    if (willMakeError) {
      // 可能会纠正错误
      if (_random.nextDouble() < 0.7) {
        // 删除并重新输入
        await Future.delayed(const Duration(milliseconds: 500));
        await think();

        return ActionResult.success(
          duration: duration + 500 + typingTime.inMilliseconds,
          actualAction: UserAction.input(target: targetElement, text: text),
        );
      }

      return ActionResult.failure(duration: duration, error: error);
    }

    return ActionResult.success(duration: duration, actualAction: action);
  }

  /// 模拟点击
  Future<ActionResult> tap({
    required String targetElement,
    bool quick = false,
  }) async {
    final startTime = DateTime.now();

    // 决定是否误点击
    final willMisclick = !quick && (_random.nextDouble() < _config.misclickRate);

    // 点击前的思考时间
    await think(inHurry: quick);

    String? actualTarget = targetElement;
    String? error;

    if (willMisclick) {
      // 误点击相邻元素
      actualTarget = _findNearbyElement(targetElement);
      error = '误点击: 期望 $targetElement, 实际 $actualTarget';
    }

    final action = UserAction(
      id: 'action_${DateTime.now().millisecondsSinceEpoch}',
      type: willMisclick ? UserActionType.error : UserActionType.tap,
      targetElement: actualTarget,
      expectedResult: targetElement,
      timestamp: DateTime.now(),
      succeeded: !willMisclick,
      errorMessage: error,
    );

    _actionHistory.add(action);

    final duration = DateTime.now().difference(startTime).inMilliseconds;

    if (willMisclick) {
      // 可能会意识到并纠正
      if (_random.nextDouble() < 0.5) {
        await think();
        // 重新点击正确的目标
        return tap(targetElement: targetElement, quick: true);
      }

      return ActionResult.failure(duration: duration, error: error);
    }

    return ActionResult.success(duration: duration, actualAction: action);
  }

  /// 模拟滚动
  Future<ActionResult> scroll({
    required String direction,
    double amount = 0.5,
  }) async {
    final startTime = DateTime.now();

    await think();

    final scrollTime = (amount * 1000).round();
    await Future.delayed(Duration(milliseconds: scrollTime));

    final action = UserAction.scroll(direction: direction, amount: amount);
    final duration = DateTime.now().difference(startTime).inMilliseconds;

    _actionHistory.add(action);

    return ActionResult.success(duration: duration, actualAction: action);
  }

  /// 模拟等待
  Future<ActionResult> wait({Duration? duration}) async {
    final waitDuration = duration ??
        Duration(
          milliseconds: _random.nextInt(2000) + 500,
        );

    await Future.delayed(waitDuration);

    final action = UserAction.wait(duration: waitDuration);
    _actionHistory.add(action);

    return ActionResult.success(
      duration: waitDuration.inMilliseconds,
      actualAction: action,
    );
  }

  /// 模拟阅读
  Future<Duration> read({required int characterCount}) async {
    final readingTime = Duration(
      milliseconds: (characterCount * _config.readingSpeed).round(),
    );

    // 如果分心，可能会重新阅读
    if (_state.isDistracted && _random.nextDouble() < 0.3) {
      await Future.delayed(readingTime);
      await think();
      return Future.delayed(readingTime).then((_) => readingTime * 2);
    }

    await Future.delayed(readingTime);
    return Future.value(readingTime);
  }

  /// 模拟犹豫
  Future<ActionResult> hesitate({Duration? duration}) async {
    final hesitateDuration = duration ??
        Duration(
          milliseconds: _random.nextInt(1500) + 500,
        );

    await Future.delayed(hesitateDuration);

    final action = UserAction(
      id: 'action_${DateTime.now().millisecondsSinceEpoch}',
      type: UserActionType.hesitate,
      timestamp: DateTime.now(),
    );

    _actionHistory.add(action);

    return ActionResult.success(
      duration: hesitateDuration.inMilliseconds,
      actualAction: action,
    );
  }

  /// 更新用户状态
  void updateState({
    UserIntent? intent,
    String? currentPage,
    double? mood,
    double? fatigue,
    bool? isInHurry,
  }) {
    _state = _state.copyWith(
      currentIntent: intent ?? _state.currentIntent,
      currentPage: currentPage ?? _state.currentPage,
      mood: mood ?? _state.mood,
      fatigue: fatigue ?? _state.fatigue,
      isInHurry: isInHurry ?? _state.isInHurry,
      lastActiveAt: DateTime.now(),
    );
  }

  /// 增加疲劳度
  void increaseFatigue([double amount = 0.05]) {
    final newFatigue = (_state.fatigue + amount).clamp(0.0, 1.0);
    _state = _state.copyWith(fatigue: newFatigue);
  }

  /// 改变心情
  void changeMood(double delta) {
    final newMood = (_state.mood + delta).clamp(0.0, 1.0);
    _state = _state.copyWith(mood: newMood);
  }

  /// 引入错别字
  String _introduceTypo(String text) {
    if (text.isEmpty) return text;

    final position = _random.nextInt(text.length);
    final chars = text.split('');

    // 随机选择一种错误类型
    final errorType = _random.nextInt(4);

    switch (errorType) {
      case 0: // 删除字符
        chars.removeAt(position.clamp(0, chars.length - 1));
        break;
      case 1: // 重复字符
        if (position < chars.length) {
          chars.insert(position, chars[position]);
        }
        break;
      case 2: // 相邻字符交换
        if (position < chars.length - 1) {
          final temp = chars[position];
          chars[position] = chars[position + 1];
          chars[position + 1] = temp;
        }
        break;
      case 3: // 替换为相邻键
        if (position < chars.length) {
          chars[position] = _getAdjacentKey(chars[position]);
        }
        break;
    }

    return chars.join();
  }

  /// 获取相邻键
  String _getAdjacentKey(String char) {
    // 简化的键盘布局
    final adjacent = {
      'a': ['s', 'q', 'z', 'w'],
      's': ['a', 'd', 'w', 'x', 'z'],
      'd': ['s', 'f', 'e', 'c', 'x'],
      'q': ['w', 'a', '1'],
      'w': ['q', 'e', 'a', 's', '2'],
      'e': ['w', 'r', 's', 'd', '3'],
    };

    final candidates = adjacent[char.toLowerCase()];
    if (candidates == null || candidates.isEmpty) {
      return char;
    }

    return candidates[_random.nextInt(candidates.length)];
  }

  /// 查找相邻元素（误点击用）
  String _findNearbyElement(String target) {
    // 简化实现：返回假想的相邻元素
    final nearbyOptions = [
      '${target}_nearby_1',
      '${target}_nearby_2',
      'back_button',
      'close_button',
    ];

    return nearbyOptions[_random.nextInt(nearbyOptions.length)];
  }

  /// 获取配置
  UserBehaviorConfig get config => _config;

  /// 清空历史
  void clearHistory() {
    _actionHistory.clear();
  }

  /// 获取行为摘要
  Map<String, dynamic> getSummary() {
    final actionCounts = <UserActionType, int>{};
    for (final action in _actionHistory) {
      actionCounts[action.type] = (actionCounts[action.type] ?? 0) + 1;
    }

    final successCount = _actionHistory.where((a) => a.succeeded).length;
    final failureCount = _actionHistory.length - successCount;

    return {
      'totalActions': _actionHistory.length,
      'successCount': successCount,
      'failureCount': failureCount,
      'successRate': _actionHistory.isEmpty
          ? 1.0
          : successCount / _actionHistory.length,
      'actionCounts': actionCounts.map(
        (k, v) => MapEntry(k.name, v),
      ),
      'currentState': {
        'intent': _state.currentIntent.name,
        'mood': _state.mood,
        'fatigue': _state.fatigue,
        'isTired': _state.isTired,
        'isDistracted': _state.isDistracted,
        'isInHurry': _state.isInHurry,
      },
    };
  }
}

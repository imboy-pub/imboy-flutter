/// 愈合策略定义
library;

/// 愈合策略类型
enum HealingStrategyType {
  /// 重试策略
  retry,

  /// 选择器更新
  selectorUpdate,

  /// 等待策略
  wait,

  /// 回退策略
  fallback,

  /// 跳过策略
  skip,

  /// AI 修复建议
  aiSuggestion,
}

/// 愈合优先级
enum HealingPriority {
  /// 低优先级 - 可以稍后处理
  low,

  /// 中优先级 - 应该尽快处理
  medium,

  /// 高优先级 - 必须立即处理
  high,

  /// 紧急 - 阻塞测试执行
  critical,
}

/// 愈合策略
class HealingStrategy {
  /// 策略类型
  final HealingStrategyType type;

  /// 优先级
  final HealingPriority priority;

  /// 策略描述
  final String description;

  /// 最大重试次数
  final int maxRetries;

  /// 重试延迟（毫秒）
  final int retryDelay;

  /// 是否需要 AI 分析
  final bool requiresAiAnalysis;

  const HealingStrategy({
    required this.type,
    required this.priority,
    required this.description,
    this.maxRetries = 3,
    this.retryDelay = 1000,
    this.requiresAiAnalysis = false,
  });

  /// 创建重试策略
  const HealingStrategy.retry({
    HealingPriority priority = HealingPriority.medium,
    int maxRetries = 3,
    int retryDelay = 1000,
  }) : this(
          type: HealingStrategyType.retry,
          priority: priority,
          description: '重试失败的测试步骤',
          maxRetries: maxRetries,
          retryDelay: retryDelay,
        );

  /// 创建等待策略
  const HealingStrategy.wait({
    HealingPriority priority = HealingPriority.low,
    int retryDelay = 2000,
  }) : this(
          type: HealingStrategyType.wait,
          priority: priority,
          description: '等待元素或状态就绪',
          retryDelay: retryDelay,
        );

  /// 创建选择器更新策略
  const HealingStrategy.selectorUpdate({
    HealingPriority priority = HealingPriority.high,
  }) : this(
          type: HealingStrategyType.selectorUpdate,
          priority: priority,
          description: '更新失效的 UI 选择器',
          requiresAiAnalysis: true,
        );

  /// 创建回退策略
  const HealingStrategy.fallback({
    HealingPriority priority = HealingPriority.medium,
    String description = '使用备用方案',
  }) : this(
          type: HealingStrategyType.fallback,
          priority: priority,
          description: description,
        );

  /// 创建跳过策略
  const HealingStrategy.skip({
    HealingPriority priority = HealingPriority.low,
  }) : this(
          type: HealingStrategyType.skip,
          priority: priority,
          description: '跳过此测试步骤',
        );

  /// 创建 AI 修复建议策略
  const HealingStrategy.aiSuggestion({
    HealingPriority priority = HealingPriority.high,
  }) : this(
          type: HealingStrategyType.aiSuggestion,
          priority: priority,
          description: '使用 AI 分析并提供修复建议',
          requiresAiAnalysis: true,
        );

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'priority': priority.name,
      'description': description,
      'maxRetries': maxRetries,
      'retryDelay': retryDelay,
      'requiresAiAnalysis': requiresAiAnalysis,
    };
  }

  /// 从 JSON 创建
  factory HealingStrategy.fromJson(Map<String, dynamic> json) {
    return HealingStrategy(
      type: HealingStrategyType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => HealingStrategyType.retry,
      ),
      priority: HealingPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => HealingPriority.medium,
      ),
      description: json['description'] as String? ?? '',
      maxRetries: json['maxRetries'] as int? ?? 3,
      retryDelay: json['retryDelay'] as int? ?? 1000,
      requiresAiAnalysis: json['requiresAiAnalysis'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'HealingStrategy($type, $priority, ${requiresAiAnalysis ? "AI" : "常规"})';
}

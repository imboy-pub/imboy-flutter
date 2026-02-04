/// AI 测试框架配置
library;

/// AI 测试配置
class AITestConfig {
  /// OpenAI API 密钥
  final String openaiApiKey;

  /// Anthropic API 密钥
  final String anthropicApiKey;

  /// 是否启用 AI 测试
  final bool enabled;

  /// LLM 模型名称
  final String model;

  /// API 超时时间
  final Duration timeout;

  /// 最大重试次数
  final int maxRetries;

  /// 是否使用模拟数据（无 API Key 时）
  final bool useMockData;

  const AITestConfig({
    String? openaiApiKey,
    String? anthropicApiKey,
    bool? enabled,
    this.model = 'gpt-4o-mini',
    this.timeout = const Duration(seconds: 60),
    this.maxRetries = 3,
    this.useMockData = false,
  })  : openaiApiKey = openaiApiKey ??
            const String.fromEnvironment('OPENAI_API_KEY', defaultValue: ''),
        anthropicApiKey = anthropicApiKey ??
            const String.fromEnvironment('ANTHROPIC_API_KEY', defaultValue: ''),
        enabled = enabled ??
            const bool.fromEnvironment('AI_TEST_ENABLED', defaultValue: false);

  /// 从环境创建配置
  factory AITestConfig.fromEnv() {
    return const AITestConfig(
      // 从环境变量读取
    );
  }

  /// 是否有可用的 API Key
  bool get hasApiKey => openaiApiKey.isNotEmpty || anthropicApiKey.isNotEmpty;

  /// 获取默认配置
  static AITestConfig get defaultConfig => AITestConfig.fromEnv();

  /// 调试配置
  static AITestConfig get debugConfig => const AITestConfig(
        enabled: true,
        useMockData: true,
        model: 'gpt-4o-mini',
      );

  @override
  String toString() =>
      'AITestConfig(enabled: $enabled, model: $model, hasApiKey: $hasApiKey, useMockData: $useMockData)';

  /// 复制并修改部分配置
  AITestConfig copyWith({
    String? openaiApiKey,
    String? anthropicApiKey,
    bool? enabled,
    String? model,
    Duration? timeout,
    int? maxRetries,
    bool? useMockData,
  }) {
    return AITestConfig(
      openaiApiKey: openaiApiKey ?? this.openaiApiKey,
      anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
      enabled: enabled ?? this.enabled,
      model: model ?? this.model,
      timeout: timeout ?? this.timeout,
      maxRetries: maxRetries ?? this.maxRetries,
      useMockData: useMockData ?? this.useMockData,
    );
  }
}

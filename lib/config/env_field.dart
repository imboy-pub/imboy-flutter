/// Both DebugEnv and ReleaseEnv must implement all these values
abstract interface class EnvField {
  abstract final String apiBaseUrl;
  abstract final String iosAppId;
  abstract final String solidifiedKey;
  abstract final String solidifiedKeyIv;
  abstract final String aMapIosKey;
  abstract final String aMapAndroidKey;
  abstract final String aMapWebKey;
  abstract final String jiguangAppKey;

  /// 支付宝 App 支付 appId（公开值，非密钥；缺失时支付入口降级「即将开通」）
  abstract final String alipayAppId;

  /// 支付宝 iOS Universal Link（公开值；新版支付宝 SDK 回跳必需）
  abstract final String alipayUniversalLink;

  /// WebSocket URL (optional, for development environments)
  /// If null, will be fetched from server config
  String? get wsUrl;

  // ┌─────────────────────────────────────────────────────────────┐
  // │ 🤖 AI 测试框架配置                                           │
  // └─────────────────────────────────────────────────────────────┘

  /// OpenAI API 密钥 (用于 AI 测试生成)
  abstract final String openaiApiKey;

  /// Anthropic API 密钥 (Claude 备选方案)
  abstract final String anthropicApiKey;

  /// AI 测试是否启用
  abstract final bool aiTestEnabled;
}

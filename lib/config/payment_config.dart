/// 第三方支付（微信 / 支付宝）编译期配置。
///
/// appId / universalLink 等**非密钥**配置项通过 `--dart-define` 在编译期注入，
/// 缺失时返回空串，由 [PaymentLauncher] 降级为"即将开通"提示，不崩溃。
///
/// 注入示例：
/// ```
/// flutter build apk \
///   --dart-define=WECHAT_APP_ID=wxxxxxxxxxxxxxxxx \
///   --dart-define=WECHAT_UNIVERSAL_LINK=https://imboy.pub/app/ \
///   --dart-define=ALIPAY_APP_ID=2021xxxxxxxxxxxx \
///   --dart-define=ALIPAY_UNIVERSAL_LINK=https://imboy.pub/app/
/// ```
///
/// 商户密钥、二次签名等机密**严禁**下发到客户端，全部由后端持有；前端仅持有
/// 公开的 appId 与 universalLink。
abstract final class PaymentConfig {
  /// 微信开放平台 appId（公开值，非密钥）。
  static const String wechatAppId = String.fromEnvironment('WECHAT_APP_ID');

  /// 微信 iOS Universal Link（iOS 唤起 SDK 必需，非密钥）。
  static const String wechatUniversalLink = String.fromEnvironment(
    'WECHAT_UNIVERSAL_LINK',
  );

  /// 支付宝 appId（公开值，非密钥）。
  static const String alipayAppId = String.fromEnvironment('ALIPAY_APP_ID');

  /// 支付宝 iOS Universal Link（iOS 唤起 SDK 必需，非密钥）。
  static const String alipayUniversalLink = String.fromEnvironment(
    'ALIPAY_UNIVERSAL_LINK',
  );

  /// 运行环境（`--dart-define=APP_ENV`）。缺省 `pro` —— 判不出来时按生产处理。
  static const String _appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'pro',
  );

  /// mock（即时入账）支付方式是否可用。
  ///
  /// 后端 `recharge_logic:is_payment_method_allowed/1` 在生产会拒绝 mock，
  /// 前端把入口一并藏掉，避免生产用户点了只拿到一个失败提示。
  /// 两侧都判生产才算安全 —— 见 BUG#82（后端曾因环境判定写错而在生产放行 mock）。
  static bool get isMockPayAllowed =>
      _appEnv != 'pro' && _appEnv != 'prod' && _appEnv != 'production';

  /// 微信支付配置是否就绪。
  static bool get isWechatConfigured => wechatAppId.isNotEmpty;

  /// 支付宝支付配置是否就绪。
  static bool get isAlipayConfigured => alipayAppId.isNotEmpty;
}

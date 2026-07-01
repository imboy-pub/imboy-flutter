import 'package:flutter/foundation.dart';

import 'package:imboy/config/payment_config.dart';
import 'package:imboy/service/app_logger.dart';
import 'package:imboy/service/payment_gateway.dart';

/// 第三方支付收银台唤起结果。
enum PaymentLaunchResult {
  /// 用户付款成功（前端仍须轮询订单状态确认入账）。
  success,

  /// 用户主动取消支付。
  cancelled,

  /// 支付失败（含 SDK 报错、未安装客户端、回调失败码）。
  failed,

  /// 支付方式未配置或下单参数不完整，应提示"即将开通"。
  notConfigured,
}

/// 支付宝原生回调状态码（resultStatus）。
abstract final class AlipayResultStatus {
  static const String success = '9000';
  static const String cancelled = '6001';
}

/// 微信支付回调 errCode。
abstract final class WechatErrCode {
  static const int success = 0;
  static const int cancelled = -2;
}

/// 第三方支付收银台唤起器。
///
/// 闭环：后端统一下单返回 `pay_params` → 本类按 method 分发并唤起对应原生 SDK →
/// 用户付款 → 返回 [PaymentLaunchResult]。调用方据结果决定是否继续轮询订单状态
/// （`success`/`failed` 继续轮询，`cancelled` 中止，`notConfigured` 提示）。
///
/// SDK 调用通过可注入的 [PaymentSdkGateway] 隔离，便于单测。
class PaymentLauncher {
  PaymentLauncher({PaymentSdkGateway? gateway})
    : _gateway = gateway ?? RealPaymentSdkGateway();

  final PaymentSdkGateway _gateway;

  /// 按支付方式分发唤起。[payParams] 为后端信封中的 `pay_params`。
  Future<PaymentLaunchResult> launch(
    String method,
    Map<dynamic, dynamic>? payParams,
  ) {
    final params = payParams ?? const <dynamic, dynamic>{};
    switch (method) {
      case 'alipay':
        return launchAlipay(params);
      case 'wechat':
        return launchWechat(params);
      default:
        // wallet 等无需唤起 SDK 的方式不应走到这里；未知方式视为未配置。
        return Future.value(PaymentLaunchResult.notConfigured);
    }
  }

  /// 唤起支付宝收银台。
  Future<PaymentLaunchResult> launchAlipay(
    Map<dynamic, dynamic> payParams,
  ) async {
    if (!PaymentConfig.isAlipayConfigured) {
      return PaymentLaunchResult.notConfigured;
    }
    final orderStr = _stringOf(payParams['order_str']);
    if (orderStr.isEmpty) return PaymentLaunchResult.notConfigured;

    try {
      final result = await _gateway.aliPay(
        orderStr,
        universalLink: _nullIfEmpty(PaymentConfig.alipayUniversalLink),
      );
      return parseAlipayResult(result);
    } on Object catch (e, s) {
      if (kDebugMode) debugPrint('[PaymentLauncher] alipay error: $e');
      AppLogger.error('[PaymentLauncher] alipay launch failed', e, s);
      return PaymentLaunchResult.failed;
    }
  }

  /// 唤起微信收银台。
  ///
  /// 微信下单需 6 项二次签名参数（partnerId/prepayId/packageValue/nonceStr/
  /// timeStamp/sign）。任一缺失视为后端二次签名未就绪 → 降级 notConfigured。
  Future<PaymentLaunchResult> launchWechat(
    Map<dynamic, dynamic> payParams,
  ) async {
    if (!PaymentConfig.isWechatConfigured) {
      return PaymentLaunchResult.notConfigured;
    }
    final fields = parseWechatParams(payParams, PaymentConfig.wechatAppId);
    if (fields == null) return PaymentLaunchResult.notConfigured;

    try {
      final registered = await _gateway.ensureWechatRegistered(
        appId: PaymentConfig.wechatAppId,
        universalLink: _nullIfEmpty(PaymentConfig.wechatUniversalLink),
      );
      if (!registered) return PaymentLaunchResult.notConfigured;

      final errCode = await _gateway.wechatPay(
        appId: fields.appId,
        partnerId: fields.partnerId,
        prepayId: fields.prepayId,
        packageValue: fields.packageValue,
        nonceStr: fields.nonceStr,
        timestamp: fields.timestamp,
        sign: fields.sign,
        signType: fields.signType,
      );
      return parseWechatResult(errCode);
    } on Object catch (e, s) {
      if (kDebugMode) debugPrint('[PaymentLauncher] wechat error: $e');
      AppLogger.error('[PaymentLauncher] wechat launch failed', e, s);
      return PaymentLaunchResult.failed;
    }
  }

  // ── 纯逻辑（可单测，不触碰 SDK）───────────────────────────────────────

  /// 解析支付宝回调 Map 的 `resultStatus`。
  static PaymentLaunchResult parseAlipayResult(Map<dynamic, dynamic> result) {
    final status = _stringOf(result['resultStatus']);
    return switch (status) {
      AlipayResultStatus.success => PaymentLaunchResult.success,
      AlipayResultStatus.cancelled => PaymentLaunchResult.cancelled,
      _ => PaymentLaunchResult.failed,
    };
  }

  /// 解析微信回调 errCode。
  static PaymentLaunchResult parseWechatResult(int? errCode) {
    return switch (errCode) {
      WechatErrCode.success => PaymentLaunchResult.success,
      WechatErrCode.cancelled => PaymentLaunchResult.cancelled,
      _ => PaymentLaunchResult.failed,
    };
  }

  /// 校验并提取微信下单参数；缺任一必要字段返回 `null`（→ notConfigured 降级）。
  ///
  /// appId 优先用后端下发，缺失时回落到编译期配置 [configAppId]。
  static WechatPayFields? parseWechatParams(
    Map<dynamic, dynamic> payParams,
    String configAppId,
  ) {
    final appId = _firstNonEmpty(_stringOf(payParams['appid']), configAppId);
    final partnerId = _stringOf(payParams['partnerid']);
    final prepayId = _stringOf(payParams['prepay_id'] ?? payParams['prepayid']);
    final packageValue = _firstNonEmpty(
      _stringOf(payParams['package']),
      'Sign=WXPay',
    );
    final nonceStr = _stringOf(payParams['noncestr'] ?? payParams['nonce_str']);
    final sign = _stringOf(payParams['sign']);
    final timestamp = _intOf(
      payParams['timestamp'] ??
          payParams['timeStamp'] ??
          payParams['time_stamp'],
    );

    if (appId.isEmpty ||
        partnerId.isEmpty ||
        prepayId.isEmpty ||
        nonceStr.isEmpty ||
        sign.isEmpty ||
        timestamp <= 0) {
      return null;
    }
    return WechatPayFields(
      appId: appId,
      partnerId: partnerId,
      prepayId: prepayId,
      packageValue: packageValue,
      nonceStr: nonceStr,
      timestamp: timestamp,
      sign: sign,
      signType: _nullIfEmpty(_stringOf(payParams['signtype'])),
    );
  }

  static String _stringOf(Object? v) => v?.toString() ?? '';

  static String? _nullIfEmpty(String v) => v.isEmpty ? null : v;

  static String _firstNonEmpty(String a, String b) => a.isNotEmpty ? a : b;

  static int _intOf(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

/// 微信下单二次签名字段集合。
@immutable
class WechatPayFields {
  const WechatPayFields({
    required this.appId,
    required this.partnerId,
    required this.prepayId,
    required this.packageValue,
    required this.nonceStr,
    required this.timestamp,
    required this.sign,
    this.signType,
  });

  final String appId;
  final String partnerId;
  final String prepayId;
  final String packageValue;
  final String nonceStr;
  final int timestamp;
  final String sign;
  final String? signType;
}

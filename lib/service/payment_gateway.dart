import 'dart:async';

import 'package:fluwx/fluwx.dart';
import 'package:tobias/tobias.dart';

/// 第三方支付 SDK 网关抽象。
///
/// 将 fluwx / tobias 的真实原生调用隔离在接口之后，使 [PaymentLauncher] 的编排与
/// 解析逻辑可在不依赖真机 / 原生通道的情况下单测（测试注入 fake 实现）。
abstract interface class PaymentSdkGateway {
  /// 支付宝支付。[orderStr] 为后端下单返回的已签名订单串。
  /// 返回原生回调 Map（含 `resultStatus`）。
  Future<Map<dynamic, dynamic>> aliPay(
    String orderStr, {
    String? universalLink,
  });

  /// 确保微信 SDK 已注册。重复调用安全。
  /// 返回 `true` 表示注册成功（appId 有效）。
  Future<bool> ensureWechatRegistered({
    required String appId,
    String? universalLink,
  });

  /// 微信支付。参数来自后端二次签名结果。
  /// 返回微信支付回调的 `errCode`（0=成功，-2=取消，其他=失败），
  /// 无回调返回 `null`。
  Future<int?> wechatPay({
    required String appId,
    required String partnerId,
    required String prepayId,
    required String packageValue,
    required String nonceStr,
    required int timestamp,
    required String sign,
    String? signType,
  });
}

/// 基于 fluwx / tobias 的真实 SDK 网关实现。
class RealPaymentSdkGateway implements PaymentSdkGateway {
  RealPaymentSdkGateway({Fluwx? fluwx, Tobias? tobias})
    : _fluwx = fluwx ?? Fluwx(),
      _tobias = tobias ?? Tobias();

  final Fluwx _fluwx;
  final Tobias _tobias;
  bool _wechatRegistered = false;

  @override
  Future<Map<dynamic, dynamic>> aliPay(
    String orderStr, {
    String? universalLink,
  }) {
    return _tobias.pay(orderStr, universalLink: universalLink);
  }

  @override
  Future<bool> ensureWechatRegistered({
    required String appId,
    String? universalLink,
  }) async {
    if (_wechatRegistered) return true;
    final ok = await _fluwx.registerApi(
      appId: appId,
      universalLink: universalLink,
    );
    _wechatRegistered = ok;
    return ok;
  }

  @override
  Future<int?> wechatPay({
    required String appId,
    required String partnerId,
    required String prepayId,
    required String packageValue,
    required String nonceStr,
    required int timestamp,
    required String sign,
    String? signType,
  }) async {
    final completer = _WechatPayWaiter();
    final cancelable = _fluwx.addSubscriber((WeChatResponse response) {
      if (response is WeChatPaymentResponse) {
        completer.complete(response.errCode);
      }
    });
    try {
      final dispatched = await _fluwx.pay(
        which: Payment(
          appId: appId,
          partnerId: partnerId,
          prepayId: prepayId,
          packageValue: packageValue,
          nonceStr: nonceStr,
          timestamp: timestamp,
          sign: sign,
          signType: signType,
        ),
      );
      if (!dispatched) return null;
      return await completer.future;
    } finally {
      cancelable.cancel();
    }
  }
}

/// 单次微信支付回调等待器（首个 PaymentResponse 命中即完成）。
class _WechatPayWaiter {
  final _completer = _SingleCompleter<int?>();
  Future<int?> get future => _completer.future;
  void complete(int? errCode) => _completer.complete(errCode);
}

/// 仅完成一次的轻量 Completer 包装，避免重复回调导致异常。
class _SingleCompleter<T> {
  final _c = Completer<T>();
  Future<T> get future => _c.future;
  void complete(T value) {
    if (!_c.isCompleted) _c.complete(value);
  }
}

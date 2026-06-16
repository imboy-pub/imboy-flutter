import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/model/channel_order_model.dart';

/// 付费频道订单 API。
///
/// 闭环：创建订单 → 支付（钱包余额即时入账 / 第三方异步回调）→ 查询状态。
/// 金额由后端频道配置决定，前端不传价格。
/// 订单模型复用 [ChannelOrderModel]，状态码见 [ChannelOrderStatus]。
class ChannelOrderApi extends HttpClient {
  /// 创建订单。价格在后端按频道配置确定。
  Future<ChannelOrderModel?> createOrder(String channelId) async {
    IMBoyHttpResponse resp = await post(
      API.channelCreateOrder(channelId),
      data: const <String, dynamic>{},
    );
    if (!resp.ok || resp.payload == null) {
      EasyLoading.showError(resp.msg);
      return null;
    }
    return ChannelOrderModel.fromJson(
      Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>),
    );
  }

  /// 支付订单。
  ///
  /// [paymentMethod] 支付方式。`wallet` 走钱包余额即时扣款入账；
  ///   `alipay`/`wechat` 等第三方需后端配置凭据并由回调入账（待 S4）。
  /// 返回后端支付结果/参数 Map；钱包余额支付通常即时置为已支付。
  Future<Map<String, dynamic>?> payOrder(
    String orderNo, {
    String paymentMethod = 'wallet',
  }) async {
    IMBoyHttpResponse resp = await post(
      API.channelOrderPay,
      data: {'order_no': orderNo, 'payment_method': paymentMethod},
    );
    if (!resp.ok) {
      EasyLoading.showError(resp.msg);
      return null;
    }
    if (resp.payload is Map) {
      return Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>);
    }
    return <String, dynamic>{};
  }

  /// 查询订单状态。
  Future<ChannelOrderModel?> getOrder(String orderNo) async {
    IMBoyHttpResponse resp = await get(API.channelOrderStatus(orderNo));
    if (!resp.ok || resp.payload == null) {
      return null;
    }
    return ChannelOrderModel.fromJson(
      Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>),
    );
  }

  /// 分页查询我的订单。
  Future<Map<String, dynamic>?> myOrders({int page = 1, int size = 20}) async {
    IMBoyHttpResponse resp = await get(
      API.channelMyOrders,
      queryParameters: {'page': page, 'size': size},
    );
    if (!resp.ok || resp.payload == null) {
      return null;
    }
    return Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>);
  }
}

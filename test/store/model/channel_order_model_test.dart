import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/channel_order_model.dart';

void main() {
  group('ChannelOrderModel.fromJson', () {
    test('parses mixed value types safely', () {
      final model = ChannelOrderModel.fromJson({
        'id': 123,
        'channel_id': 456,
        'user_id': '789',
        'order_no': 'CH1767225600000123',
        'amount': '9.90',
        'currency': 'CNY',
        'status': '1',
        'payment_method': 'mock',
        'payment_no': 112233,
        'payment_at': '1767225600000',
        'subscription_start_at': 1767225601,
        'subscription_end_at': null,
        'expires_at': '1767229200000',
        'refund_reason': '',
        'refund_at': null,
        'extra_data': '{"source":"test","coupon":"0"}',
        'channel_name': '付费频道',
        'created_at': 1767225500000,
        'updated_at': '1767225600000',
      });

      expect(model.id, '123');
      expect(model.channelId, '456');
      expect(model.userId, '789');
      expect(model.orderNo, 'CH1767225600000123');
      expect(model.amount, 9.9);
      expect(model.currency, 'CNY');
      expect(model.status, ChannelOrderStatus.paid);
      expect(model.paymentNo, '112233');
      expect(model.paymentAt, isNotNull);
      expect(model.subscriptionStartAt, isNotNull);
      expect(model.subscriptionEndAt, isNull);
      expect(model.refundReason, isNull);
      expect(model.extraData?['source'], 'test');
      expect(model.channelName, '付费频道');
      expect(model.createdAt.millisecondsSinceEpoch, 1767225500000);
      expect(model.updatedAt, isNotNull);
    });
  });
}

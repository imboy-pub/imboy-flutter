// 充值订单状态枚举跨仓契约锁定
//
// 后端权威定义（imboy src/repo/recharge_order_repo.erl）：
//   0=待支付 1=已支付 2=已取消 3=已退款 4=已过期
// 2026-08-20 修正前，Flutter 把 3 当「已过期」、4 当「支付失败」（颠倒），
// admin 把 2 当「退款中」——三端三个定义。本测试锁死数值与语义，
// 防止未来重排/误改 silently 回归。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/api/wallet_api.dart';

void main() {
  test('RechargeOrderStatus 数值与后端 recharge_order_repo 对齐', () {
    expect(RechargeOrderStatus.pending, 0); // 待支付
    expect(RechargeOrderStatus.paid, 1); // 已支付
    expect(RechargeOrderStatus.cancelled, 2); // 已取消
    expect(RechargeOrderStatus.refunded, 3); // 已退款
    expect(RechargeOrderStatus.expired, 4); // 已过期
  });

  test('RechargeOrder.fromJson 解析 status 与缺省', () {
    const json = {
      'order_no': 'R123',
      'amount': 100,
      'status': 3,
      'payment_method': 'alipay',
    };
    final order = RechargeOrder.fromJson(json);
    expect(order.status, RechargeOrderStatus.refunded);
    expect(order.isPaid, isFalse);

    final missing = RechargeOrder.fromJson(const {'order_no': 'R124'});
    expect(missing.status, RechargeOrderStatus.pending);
  });
}

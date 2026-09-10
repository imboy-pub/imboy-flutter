// ChannelOrderListPage 失败态与点击重试 Widget 测试（批次171，BUG#151 回归）。
//
// BUG#151：此前 myOrders 对业务失败静默 return null，被 provider 压成
// 空列表，页面 async.when 的 error 分支为死代码且文案与空态共用
// noOrders。修复后失败走 throwIfFailed 抛异常 → FutureProvider 进
// error 态；文案改 loadError，与空态可区分。
//
// 运行方式 / How to run:
//   flutter test test/unit_test/page/channel/channel_order_list_page_error_retry_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_exceptions.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_order_list_page.dart';
import 'package:imboy/page/channel/channel_purchase_provider.dart';
import 'package:imboy/store/api/channel_order_api.dart';

/// 可编程 fake：按注入的 thrower/载荷行为响应 myOrders。
class _StubOrderApi extends ChannelOrderApi {
  _StubOrderApi({this.thrower, this.payload});

  final Exception? Function()? thrower;
  final Map<String, dynamic>? payload;
  int callCount = 0;

  @override
  Future<Map<String, dynamic>?> myOrders({int page = 1, int size = 20}) async {
    callCount++;
    final err = thrower?.call();
    if (err != null) throw err;
    return payload;
  }
}

Widget _buildTestApp(ChannelOrderApi api) {
  return TranslationProvider(
    child: ProviderScope(
      overrides: [channelOrderApiProvider.overrideWithValue(api)],
      child: const MaterialApp(home: ChannelOrderListPage()),
    ),
  );
}

Map<String, dynamic> _orderJson(String orderNo) => {
  'id': 1,
  'channel_id': 3001,
  'user_id': 9,
  'order_no': orderNo,
  'amount': 9.9,
  'currency': 'CNY',
  'status': 2,
  'payment_method': 'wallet',
  'channel_name': '付费频道A',
  'created_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
};

void main() {
  testWidgets('OL-1 加载失败渲染失败态文案（与空态可区分），不再误显示「暂无订单」', (tester) async {
    final api = _StubOrderApi(
      thrower: () => BadRequestException(message: 'Invalid token.', code: 706),
    );

    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();

    expect(find.text(t.common.loadError), findsOneWidget);
    expect(find.text(t.channel.noOrders), findsNothing);
    // autoDispose provider 在测试帧循环下会多次重建，不做精确计数
    expect(api.callCount, greaterThanOrEqualTo(1));
  });

  testWidgets('OL-2 点击失败态触发重试（provider 刷新，请求计数增加）', (tester) async {
    final api = _StubOrderApi(
      thrower: () => BadRequestException(message: 'network down', code: 500),
    );

    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();
    final before = api.callCount;

    // NoDataView 整块 GestureDetector(onTap: onTop=ref.invalidate)
    await tester.tap(find.text(t.common.loadError));
    await tester.pumpAndSettle();

    expect(
      api.callCount,
      greaterThan(before),
      reason: '点击失败态应 invalidate provider 重试',
    );
    expect(find.text(t.common.loadError), findsOneWidget);
  });

  testWidgets('OL-3 失败后重试成功 → 空态渲染（失败可恢复）', (tester) async {
    var fail = true;
    final api = _StubOrderApi(
      thrower: () =>
          fail ? BadRequestException(message: 'boom', code: 1) : null,
      payload: const <String, dynamic>{'list': <Map<String, dynamic>>[]},
    );

    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();
    expect(find.text(t.common.loadError), findsOneWidget);

    fail = false;
    await tester.tap(find.text(t.common.loadError));
    await tester.pumpAndSettle();

    expect(find.text(t.channel.noOrders), findsOneWidget);
    expect(find.text(t.common.loadError), findsNothing);
  });

  testWidgets('OL-4 有订单时渲染列表（正常路径不进失败态）', (tester) async {
    final api = _StubOrderApi(
      payload: {
        'list': <Map<String, dynamic>>[_orderJson('CH-1')],
      },
    );

    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();

    expect(find.text('付费频道A'), findsOneWidget);
    expect(find.text(t.common.loadError), findsNothing);
  });
}

/// R10：最近注册用户页的注册时间展示链路回归。
///
/// provider 层（RecentlyRegisteredUserNotifier.page）依赖 Connectivity 与
/// UserApi 单例（私有构造，无法替身）；本测试覆盖其下游链路——
/// PeopleModel.fromJson(真实 RFC3339 形状) → state.peopleList →
/// 页面徽章渲染（`registeredAt > 0` 才显示），证明：
///   R10-1 真实注册时间被展示（不是关系时间，不是 now）；
///   R10-3 缺失/非法（0）不显示时间徽章，绝不出现"刚刚"。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/recently_registered_user/recently_registered_user_page.dart';
import 'package:imboy/page/contact/recently_registered_user/recently_registered_user_provider.dart';
import 'package:imboy/store/model/people_model.dart';

class _FakeNotifier extends RecentlyRegisteredUserNotifier {
  _FakeNotifier(this.initial);
  final RecentlyRegisteredUserState initial;

  @override
  RecentlyRegisteredUserState build() => initial;

  @override
  Future<void> initData() async {
    // 测试注入预置列表，不触网络/Connectivity。
  }
}

Future<void> _pumpPage(WidgetTester tester, List<PeopleModel> people) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          recentlyRegisteredUserApi.overrideWith(
            () => _FakeNotifier(
              RecentlyRegisteredUserState(peopleList: people, page: 2),
            ),
          ),
        ],
        child: const MaterialApp(home: RecentlyRegisteredUserPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('R10-1 真实注册时间（zoned RFC3339）渲染为日期徽章', (tester) async {
    // 40 天前注册：> 7 天 → 徽章走 MM-dd pattern（本地日历字段）。
    // 用标准 toIso8601String 构造（含毫秒）；现有 toRfc3339 输出
    // microsecond 字段而非毫秒位（R21-B 待清理），不在此用作 fixture。
    final registered = DateTime.now().toUtc().subtract(
      const Duration(days: 40),
    );
    final model = PeopleModel.fromJson({
      'uid': 5001,
      'account': 'acc01',
      'nickname': 'userA',
      'created_at': registered.toIso8601String(),
    });
    expect(model.registeredAt, registered.millisecondsSinceEpoch);

    await _pumpPage(tester, [model]);
    expect(find.text('userA'), findsOneWidget);
    final expected = DateFormat('MM-dd').format(
      DateTime.fromMillisecondsSinceEpoch(model.registeredAt, isUtc: false),
    );
    expect(find.text(expected), findsOneWidget, reason: '注册时间徽章应展示');
  });

  testWidgets('R10-3 注册时间缺失（0）不渲染时间徽章、不显示"刚刚"', (tester) async {
    // 后端合同：缺失时 created_at 为空串 → registeredAt=0
    final missing = PeopleModel.fromJson({
      'uid': 5002,
      'account': 'acc02',
      'nickname': 'userB',
      'created_at': '',
    });
    // 非法形态（纯数字字符串/无 zone）同样归 0
    final invalid = PeopleModel.fromJson({
      'uid': 5003,
      'account': 'acc03',
      'nickname': 'userC',
      'created_at': '1767225600000',
    });
    expect(missing.registeredAt, 0);
    expect(invalid.registeredAt, 0);

    await _pumpPage(tester, [missing, invalid]);
    expect(find.text('userB'), findsOneWidget);
    expect(find.text('userC'), findsOneWidget);
    // 无任何时间徽章：既无 MM-dd 日期文本，也无"刚刚"（timeJustNow 污染）
    expect(find.text(t.common.timeJustNow), findsNothing);
    final dateBadgeTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .where((s) => RegExp(r'^\d{2}-\d{2}$').hasMatch(s))
        .toList();
    expect(dateBadgeTexts, isEmpty, reason: '未知注册时间不得渲染日期徽章');
  });
}

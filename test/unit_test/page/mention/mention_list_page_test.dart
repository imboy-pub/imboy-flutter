import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mention/mention_list_page.dart';
import 'package:imboy/service/mention_service.dart'
    show NewMentionEvent, MentionAllReadEvent, MentionService;
import 'package:imboy/store/api/mention_api.dart';

/// MentionListPage 测试。
///
/// 此前本文件只能测公开构造契约：页面 initState 直接走 `MentionService.to`
/// （当时是 `static final` 单例，无注入点）→ MentionApi → HttpClient 的
/// dio Http2Adapter 真实 socket，flutter_test 的 HttpOverrides 拦不住，
/// 整页 pump 会发起真实网络请求并挂到 60s 超时。
///
/// MentionService 补上 GroupAlbumService 同款 `instanceForTest` 后即可整页
/// 渲染。下面覆盖 d2749ea4 的失败态修复：service 失败返回 null，页面此前用
/// `if (result != null)` 直接丢弃该信号，渲染成"暂无提及"。
class _FakeMentionService extends MentionService {
  _FakeMentionService({this.items = const [], this.failGetMentions = false})
    : super.withApi(MentionApi());

  final List<Map<String, dynamic>> items;

  /// true 时 getMentions 返回 null —— 与 MentionService 真实失败路径一致。
  bool failGetMentions;
  int getMentionsCallCount = 0;

  @override
  Future<Map<String, dynamic>?> getMentions({
    int page = 1,
    int size = 20,
    int? isRead,
    String? groupId,
  }) async {
    getMentionsCallCount++;
    if (failGetMentions) return null;
    return {'items': items, 'total': items.length};
  }

  @override
  Future<int> getUnreadCount({String? groupId}) async => 0;
}

Widget _buildTestApp() {
  // 页面 build 用 context.t，必须包 TranslationProvider
  return ProviderScope(
    child: TranslationProvider(
      child: const MaterialApp(home: MentionListPage(groupId: 'g100')),
    ),
  );
}

void main() {
  tearDown(() {
    MentionService.instanceForTest = null;
  });

  group('MentionListPage 失败态（d2749ea4 回归）', () {
    testWidgets('拉取失败渲染"加载失败 + 重试"，而不是"暂无提及"', (tester) async {
      MentionService.instanceForTest = _FakeMentionService(
        failGetMentions: true,
      );

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('加载失败，请重试'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text("暂无@提及"), findsNothing);
    });

    testWidgets('点重试真的重拉；成功后渲染列表且失败态消失', (tester) async {
      final fake = _FakeMentionService(
        items: const [
          {
            'id': 1,
            'group_id': 'g100',
            'msg_id': 'm1',
            'from_nickname': '张三',
            'content': '喊你一声',
            'is_read': 0,
          },
        ],
        failGetMentions: true,
      );
      MentionService.instanceForTest = fake;

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      final failedCallCount = fake.getMentionsCallCount;
      expect(failedCallCount, greaterThan(0));

      fake.failGetMentions = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();

      expect(fake.getMentionsCallCount, greaterThan(failedCallCount));
      expect(find.text('加载失败，请重试'), findsNothing);
      expect(find.textContaining('喊你一声'), findsOneWidget);
    });

    testWidgets('真的没数据时是纯空态，不带重试入口（空态/失败态语义分离）', (tester) async {
      MentionService.instanceForTest = _FakeMentionService();

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text("暂无@提及"), findsOneWidget);
      expect(find.text('加载失败，请重试'), findsNothing);
      final emptyView = tester.widget<NoDataView>(find.byType(NoDataView));
      expect(emptyView.onTop, isNull, reason: '空态不该给重试入口');
    });
  });

  group('MentionListPage 构造契约', () {
    test('MC-1 默认构造 groupId 为 null（全部提及入口）', () {
      const page = MentionListPage();

      expect(page.groupId, isNull);
    });

    test('MC-2 传入 groupId 时按群过滤（群内提及入口）', () {
      const page = MentionListPage(groupId: 'g100');

      expect(page.groupId, 'g100');
    });

    test('MC-3 createState 可创建状态对象（页面可实例化）', () {
      const page = MentionListPage();

      expect(page.createState(), isNotNull);
    });
  });

  group('提及事件契约（页面刷新触发源）', () {
    test('ME-1 NewMentionEvent 携带原始 data 且按值相等', () {
      const data = {'id': 1, 'group_id': 'g100', 'msg_id': 'm1'};

      const event = NewMentionEvent(data: data);

      expect(event.data['group_id'], 'g100');
      // AppEvent 基于 props 的值相等语义（事件去重/比对依赖此契约）
      expect(event, const NewMentionEvent(data: data));
    });

    test('ME-2 MentionAllReadEvent 的 groupId 可为 null（全部群已读）', () {
      const event = MentionAllReadEvent();

      expect(event.groupId, isNull);
      expect(event, const MentionAllReadEvent());
    });
  });
}

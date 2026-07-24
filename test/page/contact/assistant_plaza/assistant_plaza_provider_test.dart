import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/contact/assistant_plaza/assistant_plaza_provider.dart';
import 'package:imboy/store/api/agent_api.dart';

/// AssistantPlazaNotifier 单测：分页/搜索/错误态状态机。
///
/// 通过 agentApiProvider override 注入 Fake，不触网。
class _FakeAgentApi extends Fake implements AgentApi {
  _FakeAgentApi({this.pages = const {}, this.fail = false});

  /// page -> list 条目；未配置的页返回空列表
  final Map<int, List<Map<String, dynamic>>> pages;

  /// 可中途翻转，模拟「先成功后失败」场景
  bool fail;

  int callCount = 0;
  String? lastKwd;
  int? lastPage;

  @override
  Future<Map<String, dynamic>?> agentList({
    int page = 1,
    int size = 10,
    String kwd = '',
  }) async {
    callCount++;
    lastKwd = kwd;
    lastPage = page;
    if (fail) {
      return null;
    }
    return {'total': 0, 'page': page, 'size': size, 'list': pages[page] ?? []};
  }
}

Map<String, dynamic> _card(int id, String name) => {
  'id': id,
  'name': name,
  'avatar': 'avatar/$id.png',
  'description': 'desc-$id',
};

ProviderContainer _container(_FakeAgentApi api) {
  final container = ProviderContainer(
    overrides: [agentApiProvider.overrideWithValue(api)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('AssistantPlazaNotifier', () {
    test('AP-1 initData 成功：映射字段 + accountType 固定 1 + 满页 hasMore', () async {
      final api = _FakeAgentApi(
        pages: {
          1: [for (var i = 1; i <= 10; i++) _card(i, 'bot$i')],
        },
      );
      final container = _container(api);
      final notifier = container.read(assistantPlazaProvider.notifier);

      await notifier.initData();
      final state = container.read(assistantPlazaProvider);

      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.list.length, 10);
      expect(state.list.first.id, 1);
      expect(state.list.first.nickname, 'bot1');
      expect(state.list.first.sign, 'desc-1');
      expect(state.list.first.accountType, 1);
      expect(state.page, 2);
      expect(state.hasMore, true);
    });

    test('AP-2 initData 失败：error 置位且列表为空', () async {
      final api = _FakeAgentApi(fail: true);
      final container = _container(api);
      final notifier = container.read(assistantPlazaProvider.notifier);

      await notifier.initData();
      final state = container.read(assistantPlazaProvider);

      expect(state.isLoading, false);
      expect(state.error, isNotNull);
      expect(state.list, isEmpty);
    });

    test('AP-3 loadMore 追加下一页；短页后 hasMore=false 不再请求', () async {
      final api = _FakeAgentApi(
        pages: {
          1: [for (var i = 1; i <= 10; i++) _card(i, 'bot$i')],
          2: [_card(11, 'bot11')], // 短页 → hasMore=false
        },
      );
      final container = _container(api);
      final notifier = container.read(assistantPlazaProvider.notifier);

      await notifier.initData();
      await notifier.loadMore();
      var state = container.read(assistantPlazaProvider);

      expect(state.list.length, 11);
      expect(state.page, 3);
      expect(state.hasMore, false);

      final callsBefore = api.callCount;
      await notifier.loadMore(); // hasMore=false 应短路
      state = container.read(assistantPlazaProvider);

      expect(api.callCount, callsBefore);
      expect(state.list.length, 11);
    });

    test('AP-4 loadMore 失败：保留已有列表与 hasMore，供下次重试', () async {
      final api = _FakeAgentApi(
        pages: {
          1: [for (var i = 1; i <= 10; i++) _card(i, 'bot$i')],
        },
      );
      final container = _container(api);
      final notifier = container.read(assistantPlazaProvider.notifier);
      await notifier.initData();

      api.fail = true;
      await notifier.loadMore();
      final state = container.read(assistantPlazaProvider);

      expect(state.list.length, 10);
      expect(state.hasMore, true);
      expect(state.isLoadingMore, false);
      expect(state.page, 2); // 失败不推进游标，下次触底重试同一页
    });

    test('AP-5 updateKwd 重置分页并携带关键词重查', () async {
      final api = _FakeAgentApi(
        pages: {
          1: [_card(1, 'translator')],
        },
      );
      final container = _container(api);
      final notifier = container.read(assistantPlazaProvider.notifier);

      await notifier.initData();
      await notifier.updateKwd('trans');
      final state = container.read(assistantPlazaProvider);

      expect(api.lastKwd, 'trans');
      expect(api.lastPage, 1);
      expect(state.kwd, 'trans');
      expect(state.page, 2);
      expect(state.hasMore, false); // 1 条 < size 10
    });
  });
}

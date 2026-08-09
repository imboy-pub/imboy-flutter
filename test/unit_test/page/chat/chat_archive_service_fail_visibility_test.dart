/// BUG#119 修复单测：历史回填「失败」与「无数据」必须严格区分。
///
/// 旧实现 `fetchAndPersistHistoryPage` 在 API 失败（result == null）时
/// 返回 (fetched: 0, hasMore: false)，被上层当成「服务端确认无数据」——
/// 失败被完全静默，用户看到误导性的「暂无数据」且无重试入口
/// （真机证据：SharedPreferences 无任何 msg_history_seq_* 游标，回填从未成功）。
///
/// 修复后：API 失败抛 [HistoryFetchException]，由 syncHistoryBackfill 显式
/// 标记 ChatState.historySyncFailed（页面显示「历史记录加载失败，点击重试」）；
/// 「服务端确认无数据」仍返回 fetched: 0，不抛。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';
import 'package:imboy/store/api/msg_api.dart';

/// 可控返回的 MsgApi 替身：不发起真实网络请求。
class _FakeMsgApi extends MsgApi {
  _FakeMsgApi({this.historyResult});

  /// history() 的返回值；null 模拟 API 失败（401/5xx/超时/解析失败）
  Map<String, dynamic>? historyResult;

  /// history() 被调用次数
  int historyCalls = 0;

  @override
  Future<Map<String, dynamic>?> history({
    required String chatType,
    required String peerId,
    int afterSeq = 0,
    int limit = 50,
  }) async {
    historyCalls++;
    return historyResult;
  }
}

void main() {
  group('BUG#119 fetchAndPersistHistoryPage 失败与无数据区分', () {
    test('API 失败（返回 null）抛 HistoryFetchException，不再伪装成无数据', () async {
      final api = _FakeMsgApi(historyResult: null);
      final service = ChatArchiveService(api: api);

      await expectLater(
        service.fetchAndPersistHistoryPage(
          chatType: 'c2c',
          peerId: '1825989847768576000',
          afterSeq: 0,
        ),
        throwsA(isA<HistoryFetchException>()),
        reason:
            '旧行为返回 (fetched:0, hasMore:false) 把失败当无数据，'
            '上游因此保存错误游标并永久静默失败',
      );
      expect(api.historyCalls, 1);
    });

    test('API 成功但无数据（空 messages）不抛，返回 fetched:0 —— 与失败严格区分', () async {
      final api = _FakeMsgApi(
        historyResult: <String, dynamic>{
          'messages': <dynamic>[],
          'next_seq': 0,
          'has_more': false,
          'conv_key': 'c2c:1:2',
        },
      );
      final service = ChatArchiveService(api: api);

      final result = await service.fetchAndPersistHistoryPage(
        chatType: 'c2c',
        peerId: '2',
        afterSeq: 0,
      );

      // 服务端确认无数据是合法结果：不抛、0 条、无更多，页面显示「暂无数据」
      expect(result.fetched, 0);
      expect(result.hasMore, isFalse);
      expect(result.nextSeq, 0);
    });

    test('API 失败不推进游标语义：抛异常而非返回 nextSeq，防止保存错误游标', () async {
      final api = _FakeMsgApi(historyResult: null);
      final service = ChatArchiveService(api: api);

      Object? thrown;
      try {
        await service.fetchAndPersistHistoryPage(
          chatType: 'c2g',
          peerId: '1818608297223856128',
          afterSeq: 7,
        );
      } catch (e) {
        thrown = e;
      }

      expect(thrown, isA<HistoryFetchException>());
      // 若旧实现返回 (fetched:0, nextSeq:7)，调用方会把游标 0→7 且不落库，
      // 下次进会话跳过前 7 条永远看不到——这是 BUG#119 的静默失败形态。
    });
  });
}

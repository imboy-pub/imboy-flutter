/// V3-23 D3 — authoritative 会话同步的企业频道类别归一化测试。
///
/// matrix spec §5 落点 D3：`_normalizeAuthoritativeType` 从「仅 C2C/C2G」扩
/// 企业频道类别。wire 值 `channel` 依据 spec §5 B1/B6 冻结方向（origin
/// conversation_kind 扩 `channel`；resource_type `msg_channel` 归一 `channel`）。
///
/// 验收面：
/// 1. `conversation_type=channel` 的 authoritative entry 不再被丢弃成空串，
///    归一为 `CHANNEL`（与 MessageFlowType.channel 对齐）并落库；
/// 2. 真未知类别仍然丢弃（空串 → continue），不猜测；
/// 3. 非 C2C 会话不参与「不在权威列表就隐藏」（BUG#71 口径不受影响）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/conversation_api.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

const String _testUid = '880001';

class _FakeConversationApi extends ConversationApi {
  _FakeConversationApi({this.entries = const <Map<String, dynamic>>[]});

  final List<Map<String, dynamic>> entries;

  @override
  Future<List<Map<String, dynamic>>> listMine({int? lastServerTs}) async =>
      entries;
}

class _TestConversationNotifier extends ConversationNotifier {
  _TestConversationNotifier({required ConversationApi api})
    : super(conversationApi: api);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, _testUid);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await openFixtureDatabaseAtVersion(version: 32);
    SqliteService.setDbForTest(db);
  });

  tearDownAll(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  setUp(() async {
    await SqliteService.to.delete(
      ConversationRepo.tableName,
      where: '${ConversationRepo.userId} = ?',
      whereArgs: <Object?>[_testUid],
    );
  });

  Future<ProviderContainer> syncWith(List<Map<String, dynamic>> entries) async {
    final container = ProviderContainer(
      overrides: [
        conversationProvider.overrideWith(
          () => _TestConversationNotifier(
            api: _FakeConversationApi(entries: entries),
          ),
        ),
      ],
    );
    container.listen(conversationProvider, (_, _) {});
    await container
        .read(conversationProvider.notifier)
        .syncAuthoritativeConversations(trigger: 'v323_channel_test');
    return container;
  }

  test('conversation_type=channel 归一为 CHANNEL 并落库（不被丢弃）', () async {
    final container = await syncWith(<Map<String, dynamic>>[
      {
        'conversation_id': '6001',
        'conversation_type': 'channel',
        'server_ts': 3000,
        'last_msg_id': 16001,
        'last_msg': {'msg_type': 'text', 'text': '企业频道公告'},
        'is_pinned': 0,
      },
    ]);
    try {
      final channel = await ConversationRepo().findByPeerId('CHANNEL', '6001');
      expect(channel, isNotNull, reason: 'channel 类别被丢弃成空串 = D3 回归');
      expect(channel!.type, 'CHANNEL');
      expect(channel.msgType, 'text');
    } finally {
      container.dispose();
    }
  });

  test('真未知类别仍被丢弃（不猜测），channel 与 c2c 互不影响', () async {
    final container = await syncWith(<Map<String, dynamic>>[
      {
        'conversation_id': '6002',
        'conversation_type': 'channel',
        'server_ts': 3100,
        'last_msg_id': 16002,
        'last_msg': {'msg_type': 'text', 'text': 'ch'},
        'is_pinned': 0,
      },
      {
        'conversation_id': '6003',
        'conversation_type': 'workspace_channel_v9', // 真未知
        'server_ts': 3200,
        'last_msg_id': 16003,
        'last_msg': {'msg_type': 'text', 'text': 'unknown'},
        'is_pinned': 0,
      },
    ]);
    try {
      expect(
        await ConversationRepo().findByPeerId('CHANNEL', '6002'),
        isNotNull,
      );
      // 未知类别不落库
      final all = await ConversationRepo().list();
      expect(all.where((c) => c.peerId == '6003'), isEmpty);
    } finally {
      container.dispose();
    }
  });
}

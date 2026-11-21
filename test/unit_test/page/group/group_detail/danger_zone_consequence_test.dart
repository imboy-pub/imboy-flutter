/// W10（F17/J19）：群危险区四后果分离的定向向量。
///
/// J19.a/b/c（渲染层）：群主看到「转让后退出」+「解散群聊」两条独立
/// 动作；普通成员只有「退出群聊」——不再把解散伪装成唯一出口。
/// J19.d（服务层）：清空 = 仅清本机记录——消息删除但会话行保留可见
/// （is_show 不变、行仍在），不误隐藏、不退群。
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/conversation_provider.dart'
    show ConversationNotifier, conversationProvider;
import 'package:imboy/page/group/group_detail/group_detail_service.dart';
import 'package:imboy/page/group/group_detail/widgets/group_danger_zone.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart' show IMBoyMessageStatus;
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart'
    show MessageRepo;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

void _noopDirty() {}

Widget _wrap(Widget child) => TranslationProvider(
  child: ProviderScope(
    child: MaterialApp(home: Scaffold(body: child)),
  ),
);

Future<ConversationModel> _seedConversation(ConversationRepo repo) async {
  final model = ConversationModel(
    id: 0,
    type: 'C2G',
    peerId: 880990,
    avatar: '',
    title: '危险区测试群',
    subtitle: '',
    msgType: 'text',
    unreadNum: 0,
    isShow: 1,
    lastTime: DateTime.now().millisecondsSinceEpoch,
  );
  final id = await repo.insert(model);
  return model.copyWith(id: id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUpAll(() {
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(db);
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  group('J19.a/b/c：群主/成员动作分离（渲染）', () {
    Future<void> pumpZone(WidgetTester tester, int role) async {
      await tester.pumpWidget(
        _wrap(GroupDangerZone(groupId: '880990', role: role, onDirty: () {})),
      );
      await tester.pump();
    }

    testWidgets('群主：转让后退出 + 解散群聊 两条独立动作', (tester) async {
      await pumpZone(tester, 4); // 群主
      expect(find.text(t.group.transferAndLeave), findsOneWidget);
      expect(find.text(t.group.groupDissolve), findsOneWidget);
      expect(find.text(t.group.groupLeave), findsNothing);
    });

    testWidgets('普通成员：只有退出群聊（无解散、无转让）', (tester) async {
      await pumpZone(tester, 1); // 普通成员
      expect(find.text(t.group.groupLeave), findsOneWidget);
      expect(find.text(t.group.transferAndLeave), findsNothing);
      expect(find.text(t.group.groupDissolve), findsNothing);
    });
  });

  test('J19.d：清空仅删消息，会话行保留可见（不隐藏、不退群）', () async {
    final repo = ConversationRepo();
    final model = await _seedConversation(repo);
    final service = GroupDetailService();

    // 清空前会话可见。
    final before = await repo.findByPeerId('C2G', '880990');
    expect(before, isNotNull);
    expect(before!.isShow, 1);

    final cid = await service.cleanMessageByPeerId('C2G', '880990');
    expect(cid, greaterThan(0));

    // 清空后：会话入口仍在且可见（仅清本机记录的语义）。
    final after = await repo.findByPeerId('C2G', '880990');
    expect(after, isNotNull, reason: '清空不删除/隐藏会话行（J19.d 入口仍在）');
    expect(after!.isShow, 1, reason: '清空不误隐藏（隐藏是独立动作 J19.e）');
    expect(after.id, model.id);
  });

  group('UX-02 重入世代：撤权后危险区动作收回（渲染出口）', () {
    testWidgets('role 迁移 4→1 收回转让/解散，1→4 重新恢复', (tester) async {
      // provider 角色变化 → 页面以新 role 重建危险区（同一渲染出口）。
      await tester.pumpWidget(
        _wrap(
          const GroupDangerZone(
            groupId: '880990',
            role: 4,
            onDirty: _noopDirty,
          ),
        ),
      );
      await tester.pump();
      expect(find.text(t.group.transferAndLeave), findsOneWidget);
      expect(find.text(t.group.groupDissolve), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          const GroupDangerZone(
            groupId: '880990',
            role: 1,
            onDirty: _noopDirty,
          ),
        ),
      );
      await tester.pump();
      expect(find.text(t.group.transferAndLeave), findsNothing);
      expect(find.text(t.group.groupDissolve), findsNothing);
      expect(find.text(t.group.groupLeave), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          const GroupDangerZone(
            groupId: '880990',
            role: 4,
            onDirty: _noopDirty,
          ),
        ),
      );
      await tester.pump();
      expect(find.text(t.group.transferAndLeave), findsOneWidget);
      expect(find.text(t.group.groupDissolve), findsOneWidget);
    });
  });

  test('UX-02:LOCAL:02 清空旅程终态：预览/时间归零、历史清空、未读重算归零', () async {
    final repo = ConversationRepo();
    final model = await _seedConversation(repo);
    // 已设自定义头像的群不预热成员拼图（产品规则），避免列表重算的
    // 后台 warmup 走网络路径污染纯本地旅程。
    await db.update(
      'conversation',
      {'avatar': 'group-avatar-ref'},
      where: 'id = ?',
      whereArgs: [model.id],
    );
    // 2 条未确认群消息 + 未读/置顶标记 → 清空后必须与「无消息」终态一致。
    for (final autoId in [901, 902]) {
      await db.insert('msg_c2g', {
        MessageRepo.autoId: autoId,
        MessageRepo.id: autoId,
        'msg_type': 'text',
        MessageRepo.from: 8000,
        MessageRepo.to: 995011,
        MessageRepo.conversationUk3: model.uk3,
        'e2ee': '',
        MessageRepo.payload: '{"text":"m-$autoId"}',
        MessageRepo.createdAt: autoId,
        MessageRepo.topicId: 0,
        MessageRepo.status: IMBoyMessageStatus.delivered,
        MessageRepo.isAuthor: 0,
        MessageRepo.type: 'C2G',
        'action': '',
      });
    }
    await db.update(
      'conversation',
      {
        'unread_num': 2,
        'mention_unread': 1,
        'subtitle': '待清空预览',
        'last_time': 1750000009000,
      },
      where: 'id = ?',
      whereArgs: [model.id],
    );

    // 危险区确认链路：cleanMessageByPeerId + 随后的列表重算（与
    // GroupDangerZone._confirmClearChat 的 cid>0 分支同链）。
    final cid = await GroupDetailService().cleanMessageByPeerId(
      'C2G',
      '880990',
    );
    expect(cid, greaterThan(0));
    final container = ProviderContainer(
      overrides: [
        conversationProvider.overrideWith(() => ConversationNotifier()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(conversationProvider, (_, _) {});
    await container.read(conversationProvider.notifier).conversationsList();

    final after = await repo.findByPeerId('C2G', '880990');
    expect(after, isNotNull, reason: '清空旅程保留会话入口（J19.d）');
    expect(after!.isShow, 1);
    expect(after.subtitle, '', reason: '预览必须与清空后的权威终态一致');
    expect(after.lastTime, 0, reason: '清空后会话不再飘在列表顶部');
    expect(after.lastMsgId, '');
    expect(after.unreadNum, 0, reason: '未读必须随消息终态重算归零');
    expect(after.mentionUnread, 0, reason: '@ 未读同步归零');
    expect(
      await db.query(
        'msg_c2g',
        where: 'conversation_uk3 = ?',
        whereArgs: [model.uk3],
      ),
      isEmpty,
      reason: '历史消息必须真实清空',
    );
    expect(
      container.read(conversationProvider).conversationRemind[model.uk3],
      0,
      reason: '内存未读映射与持久终态一致',
    );
  });
}

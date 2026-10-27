/// W10（F17/J19）：群危险区四后果分离的定向向量。
///
/// J19.a/b/c（渲染层）：群主看到「转让后退出」+「解散群聊」两条独立
/// 动作；普通成员只有「退出群聊」——不再把解散伪装成唯一出口。
/// J19.d（服务层）：清空 = 仅清本机记录——消息删除但会话行保留可见
/// （is_show 不变、行仍在），不误隐藏、不退群。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_detail/group_detail_service.dart';
import 'package:imboy/page/group/group_detail/widgets/group_danger_zone.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

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
}

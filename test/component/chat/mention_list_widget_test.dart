import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/chat/mention_list_widget.dart';
import 'package:imboy/component/chat/mention_model.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';

/// MentionListWidget @ 候选下拉列表 widget 契约测试
///
/// 覆盖：
///   - 空候选 + 不显示 @所有人 → SizedBox.shrink（不渲染容器）
///   - 单候选 / 多候选渲染（displayName + 默认首字母头像）
///   - keyword 过滤逻辑（小写 contains）
///   - showAllMention + isAdmin + keyword 匹配 "所有人" → 渲染 @所有人 选项
///   - showAllMention + isAdmin=false → 不渲染 @所有人
///   - tap 候选项触发 onSelected
///   - role=3 (admin) / role=4 (owner) 显示角色 badge
Future<void> _pump(
  WidgetTester tester, {
  required List<MentionCandidate> candidates,
  String keyword = '',
  bool showAllMention = false,
  bool isAdmin = false,
  void Function(MentionCandidate)? onSelected,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: MentionListWidget(
            candidates: candidates,
            keyword: keyword,
            showAllMention: showAllMention,
            isAdmin: isAdmin,
            onSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

MentionCandidate _member({
  String userId = 'u_1',
  String displayName = 'Alice',
  String avatar = '',
  int role = 1,
}) {
  return MentionCandidate(
    userId: userId,
    displayName: displayName,
    avatar: avatar,
    role: role,
  );
}

void main() {
  setUpAll(() {
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
  });

  tearDownAll(() {
    IMBoyCacheManager.debugLogEnabled = true;
  });

  group('MentionListWidget empty state', () {
    testWidgets('空候选 + 不显示 @所有人 → SizedBox.shrink（无 ListView）',
        (tester) async {
      await _pump(tester, candidates: const []);

      // ListView 不应渲染（隐藏态走 SizedBox.shrink）
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('keyword 过滤后无匹配 → SizedBox.shrink', (tester) async {
      await _pump(
        tester,
        candidates: [_member(displayName: 'Alice')],
        keyword: 'xyz', // 不匹配
      );
      expect(find.byType(ListView), findsNothing);
    });
  });

  group('MentionListWidget candidate rendering', () {
    testWidgets('单候选 → 渲染 displayName + 默认首字母头像', (tester) async {
      await _pump(
        tester,
        candidates: [_member(displayName: 'Alice', avatar: '')],
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      // 默认头像首字母 'A'（avatar 空走 _buildDefaultAvatar）
      expect(find.text('A'), findsOneWidget);
      // @ 角标
      expect(find.text('@'), findsOneWidget);
    });

    testWidgets('多候选 → 全部渲染', (tester) async {
      await _pump(
        tester,
        candidates: [
          _member(userId: 'u1', displayName: 'Alice'),
          _member(userId: 'u2', displayName: 'Bob'),
          _member(userId: 'u3', displayName: 'Charlie'),
        ],
      );

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
    });

    testWidgets('keyword 过滤（小写 contains）→ 仅匹配项渲染', (tester) async {
      await _pump(
        tester,
        candidates: [
          _member(userId: 'u1', displayName: 'Alice'),
          _member(userId: 'u2', displayName: 'Bob'),
          _member(userId: 'u3', displayName: 'Bobby'),
        ],
        keyword: 'bob',
      );

      // 大小写不敏感：Bob 和 Bobby 匹配
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Bobby'), findsOneWidget);
      // Alice 不匹配
      expect(find.text('Alice'), findsNothing);
    });
  });

  group('MentionListWidget @所有人 option', () {
    testWidgets('showAllMention=true + isAdmin=true + keyword 空 → '
        '渲染 @所有人 选项 + hint', (tester) async {
      await _pump(
        tester,
        candidates: [_member(displayName: 'Alice')],
        showAllMention: true,
        isAdmin: true,
      );

      // i18n / MentionStrings.mentionAll = "所有人"
      expect(find.text('所有人'), findsOneWidget);
      // hint = "通知所有群成员"
      expect(find.text('通知所有群成员'), findsOneWidget);
      // group icon (Icons.group)
      expect(find.byIcon(Icons.group), findsOneWidget);
    });

    testWidgets('showAllMention=true + isAdmin=false → 不渲染 @所有人',
        (tester) async {
      await _pump(
        tester,
        candidates: [_member(displayName: 'Alice')],
        showAllMention: true,
        isAdmin: false,
      );

      expect(find.text('所有人'), findsNothing);
      expect(find.byIcon(Icons.group), findsNothing);
    });

    testWidgets('keyword="所" → @所有人 仍匹配（包含搜索）', (tester) async {
      await _pump(
        tester,
        candidates: const [],
        showAllMention: true,
        isAdmin: true,
        keyword: '所',
      );

      expect(find.text('所有人'), findsOneWidget);
    });

    testWidgets('keyword="xyz" → @所有人 不匹配', (tester) async {
      await _pump(
        tester,
        candidates: const [],
        showAllMention: true,
        isAdmin: true,
        keyword: 'xyz',
      );

      expect(find.text('所有人'), findsNothing);
      // 也没普通候选 → 整体 shrink
      expect(find.byType(ListView), findsNothing);
    });
  });

  group('MentionListWidget interaction', () {
    testWidgets('tap 候选项 → 触发 onSelected 并回传该 MentionCandidate',
        (tester) async {
      MentionCandidate? selected;
      final alice = _member(userId: 'u1', displayName: 'Alice');
      final bob = _member(userId: 'u2', displayName: 'Bob');

      await _pump(
        tester,
        candidates: [alice, bob],
        onSelected: (c) => selected = c,
      );

      await tester.tap(find.text('Bob'));
      await tester.pump();

      expect(selected?.userId, 'u2');
      expect(selected?.displayName, 'Bob');
    });

    testWidgets('tap @所有人 → onSelected 回传 isAllMention=true', (tester) async {
      MentionCandidate? selected;

      await _pump(
        tester,
        candidates: const [],
        showAllMention: true,
        isAdmin: true,
        onSelected: (c) => selected = c,
      );

      await tester.tap(find.text('所有人'));
      await tester.pump();

      expect(selected?.isAllMention, isTrue);
      expect(selected?.userId, 'all');
    });
  });

  group('MentionListWidget role badge', () {
    testWidgets('role=4 (群主) → 显示 群主 badge 文字', (tester) async {
      await _pump(
        tester,
        candidates: [_member(userId: 'u1', displayName: 'Alice', role: 4)],
      );

      // groupRoleLabel(4) = t.groupOwner = "群主"（zhCn）
      expect(find.text('群主'), findsOneWidget);
    });

    testWidgets('role=3 (管理员) → 显示 管理员 badge 文字', (tester) async {
      await _pump(
        tester,
        candidates: [_member(userId: 'u1', displayName: 'Bob', role: 3)],
      );

      // groupRoleLabel(3) = t.groupAdmin = "管理员"
      expect(find.text('管理员'), findsOneWidget);
    });

    testWidgets('role=1 (普通成员) → 不显示角色 badge', (tester) async {
      await _pump(
        tester,
        candidates: [_member(userId: 'u1', displayName: 'Charlie', role: 1)],
      );

      expect(find.text('群主'), findsNothing);
      expect(find.text('管理员'), findsNothing);
      expect(find.text('嘉宾'), findsNothing);
    });
  });
}

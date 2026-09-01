import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octo_image/octo_image.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/avatar_group.dart';
import 'package:imboy/page/group/group_avatar_cache.dart';

/// 群头像渲染契约（计划 W2 空头像占位 + W3 同步渲染优先，2026-08-31）。
///
/// - 空串 URL 保留格子（拼图顺序由 user_id 决定），走灰色 Container，
///   不进 OctoImage 网络/解码路径；
/// - SmartGroupAvatar 缓存命中时首帧同步渲染真图（无 FutureBuilder），
///   未命中时异步兜底且重挂载不放大 loader 调用。
void main() {
  // SmartGroupAvatar 走全局单例缓存，测试间必须清干净
  setUp(() {
    GroupAvatarMemberCache.instance.invalidateAll();
  });
  tearDown(() {
    GroupAvatarMemberCache.instance.invalidateAll();
  });

  group('GroupAvatar 空头像格子占位', () {
    testWidgets('空串占灰格，不进 OctoImage；非空 URL 正常出图位', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroupAvatar(
              memberAvatars: ['def_avatar.png#u1', '', 'def_avatar.png#u2'],
              size: 50,
            ),
          ),
        ),
      );

      // 2-4 人布局：3 个 tile，其中空串占位为灰底+人形剪影，剩 2 个 OctoImage
      expect(find.byType(OctoImage), findsNWidgets(2));
      expect(find.byIcon(CupertinoIcons.person_2), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5-9 宫格布局同样保留空位格数', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroupAvatar(
              memberAvatars: [
                'def_avatar.png#a',
                '',
                'def_avatar.png#b',
                'def_avatar.png#c',
                'def_avatar.png#d',
              ],
              size: 50,
            ),
          ),
        ),
      );

      expect(find.byType(OctoImage), findsNWidgets(4));
      expect(find.byIcon(CupertinoIcons.person_2), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('全空列表走默认群图（person_2 图标），不渲染灰格拼图', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GroupAvatar(memberAvatars: [], size: 50)),
        ),
      );

      expect(find.byIcon(CupertinoIcons.person_2), findsOneWidget);
      expect(find.byType(OctoImage), findsNothing);
    });
  });

  group('SmartGroupAvatar 同步渲染优先', () {
    testWidgets('缓存命中：首帧即 GroupAvatar 真图，无 FutureBuilder 闪变', (tester) async {
      await GroupAvatarMemberCache.instance.load(
        'g1',
        (gid) async => ['def_avatar.png#a', 'def_avatar.png#b'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SmartGroupAvatar(groupId: 'g1', size: 50)),
        ),
      );

      expect(
        find.byWidgetPredicate((w) => w is FutureBuilder<dynamic>),
        findsNothing,
        reason: '同步路径不应有 FutureBuilder，否则首帧闪变回归',
      );
      final ga = tester.widget<GroupAvatar>(find.byType(GroupAvatar));
      expect(ga.memberAvatars, ['def_avatar.png#a', 'def_avatar.png#b']);
    });

    testWidgets('群自定义头像直出单图，不加载成员、不查缓存（产品规则）', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SmartGroupAvatar(
              groupId: 'g2',
              avatar: 'def_avatar.png#custom.png',
              size: 50,
            ),
          ),
        ),
      );

      // 单图路径：GroupAvatar 拿到 avatar 而非 memberAvatars
      final ga = tester.widget<GroupAvatar>(find.byType(GroupAvatar));
      expect(ga.avatar, 'def_avatar.png#custom.png');
      expect(ga.memberAvatars, isEmpty);
      expect(
        find.byWidgetPredicate((w) => w is FutureBuilder<dynamic>),
        findsNothing,
      );
      // 未参与拼图缓存
      expect(GroupAvatarMemberCache.instance.peek('g2'), isNull);
    });

    testWidgets('缓存未命中：FutureBuilder 兜底，loader 只调一次且写入缓存', (tester) async {
      var loaderCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartGroupAvatar(
              groupId: 'g3',
              size: 50,
              avatarLoader: (gid) async {
                loaderCalls++;
                return ['def_avatar.png#x'];
              },
            ),
          ),
        ),
      );
      // 首帧：FutureBuilder 未完成 → 空列表默认图
      expect(
        find.byWidgetPredicate((w) => w is FutureBuilder<dynamic>),
        findsOneWidget,
      );
      expect(loaderCalls, 1);

      await tester.pump();
      final ga = tester.widget<GroupAvatar>(find.byType(GroupAvatar));
      expect(ga.memberAvatars, ['def_avatar.png#x']);

      // 列表滚动重挂载（同 gid 新 State）：命中缓存同步渲染，不再调 loader
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyedSubtree(
              key: const ValueKey('remount'),
              child: SmartGroupAvatar(
                groupId: 'g3',
                size: 50,
                avatarLoader: (gid) async {
                  loaderCalls++;
                  return ['def_avatar.png#x'];
                },
              ),
            ),
          ),
        ),
      );
      expect(loaderCalls, 1, reason: '重挂载必须命中缓存，否则滚动请求风暴回归');
      expect(
        find.byWidgetPredicate((w) => w is FutureBuilder<dynamic>),
        findsNothing,
      );
      expect(GroupAvatarMemberCache.instance.peek('g3'), ['def_avatar.png#x']);
    });

    testWidgets('groupId 变化（widget 复用）时按新 gid 重新加载', (tester) async {
      await GroupAvatarMemberCache.instance.load(
        'g4',
        (gid) async => ['def_avatar.png#g4'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SmartGroupAvatar(
              key: ValueKey('same-state'),
              groupId: 'g4',
              size: 50,
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartGroupAvatar(
              key: const ValueKey('same-state'),
              groupId: 'g5',
              size: 50,
              avatarLoader: (gid) async => ['def_avatar.png#g5'],
            ),
          ),
        ),
      );
      await tester.pump();

      final ga = tester.widget<GroupAvatar>(find.byType(GroupAvatar));
      expect(ga.memberAvatars, ['def_avatar.png#g5']);
    });
  });
}

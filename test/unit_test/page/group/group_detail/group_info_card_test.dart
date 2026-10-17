/// GroupInfoCard 组件回归（ux-plan imboyapp-uiux-v1 T12）。
///
/// spec D4 紧凑化后契约锁定：48 头像（与群列表行统一）、群名、成员数、
/// 简介默认一行折叠/点击展开、整卡 onTap 进编辑、简介点击不触达编辑。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_detail/widgets/group_info_card.dart';
import 'package:imboy/store/model/group_model.dart';

GroupModel _group({
  String title = '产品研发群',
  String introduction = '',
  int memberCount = 23,
}) {
  return GroupModel(
    groupId: 7001,
    type: 2,
    joinLimit: 0,
    contentLimit: 0,
    ownerUid: 1,
    creatorUid: 1,
    memberMax: 500,
    memberCount: memberCount,
    title: title,
    introduction: introduction,
    createdAt: 1700000000,
  );
}

Widget _wrap(Widget child) => TranslationProvider(
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('渲染群名/成员数/编辑箭头，头像 48 与列表行统一', (tester) async {
    await tester.pumpWidget(
      _wrap(GroupInfoCard(group: _group(), onTap: () {})),
    );
    await tester.pump();

    expect(find.text('产品研发群'), findsOneWidget);
    expect(find.text('23 ${t.group.groupMembers}'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chevron_right), findsOneWidget);
    final avatar = tester.widget<SmartGroupAvatar>(
      find.byType(SmartGroupAvatar),
    );
    expect(avatar.size, 48, reason: 'spec D4：头像与群列表行统一为 48');
  });

  testWidgets('简介默认一行折叠，点击展开/再收起，且不触发编辑 onTap', (tester) async {
    var editTaps = 0;
    await tester.pumpWidget(
      _wrap(
        GroupInfoCard(
          group: _group(introduction: '这是一个很长很长的群简介用于折叠展开行为验证'),
          onTap: () => editTaps++,
        ),
      ),
    );
    await tester.pump();

    final introFinder = find.text('这是一个很长很长的群简介用于折叠展开行为验证');
    expect(introFinder, findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chevron_down), findsOneWidget);

    // 点简介展开（不进编辑）
    await tester.tap(introFinder);
    await tester.pump();
    expect(find.byIcon(CupertinoIcons.chevron_up), findsOneWidget);
    expect(editTaps, 0, reason: '简介点击不得触达外层编辑 onTap');

    // 再点收起
    await tester.tap(introFinder);
    await tester.pump();
    expect(find.byIcon(CupertinoIcons.chevron_down), findsOneWidget);
    expect(editTaps, 0);
  });

  testWidgets('点卡片非简介区域进入编辑', (tester) async {
    var editTaps = 0;
    await tester.pumpWidget(
      _wrap(GroupInfoCard(group: _group(), onTap: () => editTaps++)),
    );
    await tester.pump();

    await tester.tap(find.text('产品研发群'));
    await tester.pump();
    expect(editTaps, 1, reason: '群名区域点击 = 整卡编辑入口');
  });

  testWidgets('无名群回退「未命名」，不暴露 groupId（TSID 不进 UI）', (tester) async {
    await tester.pumpWidget(
      _wrap(
        GroupInfoCard(
          group: _group(title: '  '),
          onTap: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text(t.main.unnamed), findsOneWidget);
    expect(find.text('7001'), findsNothing);
  });
}

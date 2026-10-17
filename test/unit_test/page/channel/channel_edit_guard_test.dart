/// 频道编辑页管理权限前置校验（ux-plan imboyapp-uiux-v1 T10 / 0016）。
///
/// 非管理角色（subscriber/none）进入编辑页渲染无权限态且不渲染任何
/// 表单字段；管理角色正常渲染。判定只用已持有的模型（不新增请求）。
/// 0014（delete_channel 死分支删除）由编译级保证：方法与 case 分支
/// 已移除，全仓无引用；0025（订单详情统一页面版）为单行 push，路由
/// 已注册，由频道域回归覆盖。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_edit_page.dart';
import 'package:imboy/store/model/channel_model.dart';

ChannelModel _channel(ChannelUserRole role) {
  final ts = DateTime.fromMillisecondsSinceEpoch(1700000000000);
  return ChannelModel(
    id: 9001,
    name: '测试频道',
    creatorId: 1,
    createdAt: ts,
    updatedAt: ts,
    visibility: 0,
    accessType: 0,
    joinPolicy: 0,
    userRole: role,
    isSubscribed: true,
    description: '描述',
    subscriberCount: 12,
  );
}

Future<void> _pump(WidgetTester tester, ChannelModel channel) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        child: MaterialApp(
          home: ChannelEditPage(
            channelId: channel.id.toString(),
            channel: channel,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('0016：subscriber 进入显示无权限态，不渲染表单', (tester) async {
    await _pump(tester, _channel(ChannelUserRole.subscriber));

    expect(
      find.text(t.common.noPermission),
      findsOneWidget,
      reason: '非管理角色看到无权限态',
    );
    expect(find.byType(TextField), findsNothing, reason: '无权限时不渲染任何表单字段');
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });

  testWidgets('0016：creator 正常渲染编辑表单', (tester) async {
    await _pump(tester, _channel(ChannelUserRole.creator));

    expect(find.text(t.common.noPermission), findsNothing);
    expect(find.text('测试频道'), findsOneWidget, reason: '管理角色看到可编辑表单（预填群名）');
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('0016：admin 正常渲染编辑表单', (tester) async {
    await _pump(tester, _channel(ChannelUserRole.admin));

    expect(find.text(t.common.noPermission), findsNothing);
    expect(find.byType(TextField), findsWidgets);
  });
}

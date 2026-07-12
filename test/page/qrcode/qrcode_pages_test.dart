import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/qrcode/channel_qrcode_page.dart';
import 'package:imboy/page/qrcode/group_qrcode_page.dart';
import 'package:imboy/store/model/group_model.dart';

/// Group/Channel 二维码页面渲染测试。
///
/// 覆盖范围与不可测说明：
/// - 验证页面能以 ProviderScope 无网络/无登录态渲染，QrImageView 存在，
///   标题/占位图标正确，footer 展示"7 天后过期"的日期（页面 exp 计算逻辑
///   通过自身渲染输出验证）。
/// - 二维码 URL 的 tk 签名（md5("${exp}_${solidifiedKey}")）不可从渲染层
///   观测：qr_flutter 4.1.0 的 QrImageView 将 data 存为私有字段 `_data`，
///   无公开 getter，测试无法提取二维码内容字符串。
/// - UserQrCodePage 在 build 中同步读取 UserRepoLocal.to.current
///   （StorageService 单例，测试环境未初始化即抛错），且无 override 注入点，
///   故跳过整页渲染；其 QR 卡片结构与本文件两页一致。
void main() {
  const sevenDaysMs = 7 * 86400 * 1000;

  Widget wrap(Widget page) {
    return TranslationProvider(
      child: ProviderScope(child: MaterialApp(home: page)),
    );
  }

  /// 断言页面 footer 展示了"当前时间 + 7 天"的过期日期。
  /// beforeMs 取自 pump 前，双候选日期规避跨零点竞态。
  void expectSevenDayExpiryDateShown(int beforeMs) {
    String fmt(int ms) =>
        DateFormat('y-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(ms));
    final candidate1 = fmt(beforeMs + sevenDaysMs);
    final candidate2 = fmt(DateTimeHelper.millisecond() + sevenDaysMs);

    final matched =
        find.textContaining(candidate1).evaluate().isNotEmpty ||
        find.textContaining(candidate2).evaluate().isNotEmpty;
    expect(matched, isTrue, reason: '应展示 7 天后过期日期 $candidate1/$candidate2');
  }

  GroupModel buildGroup({int groupId = 100, String title = '测试群'}) {
    return GroupModel(
      groupId: groupId,
      type: 1,
      joinLimit: 1,
      contentLimit: 1,
      userIdSum: 0,
      ownerUid: 1,
      creatorUid: 1,
      memberMax: 100,
      memberCount: 3,
      title: title,
      createdAt: 0,
    );
  }

  group('ChannelQrCodePage', () {
    testWidgets('CQ-1 无网络渲染出二维码与 7 天有效期提示', (tester) async {
      final beforeMs = DateTimeHelper.millisecond();

      await tester.pumpWidget(
        wrap(
          const ChannelQrCodePage(channelData: {'id': 'ch123', 'name': '测试频道'}),
        ),
      );
      await tester.pump();

      expect(find.byType(QrImageView), findsOneWidget);
      expectSevenDayExpiryDateShown(beforeMs);
    });

    testWidgets('CQ-2 显示频道名称', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ChannelQrCodePage(channelData: {'id': 'ch123', 'name': '测试频道'}),
        ),
      );
      await tester.pump();

      expect(find.text('测试频道'), findsOneWidget);
    });

    testWidgets('CQ-3 无头像时显示占位图标', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ChannelQrCodePage(channelData: {'id': 'ch123', 'name': '测试频道'}),
        ),
      );
      await tester.pump();

      expect(
        find.byIcon(CupertinoIcons.antenna_radiowaves_left_right),
        findsOneWidget,
      );
    });
  });

  group('GroupQrCodePage', () {
    testWidgets('GQ-1 无网络渲染出二维码与 7 天有效期提示', (tester) async {
      final beforeMs = DateTimeHelper.millisecond();

      await tester.pumpWidget(wrap(GroupQrCodePage(group: buildGroup())));
      await tester.pump();

      expect(find.byType(QrImageView), findsOneWidget);
      expectSevenDayExpiryDateShown(beforeMs);
    });

    testWidgets('GQ-2 显示群标题', (tester) async {
      await tester.pumpWidget(
        wrap(GroupQrCodePage(group: buildGroup(title: '周末羽毛球'))),
      );
      await tester.pump();

      expect(find.textContaining('周末羽毛球'), findsOneWidget);
    });
  });
}

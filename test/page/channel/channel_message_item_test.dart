// ChannelMessageItem Widget 测试（订阅号内容流卡片，方案二 B2）
//
// 验证「卡片流改造」后的预览化渲染：
// - imageText 卡：标题（首行）与摘要拆分为独立 Text，图片九宫格预览，
//   完整正文不作为单个 Text 内联（点进 B1 阅读页看全文）。
// - text 长文：摘要截断（maxLines）+「阅读全文」提示，而非就地展开。
// - text 短文：无「阅读全文」提示。
//
// 图片 uri 含 `def_avatar.png`，cachedImageProvider 短路为 IconImageProvider
// （同步解码、无网络、无 Timer），测试可 pump() 后同步断言、无 pending timer。
//
// 运行方式 / How to run:
//   flutter test test/page/channel/channel_message_item_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_message_item.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/channel_message_model.dart';

// 摘要截断行数（与 _ChannelMessageItemState._textSummaryMaxLines 保持一致）。
const _summaryMaxLines = 3;

ChannelMessageModel _message({
  required String content,
  required String msgType,
  Map<String, dynamic>? payload,
}) => ChannelMessageModel(
  id: 9001,
  channelId: 1001,
  authorId: 2002,
  authorName: '频道作者',
  content: content,
  msgType: msgType,
  payload: payload,
  createdAt: DateTime(2024, 1, 1),
  viewCount: 42,
);

Widget _wrap(ChannelMessageModel message) => TranslationProvider(
  child: ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [ChannelMessageItem(message: message, channelId: '1001')],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('imageText 卡：标题+摘要拆分、九宫格预览、长正文不内联全文', (tester) async {
    const title = '重磅标题一行';
    final body = '订阅号正文段落。' * 30; // 长摘要
    final content = '$title\n$body';
    await tester.pumpWidget(
      _wrap(
        _message(
          content: content,
          msgType: ChannelMessageType.imageText,
          payload: {
            'images': [
              {'uri': 'cover_a/def_avatar.png'},
              {'uri': 'cover_b/def_avatar.png'},
            ],
          },
        ),
      ),
    );
    await tester.pump();

    // 标题作为独立 Text 加粗展示
    expect(find.text(title), findsOneWidget);
    // 完整正文（标题+换行+正文）不作为单个 Text 内联（已拆分为标题+摘要）
    expect(find.text(content), findsNothing);
    // 图片九宫格预览：2 张图 → 2 个 Image（作者头像无 avatar，走文字占位，不计入）
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('text 长文：摘要截断 + 阅读全文提示（不内联全文）', (tester) async {
    final content = '一段很长的频道正文内容。' * 20; // 远超 120 字符阈值
    await tester.pumpWidget(
      _wrap(_message(content: content, msgType: ChannelMessageType.text)),
    );
    await tester.pump();

    // 正文 Text 被限制为摘要行数（截断而非全展开）
    final truncated = find.byWidgetPredicate(
      (w) => w is Text && w.data == content && w.maxLines == _summaryMaxLines,
    );
    expect(truncated, findsOneWidget);
    // 「阅读全文」提示存在
    expect(find.text(t.channel.readFull), findsOneWidget);
  });

  testWidgets('text 短文：无阅读全文提示', (tester) async {
    await tester.pumpWidget(
      _wrap(_message(content: '短短一句', msgType: ChannelMessageType.text)),
    );
    await tester.pump();

    expect(find.text('短短一句'), findsOneWidget);
    expect(find.text(t.channel.readFull), findsNothing);
  });
}

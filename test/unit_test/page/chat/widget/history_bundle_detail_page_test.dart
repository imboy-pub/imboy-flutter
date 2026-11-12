import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/imboy_cached_image_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/history_bundle_detail_page.dart';

/// W3-I / BND-04：chat_history_bundle 详情页。
///
/// 数据全部来自 bundle 快照（不回查原会话）；多类型 entry 类型安全渲染；
/// 未知 entry 类型 fallback；图片经 IMBoyCachedImageProvider 授权管线
/// （object_key 原样透传，下载边界异步签发；禁止 network 直连）。
void main() {
  // 固定旧时间戳：>7 天 → dateTimeFmt 走完整 'y-MM-dd HH:mm' 分支，
  // 断言可稳定（相对时间分支依赖当前时钟）。
  const sentAt = 1579048200000; // 2020-01-15 03:50 UTC（本地时区渲染）

  Map<String, dynamic> bundleFixture() => <String, dynamic>{
    'bundle_version': 1,
    'title': '产品群',
    'exported_at': 1579134600000,
    'entries': [
      {
        'msg_type': 'text',
        'sender_name': '张三',
        'sent_at': sentAt,
        'payload': {'text': '合并转发第一条'},
      },
      {
        'msg_type': 'quote',
        'sender_name': '李四',
        'sent_at': sentAt,
        'payload': {'text': '我的回复', 'quote_text': '被引用原文'},
      },
      {
        'msg_type': 'image',
        'sender_name': '王五',
        'sent_at': sentAt,
        // 转发器回写后的新引用：Garage object_key 形态（授权由下载边界
        // 异步签发，渲染侧原样透传给 IMBoyCachedImageProvider）
        'payload': {'uri': 'u1/2026/11/img_abc.png', 'name': 'img.png'},
      },
      {
        'msg_type': 'imageMulti',
        'sender_name': '赵六',
        'sent_at': sentAt,
        // 未回写引用：只保留显示字段占位 → 占位图 + 数量角标
        'payload': {'total': 4},
      },
      {
        'msg_type': 'file',
        'sender_name': '钱七',
        'sent_at': sentAt,
        'payload': {'filename': '年报.pdf', 'size': 1536},
      },
      {
        'msg_type': 'location',
        'sender_name': '孙八',
        'sent_at': sentAt,
        'payload': {'title': '北京市朝阳区', 'address': '望京 SOHO'},
      },
      {
        // 未来新增的 entry 类型 → fallback 描述，不崩溃
        'msg_type': 'hologram_card_v9',
        'sender_name': '周九',
        'sent_at': sentAt,
        'payload': {'whatever': '...'},
      },
    ],
  };

  Future<void> pumpPage(
    WidgetTester tester,
    Map<String, dynamic> bundle,
  ) async {
    await LocaleSettings.setLocale(AppLocale.zhCn);
    // 加高视口：ListView.builder 懒构建，保证 7 个 entry 全部 build 出来
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: HistoryBundleDetailPage(bundle: bundle)),
    );
    await tester.pumpAndSettle();
    // 图片走 IMBoyCachedImageProvider（失败重试 3 次、间隔 200/400ms 延时
    // Timer）：推进 fake clock 排空重试链并落地 errorBuilder 帧，避免
    // pending timer 挂测试。
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('头部展示标题、条数与导出时间', (tester) async {
    await pumpPage(tester, bundleFixture());

    expect(find.text('产品群'), findsOneWidget);
    expect(find.textContaining('[聊天记录] 7 条'), findsOneWidget);
    // 导出时间与发送时间都是固定旧时间戳 → 完整日期格式（数字格式与 locale 无关）
    expect(find.textContaining('2020-'), findsNWidgets(8)); // 1 头部 + 7 entry
  });

  testWidgets('多类型 entry 类型安全渲染（text/quote/file/location）', (tester) async {
    await pumpPage(tester, bundleFixture());

    expect(find.text('合并转发第一条'), findsOneWidget);
    expect(find.text('我的回复'), findsOneWidget);
    expect(find.text('被引用原文'), findsOneWidget);
    expect(find.text('年报.pdf（1.5 KB）'), findsOneWidget);
    expect(find.text('北京市朝阳区'), findsOneWidget);
    // 发送者名单
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('李四'), findsOneWidget);
    // entry 行 key
    expect(find.byKey(const Key('history_bundle_entry_0')), findsOneWidget);
    expect(find.byKey(const Key('history_bundle_entry_6')), findsOneWidget);
  });

  testWidgets('图片条目：object_key 经 IMBoyCachedImageProvider 透传（非 network 直连）', (
    tester,
  ) async {
    await pumpPage(tester, bundleFixture());

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    // imageMulti 无 uri → 占位图（Container+Icon），只有 image 条目有 Image
    expect(images, hasLength(1));

    // G2-1 P0 回归锚：禁止 Image.network 直连（viewUrl 对 object_key 返回
    // 无 scheme 相对 Uri，NetworkImage 必然抛错 → 永远占位）
    expect(images.map((i) => i.image).whereType<NetworkImage>(), isEmpty);
    // 解码缩放经 ResizeImage 包裹（等价 cacheWidth），内层必须是授权 provider
    final resized = images
        .map((i) => i.image)
        .whereType<ResizeImage>()
        .toList();
    expect(resized, hasLength(1));
    expect(resized.single.width, 96); // 容器宽 96 × DPR(1.0)
    final inner = resized.single.imageProvider;
    expect(inner, isA<IMBoyCachedImageProvider>());
    // object_key 原样透传（短时 URL 由下载边界异步签发）
    expect((inner as IMBoyCachedImageProvider).url, 'u1/2026/11/img_abc.png');

    // 真实图片 widget 的 ValueKey（G6 设备旅程定位锚，key 名冻结）
    expect(find.byKey(const ValueKey('bundle_detail_thumb_2')), findsOneWidget);

    // imageMulti 占位：sender 行类型小图标 + 96x96 占位图各一个 photo 图标
    expect(
      find.descendant(
        of: find.byKey(const Key('history_bundle_entry_3')),
        matching: find.byIcon(CupertinoIcons.photo),
      ),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('history_bundle_entry_3')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    // 授权管线的加载异常由 errorBuilder 消化，不进测试异常通道
    expect(tester.takeException(), isNull);
  });

  testWidgets('语音条目：秒数用 voiceDurationSeconds 格式化', (tester) async {
    await pumpPage(tester, <String, dynamic>{
      'bundle_version': 1,
      'entries': [
        {
          'msg_type': 'voice',
          'sender_name': '阿声',
          'sent_at': sentAt,
          'payload': {'duration_ms': 2500},
        },
      ],
    });

    expect(find.byIcon(CupertinoIcons.waveform), findsNWidgets(2));
    // 2500ms → 3 秒（G2-5：不再手拼 '$seconds″'）
    expect(find.text(t.chat.voiceDurationSeconds(seconds: 3)), findsOneWidget);
  });

  testWidgets('sender 缺省回退 unknownSender（不再用 bundleTitle）', (tester) async {
    await pumpPage(tester, <String, dynamic>{
      'bundle_version': 1,
      'entries': [
        {
          'msg_type': 'text',
          'sent_at': sentAt,
          'payload': {'text': '匿名发言'},
        },
      ],
    });

    expect(find.text('匿名发言'), findsOneWidget);
    // G2-4：sender 空时展示「未知发送者」；「聊天记录」仅剩导航栏 + 头部两处
    expect(find.text(t.chat.unknownSender), findsOneWidget);
    expect(find.text('聊天记录'), findsNWidgets(2));
  });

  testWidgets('未知 entry 类型 → fallback 描述，不崩溃', (tester) async {
    await pumpPage(tester, bundleFixture());

    expect(find.text('不支持的消息类型'), findsOneWidget);
    // sender 行类型小图标 + fallback 正文图标各一个 question 图标
    expect(
      find.descendant(
        of: find.byKey(const Key('history_bundle_entry_6')),
        matching: find.byIcon(CupertinoIcons.question),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('畸形 bundle（无 entries）也安全渲染', (tester) async {
    await pumpPage(tester, <String, dynamic>{'bundle_version': 1});

    // 导航栏标题 + 头部回退标题各一处
    expect(find.text('聊天记录'), findsNWidgets(2));
    expect(find.textContaining('[聊天记录] 0 条'), findsOneWidget);
    expect(find.byKey(const Key('history_bundle_entry_0')), findsNothing);
  });
}

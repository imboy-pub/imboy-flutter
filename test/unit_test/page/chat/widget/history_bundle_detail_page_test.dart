import 'dart:io';
import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:open_file/open_file.dart';
import 'package:imboy/component/chat/message.dart' show confirmOpenFile;
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/service/e2ee/attachment_open_registry.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:imboy/component/ui/imboy_cached_image_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/history_bundle_detail_page.dart';

/// W3-I / BND-04：chat_history_bundle 详情页。
///
/// 数据全部来自 bundle 快照（不回查原会话）；多类型 entry 类型安全渲染；
/// 未知 entry 类型 fallback；图片经 IMBoyCachedImageProvider 授权管线
/// （object_key 原样透传，下载边界异步签发；禁止 network 直连）。
class _Cache extends Mock implements IMBoyCacheManager {}

void main() {
  setUp(AttachmentOpenRegistry.resetForTest);
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

  testWidgets('S1-L5：顶层 sender_name 渲染「由 <转发者> 转发」来源行；缺省无', (tester) async {
    final withSender = bundleFixture();
    withSender['sender_name'] = '张三';
    await pumpPage(tester, withSender);
    expect(
      find.text(t.chat.bundleForwardedBy(name: '张三')),
      findsOneWidget,
      reason: '合同顶层预留键渲染来源行（S1-L5 来源行）',
    );

    await pumpPage(tester, bundleFixture());
    expect(
      find.text(t.chat.bundleForwardedBy(name: '张三')),
      findsNothing,
      reason: '键省略时无来源行（快照字节形态向后兼容）',
    );
  });

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

  testWidgets('S1-M2 非 object_key uri 一律占位（presigned 伪装/完整 URL 零出网）', (
    tester,
  ) async {
    await pumpPage(tester, <String, dynamic>{
      'bundle_version': 1,
      'entries': [
        {
          // presigned 伪装：isPresignedUrl 形状齐全，若透传 viewUrl 会
          // 直通任意 host（S1-M2 攻击面）
          'msg_type': 'image',
          'sender_name': '攻击者A',
          'sent_at': sentAt,
          'payload': {
            'uri':
                'https://evil.com/t.jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256'
                '&X-Amz-Credential=AKIAFAKE/20261112/us-east-1/s3/aws4_request'
                '&X-Amz-Signature=deadbeef',
          },
        },
        {
          // 非 presigned 完整 URL：viewUrl 会把 s/a 授权参数拼到第三方 host
          'msg_type': 'image',
          'sender_name': '攻击者B',
          'sent_at': sentAt,
          'payload': {'uri': 'https://cdn.example.com/u1/img.png'},
        },
      ],
    });

    // 零出网：不构建任何 Image / 图片 provider（fail-closed 一律占位）
    expect(find.byType(Image), findsNothing);
    // 每条 entry：sender 行类型图标 + 占位图 photo 图标各一 → 共 4 个
    expect(find.byIcon(CupertinoIcons.photo), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('S1-M2/M1-a 遗留全 URL 与畸形串 uri：占位兜底，build 不抛 FormatException', (
    tester,
  ) async {
    await pumpPage(tester, <String, dynamic>{
      'bundle_version': 1,
      'entries': [
        {
          // 遗留 go-fastdfs 全 URL bundle（老客户端历史消息）：S1-M2
          // fail-closed 占位，不走 viewUrl（legacy 分支行为回归锚）
          'msg_type': 'image',
          'sender_name': '老消息',
          'sent_at': sentAt,
          'payload': {
            'uri': 'https://i.imboy.pub/file_1730000000_abcdef/y2.png',
          },
        },
        {
          // 畸形串：Uri.parse('http://[') 会抛 FormatException——闸必须
          // 在任何解析前拦截，build 零异常（M1-a 白屏回归锚）
          'msg_type': 'image',
          'sender_name': '畸形',
          'sent_at': sentAt,
          'payload': {'uri': 'http://['},
        },
      ],
    });

    // 两条均占位：无 Image widget、无任何出网 provider
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(CupertinoIcons.photo), findsNWidgets(4));
    // 畸形串未把 FormatException 冒泡进测试异常通道
    expect(tester.takeException(), isNull);
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
  Map<String, dynamic> attachment(String key) {
    final sealed = AttachmentEncryptor.seal(
      plaintext: Uint8List.fromList([1, 2, 3]),
      bindingHash: Uint8List(32),
      attachmentId: 'test-file',
      objectKey: key,
      mime: 'application/octet-stream',
      name: 'test.bin',
      contentKey: AttachmentEncryptor.randomContentKey(),
      baseNonce: AttachmentEncryptor.randomBaseNonce(),
    );
    return {
      'uri': key,
      AttachmentSealPolicy.descriptorPayloadKey: sealed.descriptor.toMap(),
    };
  }

  testWidgets('多图从images取首图与实际数量并可打开图库', (tester) async {
    await pumpPage(tester, {
      'entries': [
        {
          'msg_type': 'imageMulti',
          'payload': {
            'images': [
              {'uri': 'u1/a.png'},
              {'uri': 'u1/b.png'},
            ],
            'total': 99,
          },
        },
      ],
    });
    final thumb = tester.widget<Image>(
      find.byKey(const ValueKey('bundle_detail_thumb_0')),
    );
    expect(
      ((thumb.image as ResizeImage).imageProvider as IMBoyCachedImageProvider)
          .url,
      'u1/a.png',
    );
    await tester.tap(find.byKey(const ValueKey('bundle_detail_image_0')));
    await tester.pumpAndSettle();
    expect(find.text(t.common.operationFailedAgainLater), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(PhotoViewGallery), findsOneWidget);
    expect(find.byType(HistoryBundleDetailPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('图库可显示正常已解码图片并返回详情', (tester) async {
    final image = (await tester.runAsync(createTestImage))!;
    final provider = IMBoyCachedImageProvider('u1/decoded.png', const {});
    PaintingBinding.instance.imageCache.putIfAbsent(
      provider,
      () => OneFrameImageStreamCompleter(
        Future.value(ImageInfo(image: image.clone())),
      ),
    );
    addTearDown(PaintingBinding.instance.imageCache.clear);
    await pumpPage(tester, {
      'entries': [
        {
          'msg_type': 'image',
          'payload': {'uri': 'u1/decoded.png'},
        },
      ],
    });
    await tester.tap(find.byKey(const ValueKey('bundle_detail_image_0')));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewGallery), findsOneWidget);
    expect(find.text(t.common.operationFailedAgainLater), findsNothing);
    expect(find.byType(RawImage), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewGallery), findsNothing);
  });

  testWidgets('加密图片缺少登记、描述损坏或uri不符均无下载provider', (tester) async {
    final payload = attachment('u1/secret.png');
    for (final value in [
      payload,
      {...payload, AttachmentSealPolicy.descriptorPayloadKey: 42},
    ]) {
      await pumpPage(tester, {
        'entries': [
          {'msg_type': 'image', 'payload': value},
        ],
      });
      expect(find.byType(Image), findsNothing);
      expect(find.byKey(const ValueKey('bundle_detail_image_0')), findsNothing);
    }
    AttachmentOpenRegistry.registerFromMessage(
      payload: payload,
      messageId: 'bundle',
      chatType: 'C2C',
      fromUid: '1',
      toUid: '2',
    );
    await pumpPage(tester, {
      'entries': [
        {
          'msg_type': 'image',
          'payload': {...payload, 'uri': 'u1/other.png'},
        },
      ],
    });
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('文件按钮读屏标签唯一且保留点击动作', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpPage(tester, {
        'entries': [
          {
            'msg_type': 'file',
            'payload': {'uri': 'u1/report.pdf', 'name': 'report.pdf'},
          },
        ],
      });
      final button = find.byKey(const ValueKey('bundle_detail_file_0'));
      expect(button, findsOneWidget);
      final data = tester
          .getSemantics(find.bySemanticsLabel('report.pdf'))
          .getSemanticsData();
      expect(data.label, 'report.pdf');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(find.bySemanticsLabel('report.pdf'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('加密文件未登记或descriptor非法、引用不符时不可打开', (tester) async {
    final payload = attachment('u1/a.bin');
    Future<void> check(Map<String, dynamic> value) async {
      await pumpPage(tester, {
        'entries': [
          {'msg_type': 'file', 'payload': value},
        ],
      });
      expect(find.byKey(const ValueKey('bundle_detail_file_0')), findsNothing);
    }

    await check(payload);
    await check({...payload, AttachmentSealPolicy.descriptorPayloadKey: null});
    await check({
      ...payload,
      AttachmentSealPolicy.descriptorPayloadKey: {'bad': true},
    });
    AttachmentOpenRegistry.registerFromMessage(
      payload: payload,
      messageId: 'bundle',
      chatType: 'C2C',
      fromUid: '1',
      toUid: '2',
    );
    await check({...payload, 'uri': 'u1/other.bin'});
    await pumpPage(tester, {
      'entries': [
        {'msg_type': 'file', 'payload': payload},
      ],
    });
    await tester.tap(find.byKey(const ValueKey('bundle_detail_file_0')));
    await tester.pumpAndSettle();
    expect(find.text(t.chat.sureOpenTheFile), findsOneWidget);
    await tester.tap(find.text(t.common.buttonCancel));
    await tester.pumpAndSettle();
    expect(find.text(t.chat.sureOpenTheFile), findsNothing);
  });

  for (final failure in [
    'cancel',
    'download',
    'open',
    'success',
    'clear-before',
    'clear-during',
  ]) {
    testWidgets('文件确认边界：$failure', (tester) async {
      final cache = _Cache();
      var opens = 0;
      var available = true;
      when(() => cache.getSingleFile('u1/test.bin', validateImageData: false))
          .thenAnswer((_) async {
            if (failure == 'download') {
              throw const FileSystemException('private URL');
            }
            if (failure == 'clear-during') available = false;
            return File('/synthetic/test.bin');
          });
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => confirmOpenFile(
                context,
                'u1/test.bin',
                cacheManager: cache,
                canOpen: () => available,
                openFile: (path) async {
                  opens++;
                  expect(path, '/synthetic/test.bin');
                  return OpenResult(
                    type: failure == 'open'
                        ? ResultType.error
                        : ResultType.done,
                  );
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      if (failure == 'clear-before') available = false;
      await tester.tap(
        find.text(
          failure == 'cancel' ? t.common.buttonCancel : t.common.buttonConfirm,
        ),
      );
      await tester.pumpAndSettle();
      if (failure == 'cancel' || failure == 'clear-before') {
        verifyNever(
          () => cache.getSingleFile(
            any(),
            validateImageData: any(named: 'validateImageData'),
          ),
        );
      } else {
        verify(
          () => cache.getSingleFile('u1/test.bin', validateImageData: false),
        ).called(1);
      }
      expect(opens, failure == 'open' || failure == 'success' ? 1 : 0);
      expect(
        find.text(t.common.operationFailedAgainLater),
        failure == 'download' ||
                failure == 'open' ||
                failure.startsWith('clear-')
            ? findsOneWidget
            : findsNothing,
      );
      expect(find.textContaining('private URL'), findsNothing);
    });
  }
}

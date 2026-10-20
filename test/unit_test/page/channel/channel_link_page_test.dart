import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_link_page.dart';
import 'package:imboy/page/qrcode/channel_qrcode_page.dart';
import 'package:imboy/store/model/channel_model.dart';

void main() {
  testWidgets('链接身份区区分个人公开频道与企业内部频道', (tester) async {
    for (final scope in ['personal', 'workspace']) {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: ChannelLinkPage(
              channel: ChannelModel(
                id: 42,
                scope: scope,
                name: '频道名称',
                creatorId: 7,
                visibility: scope == 'personal' ? 0 : 1,
                accessType: 0,
                joinPolicy: scope == 'personal' ? 0 : 1,
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final expected = scope == 'workspace'
          ? t.channel.enterpriseChannelLabel
          : '${t.channel.personalChannelLabel} · ${t.channel.typePublic}';
      expect(find.text(expected), findsOneWidget);
    }
  });

  testWidgets('链接页在窄屏、大字体和暗色下保留完整操作入口', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: ChannelLinkPage(
              channel: ChannelModel(
                id: 42,
                name: '一个较长的频道名称用于检验排版',
                creatorId: 7,
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(t.channel.qrcode),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('整数频道 ID 的二维码可在窄屏大字体下滚动查看', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const ChannelQrCodePage(
                channelData: {'id': 42, 'name': '测试频道'},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(t.common.saveQrCode), 150);
    expect(tester.takeException(), isNull);
  });
}

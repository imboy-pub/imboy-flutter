import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/resource_entry_tile.dart';

import '../../../uiux/support/golden_font_loader.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_oa/presentation/enterprise_workbench_page.dart';

void main() {
  testWidgets('resource title and subtitle preserve the inherited font', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultTextStyle(
            style: const TextStyle(fontFamily: 'ResourceTestFont'),
            child: ResourceEntryTile(
              title: '项目 Project',
              subtitle: '客户会话 Queue',
              icon: CupertinoIcons.folder,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    for (final label in ['项目 Project', '客户会话 Queue']) {
      final richText = tester.widget<RichText>(
        find.descendant(of: find.text(label), matching: find.byType(RichText)),
      );
      expect(richText.text.style?.fontFamily, 'ResourceTestFont');
    }
  });

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (const String.fromEnvironment('UIUX_PREVIEW').isNotEmpty) {
      final resolution = resolveGoldenFont();
      expect(resolution.status, GoldenFontStatus.ok, reason: resolution.reason);
      await loadGoldenFont(resolution);
    }
  });
  testWidgets(
    'workbench entries align icons, titles and arrows with and without subtitles',
    (tester) async {
      tester.view.physicalSize = const Size(420, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      var taps = 0;
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            theme: const String.fromEnvironment('UIUX_PREVIEW').isNotEmpty
                ? applyGoldenFont(ThemeData.light())
                : ThemeData.light(),
            home: Scaffold(
              backgroundColor: CupertinoColors.systemGroupedBackground,
              body: RepaintBoundary(
                key: boundary,
                child: ColoredBox(
                  color: CupertinoColors.systemGroupedBackground,
                  child: EnterpriseWorkbenchPage(
                    entries: const [],
                    accountKey: 'preview',
                    organizationId: 'preview',
                    resourceEntries: [
                      ResourceEntryTile(
                        title: '客服工作台',
                        subtitle: '接单并处理客户会话',
                        icon: CupertinoIcons.chat_bubble_2,
                        onTap: () => taps++,
                      ),
                      ResourceEntryTile(
                        title: '群聊',
                        icon: CupertinoIcons.person_2,
                        onTap: () => taps++,
                      ),
                      ResourceEntryTile(
                        title: '频道',
                        icon: CupertinoIcons.speaker_2,
                        onTap: () => taps++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final titles = ['客服工作台', '群聊', '频道'];
      final positions = titles
          .map((text) => tester.getTopLeft(find.text(text)).dx)
          .toSet();
      expect(positions, hasLength(1));
      final arrows = find.byIcon(CupertinoIcons.chevron_right);
      expect(arrows, findsNWidgets(4));
      final rightEdges = {
        for (var i = 0; i < arrows.evaluate().length; i++)
          tester.getTopRight(arrows.at(i)).dx,
      };
      expect(rightEdges, hasLength(1));
      await tester.tap(find.text('群聊'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
      const destination = String.fromEnvironment('UIUX_PREVIEW');
      if (destination.isNotEmpty) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(destination).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );

  testWidgets(
    'resource rows wrap at large text size without clipping or losing action',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: ResourceEntryTile(
                title: '企业协作与工作区资源',
                subtitle: '查看我有权访问的资源',
                icon: CupertinoIcons.square_grid_2x2,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ResourceEntryTile)).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.text('企业协作与工作区资源'));
      expect(tapped, isTrue);
    },
  );
}

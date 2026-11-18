@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/web_shell/web_attachment_input.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _File extends PlatformFile {
  _File(this.name) : bytes = Uint8List.fromList([1, 2, 3]);
  @override
  final String name;
  final Uint8List bytes;
  @override
  Uri get uri => Uri.file('/synthetic/$name');
  @override
  int? lengthSync() => bytes.length;
  @override
  Future<int?> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() =>
      Stream<Uint8List>.fromIterable([bytes]);
  @override
  XFile get xFile => XFile.fromData(bytes, name: name, path: uri.toString());
}

final class _Picker extends FilePickerPlatform {
  Future<List<PlatformFile>>? result;
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    String? fileName,
    bool withData = true,
    bool withReadStream = false,
    bool lockParentWindow = false,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) => result ?? Future.value(const []);
}

/// A11Y-04（<390 视口 × huge 字号）：附件待选区布局回归。
///
/// 缺陷背景（runs/reverify-jny02-20261116/a11y04-corrective/
/// fixup-combo-390/320-semantics.json）：待选列表默认 cacheExtent=250px，
/// 滚出窗口的行语义节点仍留在 DOM（390×667×huge 第 4/5 个「移出」钮
/// rect y=629/685>667；320×568 第 4/5 个 y=530/586>568），初次渲染
/// 不可达即被探针判 FAIL。修复：窗口高度随视口自适应 + cacheExtent=0
/// ——语义只覆盖窗口内行，滚出窗口的行靠内滚触达。
void main() {
  late FilePickerPlatform original;
  late _Picker picker;
  late FocusNode focus;
  late GlobalKey region;
  var current = true;
  final pick = find.byKey(const ValueKey('web-attachment-file'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '900001'});
    await StorageService.init();
    original = FilePickerPlatform.instance;
    picker = _Picker();
    FilePickerPlatform.instance = picker;
    focus = FocusNode();
    region = GlobalKey();
    current = true;
  });

  tearDown(() {
    FilePickerPlatform.instance = original;
    focus.dispose();
  });

  Future<void> pumpComposer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: ThemeData(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          home: Scaffold(
            body: Container(
              key: region,
              child: WebAttachmentInput(
                key: const ValueKey('attachment-composer'),
                selection: const ChatSelection(
                  peerId: '990001',
                  chatType: 'C2C',
                ),
                currentUserId: '900001',
                isCurrent: () => current,
                inputFocus: focus,
                regionKey: region,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> stageFiveFiles(WidgetTester tester) async {
    picker.result = Future.value([
      for (var i = 1; i <= 5; i++) _File('a11y04-$i.bin'),
    ]);
    await tester.tap(pick);
    await tester.pumpAndSettle();
    // cacheExtent=0 下窗口外的行不构建（正解）：断言窗口内行已出现 + 汇总行可见。
    expect(find.textContaining(t.main.selected), findsOneWidget);
    expect(find.byTooltip(t.common.buttonRemove), findsAtLeastNWidgets(1));
  }

  testWidgets('窗口内行语义 rect 全部落在视口内，滚出行不再泄漏出视口', (tester) async {
    await pumpComposer(tester);
    await stageFiveFiles(tester);

    // 初次渲染：只有窗口内的行参与语义（cacheExtent=0，滚出行不构建）。
    final visibleRemoves = find.byTooltip(t.common.buttonRemove);
    final initialCount = visibleRemoves.evaluate().length;
    expect(
      initialCount,
      inInclusiveRange(2, 3),
      reason: '320×568×huge 下窗口约两行半',
    );

    // 每个已构建行的「移出」语义 rect 必须在 320×568 视口内。
    for (final node in visibleRemoves.evaluate()) {
      final rect = tester.getRect(find.byWidget(node.widget));
      expect(
        rect.bottom <= 568 && rect.top >= 0,
        isTrue,
        reason: 'remove 钮 rect $rect 不得越出视口（fixup-combo-320 缺陷回归）',
      );
    }
  });

  testWidgets('滚出窗口的行靠内滚逐行触达，5 行依次可达且 rect 不越窗口底缘', (tester) async {
    await pumpComposer(tester);
    await stageFiveFiles(tester);

    // cacheExtent=0：任一时刻窗口内最多 ~3 行；沿滚动全程收集曾出现的行名，
    // 5 行都必须在某滚动位置可达（fixup-combo-320 第 4/5 行不可达的对面）。
    final reachedNames = <String>{};
    final windowBottom = tester
        .getRect(
          find.byWidgetPredicate(
            (widget) =>
                widget is ConstrainedBox &&
                widget.constraints.maxHeight < double.infinity,
          ),
        )
        .bottom;
    for (var scroll = 0; scroll < 8; scroll++) {
      for (final element in find.byTooltip(t.common.buttonRemove).evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(
          rect.top,
          lessThanOrEqualTo(windowBottom - 1),
          reason: 'remove 钮 rect $rect 顶缘须在窗口内（fixup-combo 缺陷=整钮 y 完全越出视口）',
        );
        final rowText = tester
            .widget<Text>(
              find
                  .descendant(
                    of: find.ancestor(
                      of: find.byWidget(element.widget),
                      matching: find.byType(Row),
                    ),
                    matching: find.byWidgetPredicate(
                      (widget) => widget is Text && widget.data != null,
                    ),
                  )
                  .first,
            )
            .data!;
        reachedNames.add(rowText.split(' · ').first);
      }
      await tester.drag(find.byType(ListView), const Offset(0, -80));
      await tester.pumpAndSettle();
    }
    expect(
      reachedNames,
      containsAll([
        'a11y04-1.bin',
        'a11y04-2.bin',
        'a11y04-3.bin',
        'a11y04-4.bin',
        'a11y04-5.bin',
      ]),
      reason: '内滚全程 5 行的移出钮全部触达',
    );
  });

  testWidgets('窗口高度随视口自适应（cap=min(3 行, 视口 30%)，下限 2 行触达目标）', (tester) async {
    await pumpComposer(tester);
    await stageFiveFiles(tester);

    final box = tester.widget<ConstrainedBox>(
      find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox &&
            widget.constraints.maxHeight < double.infinity,
      ),
    );
    final expectedCap = 568 * 0.3; // 170.4 → min(144, 170.4) = 144
    expect(box.constraints.maxHeight, lessThanOrEqualTo(expectedCap));
    expect(box.constraints.maxHeight, greaterThanOrEqualTo(96.0));
  });
}

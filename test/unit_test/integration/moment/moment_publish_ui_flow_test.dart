/// 朋友圈发布页（MomentCreatePage）真实 widget 测试。
///
/// ## 为什么整份重写
///
/// 旧版 580 行、11 个 testWidgets + 20 个 test，其中：
///
/// - **7 个 testWidgets 长期失败**：断言的是 `TextButton`、
///   `DropdownButtonFormField<int>`、`Icons.add_photo_alternate_outlined`、
///   `maxLines == 6`——页面早已改成 Cupertino 风格（`CupertinoButton`、
///   可见范围走 ActionSheet、`CupertinoIcons.add`、`maxLines: 10`）。
/// - **大半 test 是伪覆盖**：在测试体内自建 `List`/`bool` 再断言 Dart 自身
///   行为，完全没触碰生产代码。例如「media item can be removed」建个本地
///   List 调 `removeAt` 然后断言长度变了；「allow comment default is true」
///   写 `bool x = true; expect(x, isTrue)`。UID 解析更是在文件底部**本地
///   复刻**了一份 `_parseUidList`，生产的 `parseMomentUidList` 从未被调用。
///
/// 伪覆盖比没有覆盖更糟：它让「31 个用例」的数字看起来很安全。
///
/// ## 本文件的覆盖范围
///
/// 1. 真实渲染契约（按当前 Cupertino 实现断言）
/// 2. 生产纯函数 `parseMomentUidList` 的真实行为
/// 3. 两个已修 bug 的回归保护（草稿恢复丢图 / 退出提醒对纯文字失效）
///
/// 媒体上传的逐项状态、9 张上限、删除等已由
/// `test/unit_test/component/upload/batch_upload_controller_test.dart` 真实覆盖，
/// 不在此处重复造伪测试。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/component/ui/common_bar.dart' show GlassBackButton;
import 'package:imboy/component/ui/detail_settings_tile.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/moment/moment_create_page.dart';
import 'package:imboy/page/moment/moment_interactions.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/app_colors.dart';

const String _uid = 'tsid_moment_tester';

Future<void> _pumpPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  final loading = AppLoading.init();
  await tester.pumpWidget(
    TranslationProvider(
      // 恢复草稿会弹 AppLoading toast，未挂 builder 时 EasyLoading 会断言
      // 'overlayEntry != null'。走项目 facade AppLoading.init()，不直接
      // import flutter_easyloading（边界门禁只允许 app_loading.dart 依赖它）。
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const MomentCreatePage(),
        builder: (context, child) => loading(
          context,
          MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 拆掉 widget 树并把 pending 定时器跑完（页面内有上传/定位相关异步）。
/// 取页面 PopScope 的 canPop。用谓词而非 byType：PopScope 是泛型，
/// find.byType(PopScope) 找的是 `PopScope<dynamic>`，匹配不到 `PopScope<Object?>`。
bool _canPopOf(WidgetTester tester) {
  final finder = find.byWidgetPredicate((w) => w is PopScope);
  expect(finder, findsWidgets, reason: '页面应有 PopScope 退出保护');
  return (tester.widget(finder.first) as PopScope).canPop;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 500));
  // 取消 toast 的自动关闭计时器，否则树 dispose 后仍有 pending timer
  await AppLoading.dismiss(animation: false);
}

void main() {
  setUpAll(() async {
    await StorageService.to.setString(Keys.currentUid, _uid);
  });

  tearDownAll(() async {
    await StorageService.to.remove(Keys.currentUid);
  });

  tearDown(() async {
    // 草稿按 uid 隔离，逐个用例清掉避免互相污染
    await StorageService.to.remove(momentFailedDraftKey(_uid));
    await StorageService.to.remove('moment_last_visibility_$_uid');
  });

  group('渲染契约（当前 Cupertino 实现）', () {
    testWidgets('标题与发送动作分开，空内容禁用发送', (tester) async {
      await _pumpPage(tester);

      expect(find.text(t.chat.momentsSend), findsOneWidget);
      expect(find.text(t.discovery.moments), findsOneWidget);
      expect(
        tester
            .widget<CupertinoButton>(
              find.widgetWithText(CupertinoButton, t.chat.momentsSend),
            )
            .onPressed,
        isNull,
      );
      // 旧用例断言 TextButton —— 页面是 Cupertino 风格，从来就没有
      expect(find.byType(TextButton), findsNothing);

      await _unmount(tester);
    });

    testWidgets('正文输入框 maxLines=10 / maxLength=5000', (tester) async {
      await _pumpPage(tester);

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.maxLines, 10);
      expect(field.maxLength, 5000);

      await _unmount(tester);
    });

    testWidgets('可见范围走 ActionSheet，不是 DropdownButtonFormField', (tester) async {
      await _pumpPage(tester);

      // 旧用例找 DropdownButtonFormField<int>，早已不存在
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      // 工具栏里有"谁可以看"这一行
      expect(find.text(t.discovery.momentsVisibility), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('添加媒体用 CupertinoIcons.add，不是 Material 图标', (tester) async {
      await _pumpPage(tester);

      expect(find.byIcon(CupertinoIcons.add), findsOneWidget);
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);

      await _unmount(tester);
    });

    testWidgets('正文可输入文本', (tester) async {
      await _pumpPage(tester);

      await tester.enterText(find.byType(TextField).first, '今天天气不错');
      await tester.pump();

      expect(find.text('今天天气不错'), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('响应式编辑布局与主题', () {
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 1200.0]) {
        testWidgets('内容限宽、缩略图适度、设置可操作 $brightness $width', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 700);
          addTearDown(tester.view.reset);
          await StorageService.setMap('moment_last_visibility_$_uid', {
            'visibility': momentVisibilityAllowList,
            'allow_uids': List.generate(30, (i) => 'synthetic-$i'),
          });
          await _pumpPage(tester, brightness: brightness, textScale: 2);
          await tester.pumpAndSettle();

          expect(
            tester.getSize(find.byType(ListView)).width,
            lessThanOrEqualTo(680),
          );
          final add = find.ancestor(
            of: find.byIcon(CupertinoIcons.add),
            matching: find.byType(CellPressable),
          );
          expect(tester.getSize(add).width, inInclusiveRange(48, 120));
          final nav = tester.widget<CupertinoNavigationBar>(
            find.byType(CupertinoNavigationBar),
          );
          final title = nav.middle! as Text;
          expect(title.style!.color, AppColors.getTextColor(brightness));
          expect(
            nav.backgroundColor!.computeLuminance() < .1,
            brightness == Brightness.dark,
          );

          await tester.enterText(find.byType(TextField).first, '合成测试内容');
          await tester.pump();
          expect(
            tester
                .widget<CupertinoButton>(
                  find.widgetWithText(CupertinoButton, t.chat.momentsSend),
                )
                .onPressed,
            isNotNull,
          );
          final toggle = find.byType(CupertinoSwitch);
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          expect(toggle.hitTestable(), findsOneWidget);
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(tester.widget<CupertinoSwitch>(toggle).value, isFalse);
          expect(find.byType(DetailSettingsTile), findsNWidgets(4));
          expect(tester.takeException(), isNull);
          await _unmount(tester);
        });
      }
    }

    testWidgets('键盘展开后设置和媒体仍能滚动到达，可见范围仍可修改', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.reset);
      await _pumpPage(tester, brightness: Brightness.dark);
      await tester.pumpAndSettle();
      final visibility = find.text(t.discovery.momentsVisibility);
      await tester.ensureVisible(visibility);
      await tester.pumpAndSettle();
      await tester.tap(visibility);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          CupertinoActionSheetAction,
          t.discovery.momentsVisibilityPublic,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.discovery.momentsVisibilityPublic), findsOneWidget);
      final add = find.byIcon(CupertinoIcons.add);
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      expect(add.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  });

  group('退出提醒（回归：canPop 曾对纯文字失效）', () {
    testWidgets('导航返回先询问草稿，取消后正文仍在', (tester) async {
      await _pumpPage(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final pushed = navigator.push<void>(
        CupertinoPageRoute(builder: (_) => const MomentCreatePage()),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '尚未发布的合成内容');
      await tester.pump();
      await tester.tap(find.byType(GlassBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await tester.tap(
        find.widgetWithText(
          CupertinoDialogAction,
          t.discovery.momentActionCancel,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('尚未发布的合成内容'), findsOneWidget);
      expect(find.byType(GlassBackButton), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await navigator.maybePop();
      await tester.pumpAndSettle();
      await pushed;
      await _unmount(tester);
    });

    // 原 bug：PopScope 用 `canPop: !_hasUnsavedContent`，而该 getter 读
    // _contentController.text；页面只监听 _uploads 不监听 controller，打字
    // 不触发 rebuild，canPop 停在 true，侧滑直接把内容丢掉。只有加过图才
    // 碰巧生效。
    //
    // 修法不是写死 canPop: false —— 那会连空页面一起拦，而 Flutter 在
    // canPop 为 false 时整体禁用 iOS 侧滑返回手势，没东西可丢时也不让滑。
    // 正确做法是监听 controller 让 canPop 真的随内容变化。
    testWidgets('打字后 canPop 转 false（纯文字也拦得住）', (tester) async {
      await _pumpPage(tester);

      // PopScope 在新版 Flutter 是泛型（PopScope<T>），find.byType(PopScope)
      // 找的是 PopScope<dynamic>，匹配不到实际的 PopScope<Object?>。
      expect(_canPopOf(tester), isTrue, reason: '空页面应可自由返回');

      await tester.enterText(find.byType(TextField).first, '写了一半的内容');
      await tester.pump();

      expect(
        _canPopOf(tester),
        isFalse,
        reason: 'canPop 不随 controller 更新的话，纯文字场景会直接放行丢内容',
      );

      await _unmount(tester);
    });

    testWidgets('清空内容后 canPop 转回 true（不误拦、不禁用侧滑）', (tester) async {
      await _pumpPage(tester);

      await tester.enterText(find.byType(TextField).first, '临时输入');
      await tester.pump();
      expect(_canPopOf(tester), isFalse);

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();

      expect(
        _canPopOf(tester),
        isTrue,
        reason: '写死 canPop: false 会让空页面也禁用 iOS 侧滑返回',
      );

      await _unmount(tester);
    });

    testWidgets('空内容时不弹确认框（不打扰）', (tester) async {
      await _pumpPage(tester);

      expect(_canPopOf(tester), isTrue);
      expect(find.byType(CupertinoAlertDialog), findsNothing);

      await _unmount(tester);
    });
  });

  group('草稿恢复（回归：曾只回填文字、图片全丢）', () {
    testWidgets('草稿里的 media_urls 会被恢复成媒体项', (tester) async {
      // 合成四图草稿同时验证恢复和桌面三列排列。
      await StorageService.setMap(
        momentFailedDraftKey(_uid),
        buildMomentDraft(
          content: '发布失败的内容',
          mediaUrls: List.generate(4, (i) => 'synthetic/moment-$i.png'),
          visibility: momentVisibilityFriends,
          allowUids: const [],
          denyUids: const [],
          savedAt: DateTime(2026, 7, 31),
        ),
      );

      await _pumpPage(tester);
      // _tryRestoreDraft 走 addPostFrameCallback
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('发布失败的内容'), findsOneWidget);
      // 四张恢复的图 + 一个"+"按钮；修复前这里只有"+"。
      expect(
        find.byIcon(CupertinoIcons.xmark),
        findsNWidgets(4),
        reason: '每张恢复的图都该有删除角标；数量为 0 说明媒体没被恢复',
      );
      final thumbs = find.byIcon(CupertinoIcons.xmark);
      expect(
        tester.getTopLeft(thumbs.at(0)).dy,
        tester.getTopLeft(thumbs.at(2)).dy,
      );
      expect(
        tester.getTopLeft(thumbs.at(3)).dy,
        greaterThan(tester.getTopLeft(thumbs.at(2)).dy),
      );

      await _unmount(tester);
    });

    testWidgets('无草稿时不显示任何媒体项', (tester) async {
      await _pumpPage(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(CupertinoIcons.xmark), findsNothing);

      await _unmount(tester);
    });
  });

  group('parseMomentUidList（生产函数，旧文件曾本地复刻一份假的）', () {
    test('空串与纯空白返回空列表', () {
      expect(parseMomentUidList(''), isEmpty);
      expect(parseMomentUidList('   '), isEmpty);
    });

    test('单个 uid', () {
      expect(parseMomentUidList('user_001'), ['user_001']);
    });

    test('逗号分隔并去空白', () {
      expect(parseMomentUidList('a, b ,c'), ['a', 'b', 'c']);
    });

    test('连续逗号与首尾逗号不产生空项', () {
      expect(parseMomentUidList(',a,,b,'), ['a', 'b']);
    });
  });

  group('时间线事件契约', () {
    test('MomentTimelineChangedEvent 携带 action / momentId / payload', () async {
      final received = <MomentTimelineChangedEvent>[];
      final sub = AppEventBus.on<MomentTimelineChangedEvent>().listen(
        received.add,
      );

      AppEventBus.fire(
        const MomentTimelineChangedEvent(
          action: 'moment_new',
          momentId: 'm_001',
          payload: {'id': 'm_001', 'content': 'hi'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(received, hasLength(1));
      expect(received.single.action, 'moment_new');
      expect(received.single.momentId, 'm_001');
      expect(received.single.payload['content'], 'hi');

      await sub.cancel();
    });
  });
}

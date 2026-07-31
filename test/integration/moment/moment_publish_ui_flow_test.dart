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
/// `test/component/upload/batch_upload_controller_test.dart` 真实覆盖，
/// 不在此处重复造伪测试。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/moment/moment_create_page.dart';
import 'package:imboy/page/moment/moment_interactions.dart';
import 'package:imboy/page/moment/moment_utils.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/storage.dart';

const String _uid = 'tsid_moment_tester';

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(
    TranslationProvider(
      // 恢复草稿会弹 AppLoading toast，未挂 builder 时 EasyLoading 会断言
      // 'overlayEntry != null'。走项目 facade AppLoading.init()，不直接
      // import flutter_easyloading（边界门禁只允许 app_loading.dart 依赖它）。
      child: MaterialApp(
        home: const MomentCreatePage(),
        builder: AppLoading.init(),
      ),
    ),
  );
  await tester.pump();
}

/// 拆掉 widget 树并把 pending 定时器跑完（页面内有上传/定位相关异步）。
/// 取页面 PopScope 的 canPop。用谓词而非 byType：PopScope 是泛型，
/// find.byType(PopScope) 找的是 PopScope<dynamic>，匹配不到 PopScope<Object?>。
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
  });

  group('渲染契约（当前 Cupertino 实现）', () {
    testWidgets('标题是"发表"，右上是 Cupertino 确认按钮而非 TextButton', (tester) async {
      await _pumpPage(tester);

      expect(find.text(t.chat.momentsSend), findsOneWidget);
      expect(find.text(t.common.confirm), findsOneWidget);
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

  group('退出提醒（回归：canPop 曾对纯文字失效）', () {
    // 曾经的 bug：PopScope 用 `canPop: !_hasUnsavedContent`，而该 getter 读
    // _contentController.text；页面只监听 _uploads 不监听 controller，打字
    // 不触发 rebuild，canPop 停在 true，侧滑直接把内容丢掉。只有加过图才
    // 碰巧生效。修法是 canPop: false 统一走 _confirmExit。
    testWidgets('PopScope.canPop 恒为 false，纯文字也拦得住', (tester) async {
      await _pumpPage(tester);

      await tester.enterText(find.byType(TextField).first, '写了一半的内容');
      await tester.pump();

      // PopScope 在新版 Flutter 是泛型（PopScope<T>），find.byType(PopScope)
      // 找的是 PopScope<dynamic>，匹配不到实际的 PopScope<Object?>。
      expect(
        _canPopOf(tester),
        isFalse,
        reason: 'canPop 一旦依赖未被监听的 controller，纯文字场景会直接放行丢内容',
      );

      await _unmount(tester);
    });

    testWidgets('空内容时返回不弹确认框（不打扰）', (tester) async {
      await _pumpPage(tester);

      // canPop 恒 false，但 _confirmExit 在无内容时直接 pop，不弹框
      expect(_canPopOf(tester), isFalse);
      expect(find.byType(CupertinoAlertDialog), findsNothing);

      await _unmount(tester);
    });
  });

  group('草稿恢复（回归：曾只回填文字、图片全丢）', () {
    testWidgets('草稿里的 media_urls 会被恢复成媒体项', (tester) async {
      // 模拟"发布失败后存下的草稿"：文字 + 两张已上传成功的图
      await StorageService.setMap(
        momentFailedDraftKey(_uid),
        buildMomentDraft(
          content: '发布失败的内容',
          mediaUrls: const ['https://cdn.example.com/a.jpg', 'b.jpg'],
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
      // 两张恢复的图 + 一个"+"按钮；修复前这里只有"+"
      expect(
        find.byIcon(CupertinoIcons.xmark),
        findsNWidgets(2),
        reason: '每张恢复的图都该有删除角标；数量为 0 说明媒体没被恢复',
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
      expect(received.single.payload?['content'], 'hi');

      await sub.cancel();
    });
  });
}

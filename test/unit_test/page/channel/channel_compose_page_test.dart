// ChannelComposePage 选图逻辑测试（BUG#137 回归）
//
// 背景：真机 Android 9 上本页「添加图片」点击无任何反应（release 下
// AssetPicker.pickAssets 抛异常时无 try/catch，异常逃逸到 zone 被吞掉 → 静默
// 「无反应」）。修复 = try/catch + 把真实异常透出为 EasyLoading toast。
//
// 本文件钉两条契约：
//   1. picker 抛异常 → catch 分支弹 toast（「选择图片失败 · 真实原因」格式），
//      异常不再逃逸为未处理异步错误——testWidgets 对未处理异常直接判失败，
//      用例能过即是「已处理」的证明。
//   2. picker 返回 null / 空列表（用户取消）→ 静默返回，无 toast、无图格。
//
// 注入方式：ChannelComposePage.pickAssetsOverride（@visibleForTesting 接缝，
// 生产恒为 null）。选图成功出图格需 AssetEntityImageProvider 走 photo_manager
// 插件通道，无头环境会 MissingPluginException，属设备端 integration 覆盖。
//
// 运行方式 / How to run:
//   flutter test test/unit_test/page/channel/channel_compose_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_compose_page.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

Widget _buildApp(PickAssetsFn picker) {
  return TranslationProvider(
    child: ProviderScope(
      child: MaterialApp(
        // EasyLoading 需 init 才持有 overlay，否则 showError 会触发
        // 「You should call EasyLoading.init()」断言。
        builder: AppLoading.init(),
        home: ChannelComposePage(channelId: 'c1', pickAssetsOverride: picker),
      ),
    ),
  );
}

/// 点「添加图片」并等待 EasyLoading 淡入完成。
Future<void> _tapAddTile(WidgetTester tester) async {
  final addTile = find.byIcon(Icons.add);
  await tester.ensureVisible(addTile);
  await tester.tap(addTile);
  await tester.pump(); // 启动 _pickImages
  await tester.pump(const Duration(milliseconds: 300)); // toast 淡入
}

/// 排干 EasyLoading 的自动消失 timer（displayDuration 默认 2s），
/// 避免 testWidgets 结束时报 pending timer。
///
/// 时机陷阱：toast 的 2s 定时器在淡入动画完成的那一帧末尾才创建
/// （easy_loading.dart L476-484 `completer.future.whenComplete`），之后才轮到
/// 定时器触发、淡出、_reset 清空 overlay。单次大步 pump 会「先越过动画、再
/// 创建定时器」，创建出的定时器反而没人推进了；pumpAndSettle 也不推进纯
/// timer。故分段推进、以「toast 文本从树上消失」为排干信号。
Future<void> _drainToast(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    if (find.textContaining(t.common.selectImageFailed).evaluate().isEmpty) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.pumpAndSettle();
}

/// 注入一个必然抛异常的 picker（模拟真机 release 下 pickAssets 的平台异常）。
Future<List<AssetEntity>?> _throwingPicker(
  BuildContext context, {
  AssetPickerConfig pickerConfig = const AssetPickerConfig(),
}) async {
  throw PlatformException(code: 'test-pick-failure', message: 'boom');
}

/// 注入一个返回 null 的 picker（模拟用户取消）。
Future<List<AssetEntity>?> _nullPicker(
  BuildContext context, {
  AssetPickerConfig pickerConfig = const AssetPickerConfig(),
}) async {
  return null;
}

/// 注入一个返回空列表的 picker（模拟相册无图）。
Future<List<AssetEntity>?> _emptyPicker(
  BuildContext context, {
  AssetPickerConfig pickerConfig = const AssetPickerConfig(),
}) async {
  return const <AssetEntity>[];
}

void main() {
  testWidgets('选图抛异常 → toast 显示「选择图片失败 · 真实原因」，不再静默', (tester) async {
    await tester.pumpWidget(_buildApp(_throwingPicker));
    await tester.pump(); // 执行 postFrameCallback 的 _restoreDraft

    await _tapAddTile(tester);

    expect(
      find.textContaining(t.common.selectImageFailedWithError),
      findsOneWidget,
      reason: '失败必须可见，不得静默（BUG#137 核心症状）',
    );
    expect(
      find.textContaining('test-pick-failure'),
      findsOneWidget,
      reason: '必须透出真实异常原因，作为下次真机复验的根因线索',
    );
    // 页面未跳转、未新增图格
    expect(find.byIcon(Icons.close), findsNothing);

    await _drainToast(tester);
  });

  testWidgets('选图返回 null（用户取消）→ 静默，无 toast 无图格', (tester) async {
    await tester.pumpWidget(_buildApp(_nullPicker));
    await tester.pump();

    await _tapAddTile(tester);

    expect(find.textContaining(t.common.selectImageFailed), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('选图返回空列表 → 静默，无 toast 无图格', (tester) async {
    await tester.pumpWidget(_buildApp(_emptyPicker));
    await tester.pump();

    await _tapAddTile(tester);

    expect(find.textContaining(t.common.selectImageFailed), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.pump(const Duration(seconds: 2));
  });
}

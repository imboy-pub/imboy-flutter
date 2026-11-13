import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/personal_info/set_region/set_region_page.dart';
import 'package:imboy/page/personal_info/widget/more_page.dart';
import 'package:imboy/service/cache/region_cache.dart';

/// AT-MF06 post-save assertions live outside the large acceptance-test carrier
/// so its file-size ratchet remains non-growing.
Future<void> expectRegionSave(
  WidgetTester tester, {
  required String expectedRegion,
  required String cachedRegion,
  required Future<String> Function() loadDbRegion,
}) async {
  expect(
    await _waitForRegionSave(tester, expectedRegion),
    isTrue,
    reason: '保存成功应返回 MorePage 并显示完整三级地区',
  );
  expect(cachedRegion, expectedRegion, reason: '本地用户缓存应保存完整三级路径');

  final dbRegion = await loadDbRegion();
  expect(dbRegion, expectedRegion, reason: '服务端 region 应精确保存完整三级路径');
  expect(cachedRegion, dbRegion, reason: '用户缓存应与服务端一致');

  expect(
    await RegionCache.loadSelectedRegion(),
    expectedRegion,
    reason: '地区字符串缓存应与服务端一致',
  );
  expect(
    await RegionCache.loadRegionPath(),
    expectedRegion.split(' '),
    reason: '地区路径缓存应保留全部三级节点',
  );
}

Future<bool> _waitForRegionSave(
  WidgetTester tester,
  String expectedRegion,
) async {
  for (var i = 0; i < 30; i++) {
    if (tester.any(find.byType(MorePage)) &&
        !tester.any(find.byType(SetRegionPage)) &&
        tester.any(find.text(expectedRegion))) {
      return true;
    }
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return tester.any(find.byType(MorePage)) &&
      !tester.any(find.byType(SetRegionPage)) &&
      tester.any(find.text(expectedRegion));
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/settings/safety_number_page.dart';

/// lib/page/settings/safety_number_page.dart 的布局回归测试。
///
/// 回归 BUG：页面把 ListView 传给 IosPageTemplate 的 `child:`，而模板对
/// child 的兜底容器是 SingleChildScrollView > Column（ios_settings_ui.dart
/// _buildBody）——同轴嵌套两层可滚动 → ListView 收到无界高度 →
/// "RenderBox was not laid out" 布局断言崩（真机偶现）。
///
/// 修复契约：自带滚动体的页面必须传 `body:`（模板注释明示的逃生门），
/// 不得传 `child:`。页面 _load 在测试环境必然异常兜底进入 _error 分支，
/// 但依然渲染 ListView，恰好构成布局回归门。
void main() {
  Widget wrap(Widget page) {
    return TranslationProvider(
      child: ProviderScope(child: MaterialApp(home: page)),
    );
  }

  group('SafetyNumberPage 布局回归（child:ListView 无界崩溃）', () {
    testWidgets('加载完成（或异常兜底）后 ListView 帧无布局异常', (tester) async {
      await tester.pumpWidget(wrap(const SafetyNumberPage(peerUid: '123')));
      // 首帧：_isLoading=true → Center(loading)
      await tester.pump();
      // postFrameCallback 触发 _load；测试环境无 Olm FFI → 异常被页面
      // catch 兜底 → setState(_error)
      await tester.pump();
      // 兜底后的帧：_isLoading=false → ListView 渲染
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}

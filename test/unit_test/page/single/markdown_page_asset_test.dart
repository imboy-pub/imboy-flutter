import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:imboy/page/single/markdown_page.dart';

/// 回归：设置页三个文档（更新日志/FAQ/隐私政策）改为 asset:// 离线打包
/// 加载——此前硬编码 gitee raw URL 匿名访问 404，三页全部「加载失败」
/// （2026-07-14 真机 QA 坐实，隐私政策打不开有合规风险）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) => ProviderScope(
    child: TranslationProvider(child: MaterialApp(home: child)),
  );

  testWidgets('asset:// url 离线加载且三个打包文档资产均存在非空', (tester) async {
    // 三个文档资产存在性（防再次目录改名 doc/→docs/ 类回归）
    for (final path in [
      'docs/changelog.md',
      'docs/FAQ.md',
      'docs/privacy-policy.md',
    ]) {
      final content = await rootBundle.loadString(path);
      expect(content.trim(), isNotEmpty, reason: path);
    }

    // asset:// 机制端到端：页面离线渲染无错误态
    await tester.pumpWidget(
      wrap(const MarkdownPage(title: 'FAQ', url: 'asset://docs/FAQ.md')),
    );
    await tester.pumpAndSettle();
    expect(find.text('加载失败，请重试'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

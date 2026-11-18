import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/theme.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/web_writer_gate.dart';

/// 初始化失败兜底页 / Init failure fallback page
///
/// #95：此前 main() 里 initialize 抛异常直接 return → runApp 永不执行 →
/// 永久白屏（且 _initialized 已提前置位，进程内再无自愈机会）。
/// 本页在 init 失败时渲染，展示错误并提供「重试」，重试重新走完整
/// bootstrap 链（init → run）。
///
/// 注意：本页运行于真实 App / i18n 恢复之前，文案硬编码
/// （app 默认语言即简体中文，与兜底语义一致），不依赖任何待初始化服务。
class InitErrorPage extends StatefulWidget {
  const InitErrorPage({super.key, required this.error, required this.onRetry});

  /// 重新执行完整启动链（init → run）
  final Future<void> Function() onRetry;

  /// 初始化抛出的原始异常，用于现场诊断
  final Object error;

  @override
  State<InitErrorPage> createState() => _InitErrorPageState();
}

class _InitErrorPageState extends State<InitErrorPage> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      if (widget.error is WebWriterGateFailure) {
        await reloadWebWriterPage();
      } else {
        await widget.onRetry();
      }
    } catch (e) {
      // bootstrap 内部已兜底渲染新的错误页；此处仅防御性记录
      debugPrint('[InitErrorPage] retry threw: $e');
    } finally {
      // 成功路径整棵树已被 run() 替换，此 setState 不会再触发
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final writerFailure = widget.error is WebWriterGateFailure
        ? widget.error as WebWriterGateFailure
        : null;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // PERF-05（F5 错误屏路径）：此前本页挂裸 MaterialApp——SDK 默认
      // ThemeData 无 fontFamilyFallback，CanvasKit 侧 'Roboto'/'CupertinoSystemText'
      // 皆未注册 → FilledButton 等框架默认文本样式触发 fonts.gstatic 动态
      // 分片拉取（cors-incident-f5-errorpath.json 实锤 116/117 命中）。
      // 挂 app 回退链（首位内嵌 NotoSansSC 子集）后框架默认样式本地命中。
      theme: ThemeData(
        useMaterial3: true,
        fontFamilyFallback: kAppFontFamilyFallback,
        cupertinoOverrideTheme: CupertinoThemeData(
          // Cupertino 侧（scaffold/导航）同样挂链；SDK 默认样式不带 fallback。
          brightness: Brightness.light,
          textTheme: AppTheme.cupertinoFallbackTextTheme,
        ),
      ),
      home: CupertinoPageScaffold(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_circle,
                    size: 64,
                    color: AppColors.iosRed,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    writerFailure == null ? '应用初始化失败' : 'Web 暂时无法打开',
                    style: context.textStyle(
                      FontSizeType.large,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    writerFailure == null
                        ? '可能是网络或本地存储异常导致，请重试；'
                              '若持续失败请重新安装或联系客服。'
                        : _writerFailureDescription(writerFailure.kind),
                    textAlign: TextAlign.center,
                    style: context.textStyle(
                      FontSizeType.normal,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (writerFailure == null)
                    SelectableText(
                      widget.error.toString(),
                      style: context
                          .textStyle(
                            FontSizeType.caption2,
                            color: AppColors.textSecondary,
                          )
                          .copyWith(fontFamily: 'monospace'),
                      maxLines: 6,
                    ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _retrying ? null : _retry,
                    icon: _retrying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CupertinoActivityIndicator(),
                          )
                        : const Icon(CupertinoIcons.arrow_clockwise),
                    label: Text(
                      _retrying
                          ? t.common.retrying
                          : writerFailure == null
                          ? t.common.retry
                          : '刷新页面',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Pre-i18n startup fallback, matching this existing page's boot-copy policy.
String _writerFailureDescription(WebWriterFailureKind kind) => switch (kind) {
  WebWriterFailureKind.occupied =>
    '另一个 ImBoy 页面正在使用本地会话。请关闭其他 ImBoy 页面后刷新本页；不要清除浏览器数据。',
  WebWriterFailureKind.unavailable =>
    '本地存储未能准备完成，请在受支持的浏览器和安全连接中刷新重试；不要清除浏览器数据。',
  WebWriterFailureKind.poisoned => '本页的本地存储不能继续使用，请刷新页面重新读取已保存的数据；不要清除浏览器数据。',
};

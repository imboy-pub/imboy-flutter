import 'package:flutter/material.dart';

import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 初始化失败兜底页 / Init failure fallback page
///
/// #95：此前 main() 里 initialize 抛异常直接 return → runApp 永不执行 →
/// 永久白屏（且 _initialized 已提前置位，进程内再无自愈机会）。
/// 本页在 init 失败时渲染，展示错误并提供「重试」，重试重新走完整
/// bootstrap 链（init → Sentry → run）。
///
/// 注意：本页运行于真实 App / i18n 恢复之前，文案硬编码
/// （app 默认语言即简体中文，与兜底语义一致），不依赖任何待初始化服务。
class InitErrorPage extends StatefulWidget {
  const InitErrorPage({super.key, required this.error, required this.onRetry});

  /// 重新执行完整启动链（init → Sentry → run）
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
      await widget.onRetry();
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.iosRed,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '应用初始化失败',
                    style: context.textStyle(
                      FontSizeType.large,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '可能是网络或本地存储异常导致，请重试；'
                    '若持续失败请重新安装或联系客服。',
                    textAlign: TextAlign.center,
                    style: context.textStyle(
                      FontSizeType.normal,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(_retrying ? '重试中…' : '重试'),
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

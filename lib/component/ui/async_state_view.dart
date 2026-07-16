import 'package:flutter/cupertino.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 统一的加载 / 空 / 错误三态视图组件。
///
/// 状态优先级：isLoading > error != null > isEmpty，否则渲染 [child]。
/// loading 态复用项目既有的 `Center(child: CupertinoActivityIndicator())` 写法；
/// error / empty 态复用既有 [NoDataView]，保持 iOS 风格 token 一致。
class AsyncStateView extends StatelessWidget {
  final bool isLoading;
  final Object? error;
  final bool isEmpty;
  final Widget child;

  /// 点击重试时触发（error/empty 态均可用）。为 null 时 NoDataView 不展示重试提示。
  final VoidCallback? onRetry;

  final String? emptyText;
  final IconData? emptyIcon;
  final String? errorText;
  final IconData errorIcon;

  const AsyncStateView({
    super.key,
    required this.isLoading,
    required this.isEmpty,
    required this.child,
    this.error,
    this.onRetry,
    this.emptyText,
    this.emptyIcon,
    this.errorText,
    this.errorIcon = CupertinoIcons.exclamationmark_circle,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (error != null) {
      return NoDataView(
        text: errorText ?? t.common.tipFailed,
        icon: errorIcon,
        onTop: onRetry,
      );
    }
    if (isEmpty) {
      // 空态仅展示引导文案，不显示"重试"（重试语义仅属 error 态，
      // 避免"暂无数据 + 重试"这种空态/失败态混淆）。
      return NoDataView(
        text: emptyText ?? t.common.noData,
        icon: emptyIcon,
        onTop: null,
      );
    }
    return child;
  }
}

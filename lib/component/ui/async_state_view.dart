import 'package:flutter/cupertino.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 统一的加载 / 空 / 错误 / 权限四态视图组件。
///
/// 状态优先级：isLoading > permissionDenied > error != null > isEmpty，
/// 否则渲染 [child]（与 OrgStateView 的既有序一致：权限态先于错误态，
/// 页面同时持有两者时按"权限不足"而非"系统错误"呈现）。
/// loading 态复用项目既有的 `Center(child: CupertinoActivityIndicator())` 写法；
/// error / empty / permission 态复用既有 [NoDataView]，保持 iOS 风格 token 一致。
///
/// 权限态（ENT-FND-02）：403 类失败是终态而非系统错误，不引导盲目重试，
/// 因此不渲染重试入口；判定不解析错误字符串，由调用方（或域内映射
/// helper，如 organization 的 `orgErrorToUiState`）注入布尔标志。
class AsyncStateView extends StatelessWidget {
  final bool isLoading;
  final Object? error;
  final bool isEmpty;
  final Widget child;

  /// 权限不足专用态（403 类终态）。默认 false，既有三态调用点不受影响。
  final bool permissionDenied;

  /// 点击重试时触发（error 态可用）。为 null 时 NoDataView 不展示重试提示。
  /// empty / permission 态不渲染重试（重试语义仅属 error 态）。
  final VoidCallback? onRetry;

  final String? emptyText;
  final IconData? emptyIcon;
  final String? errorText;
  final IconData errorIcon;

  /// 权限态主文案。默认 [t.common.noPermission]。
  final String? permissionText;

  /// 权限态图标。默认锁形，与 OrgStateView.permissionDenied 的语义一致。
  final IconData permissionIcon;

  const AsyncStateView({
    super.key,
    required this.isLoading,
    required this.isEmpty,
    required this.child,
    this.error,
    this.permissionDenied = false,
    this.onRetry,
    this.emptyText,
    this.emptyIcon,
    this.errorText,
    this.errorIcon = CupertinoIcons.exclamationmark_circle,
    this.permissionText,
    this.permissionIcon = CupertinoIcons.lock_fill,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (permissionDenied) {
      // 403 是授权终态而非瞬时故障：重试不会改变结果，
      // 渲染引导文案但不给重试按钮（对齐 OrgStateView.permissionDenied）。
      return NoDataView(
        text: permissionText ?? t.common.noPermission,
        icon: permissionIcon,
        onTop: null,
      );
    }
    if (error != null) {
      // 默认文案用 loadError（"加载失败，请重试"）而非 tipFailed（"操作失败！"）：
      // 本组件 15 个调用点全是页面级数据加载视图，"操作失败"读起来像写操作
      // 失败，会误导用户以为自己刚才的动作出了问题。真机实测群标签断网即此症。
      return NoDataView(
        text: errorText ?? t.common.loadError,
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

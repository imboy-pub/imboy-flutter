/// QR 登录确认页（Provider 容器）。
///
/// 职责：
///   1. initState 后自动调 `qrLoginConfirmProvider.notifier.scan(qrToken)`
///   2. listen state 变化，终态（Success / CancelledByMe）后 800ms 自动 pop
///   3. 把 state 与三个回调（confirm / cancel / close）注入展示组件
///      [QrLoginConfirmContent]
///
/// 测试策略：本 widget 不单测（按项目惯例）；UI 渲染契约已被
/// `qr_login_confirm_content_test.dart` 覆盖（17 widget 测）；状态机正确性
/// 已被 `qr_login_confirm_rules_test.dart` 覆盖（31 单测）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/page/scanner/qr_login_confirm_content.dart';
import 'package:imboy/page/scanner/qr_login_confirm_provider.dart';
import 'package:imboy/page/scanner/qr_login_confirm_rules.dart';

class QrLoginConfirmPage extends ConsumerStatefulWidget {
  const QrLoginConfirmPage({super.key, required this.qrToken});

  /// 来自 scanner 的 `qr_token`（透传给后端 scan/confirm）。
  final String qrToken;

  @override
  ConsumerState<QrLoginConfirmPage> createState() => _QrLoginConfirmPageState();
}

class _QrLoginConfirmPageState extends ConsumerState<QrLoginConfirmPage> {
  @override
  void initState() {
    super.initState();
    // 进入页面后立即上报扫码（让 Web 端从 waiting → scanned）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(qrLoginConfirmProvider.notifier).scan(widget.qrToken);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 终态自动 pop（成功 800ms 后退栈，让用户看清成功反馈）。
    ref.listen<QrLoginConfirmState>(qrLoginConfirmProvider, (prev, next) {
      switch (next) {
        case QrLoginConfirmSuccess() || QrLoginConfirmCancelledByMe():
          Future<dynamic>.delayed(const Duration(milliseconds: 800), () {
            if (mounted) Navigator.of(context).pop();
          });
        default:
          break;
      }
    });

    final state = ref.watch(qrLoginConfirmProvider);
    return QrLoginConfirmContent(
      state: state,
      onConfirm: () =>
          ref.read(qrLoginConfirmProvider.notifier).confirm(widget.qrToken),
      onCancel: () => ref.read(qrLoginConfirmProvider.notifier).cancelByMe(),
      onClose: () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }
}

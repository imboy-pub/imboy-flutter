/// QR 登录确认页（Provider 容器）。
///
/// 职责：
///   1. initState 后自动调 `qrLoginConfirmProvider.notifier.scan(qrToken)`
///   2. listen state 变化：CancelledByMe 后 800ms 自动 pop；
///      Success 不自动退栈——展示组件出现"我知道了"按钮，点击后双层退栈
///      （确认页 + 扫码页）回到进入扫一扫之前的页面（2026-11-19 前成功态
///      800ms 自动 pop 只退到扫码取景页，用户观感"停留在扫描状态"）
///   3. 把 state 与四个回调（confirm / cancel / close / acknowledged）
///      注入展示组件 [QrLoginConfirmContent]
///
/// 测试策略：本 widget 不单测（按项目惯例）；UI 渲染契约已被
/// `qr_login_confirm_content_test.dart` 覆盖（widget 测）；状态机正确性
/// 已被 `qr_login_confirm_rules_test.dart` 覆盖（31 单测）。
library;

import 'package:material_ui/material_ui.dart';
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
    // 我知道了：确认页 + 扫码页双层退栈（栈形 [..., /scanner 路由页, 确认页]，
    // 由 scanner_page.dart onDetect CupertinoPageRoute push 保证）。
    // canPop 守卫：/scanner 是顶层 GoRoute，若它以根路由形态被直接打开
    // （深链/冷启动直达），退栈只能退确认页，绝不 pop 最后一页（空 Navigator）。
    void acknowledgeAndReturn() {
      if (!context.mounted) return;
      final navigator = Navigator.of(context);
      navigator.pop();
      if (navigator.canPop()) {
        navigator.pop();
      }
    }

    // 终态自动 pop（仅我方取消；成功态改为显式"我知道了"，见类注释）。
    ref.listen<QrLoginConfirmState>(qrLoginConfirmProvider, (prev, next) {
      switch (next) {
        case QrLoginConfirmCancelledByMe():
          Future<dynamic>.delayed(const Duration(milliseconds: 800), () {
            if (context.mounted) Navigator.of(context).pop();
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
        if (context.mounted) Navigator.of(context).pop();
      },
      onAcknowledged: acknowledgeAndReturn,
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 企业壳页内分段切换器 — 当前消息页（群聊/频道）在用；通讯录页的
/// 「成员/组织架构」分段已改为组织架构入口行（企业微信式），不再消费。
/// 规格契约：左右 16pt（DESIGN.md 4.2 页面 padding）、高 32pt
/// （iOS UISegmentedControl 标准高度）、居中限宽 288pt —— 宽屏桌面宿主下
/// 满宽分段会横跨整窗，居中限宽是手机/桌面两种宿主都安全的形态。
/// 壳内如再出现分段切换需求，必须复用本组件，勿再各写各的规格。
class WorkspaceSegmentSwitcher extends StatelessWidget {
  const WorkspaceSegmentSwitcher({
    super.key,
    required this.value,
    required this.offLabel,
    required this.onLabel,
    required this.onChanged,
  });

  final bool value;
  final String offLabel;
  final String onLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.small,
        AppSpacing.regular,
        AppSpacing.small,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.xxxLarge * 6),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<bool>(
              groupValue: value,
              children: {
                false: SizedBox(
                  height: 32,
                  child: Center(child: Text(offLabel)),
                ),
                true: SizedBox(height: 32, child: Center(child: Text(onLabel))),
              },
              onValueChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ),
      ),
    );
  }
}

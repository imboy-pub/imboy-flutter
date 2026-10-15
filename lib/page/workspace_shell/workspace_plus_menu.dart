/// 企业壳「消息」tab 右上角「+」按钮与弹出菜单（2026-10 飞书风格改版，
/// 参考稿③）：蓝调菜单项 + 顶部箭头缺口 + 新功能红点。
///
/// 动作接线（企业模式语境）：
/// - 发起群聊 / 扫一扫：既有路由直达（扫码必须走 go_router，原因见
///   个人模式 RightButton 同款注释——扫码页 pushReplacement 依赖
///   go_router 栈）；
/// - 添加客户：企业语境复用加好友路由（/contact/add_friend）；
/// - 记录面聊 / 智能总结 / 休息一下：暂无后端能力，点击提示
///   「功能开发中」，入口保留以对齐参考稿。
library;

import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/popover_menu.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';

class WorkspacePlusButton extends StatefulWidget {
  const WorkspacePlusButton({super.key});

  @override
  State<WorkspacePlusButton> createState() => _WorkspacePlusButtonState();
}

class _WorkspacePlusButtonState extends State<WorkspacePlusButton> {
  final _plusKey = GlobalKey();

  void _showMenu() {
    final renderBox = _plusKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final pageContext = context;
    final primary = Theme.of(pageContext).colorScheme.primary;
    Future<void> comingSoon() async {
      await AppLoading.showToast(t.workspace.featureComingSoon);
    }

    unawaited(
      showPopoverMenu(
        pageContext,
        anchor: renderBox.localToGlobal(Offset.zero) & renderBox.size,
        showArrow: true,
        entries: [
          PopoverMenuEntry(
            icon: Icon(
              CupertinoIcons.chat_bubble_fill,
              size: 20,
              color: primary,
            ),
            title: t.chat.initiateChat,
            foreground: primary,
            action: () => pageContext.push('/launch_chat'),
          ),
          PopoverMenuEntry(
            icon: Icon(CupertinoIcons.videocam_fill, size: 20, color: primary),
            title: t.workspace.recordFaceChat,
            foreground: primary,
            showDot: true,
            action: comingSoon,
          ),
          PopoverMenuEntry(
            icon: Icon(
              CupertinoIcons.person_crop_circle_badge_plus,
              size: 20,
              color: primary,
            ),
            title: t.common.addFriend,
            foreground: primary,
            action: () => pageContext.push('/contact/add_friend'),
          ),
          PopoverMenuEntry(
            icon: Icon(CupertinoIcons.sparkles, size: 20, color: primary),
            title: t.workspace.smartSummary,
            foreground: primary,
            action: comingSoon,
          ),
          PopoverMenuEntry(
            icon: Icon(
              CupertinoIcons.qrcode_viewfinder,
              size: 20,
              color: primary,
            ),
            title: t.account.scanQrCode,
            foreground: primary,
            // 必须走 go_router 打开（扫码页命中名片后 pushReplacement 会
            // 替换 go_router 栈顶，rootNavigator push 会让栈错位，见
            // RightButton 同款注释）。
            action: () => pageContext.push('/scanner'),
          ),
          PopoverMenuEntry(
            icon: Icon(Icons.local_cafe_outlined, size: 20, color: primary),
            title: t.workspace.takeABreak,
            foreground: primary,
            action: comingSoon,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      key: _plusKey,
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: _showMenu,
      child: Semantics(
        label: t.common.buttonMore,
        button: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              CupertinoIcons.plus_circle,
              size: 22,
              color: AppColors.primary,
            ),
            Positioned(
              top: -1,
              right: -3,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.iosRed,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

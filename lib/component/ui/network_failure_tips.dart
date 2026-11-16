import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show Assertiveness, SemanticsService;
import 'package:imboy/i18n/strings.g.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/theme/default/app_colors.dart';

// ignore: must_be_immutable
class NetworkFailureTips extends StatefulWidget {
  Color? backgroundColor;

  NetworkFailureTips({super.key, this.backgroundColor});

  @override
  State<NetworkFailureTips> createState() => _NetworkFailureTipsState();
}

class _NetworkFailureTipsState extends State<NetworkFailureTips> {
  String get _message =>
      "${t.common.networkNotAvailable}${t.error.pleaseCheckNetwork}";

  @override
  void initState() {
    super.initState();
    _announceOnMount();
  }

  /// DEF-A11YNEW-04（R6b 修复窗）：横幅出现必须被读屏主动播报
  /// （WCAG 2.2 SC 4.1.3 Status Messages）。
  ///
  /// 根因（对 build/web/main.dart.js 的引擎反编译实证）：
  /// 本引擎构建（Flutter 3.50 canvaskit，2026-11-09）的语义层**不存在**
  /// `SemanticsFlag.isLiveRegion`（bit 15, 32768）→ 节点 DOM `aria-live`
  /// 的映射——flag 常量仅出现在 flag 名称表里，全引擎仅有的两处
  /// `setAttribute("aria-live", …)` 是 `flt-announcement-polite/assertive`
  /// 单例与 "Enable accessibility" placeholder。因此 L18 S4 的
  /// `Semantics(liveRegion: true)` 在 release 构建不显现（收据
  /// b4-banner-nodes.json：横幅子树所有节点 ariaLive=null，
  /// flt-announcement-polite 零播报），不是 flag 丢失或被外层吞。
  ///
  /// 修复：保留 liveRegion 标志（Android/iOS 等平台仍按平台语义消费；
  /// 将来引擎补上映射后自动生效），同时走本引擎**实际支持**的通告通道：
  /// `SemanticsService.sendAnnouncement` → AnnounceSemanticsEvent →
  /// 引擎写入 flt-announcement-polite → 读屏播报。
  void _announceOnMount() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final view = View.of(context);
      final direction = Directionality.of(context);
      SemanticsService.sendAnnouncement(
        view,
        _message,
        direction,
        assertiveness: Assertiveness.polite,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // DSN-05 R25-R28：原亮粉底 #F7E2E6 + iosRed #FF3B30 = 2.867:1，且暗色
    // 主题无适配。改按主题取 errorContainer 对（亮 #F7E2E6 +
    // lightDestructiveText #B42318 = 5.315；暗 #4A0E0E + #FFDAD6 = 11.95）。
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final bg =
        widget.backgroundColor ??
        (isDark
            ? AppColors.darkErrorContainer
            : const Color.fromRGBO(247, 226, 230, 1));
    final fg = isDark
        ? AppColors.darkOnErrorContainer
        : AppColors.lightDestructiveText;
    // DEF-A11YNEW-04：横幅此前 role=button 且无 aria-live——离线时横幅静默
    // 出现，读屏用户无任何主动通告。liveRegion=true → 引擎
    // `_engine/engine/semantics/live_region.dart` 渲染 aria-live="polite"，
    // 横幅挂载/文本变化时读屏主动播报；注解沿单子语义链并入按钮节点。
    // role 保留 button：横幅本体可点（onPressed 跳网络诊断引导页
    // /network_failure_guidance，见下方 RawMaterialButton），button 角色成立
    // （收据"是否可点未验证"→源码验证可点）。
    // 注（R6b）：web canvaskit 引擎 3.50 不映射 isLiveRegion → aria-live，
    // 播报由上方 _announceOnMount 的 sendAnnouncement 通道承担。
    return Semantics(
      liveRegion: true,
      child: Container(
        color: bg,
        child: RawMaterialButton(
          // highlightColor是点击的时候的高亮效果
          // highlightColor: const Color.fromRGBO(247, 226, 230, 1),
          // splashColor 是点击后不松手的扩散效果
          splashColor: bg,
          onPressed: () {
            // 使用 go_router 替代 Get.to()
            context.push('/network_failure_guidance');
          },
          child: Row(
            // 直接使用 Flutter 的 Row
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Icon(CupertinoIcons.info_circle, color: fg),
              ),
              Expanded(
                child: Text(
                  // '当前网络不可用，请检查你的网络设置。'
                  _message,
                  // '当前网络不可用，请检查你的网络设置。当前网络不可用，请检查你的网络设置。当前网络不可用，请检查你的网络设置。',
                  style: TextStyle(color: fg),
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                // color: AppColors.LabelTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

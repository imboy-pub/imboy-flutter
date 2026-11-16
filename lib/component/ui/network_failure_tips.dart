import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/theme/default/app_colors.dart';

// ignore: must_be_immutable
class NetworkFailureTips extends StatelessWidget {
  Color? backgroundColor;

  NetworkFailureTips({super.key, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    // DSN-05 R25-R28：原亮粉底 #F7E2E6 + iosRed #FF3B30 = 2.867:1，且暗色
    // 主题无适配。改按主题取 errorContainer 对（亮 #F7E2E6 +
    // lightDestructiveText #B42318 = 5.315；暗 #4A0E0E + #FFDAD6 = 11.95）。
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final bg =
        backgroundColor ??
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
                  // '当前网络不可用，请检查你的网络设置。',
                  "${t.common.networkNotAvailable}${t.error.pleaseCheckNetwork}",
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

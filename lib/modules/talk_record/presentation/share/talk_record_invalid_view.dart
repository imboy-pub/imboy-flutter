/// 面聊记录（talk_record）通用失效视图（T18）。
///
/// 契约源：UI-SPEC §4「无权限/不存在统一：暂时无法查看；不泄露记录
/// 标题与人员，也不凭错误推断用户已离职」+ BACKEND-API.md §11.3
/// （GET /:id 无权限或不存在统一 404；已授权客户端收到撤权显示通用
/// 访问失效，不披露服务器具体成员关系原因）。
///
/// 本文件是该分型文案的共享实现处：T18 分享域（非 owner 门控/无访问）
/// 与后续 403/404 落地（详情页错误映射，见 Q-review-T16 问题 #2）复用
/// 同一视图，不允许各自复制文案漂移。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 通用失效视图（可嵌入任意页面失败区；文案冻结，不含任何记录信息）。
///
/// [onBack] 为空时不显示返回动作（嵌入态由宿主页提供导航）。
class TalkRecordInvalidView extends StatelessWidget {
  const TalkRecordInvalidView({super.key, this.onBack, this.backLabel});

  /// 返回动作回调（通常 `context.pop()` 或返回列表）。
  final VoidCallback? onBack;

  /// 覆盖返回文案（默认 invalidBack）。
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      key: const ValueKey('talk_record_invalid_view'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.lock_shield,
              size: AppSpacing.xxxLarge + 8,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            const SizedBox(height: AppSpacing.medium),
            // 统一文案：不泄露标题/人员，不推断离职等具体原因。
            Text(
              t.talkRecord.invalidTitle,
              textAlign: TextAlign.center,
              // C-F3：可换行不截断。
              maxLines: null,
              style: context.textStyle(
                FontSizeType.medium,
                fontWeight: FontWeight.w600,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              t.talkRecord.invalidBody,
              textAlign: TextAlign.center,
              maxLines: null,
              style: context.textStyle(
                FontSizeType.footnote,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            if (onBack != null) ...[
              const SizedBox(height: AppSpacing.large),
              CupertinoButton(
                key: const ValueKey('talk_record_invalid_back'),
                // C-F4：触达 ≥44。
                minimumSize: const Size(120, 44),
                onPressed: onBack,
                child: Text(backLabel ?? t.talkRecord.invalidBack),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 通用失效页（路由挂载形态；`/talk_record/invalid`）。
///
/// 供深链打开无权限记录、撤权后通用访问失效等场景跳转使用；
/// 页面本身不携带也不请求任何记录数据（避免失效页反而泄露信息）。
class TalkRecordInvalidPage extends StatelessWidget {
  const TalkRecordInvalidPage({super.key});

  @override
  Widget build(BuildContext context) {
    return IosPageTemplate(
      title: t.talkRecord.invalidTitle,
      body: TalkRecordInvalidView(onBack: () => _back(context)),
    );
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/talk_record');
    }
  }
}

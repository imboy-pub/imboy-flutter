/// V3-23 企业应用代发卡片（链接卡片 / 业务操作卡片）的共享 payload 解析与
/// 降级占位。
///
/// payload schema 来源：matrix spec `message-session-matrix.md` §5 落点 A2/D1
/// （backend `enterprise_message_logic` build_payload 冻结分支
/// `<<"link_card">>` / `<<"business_action_card">>`）：
/// - 共同必填：`title`（非空字符串）
/// - `url`（出现时必须 http/https 且带 host；spec A2「url 带 host ≤2048」的
///   客户端侧同口径校验，超限一律判畸形、不跳转）
/// - link_card：`title` 必填；`url` 必填
/// - business_action_card：`title` + `action_type` 必填；`url` 可选
///
/// 设计约束（对齐 hosted_message_facts 的失败不伪造原则）：
/// - **畸形 payload 不崩溃、不猜测**：解析失败渲染降级占位
///   [EnterpriseCardFallback]，绝不把畸形卡片当普通文本或空白吞掉；
/// - 跳转只走 [SafeLauncher]（scheme 白名单 + host 校验 + 应用内 WebView），
///   禁止 `context.push` 任意字符串路由（伪造跳转面）。
library;

import 'package:flutter/material.dart';

import 'package:imboy/component/helper/safe_launcher.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// spec A2 的 URL 长度上限（≤2048）。
const int kEnterpriseCardUrlMaxLength = 2048;

/// 把卡片消息的 metadata 摊平：业务字段优先取顶层，缺失时回落到嵌套的
/// `payload`。历史转发链会把业务字段包进 `payload` 再落库（channel 卡片的
/// 同款历史形态，见 message_channel_card_builder._flatten）。
Map<String, dynamic> flattenCardMeta(Map<String, dynamic>? metadata) {
  if (metadata == null) return const <String, dynamic>{};
  final dynamic nested = metadata['payload'];
  if (nested is! Map) return metadata;
  return <String, dynamic>{...Map<String, dynamic>.from(nested), ...metadata};
}

/// 非空字符串解析：缺失/空串/非字符串统一返回 ''（调用方按必填校验）。
String cardString(dynamic raw) {
  final String s = parseModelString(raw).trim();
  return s;
}

/// spec A2 口径的 URL 校验：http/https、带 host、≤2048。
bool isValidCardUrl(String url) {
  if (url.isEmpty || url.length > kEnterpriseCardUrlMaxLength) return false;
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) return false;
  final String scheme = uri.scheme.toLowerCase();
  return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
}

/// 经 [SafeLauncher] 打开卡片链接（scheme 白名单 + host 校验 + 应用内
/// WebView）。任何失败只记日志，不抛出、不崩溃。
Future<void> openCardUrl(BuildContext context, String url) async {
  await SafeLauncher.safeLaunchUrlString(url, context: context);
}

/// 畸形 payload 的共享降级占位（**不静默吞掉**：明确展示「卡片内容无法显示」）。
class EnterpriseCardFallback extends StatelessWidget {
  const EnterpriseCardFallback({super.key, this.sentByMe = false});

  final bool sentByMe;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = sentByMe
        ? AppColors.sentMessageText
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: AppColors.getChatBubbleBackground(
          sentByMe,
          false,
          Theme.of(context).brightness,
        ),
        borderRadius: AppRadius.borderRadiusSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: AppSizes.iconSizeSmall,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.small),
          Flexible(
            child: Text(
              t.enterpriseApp.cardPayloadInvalid,
              style: context.textStyle(FontSizeType.small, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

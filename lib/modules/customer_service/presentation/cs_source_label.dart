/// 来源渠道展示映射（T21/P3-03）— imboy-enterprise-uiux-v1
///
/// 纯展示函数：wire 来源值 → 可读展示名。无 API/数据模型改动；
/// wire 原值永远不出现在 UI/语义/提示中。
///
/// 口径（i18n 主键来自 T06 customerService.sourceWidget）：
/// - `widget` → sourceWidget（'网页'/'Web'，本地化网页咨询）；
/// - 其他非空 wire → 通用「未知」（t.common.unknown，绝不透出原枚举）；
/// - 空 wire → 同样归「未知」。
library;

import 'package:flutter/widgets.dart' show BuildContext;

import 'package:imboy/i18n/strings.g.dart';

/// wire 来源的展示名。
String csSourceDisplayLabel(BuildContext context, String wire) {
  if (wire == 'widget') {
    return context.t.customerService.sourceWidget;
  }
  return context.t.common.unknown;
}

/// 动态元信息展示组件（feed 卡与详情页共用）：所在位置地标 + @提醒摘要。
///
/// 均为轻量纯展示 widget：有数据才渲染，无数据返回 `SizedBox.shrink()`。
/// 数据消费 E1 数据层：位置走 [normalizeMomentLocation]，@提醒名走
/// [momentAtNames]（enrich 阶段已解析昵称，展示层同步读取）。
library;

import 'package:flutter/cupertino.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/moment/moment_utils.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 动态所在位置地标：`location.name` 存在才渲染（icon + 地名）。
///
/// ponytail: 纯展示不跳地图。跳转需 map_launcher 弹「用哪个地图 App」的
/// sheet + 坐标校验，属可选增强；当前先只展示地名，需要时接
/// `MapLauncher.showMarker(coords, title)` 即可（location 已含 lat/lng）。
class MomentLocationLabel extends StatelessWidget {
  /// 帖子原始 `location` 字段（`{name,lng,lat,address?}` 或脏数据/null）。
  final dynamic rawLocation;

  const MomentLocationLabel({super.key, required this.rawLocation});

  @override
  Widget build(BuildContext context) {
    final location = normalizeMomentLocation(rawLocation);
    if (location == null) return const SizedBox.shrink();
    final name = parseModelString(location['name']);
    if (name.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          CupertinoIcons.location_solid,
          size: 13,
          color: AppColors.iosGray,
        ),
        AppSpacing.horizontalTiny,
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.iosGray,
            ),
          ),
        ),
      ],
    );
  }
}

/// 动态 @提醒摘要：`at_uids` 非空才渲染。
/// - 1 人：「提醒了 张三」
/// - N 人：「提醒了 张三 等N人」
class MomentAtSummary extends StatelessWidget {
  /// 整条帖子（内部经 [momentAtNames] 取展示名，兼容未 enrich 回退 uid）。
  final Map<String, dynamic> item;

  const MomentAtSummary({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final names = momentAtNames(item);
    if (names.isEmpty) return const SizedBox.shrink();
    final text = names.length == 1
        ? t.discovery.momentAtReminded(name: names.first)
        : t.discovery.momentAtRemindedMore(
            name: names.first,
            count: names.length,
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(CupertinoIcons.at, size: 13, color: AppColors.wechatBlue),
        AppSpacing.horizontalTiny,
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.wechatBlue,
            ),
          ),
        ),
      ],
    );
  }
}

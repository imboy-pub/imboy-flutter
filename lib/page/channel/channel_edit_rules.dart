/// channel_edit_page 纯决策函数
///
/// 从 channel_edit_page.dart 提取的零依赖纯函数，
/// 便于单元测试和跨 widget 复用。
library;

import 'package:flutter/foundation.dart';
import 'package:imboy/store/model/channel_model.dart';

/// CE-1 标签规范化：trim + 过滤空白 + 去重 + 排序
///
/// - null / 空列表 → 返回空列表
/// - 每项两端空白被 trim
/// - trim 后为空的项被过滤
/// - 去重（基于 Set）
/// - 结果升序排序
List<String> normalizeTags(List<String>? tags) {
  final result =
      (tags ?? const <String>[])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return result;
}

/// CE-2 两组标签语义相等判断
///
/// 内部先经过 [normalizeTags] 归一化后再比较，
/// 因此顺序、重复、前后空白均不影响结果。
bool channelTagsEqual(List<String>? left, List<String>? right) {
  return listEquals(normalizeTags(left), normalizeTags(right));
}

/// CE-3 编辑表单当前值是否与已有 channel 完全一致（即无实质变更）
///
/// 参数：
///   - [channel]     现有频道对象
///   - [name]        表单中的名称
///   - [description] 表单中的简介
///   - [avatar]      表单中的头像 URL（null 表示「未修改」，忽略比较）
///   - [tags]        表单中的标签列表（null 表示「未修改」，忽略比较）
///
/// 返回 true 表示「与原始数据完全一致」，可用于禁用"保存"按钮。
bool isChannelUpdateApplied({
  required ChannelModel channel,
  required String name,
  required String description,
  String? avatar,
  List<String>? tags,
}) {
  final avatarMatched = avatar == null || (channel.avatar ?? '') == avatar;
  final tagsMatched = tags == null || channelTagsEqual(channel.tags, tags);
  return channel.name == name &&
      (channel.description ?? '') == description &&
      avatarMatched &&
      tagsMatched;
}

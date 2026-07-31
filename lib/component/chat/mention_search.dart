/// @提及候选的关键词匹配（纯函数，零 Widget 依赖，可独立单测）。
///
/// 只按 displayName 做子串匹配是不够的：群成员多为中文昵称，而用户习惯
/// 打拼音（`@zhangsan`）或首字母（`@zs`）。项目已依赖 lpinyin（联系人
/// 索引栏在用），这里复用同一套转换，不引新依赖。
library;

import 'package:lpinyin/lpinyin.dart';

/// 候选是否命中关键词。
///
/// 依次尝试三种匹配，任一命中即可：
///   1. 原文子串    「张三」 ← "张"
///   2. 全拼子串    「张三」 ← "zhangsan" / "zhang"
///   3. 首字母子串  「张三」 ← "zs"
///
/// 全部大小写不敏感；[keyword] 为空视为全部命中（刚敲下 @ 时展示全部候选）。
bool mentionMatches(String displayName, String keyword) {
  final kw = keyword.trim().toLowerCase();
  if (kw.isEmpty) return true;

  final name = displayName.trim();
  if (name.isEmpty) return false;

  if (name.toLowerCase().contains(kw)) return true;

  // 纯 ASCII 昵称没有拼音可言，跳过转换（getPinyinE 对英文会原样返回，
  // 再匹配一次纯属浪费）。
  if (!_hasCjk(name)) return false;

  if (_fullPinyin(name).contains(kw)) return true;
  if (_initials(name).contains(kw)) return true;

  return false;
}

/// 全拼（无声调、无分隔符）：「张三」→ "zhangsan"
String _fullPinyin(String name) {
  try {
    return PinyinHelper.getPinyinE(
      name,
      separator: '',
      format: PinyinFormat.WITHOUT_TONE,
    ).toLowerCase();
  } catch (_) {
    // 生僻字/异常字符转换失败不应让整个搜索崩掉，降级为不匹配这一路
    return '';
  }
}

/// 首字母：「张三」→ "zs"
String _initials(String name) {
  try {
    return PinyinHelper.getShortPinyin(name).toLowerCase();
  } catch (_) {
    return '';
  }
}

/// 是否含中日韩统一表意文字（决定要不要走拼音转换）。
bool _hasCjk(String s) {
  for (final c in s.runes) {
    if (c >= 0x4E00 && c <= 0x9FFF) return true;
  }
  return false;
}

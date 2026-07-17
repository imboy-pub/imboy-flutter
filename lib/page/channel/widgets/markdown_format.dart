/// 频道撰写页「格式工具条」的纯 markdown 插入逻辑（方案三 D2）。
///
/// 这些函数只做字符串 + 光标数学，不碰 Flutter widget / i18n，方便单测覆盖。
/// 每个函数返回 `(text, selection)`：调用方直接写回
/// `controller.value = TextEditingValue(text:, selection:)`。
///
/// ponytail: 为保持简单，包裹/前缀**不做 toggle**（已加粗再点不会取消）——
/// 撰写场景重复标记极少见，真需要 toggle 再加。
library;

import 'package:flutter/widgets.dart' show TextSelection;

typedef MarkdownEdit = ({String text, TextSelection selection});

/// 归一化选区：非法（offset < 0）时退化为文末光标，越界钳制到 [0, len]。
({int start, int end}) _range(String text, TextSelection sel) {
  if (!sel.isValid) return (start: text.length, end: text.length);
  return (
    start: sel.start.clamp(0, text.length),
    end: sel.end.clamp(0, text.length),
  );
}

/// 行内包裹（加粗 `**` / 斜体 `*` / 删除线 `~~` / 行内代码 `` ` ``）。
///
/// - 有选区：用 [marker] 包裹选区，光标落在包裹后文本末尾。
/// - 无选区：插入 `marker+marker`，光标置于中间（等待用户输入）。
MarkdownEdit applyInlineWrap(String text, TextSelection sel, String marker) {
  final (:start, :end) = _range(text, sel);
  final before = text.substring(0, start);
  final selected = text.substring(start, end);
  final after = text.substring(end);
  final newText = '$before$marker$selected$marker$after';

  if (start == end) {
    // 无选区：光标落在两个 marker 之间。
    final caret = start + marker.length;
    return (text: newText, selection: TextSelection.collapsed(offset: caret));
  }
  // 有选区：光标落在整段包裹文本末尾。
  final caret = start + marker.length + selected.length + marker.length;
  return (text: newText, selection: TextSelection.collapsed(offset: caret));
}

/// 行级前缀（标题 `# `/`## `/`### `、无序列表 `- `、引用 `> `）。
///
/// 作用于光标所在行行首插入 [prefix]，选区两端整体右移 [prefix] 长度。
///
/// ponytail: 不检测/去重已有前缀，直接插入——重复点会叠加前缀，撰写场景可接受。
MarkdownEdit applyLinePrefix(String text, TextSelection sel, String prefix) {
  final (:start, :end) = _range(text, sel);
  // 光标所在行行首：从光标前一位往回找最近换行，其后即行首（无换行则为 0）。
  // start == 0 时 start-1 为 -1，lastIndexOf 会抛 RangeError，需直接取行首 0。
  final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
  final newText =
      '${text.substring(0, lineStart)}$prefix'
      '${text.substring(lineStart)}';

  // 行首在所有 >= lineStart 的偏移之前插入，故这些偏移整体右移。
  int shift(int offset) =>
      offset >= lineStart ? offset + prefix.length : offset;
  return (
    text: newText,
    selection: TextSelection(
      baseOffset: shift(sel.baseOffset < 0 ? start : sel.baseOffset),
      extentOffset: shift(sel.extentOffset < 0 ? end : sel.extentOffset),
    ),
  );
}

/// 插入链接模板 `[链接文字](url)`，光标选中 url 占位符待用户覆盖填写。
///
/// 有选区时用选中文字当链接文字；否则用 [linkTextPlaceholder]。
MarkdownEdit applyLink(
  String text,
  TextSelection sel, {
  String linkTextPlaceholder = 'link',
  String urlPlaceholder = 'url',
}) {
  final (:start, :end) = _range(text, sel);
  final selected = text.substring(start, end);
  final linkText = selected.isEmpty ? linkTextPlaceholder : selected;
  final template = '[$linkText]($urlPlaceholder)';
  final newText = '${text.substring(0, start)}$template${text.substring(end)}';

  // url 占位符落点：'[' + linkText + '](' 之后。
  final urlStart = start + 1 + linkText.length + 2;
  final urlEnd = urlStart + urlPlaceholder.length;
  return (
    text: newText,
    selection: TextSelection(baseOffset: urlStart, extentOffset: urlEnd),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:imboy/component/helper/func.dart'
    show cachedImageProvider, iPrint;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 频道富文本渲染基础（方案三 D1）。
///
/// 频道图文正文采用 Markdown 表示——纯文本即合法 markdown，旧消息渲染不变
/// （向后兼容）。样式全部走 token（AppColors / FontSizeType），暗/亮双色正确。
/// 不引入新依赖：复用项目已有 `flutter_markdown_plus`。

/// 频道 markdown 样式表：从主题派生骨架（列表缩进/代码块/水平线等），
/// 再用 token 覆盖颜色与字号。正文与原 SelectableText 视觉一致（body 17 / height 1.5）。
MarkdownStyleSheet channelMarkdownStyle(BuildContext context) {
  final brightness = Theme.of(context).brightness;
  final textColor = AppColors.getTextColor(brightness);
  final secondary = AppColors.getTextColor(brightness, isSecondary: true);
  final separator = AppColors.getIosSeparator(brightness);

  final body = context
      .textStyle(FontSizeType.body, color: textColor)
      .copyWith(height: 1.5);

  return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
    p: body,
    a: context
        .textStyle(FontSizeType.body, color: AppColors.primary)
        .copyWith(decoration: TextDecoration.underline),
    strong: body.copyWith(fontWeight: FontWeight.w700),
    em: body.copyWith(fontStyle: FontStyle.italic),
    h1: context.textStyle(
      FontSizeType.title,
      color: textColor,
      fontWeight: FontWeight.w600,
    ),
    h2: context.textStyle(
      FontSizeType.extraLarge,
      color: textColor,
      fontWeight: FontWeight.w600,
    ),
    h3: context.textStyle(
      FontSizeType.large,
      color: textColor,
      fontWeight: FontWeight.w600,
    ),
    listBullet: body,
    blockquote: context
        .textStyle(FontSizeType.body, color: secondary)
        .copyWith(height: 1.5),
    blockquoteDecoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.06),
      border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
    ),
    code: context
        .textStyle(FontSizeType.small, color: textColor)
        .copyWith(
          fontFamily: 'monospace',
          backgroundColor: separator.withValues(alpha: 0.2),
        ),
    codeblockDecoration: BoxDecoration(
      color: separator.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

/// 频道 markdown 正文渲染（内联非滚动版，配 CustomScrollView/Column 使用）。
///
/// - 链接经 url_launcher 外部打开（无法打开则仅 iPrint，不崩）。
/// - 图片语法 `![](uri)` 经 cachedImageProvider（内部 AssetsService.viewUrl 授权）。
Widget channelMarkdownBody(
  BuildContext context,
  String data, {
  bool selectable = false,
}) {
  return MarkdownBody(
    data: data,
    selectable: selectable,
    styleSheet: channelMarkdownStyle(context),
    onTapLink: (text, href, title) => _openLink(href),
    imageBuilder: _markdownImage,
  );
}

Future<void> _openLink(String? href) async {
  if (href == null || href.isEmpty) return;
  final uri = Uri.tryParse(href);
  if (uri == null) {
    iPrint('[channel_markdown] 无效链接: $href');
    return;
  }
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    iPrint('[channel_markdown] 无法打开链接: $href');
  }
}

/// 正文图片：http(s) 经 cachedImageProvider 授权直传；其余（非本批重点）不渲染。
Widget _markdownImage(Uri uri, String? title, String? alt) {
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    return Image(image: cachedImageProvider(uri.toString(), w: 600));
  }
  // ponytail: 非 http 图片（相对路径/asset）不是本批重点，直接跳过不渲染。
  return const SizedBox.shrink();
}

/// 把 markdown 语法剥成纯文本，用于 feed 卡摘要（去掉裸 `**` `#` `>` `-` `[]()` 等噪音）。
///
/// ponytail: 面向摘要的启发式剥离，非完整 markdown 解析。已知上限——
/// 词内下划线（foo_bar）会被当强调标记去掉；摘要场景可接受，需精确渲染走
/// [channelMarkdownBody]。
String stripMarkdown(String input) {
  var s = input;
  // 图片 ![alt](url) -> alt（须在链接之前处理）
  s = s.replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), (m) => m[1] ?? '');
  // 链接 [text](url) -> text
  s = s.replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1] ?? '');
  // 行内代码 `code` -> code
  s = s.replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m[1] ?? '');
  // 强调 / 删除线标记：*** ** * ___ __ _ ~~
  s = s.replaceAll(RegExp(r'\*{1,3}|_{1,3}|~~'), '');
  // 逐行剥离行首标记
  final lines = s.split('\n').map((line) {
    // 纯分隔线（--- *** ___）整行去掉
    if (RegExp(r'^\s*([-*_])\1{2,}\s*$').hasMatch(line)) return '';
    var l = line;
    l = l.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), ''); // 标题
    l = l.replaceFirst(RegExp(r'^\s{0,3}>\s?'), ''); // 引用
    l = l.replaceFirst(RegExp(r'^\s{0,3}([-*+]|\d+\.)\s+'), ''); // 列表
    return l;
  });
  return lines.join('\n').trim();
}

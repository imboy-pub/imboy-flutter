/// 全仓守门：纯图标可点控件必须有读屏标签（DESIGN.md 11.4）。
///
/// 这类缺口是一个个页面独立长出来的——写按钮时图标一目了然，很容易忘记
/// 读屏用户只会听到一个"按钮"。逐页 review 抓不干净，所以用一条扫描断言
/// 兜住：新增没有标签的纯图标按钮会让这条直接红。
///
/// 判定口径（保守，宁可漏报不误报）：
///   - 只看 IconButton / CupertinoButton
///   - 块内有 Icon( 且没有任何 Text( —— 有文字的不算纯图标
///   - 块内有 semanticLabel / tooltip / Semantics( 的算已处理
///   - **往上看 8 行**：父层包了 Semantics 的也算已处理。
///     少了这一条会误报 15 处（chat_input、contact_page 等都是父层包的）。
///
/// 已知豁免见 [_allowlist]，每条都写了原因。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 暂时豁免的位置，key 是 `路径:行号` 之外的稳定标识（文件路径 + 图标名）。
///
/// 这些的标签需要页面特定措辞，不能套通用词，留给对应页面的整改：
/// 比如 set_region 的 refresh 图标实际是"恢复初始"，套"刷新"是错的。
const _allowlist = <String>{
  'lib/page/personal_info/set_region/set_region_page.dart|refresh',
  'lib/page/mine/user_collect/user_collect_page.dart|xmark_circle',
  'lib/page/mine/user_collect/user_collect_page.dart|square_list',
  'lib/page/mine/user_collect/user_collect_page.dart|tag',
  'lib/page/group/tag/group_tag_page.dart|delete',
  'lib/page/user_tag/contact_tag_list/contact_tag_list_page.dart|add',
  'lib/page/mine/feedback/feedback_page.dart|add',
  'lib/page/wallet/wallet_page.dart|add_circled',
  'lib/page/contact/new_friend/new_friend_page.dart|person_add',
  'lib/page/chat/widget/chat_input.dart|at',
  'lib/page/chat/widget/chat_input.dart|arrow_up',
  'lib/page/passport/login_page.dart|?',
};

final _ctrl = RegExp(r'\b(IconButton|CupertinoButton)\s*\(');
final _handled = RegExp(r'semanticLabel|tooltip|Semantics\(');
final _iconName = RegExp(r'Icon\(\s*(?:CupertinoIcons|Icons)\.([A-Za-z0-9_]+)');

void main() {
  test('纯图标按钮都有读屏标签', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsStringSync().split('\n');

      for (var i = 0; i < lines.length; i++) {
        if (!_ctrl.hasMatch(lines[i])) continue;

        var depth = 0;
        final blk = <String>[];
        for (var j = i; j < lines.length && j < i + 40; j++) {
          blk.add(lines[j]);
          depth += '('.allMatches(lines[j]).length;
          depth -= ')'.allMatches(lines[j]).length;
          if (j > i && depth <= 0) break;
        }
        final body = blk.join('\n');
        if (!body.contains('Icon(')) continue;
        if (body.contains('Text(')) continue;
        if (_handled.hasMatch(body)) continue;

        final above = lines.sublist(i - 8 < 0 ? 0 : i - 8, i).join('\n');
        if (above.contains('Semantics(')) continue;

        final icon = _iconName.firstMatch(body)?.group(1) ?? '?';
        if (_allowlist.contains('${entity.path}|$icon')) continue;

        offenders.add('${entity.path}:${i + 1}  ($icon)');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '这些纯图标按钮读屏只会念出「按钮」，用户不知道按下去干什么。\n'
          '补 semanticLabel，或在 _allowlist 里写明为什么暂不补：\n'
          '${offenders.join('\n')}',
    );
  });
}

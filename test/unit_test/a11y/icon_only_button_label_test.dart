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
final _navContext = RegExp(
  r'actions:|leading:|trailing:|AppBar|NavigationBar|BottomNav|tabBar',
);
final _materialIcon = RegExp(r'(?<!\w)Icons\.([A-Za-z0-9_]+)(?![A-Za-z0-9_])');

/// 「统一 CupertinoIcons」用例的存量豁免，key 为 `文件路径|图标名`
///（不含行号，行号会随编辑漂移）。
///
/// 收录规则：CupertinoIcons 无对等设计资源（如 emoji 分类族、drag_handle、
/// verified），或图标更换属于设计统一决策、不应由测试红绿倒逼。
/// 豁免只认存量——新增高可见 Material 图标会再次报红。
const _cupertinoExemptions = <String>{
  'lib/page/channel/channel_admin_page.dart|error_outline',
  'lib/page/channel/channel_comment_page.dart|cloud_off_outlined',
  'lib/page/channel/channel_detail_page.dart|more_vert',
  'lib/page/channel/channel_discover_page.dart|campaign',
  'lib/page/channel/channel_discover_page.dart|clear',
  'lib/page/channel/channel_discover_page.dart|verified',
  'lib/page/channel/channel_invitation_page.dart|open_in_new',
  'lib/page/channel/channel_list_page.dart|more_vert',
  'lib/page/channel/channel_subscriber_page.dart|clear',
  'lib/page/chat/widget/chat_input.dart|coffee_outlined',
  'lib/page/chat/widget/chat_input.dart|cruelty_free_outlined',
  'lib/page/chat/widget/chat_input.dart|directions_car_filled_outlined',
  'lib/page/chat/widget/chat_input.dart|emoji_emotions_outlined',
  'lib/page/chat/widget/chat_input.dart|emoji_symbols_outlined',
  'lib/page/chat/widget/chat_input.dart|lightbulb_outline',
  'lib/page/chat/widget/chat_input.dart|sports_soccer_outlined',
  'lib/page/chat/widget/quick_reply_manage_page.dart|drag_handle',
  'lib/page/group/album/group_album_page.dart|add_photo_alternate_outlined',
  'lib/page/group/album/group_album_photo_page.dart|cloud_off',
  'lib/page/group/file/group_file_audio_preview_page.dart|audiotrack',
  'lib/page/group/file/group_file_page.dart|broken_image_outlined',
  'lib/page/group/vote/group_vote_detail_page.dart|cloud_off',
  'lib/page/passport/passport_notifier.dart|keyboard_arrow_left',
  'lib/page/search/search_chat_page.dart|lock_outline',
  'lib/page/live_room/live_room_list/live_room_list_page.dart|circle',
  'lib/page/live_room/live_room_list/live_room_list_page.dart|live_tv',
  'lib/page/live_room/live_room_list/live_room_list_page.dart|navigate_next',
  'lib/page/live_room/subscriber/subscriber_page.dart|remove_red_eye',
  'lib/page/mine/user_collect/user_collect_detail_page.dart|more_horiz',
  'lib/page/mine/user_device/user_device_detail_page.dart|power_settings_new',
  'lib/page/personal_info/widget/more_page.dart|location_on_outlined',
  'lib/page/scanner/scanner_result_page.dart|keyboard_arrow_left',
  'lib/page/web_shell/web_nav_items_factory.dart|chat_bubble',
  'lib/page/web_shell/web_nav_items_factory.dart|chat_bubble_outline',
  'lib/page/web_shell/web_nav_items_factory.dart|people_alt',
  'lib/page/web_shell/web_nav_items_factory.dart|people_alt_outlined',
  // alipay_simulator：支付方式行是支付宝品牌隐喻（payment/credit_card/
  // 绿色能量 energy_savings_leaf），CupertinoIcons 无对等资源，更换图标
  // 会失真——页面为支付联调模拟器，非通用 UI。
  'lib/page/wallet/alipay_simulator.dart|payment',
  'lib/page/wallet/alipay_simulator.dart|credit_card',
  'lib/page/wallet/alipay_simulator.dart|energy_savings_leaf',
};

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

  test('高可见位置统一使用 CupertinoIcons', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsStringSync().split('\n');

      for (var i = 0; i < lines.length; i++) {
        if (!_materialIcon.hasMatch(lines[i])) continue;
        final start = i - 25 < 0 ? 0 : i - 25;
        final end = i + 3 > lines.length ? lines.length : i + 3;
        if (!_navContext.hasMatch(lines.sublist(start, end).join('\n'))) {
          continue;
        }

        for (final match in _materialIcon.allMatches(lines[i])) {
          if (_cupertinoExemptions.contains(
            '${entity.path}|${match.group(1)}',
          )) {
            continue;
          }
          offenders.add('${entity.path}:${i + 1} Icons.${match.group(1)}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '高可见导航/操作位置不得使用 Material Icons；请改为对应 CupertinoIcons：\n'
          '${offenders.join('\n')}',
    );
  });
}

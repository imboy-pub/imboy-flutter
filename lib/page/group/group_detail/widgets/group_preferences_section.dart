import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/page/group/group_role_rules.dart';
import 'package:imboy/page/personal_info/update/update_page.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

import '../group_detail_provider.dart';
import '../group_detail_service.dart';
import '../group_notice_disabled_tile.dart';

/// 偏好设置 Section（4）：群昵称 / 群备注 / 消息免打扰 / 群级 E2EE / 搜索聊天内容。
///
/// ENT-APP-02 等价拆分：自 group_detail_page.dart build 中「偏好设置 Section」
/// 机械搬运。页面级状态（免打扰/E2EE 旗标由 initData 回读写入）经构造参数
/// 注入，变更经回调上抛页面（setState/落库/回滚仍在页面，与原实现一致）。
class GroupPreferencesSection extends ConsumerWidget {
  const GroupPreferencesSection({
    super.key,
    required this.groupId,
    required this.title,
    required this.gidInt,
    required this.role,
    required this.noticeDisabled,
    required this.groupE2ee,
    required this.onNoticeDisabledChanged,
    required this.onEnableE2ee,
    this.options,
  });

  final String groupId;

  /// 页面构造参数 title（搜索 extra 的 peerTitle 原取 `widget.title`）。
  final String title;

  /// `int.tryParse(groupId) ?? 0`，由页面预计算（原 `_gidInt`）。
  final int gidInt;

  /// 页面当前 role（原 `state.role`，渲染时同值）。
  final int role;

  /// 页面回读的本地免打扰状态（原 `_noticeDisabled`）。
  final bool noticeDisabled;

  /// 页面回读的群级 E2EE 旗标（原 `_groupE2ee`）。
  final bool groupE2ee;

  /// 免打扰开关变化：页面实现 setState + KV 落库 + 失败回滚。
  final Future<void> Function(bool v) onNoticeDisabledChanged;

  /// E2EE 开启确认入口（页面 `_confirmEnableE2ee`）。
  final VoidCallback onEnableE2ee;

  /// 透传给 /search_chat 的 extra 字段（原 widget.options）。
  final Map<String, dynamic>? options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupDetailProvider);

    return ImBoySettingsSection(
      children: [
        ImBoySettingsTile(
          title: Text(t.group.groupAlias),
          trailing: Text(
            strEmpty(state.myGroupAlias)
                ? UserRepoLocal.to.current.nickname
                : state.myGroupAlias!,
            style: context.textStyle(
              FontSizeType.subheadline,
              color: AppColors.iosGray,
            ),
          ),
          // 复用通用文本编辑页 UpdatePage（callback 内落库）。
          // 原先推送的 /group/remark 是未注册路由，点击必抛 no-routes。
          onTap: () async {
            await Navigator.push(
              context,
              CupertinoPageRoute<void>(
                builder: (_) => UpdatePage(
                  title: t.group.groupAlias,
                  value: state.myGroupAlias ?? '',
                  field: 'input',
                  maxLength: 56,
                  callback: (val) async {
                    final ok = await GroupDetailService().updateMyGroupAlias(
                      groupId,
                      val,
                    );
                    if (ok) {
                      ref
                          .read(groupDetailProvider.notifier)
                          .setMyGroupAlias(val);
                    }
                    return ok;
                  },
                ),
              ),
            );
          },
        ),
        ImBoySettingsTile(
          title: Text(t.contact.remark),
          trailing: Text(
            strEmpty(state.groupRemark)
                ? state.group?.title ?? ''
                : state.groupRemark!,
            style: context.textStyle(
              FontSizeType.subheadline,
              color: AppColors.iosGray,
            ),
          ),
          // 同上：/group/remark 未注册，改用 UpdatePage。
          onTap: () async {
            await Navigator.push(
              context,
              CupertinoPageRoute<void>(
                builder: (_) => UpdatePage(
                  title: t.contact.remark,
                  value: state.groupRemark ?? '',
                  field: 'input',
                  maxLength: 56,
                  callback: (val) async {
                    final ok = await GroupApi().updateRemark(
                      gid: groupId,
                      remark: val,
                    );
                    if (ok) {
                      ref
                          .read(groupDetailProvider.notifier)
                          .setGroupRemark(val);
                    }
                    return ok;
                  },
                ),
              ),
            );
          },
        ),
        GroupNoticeDisabledTile(
          label: t.common.muteNotifications,
          value: noticeDisabled,
          onChanged: gidInt <= 0 ? null : onNoticeDisabledChanged,
        ),
        // 群级 E2EE：仅群主可开，0→1 单向不可撤销；成员只读展示状态。
        // 服务端关闭 E2EE（features.e2ee=false，硬闸档位）时整项隐藏：
        // 此时 set_e2ee_mode 会被服务端拒绝，入口没有意义。
        if (AppFeatureRegistry.isEnabled(FeatureKeys.e2ee))
          GroupNoticeDisabledTile(
            label: t.group.e2eeTitle,
            value: groupE2ee,
            onChanged: groupE2ee || !isGroupOwner(role) || gidInt <= 0
                ? null
                : (v) {
                    if (v) onEnableE2ee();
                  },
          ),
        ImBoySettingsTile(
          title: Text(t.common.searchChatContent),
          leading: const Icon(
            CupertinoIcons.search,
            color: AppColors.iosBlue,
            size: 20,
          ),
          onTap: () => context.push(
            '/search_chat',
            extra: {
              'type': 'C2G',
              'peerId': groupId,
              'peerTitle': title,
              'peerAvatar': options?['peerAvatar'],
              'peerSign': options?['peerSign'],
              'conversationUk3': options?['conversationUk3'],
            },
          ),
        ),
      ],
    );
  }
}

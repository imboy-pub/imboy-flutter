import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/store/model/denylist_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/user_denylist_repo_sqlite.dart';

import 'contact_setting_provider.dart';
import '../contact_setting_tag/contact_setting_tag_page.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 联系人设置页面
class ContactSettingPage extends ConsumerStatefulWidget {
  final String peerId; // 用户ID
  final String peerAccount;
  final String peerAvatar;
  final String peerTitle;
  final String peerNickname;
  final int peerGender;
  final String peerSign;
  final String peerRegion;
  final String peerSource;
  final String peerRemark;
  final String peerTag;

  const ContactSettingPage({
    super.key,
    required this.peerId,
    required this.peerAccount,
    required this.peerAvatar,
    required this.peerNickname,
    required this.peerGender,
    required this.peerTitle,
    required this.peerSign,
    required this.peerRegion,
    required this.peerSource,
    required this.peerRemark,
    required this.peerTag,
  });

  @override
  ConsumerState<ContactSettingPage> createState() => _ContactSettingPageState();
}

class _ContactSettingPageState extends ConsumerState<ContactSettingPage> {
  @override
  void initState() {
    super.initState();
    // 初始化数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactSettingProvider.notifier).initData(widget.peerId);
    });
  }

  /// 构建设置项卡片
  Widget _buildSettingCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.borderRadiusMedium,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: iconColor ?? Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建开关设置项
  Widget _buildSwitchCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool value,
    ValueChanged<bool>? onChanged,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建危险操作按钮
  Widget _buildDangerButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.borderRadiusMedium,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.error,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayRemark = widget.peerRemark.isEmpty
        ? widget.peerNickname
        : widget.peerRemark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20.0),
              topRight: Radius.circular(20.0),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部指示条
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: AppRadius.borderRadiusTiny,
                  ),
                ),

                // 警告图标
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: colorScheme.error,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 20),

                // 标题
                Text(
                  t.deleteContact,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 12),

                // 描述文字
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    t.tipDeleteContact(param: displayRemark),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 按钮区域
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      // 删除按钮
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop(); // 先关闭底部弹窗
                            EasyLoading.show(status: t.deleting);
                            bool res = await ref
                                .read(contactSettingProvider.notifier)
                                .deleteContact(widget.peerId);
                            EasyLoading.dismiss();
                            if (res) {
                              EasyLoading.showSuccess(t.tipSuccess);
                              if (mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  CupertinoPageRoute(
                                    builder: (context) =>
                                        const BottomNavigationPage(),
                                  ),
                                  (route) => false,
                                );
                              }
                            } else {
                              EasyLoading.showError(t.error);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.borderRadiusXLarge,
                            ),
                          ),
                          child: Text(
                            t.deleteContact,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 取消按钮
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.borderRadiusXLarge,
                            ),
                          ),
                          child: Text(
                            t.buttonCancel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(contactSettingProvider);

    return Scaffold(
      appBar: GlassAppBar(
        titleWidget: Text(
          t.profileSettings,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // 设置备注和标签
            _buildSettingCard(
              context: context,
              title: t.setParam(param: t.remarksTags),
              icon: Icons.edit_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => ContactSettingTagPage(
                      peerId: widget.peerId,
                      peerAvatar: widget.peerAvatar,
                      peerAccount: widget.peerAccount,
                      peerNickname: widget.peerNickname,
                      peerGender: widget.peerGender,
                      peerTitle: widget.peerTitle,
                      peerSign: widget.peerSign,
                      peerRegion: widget.peerRegion,
                      peerSource: widget.peerSource,
                      peerRemark: widget.peerRemark,
                      peerTag: widget.peerTag,
                      onRemarkChanged: (newRemark) {
                        ref
                            .read(contactSettingProvider.notifier)
                            .updateRemark(newRemark);
                      },
                    ),
                  ),
                );
              },
            ),

            // 推荐给朋友
            _buildSettingCard(
              context: context,
              title: t.recommendToFriend,
              icon: Icons.share_outlined,
              onTap: () async {
                // 推荐给朋友的逻辑
                EasyLoading.showInfo(t.featureInDevelopment);
              },
            ),

            const SizedBox(height: 16),

            // 加入黑名单开关
            _buildSwitchCard(
              context: context,
              title: t.addToDenylist,
              icon: Icons.block_outlined,
              iconColor: state.isInDenylist
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
              value: state.isInDenylist,
              // 切换开关：true 加入黑名单；false 移出黑名单
              onChanged: (val) async {
                EasyLoading.show(status: t.loading);
                final denylistRepo = UserDenylistRepo();
                bool res;
                if (val) {
                  // 加入黑名单
                  DenylistModel model = DenylistModel(
                    deniedUid: parseModelInt(widget.peerId),
                    nickname: widget.peerNickname,
                    account: widget.peerAccount,
                    remark: widget.peerRemark,
                    sign: widget.peerSign,
                    source: widget.peerSource,
                    avatar: widget.peerAvatar,
                    region: widget.peerRegion,
                    gender: widget.peerGender,
                    createdAt: DateTimeHelper.millisecond(),
                  );
                  await denylistRepo.insert(model);
                  res = true;
                } else {
                  // 移出黑名单
                  final count = await denylistRepo.delete(widget.peerId);
                  res = count > 0;
                }
                EasyLoading.dismiss();

                if (res) {
                  await ref
                      .read(contactSettingProvider.notifier)
                      .toggleDenylist(
                        peerId: widget.peerId,
                        addToDenylist: val,
                        peerData: {},
                      );
                  EasyLoading.showSuccess(
                    val ? t.addedToDenylist : t.removedFromDenylist,
                  );
                } else {
                  EasyLoading.showError(t.error);
                }
              },
            ),

            const SizedBox(height: 32),

            // 删除联系人按钮
            _buildDangerButton(
              context: context,
              title: t.deleteContact,
              icon: Icons.person_remove_outlined,
              onTap: () => _showDeleteConfirmation(context),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

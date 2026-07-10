import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/api/denylist_api.dart';
import 'package:imboy/store/api/report_api.dart';
import 'package:imboy/page/group/widgets/group_dialogs.dart';
import 'package:imboy/store/model/denylist_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/user_denylist_repo_sqlite.dart';

import 'contact_setting_provider.dart';
import '../contact_setting_tag/contact_setting_tag_page.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 联系人设置页面 - 像素级对齐 iOS 17 Premium 风格
class ContactSettingPage extends ConsumerStatefulWidget {
  final String peerId;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactSettingProvider.notifier).initData(widget.peerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactSettingProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.common.profileSettings,
      useLargeTitle: false,
      child: Column(
        children: [
          // 资料设置 Section
          ImBoySettingsSection(
            children: [
              ImBoySettingsTile(
                title: Text(t.main.setParam(param: t.contact.remarksTags)),
                leading: _buildIcon(Icons.edit_outlined, AppColors.iosBlue),
                onTap: () => Navigator.push(
                  context,
                  CupertinoPageRoute<dynamic>(
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
                      onRemarkChanged: (r) => ref
                          .read(contactSettingProvider.notifier)
                          .updateRemark(r),
                    ),
                  ),
                ),
              ),
              ImBoySettingsTile(
                title: Text(t.contact.recommendToFriend),
                leading: _buildIcon(Icons.share_outlined, AppColors.iosPurple),
                onTap: () => AppLoading.showInfo(t.common.featureInDevelopment),
              ),
            ],
          ),

          // 隐私 Section
          ImBoySettingsSection(
            header: Text(t.common.sectionPrivacySecurity.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(t.common.addToDenylist),
                leading: _buildIcon(
                  Icons.block_outlined,
                  state.isInDenylist
                      ? AppColors.getIosRed(brightness)
                      : AppColors.iosGray,
                ),
                trailing: CupertinoSwitch(
                  value: state.isInDenylist,
                  activeTrackColor: AppColors.getIosRed(brightness),
                  onChanged: (val) => _showDenylistConfirmation(context, val),
                ),
              ),
              ImBoySettingsTile(
                title: Text(t.complaint.complaint),
                leading: _buildIcon(
                  Icons.flag_outlined,
                  AppColors.getIosRed(brightness),
                ),
                onTap: () => _showReportDialog(context),
              ),
            ],
          ),

          // 操作 Section
          ImBoySettingsSection(
            children: [
              ImBoySettingsTile(
                title: Center(child: Text(t.common.deleteContact)),
                destructive: true,
                trailing: const SizedBox.shrink(),
                onTap: () => _showDeleteConfirmation(context),
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _showDenylistConfirmation(BuildContext context, bool val) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: val ? Text(t.common.addToDenylist) : null,
        content: Text(
          val
              ? t.common.addedToDenylistTips
              : t.common.confirmRemoveFromDenylist,
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _handleDenylistToggle(val);
            },
            child: Text(t.common.buttonConfirm),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDenylistToggle(bool val) async {
    AppLoading.show(status: t.common.loading);
    final api = DenylistApi();
    final denylistRepo = UserDenylistRepo();
    bool res;

    if (val) {
      // P0 修复：先调服务端 API，成功后再写本地 SQLite
      final apiResult = await api.add(deniedUserUid: widget.peerId);
      if (apiResult != null) {
        final model = DenylistModel(
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
        res = false;
      }
    } else {
      // P0 修复：先调服务端 API，成功后再删本地 SQLite
      final apiOk = await api.remove(deniedUserUid: widget.peerId);
      if (apiOk) {
        await denylistRepo.delete(widget.peerId);
        res = true;
      } else {
        res = false;
      }
    }

    AppLoading.dismiss();
    if (res) {
      await ref
          .read(contactSettingProvider.notifier)
          .toggleDenylist(
            peerId: widget.peerId,
            addToDenylist: val,
            peerData: {},
          );
      AppLoading.showSuccess(
        val ? t.common.addedToDenylist : t.common.removedFromDenylist,
      );
    } else {
      AppLoading.showError(t.common.error);
    }
  }

  /// 举报用户：复用 complaintReason 枚举与 ReportApi（targetType='user'）。
  void _showReportDialog(BuildContext context) {
    GroupDialogs.actionSheet(
      context,
      title: t.complaint.complaint,
      actions: [
        (
          label: t.complaintReason.spam,
          destructive: false,
          onPressed: () => _submitReport('spam'),
        ),
        (
          label: t.complaintReason.harassment,
          destructive: false,
          onPressed: () => _submitReport('harassment'),
        ),
        (
          label: t.complaintReason.inappropriate,
          destructive: false,
          onPressed: () => _submitReport('inappropriate'),
        ),
        (
          label: t.complaintReason.other,
          destructive: false,
          onPressed: () => _submitReport('other'),
        ),
      ],
    );
  }

  Future<void> _submitReport(String reason) async {
    if (await ReportApi().create(
      targetType: 'user',
      targetId: widget.peerId,
      reason: reason,
    )) {
      AppLoading.showSuccess(t.common.complaintSuccess);
    } else {
      AppLoading.showError(t.common.complaintFailed);
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    final displayRemark = widget.peerRemark.isEmpty
        ? widget.peerNickname
        : widget.peerRemark;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.common.deleteContact),
        content: Text(t.common.tipDeleteContact(param: displayRemark)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              AppLoading.show(status: t.main.deleting);
              if (await ref
                  .read(contactSettingProvider.notifier)
                  .deleteContact(widget.peerId)) {
                AppLoading.showSuccess(t.common.tipSuccess);
                if (context.mounted) context.go('/bottom_navigation');
              } else {
                AppLoading.showError(t.common.error);
              }
            },
            child: Text(t.common.buttonConfirm),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/capabilities/capability_locator.dart';
import 'package:imboy/capabilities/contracts/media_picker_capability.dart';
import 'package:share_plus/share_plus.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/detail_settings_tile.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'profile_provider.dart';
import 'widgets/profile_completion_widget.dart';
import 'widgets/profile_identity_header.dart';

/// 个人资料页面 - iOS 17 Premium 风格重构
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  /// 跳到子页编辑，回来后重新读一次本地用户数据。
  ///
  /// 子页（昵称/性别/地区/隐私）通过 `UserProfileService.updateField` 保存，
  /// 成功后会写 `UserRepoLocal`，但本页 state 是进页时的快照，不会自己更新 ——
  /// 于是出现「保存成功、返回后还是旧值，必须手动点刷新」（QA#41）。
  /// 同页的生日走 modal 不经路由，所以一直是正常的，正好是对照组。
  Future<void> _pushThenReload(String location) async {
    await context.push(location);
    if (!mounted) return;
    ref.read(profileProvider.notifier).refreshUserData();
  }

  /// 完善建议 chip → 对应编辑入口。
  /// 走路由的复用 [_pushThenReload]（含回来后刷新，见 QA#41）；
  /// 头像/签名/生日本来就是本页 modal，直接调既有方法。
  void _openSuggestion(String key) {
    switch (key) {
      case 'avatar':
        _editAvatar(context, ref.read(profileProvider.notifier));
      case 'nickname':
        _pushThenReload('/personal_info/set_nickname');
      case 'gender':
        _pushThenReload('/personal_info/set_gender');
      case 'region':
        _pushThenReload('/personal_info/set_region');
      case 'signature':
        _editSignature(context);
      case 'birthday':
        _editBirthday(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final profileNotifier = ref.read(profileProvider.notifier);

    return IosPageTemplate(
      title: t.common.personalInfo,
      useLargeTitle: false,
      actions: [
        IconButton(
          onPressed: profileState.isLoading
              ? null
              : () => profileNotifier.refreshUserData(),
          icon: profileState.isLoading
              ? const CupertinoActivityIndicator(radius: 10)
              : const Icon(CupertinoIcons.refresh, size: 20),
          tooltip: t.groupList.refresh,
        ),
        _buildMenuButton(context, profileState),
      ],
      slivers: [
        // 顶部头像卡片
        SliverToBoxAdapter(
          child: ProfileIdentityHeader(
            state: profileState,
            onPreviewAvatar: () => _previewAvatar(context, profileState.avatar),
            onEditAvatar: () => _editAvatar(context, profileNotifier),
            onEditBackground: () => _editBackground(context),
          ),
        ),

        // 完善度进度
        SliverToBoxAdapter(
          child: ProfileCompletionWidget(onSuggestionTap: _openSuggestion),
        ),

        // 基本信息
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            header: Text(t.common.basicInfo.toUpperCase()),
            children: [
              DetailSettingsTile(
                title: Text(t.account.nickname),
                value: profileState.nickname.isEmpty
                    ? t.common.notSet
                    : profileState.nickname,
                onTap: () => _pushThenReload('/personal_info/set_nickname'),
              ),
              DetailSettingsTile(
                title: Text(t.account.gender),
                value: profileNotifier.getGenderText(profileState.gender),
                onTap: () => _pushThenReload('/personal_info/set_gender'),
              ),
              DetailSettingsTile(
                title: Text(t.account.birthday),
                value: profileState.birthday.isEmpty
                    ? t.common.notSet
                    : profileState.birthday,
                onTap: () => _editBirthday(context),
              ),
              DetailSettingsTile(
                title: Text(t.account.region),
                value: profileNotifier.formatRegion(profileState.region),
                onTap: () => _pushThenReload('/personal_info/set_region'),
              ),
            ],
          ),
        ),

        // 联系信息
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            header: Text(t.common.contactInfo.toUpperCase()),
            children: [
              DetailSettingsTile(
                title: Text(t.account.email),
                value: profileState.email.isEmpty
                    ? t.common.notSet
                    : profileState.email,
              ),
              DetailSettingsTile(
                title: Text(t.account.mobile),
                value: profileState.mobile.isEmpty
                    ? t.common.notSet
                    : profileState.mobile,
              ),
            ],
          ),
        ),

        // 个人展示
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            header: Text(t.common.personalDisplay.toUpperCase()),
            children: [
              DetailSettingsTile(
                title: Text(t.common.personalSignature),
                subtitle: Text(
                  profileState.signature.isEmpty
                      ? t.common.notSet
                      : profileState.signature,
                ),
                onTap: () => _editSignature(context),
              ),
              DetailSettingsTile(
                title: Text(t.common.personalBackground),
                trailing: const Icon(
                  CupertinoIcons.photo,
                  size: 18,
                  color: AppColors.iosGray,
                ),
                onTap: () => _editBackground(context),
              ),
            ],
          ),
        ),

        // 更多信息
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            header: Text(t.common.extendedInfo.toUpperCase()),
            children: [
              DetailSettingsTile(
                title: Text(t.common.profession),
                value: profileState.profession.isEmpty
                    ? t.common.notSet
                    : profileState.profession,
                onTap: () => _editProfession(context),
              ),
              DetailSettingsTile(
                title: Text(t.main.school),
                value: profileState.school.isEmpty
                    ? t.common.notSet
                    : profileState.school,
                onTap: () => _editSchool(context),
              ),
              DetailSettingsTile(
                title: Text(t.main.hobbiesAndInterests),
                value: profileState.interests.isEmpty
                    ? t.common.notSet
                    : profileState.interests,
                onTap: () => _editInterests(context),
              ),
            ],
          ),
        ),

        // 功能
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.large,
              AppSpacing.regular,
              AppSpacing.xxLarge,
            ),
            children: [
              DetailSettingsTile(
                title: Text(t.account.myQRCode),
                leading: Icon(
                  CupertinoIcons.qrcode,
                  color: AppColors.getTextColor(
                    Theme.of(context).brightness,
                    isSecondary: true,
                  ),
                  size: AppSizes.iconSizeMedium,
                ),
                onTap: () => context.push('/qrcode/user'),
              ),
              DetailSettingsTile(
                title: Text(t.common.privacySettings),
                leading: Icon(
                  CupertinoIcons.shield,
                  color: AppColors.getTextColor(
                    Theme.of(context).brightness,
                    isSecondary: true,
                  ),
                  size: AppSizes.iconSizeMedium,
                ),
                onTap: () => _pushThenReload('/personal_info/privacy_settings'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuButton(BuildContext context, ProfileState profileState) {
    return PopupMenuButton<String>(
      icon: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
      onSelected: (value) {
        if (value == 'share') {
          _shareProfile();
        } else if (value == 'export') {
          _exportProfile();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              const Icon(CupertinoIcons.share, size: 18),
              AppSpacing.horizontalMedium,
              Text(t.common.profileShareProfile),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              const Icon(CupertinoIcons.cloud_download, size: 18),
              AppSpacing.horizontalMedium,
              Text(t.chat.profileExportProfile),
            ],
          ),
        ),
      ],
    );
  }

  void _editAvatar(BuildContext context, ProfileNotifier profileNotifier) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final file = await profileNotifier.pickCamera(context);
              if (file != null) await _uploadAvatar(file);
            },
            child: Text(t.main.takePhoto),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final file = await profileNotifier.pickImage(context);
              if (file != null) await _uploadAvatar(file);
            },
            child: Text(t.main.selectFromAlbum),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: Text(t.common.buttonCancel),
        ),
      ),
    );
  }

  void _previewAvatar(BuildContext context, String avatarUrl) {
    if (avatarUrl.isEmpty) return;
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          alignment: Alignment.center,
          color: AppColors.transparent,
          child: Avatar(
            imgUri: avatarUrl,
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.width * 0.8,
          ),
        ),
      ),
    );
  }

  void _editBirthday(BuildContext context) {
    final currentBirthday = UserRepoLocal.to.current.birthday;
    DateTime initialDate = currentBirthday.isNotEmpty
        ? (DateTime.tryParse(currentBirthday) ?? DateTime(1990, 1, 1))
        : DateTime(1990, 1, 1);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        DateTime selectedDate = initialDate;
        return Container(
          height: 300,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.getIosSeparator(
                        Theme.of(context).brightness,
                      ).withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(t.common.cancel),
                    ),
                    Text(
                      t.account.birthday,
                      style: context.textStyle(
                        FontSizeType.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final birthdayStr =
                            "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
                        final success = await ref
                            .read(profileProvider.notifier)
                            .changeInfo({
                              "field": "birthday",
                              "value": birthdayStr,
                            });
                        if (success) {
                          final payload = UserRepoLocal.to.current.toMap();
                          payload['birthday'] = birthdayStr;
                          UserRepoLocal.to.changeInfo(payload);
                        } else {
                          AppLoading.showError(t.common.saveFailed);
                        }
                      },
                      child: Text(
                        t.common.confirm,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  minimumDate: DateTime(1900, 1, 1),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (d) => selectedDate = d,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editSignature(BuildContext context) {
    final currentSign = UserRepoLocal.to.current.sign;
    final controller = TextEditingController(text: currentSign);
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.account.signature),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            enableSuggestions: false,
            autocorrect: false,
            controller: controller,
            maxLength: 100,
            maxLines: 3,
            placeholder: t.chat.pleaseEnterSignature,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              final newSign = controller.text.trim();
              if (newSign == currentSign) return;
              final success = await ref
                  .read(profileProvider.notifier)
                  .changeInfo({"field": "sign", "value": newSign});
              if (success) {
                final payload = UserRepoLocal.to.current.toMap();
                payload['sign'] = newSign;
                UserRepoLocal.to.changeInfo(payload);
              } else {
                AppLoading.showError(t.common.saveFailed);
              }
            },
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
  }

  void _editBackground(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              if (!context.mounted) return;
              final media = await CapabilityLocator.I
                  .get<MediaPickerCapability>()
                  .pickSingle(context, MediaType.image);
              if (media != null) await _uploadAndSetBackground(media.path);
            },
            child: Text(t.main.chooseFromAlbum),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.common.cancel),
        ),
      ),
    );
  }

  Future<void> _uploadAvatar(File file) async {
    AppLoading.show(status: t.common.uploading);
    if (await ref.read(profileProvider.notifier).uploadAvatar(file)) {
      AppLoading.showSuccess(t.common.uploadSuccess);
    } else {
      AppLoading.showError(t.common.uploadFailed);
    }
    AppLoading.dismiss();
  }

  Future<void> _uploadAndSetBackground(String path) async {
    AppLoading.show(status: t.common.uploading);
    if (await ref.read(profileProvider.notifier).uploadBackground(path)) {
      AppLoading.showSuccess(t.common.uploadSuccess);
    } else {
      AppLoading.showError(t.common.uploadFailed);
    }
    AppLoading.dismiss();
  }

  void _editProfession(BuildContext context) => _showTextEdit(
    t.common.profession,
    UserRepoLocal.to.current.profession,
    'profession',
  );
  void _editSchool(BuildContext context) =>
      _showTextEdit(t.main.school, UserRepoLocal.to.current.school, 'school');
  void _editInterests(BuildContext context) => _showTextEdit(
    t.main.interests,
    UserRepoLocal.to.current.interests,
    'interests',
    maxLines: 2,
  );

  void _showTextEdit(
    String title,
    String current,
    String field, {
    int maxLines = 1,
  }) {
    final controller = TextEditingController(text: current);
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            enableSuggestions: false,
            autocorrect: false,
            controller: controller,
            maxLines: maxLines,
            placeholder: title,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              final val = controller.text.trim();
              if (val == current) return;
              final success = await ref
                  .read(profileProvider.notifier)
                  .changeInfo({"field": field, "value": val});
              if (success) {
                final payload = UserRepoLocal.to.current.toMap();
                payload[field] = val;
                UserRepoLocal.to.changeInfo(payload);
              } else {
                AppLoading.showError(t.common.saveFailed);
              }
            },
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
  }

  void _shareProfile() async {
    final user = UserRepoLocal.to.current;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '${t.account.nickname}: ${user.nickname}\nID: ${user.account}',
          subject: t.account.profile,
        ),
      );
    } catch (_) {
      AppLoading.showError(t.common.shareFailed);
    }
  }

  void _exportProfile() {
    final user = UserRepoLocal.to.current;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(t.chat.exportProfile),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _exportToClipboard(user.toJson().toString(), 'JSON');
            },
            child: const Text('JSON'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _exportToClipboard(
                "${user.nickname}\nID: ${user.account}",
                'TXT',
              );
            },
            child: const Text('TXT'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.common.cancel),
        ),
      ),
    );
  }

  void _exportToClipboard(String content, String format) async {
    await Clipboard.setData(ClipboardData(text: content));
    AppLoading.showSuccess(
      t.common.exportSuccessThenCopiedToClipboard(param: format),
    );
  }
}

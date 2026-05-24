import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/qrcode/qrcode_page.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'profile_provider.dart';
import 'widgets/profile_completion_widget.dart';

/// 个人资料页面 - iOS 17 Premium 风格重构
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final profileNotifier = ref.read(profileProvider.notifier);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.common.personalInfo,
      actions: [
        IconButton(
          onPressed: profileState.isLoading
              ? null
              : () => profileNotifier.refreshUserData(),
          icon: profileState.isLoading
              ? const CupertinoActivityIndicator(radius: 10)
              : const Icon(CupertinoIcons.refresh, size: 20),
        ),
        _buildMenuButton(context, profileState),
      ],
      slivers: [
        // 顶部头像卡片
        SliverToBoxAdapter(
          child: _buildAvatarHeader(
            context,
            profileState,
            profileNotifier,
            brightness,
          ),
        ),

        // 完善度进度
        const SliverToBoxAdapter(child: ProfileCompletionWidget()),

        // 基本信息
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            header: Text(t.common.basicInfo.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(t.account.nickname),
                trailing: Text(
                  profileState.nickname.isEmpty
                      ? t.common.notSet
                      : profileState.nickname,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.iosGray,
                  ),
                ),
                onTap: () => context.push('/personal_info/set_nickname'),
              ),
              ImBoySettingsTile(
                title: Text(t.account.gender),
                trailing: Text(
                  profileNotifier.getGenderText(profileState.gender),
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.iosGray,
                  ),
                ),
                onTap: () => context.push('/personal_info/set_gender'),
              ),
              ImBoySettingsTile(
                title: Text(t.account.birthday),
                trailing: Text(
                  profileState.birthday.isEmpty
                      ? t.common.notSet
                      : profileState.birthday,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.iosGray,
                  ),
                ),
                onTap: () => _editBirthday(context),
              ),
              ImBoySettingsTile(
                title: Text(t.account.region),
                trailing: Text(
                  profileNotifier.formatRegion(profileState.region),
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.iosGray,
                  ),
                ),
                onTap: () => context.push('/personal_info/set_region'),
              ),
            ],
          ),
        ),

        // 联系信息
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            header: Text(t.common.contactInfo.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(t.account.email),
                trailing: Text(
                  profileState.email.isEmpty
                      ? t.common.notSet
                      : profileState.email,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.iosGray,
                  ),
                ),
              ),
              ImBoySettingsTile(
                title: Text(t.account.mobile),
                trailing: Text(
                  profileState.mobile.isEmpty
                      ? t.common.notSet
                      : profileState.mobile,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.iosGray,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 个人展示
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            header: Text(t.common.personalDisplay.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(t.common.personalSignature),
                subtitle: Text(
                  profileState.signature.isEmpty
                      ? t.common.notSet
                      : profileState.signature,
                  maxLines: 2,
                ),
                onTap: () => _editSignature(context),
              ),
              ImBoySettingsTile(
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
              ImBoySettingsTile(
                title: Text(t.common.profession),
                trailing: Text(
                  profileState.profession.isEmpty
                      ? t.common.notSet
                      : profileState.profession,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.iosGray,
                  ),
                ),
                onTap: () => _editProfession(context),
              ),
              ImBoySettingsTile(
                title: Text(t.main.school),
                trailing: Text(
                  profileState.school.isEmpty
                      ? t.common.notSet
                      : profileState.school,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.iosGray,
                  ),
                ),
                onTap: () => _editSchool(context),
              ),
              ImBoySettingsTile(
                title: Text(t.main.hobbiesAndInterests),
                trailing: Text(
                  profileState.interests.isEmpty
                      ? t.common.notSet
                      : profileState.interests,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.iosGray,
                  ),
                ),
                onTap: () => _editInterests(context),
              ),
            ],
          ),
        ),

        // 功能
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            margin: const EdgeInsets.fromLTRB(16, 24, 16, 40),
            children: [
              ImBoySettingsTile(
                title: Text(t.account.myQRCode),
                leading: const Icon(
                  CupertinoIcons.qrcode,
                  color: AppColors.iosBlue,
                  size: 22,
                ),
                onTap: () => Navigator.push(
                  context,
                  CupertinoPageRoute<void>(builder: (_) => UserQrCodePage()),
                ),
              ),
              ImBoySettingsTile(
                title: Text(t.common.privacySettings),
                leading: const Icon(
                  CupertinoIcons.shield_fill,
                  color: AppColors.iosGreen,
                  size: 22,
                ),
                onTap: () => context.push('/personal_info/privacy_settings'),
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
              const SizedBox(width: 12),
              Text(t.common.profileShareProfile),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              const Icon(CupertinoIcons.cloud_download, size: 18),
              const SizedBox(width: 12),
              Text(t.chat.profileExportProfile),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarHeader(
    BuildContext context,
    ProfileState state,
    ProfileNotifier notifier,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceGroupedTertiary : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _previewAvatar(context, state.avatar),
              child: Stack(
                children: [
                  Avatar(imgUri: state.avatar, width: 100, height: 100),
                  if (state.isUploading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: const Center(
                          child: CupertinoActivityIndicator(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              state.nickname.isEmpty ? t.common.nicknameNotSet : state.nickname,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ID: ${UserRepoLocal.to.current.account}',
              style: const TextStyle(fontSize: 14, color: AppColors.iosGray),
            ),
            const SizedBox(height: 20),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              color: AppColors.getIosBlue(brightness).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              onPressed: () => _editAvatar(context, notifier),
              child: Text(
                t.common.avatarEditAvatar,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getIosBlue(brightness),
                ),
              ),
            ),
          ],
        ),
      ),
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
              final file = await profileNotifier.pickImage(ImageSource.camera);
              if (file != null) await profileNotifier.uploadAvatar(file);
            },
            child: Text(t.main.takePhoto),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final file = await profileNotifier.pickImage(ImageSource.gallery);
              if (file != null) await profileNotifier.uploadAvatar(file);
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
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final birthdayStr =
                            "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
                        await ref.read(profileProvider.notifier).changeInfo({
                          "field": "birthday",
                          "value": birthdayStr,
                        });
                        final payload = UserRepoLocal.to.current.toMap();
                        payload['birthday'] = birthdayStr;
                        UserRepoLocal.to.changeInfo(payload);
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
              await ref.read(profileProvider.notifier).changeInfo({
                "field": "sign",
                "value": newSign,
              });
              final payload = UserRepoLocal.to.current.toMap();
              payload['sign'] = newSign;
              UserRepoLocal.to.changeInfo(payload);
            },
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
  }

  void _editBackground(BuildContext context) {
    final ImagePicker picker = ImagePicker();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final file = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 1920,
                maxHeight: 1080,
              );
              if (file != null) await _uploadAndSetBackground(file.path);
            },
            child: Text(t.main.chooseFromAlbum),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final file = await picker.pickImage(
                source: ImageSource.camera,
                maxWidth: 1920,
                maxHeight: 1080,
              );
              if (file != null) await _uploadAndSetBackground(file.path);
            },
            child: Text(t.main.takePhoto),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.common.cancel),
        ),
      ),
    );
  }

  Future<void> _uploadAndSetBackground(String path) async {
    EasyLoading.show(status: t.common.uploading);
    if (await ref.read(profileProvider.notifier).uploadBackground(path)) {
      EasyLoading.showSuccess(t.common.uploadSuccess);
    } else {
      EasyLoading.showError(t.common.uploadFailed);
    }
    EasyLoading.dismiss();
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
              await ref.read(profileProvider.notifier).changeInfo({
                "field": field,
                "value": val,
              });
              final payload = UserRepoLocal.to.current.toMap();
              payload[field] = val;
              UserRepoLocal.to.changeInfo(payload);
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
      EasyLoading.showError(t.common.shareFailed);
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
    EasyLoading.showSuccess(
      t.common.exportSuccessThenCopiedToClipboard(param: format),
    );
  }
}

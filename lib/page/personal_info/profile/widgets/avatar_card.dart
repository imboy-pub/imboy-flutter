import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/i18n/strings.g.dart';
import '../profile_provider.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 增强版头像卡片组件
class AvatarCard extends ConsumerWidget {
  const AvatarCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final profileNotifier = ref.read(profileProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: AppRadius.borderRadiusRegular,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 头像区域
          Stack(
            children: [
              // 头像容器
              GestureDetector(
                onTap: () => _previewAvatar(context, profileState.avatar),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.borderRadiusRegular,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadius.borderRadiusRegular,
                    child: profileState.avatar.isEmpty
                        ? Container(
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                          )
                        : Avatar(
                            imgUri: profileState.avatar,
                            width: 80,
                            height: 80,
                          ),
                  ),
                ),
              ),

              // 编辑按钮
              Positioned(
                right: -4,
                bottom: -4,
                child: GestureDetector(
                  onTap: () => _selectAvatarSource(context, profileNotifier),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),

              // 上传进度指示器
              if (profileState.isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: AppRadius.borderRadiusRegular,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 20),

          // 用户信息区域
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 昵称
                Text(
                  profileState.nickname.isEmpty
                      ? t.setNickname
                      : profileState.nickname,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: profileState.nickname.isEmpty
                        ? Colors.grey[400]
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),

                const SizedBox(height: 4),

                // 账号
                Text(
                  'ID: ${UserRepoLocal.to.current.account}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),

                const SizedBox(height: 8),

                // 个性签名
                Text(
                  profileState.signature.isEmpty
                      ? '设置个性签名，展示个人魅力'
                      : profileState.signature,
                  style: TextStyle(
                    fontSize: 14,
                    color: profileState.signature.isEmpty
                        ? Colors.grey[400]
                        : (isDark ? Colors.white70 : Colors.black54),
                    fontStyle: profileState.signature.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 箭头图标
          Icon(Icons.navigate_next, color: Colors.grey[400], size: 24),
        ],
      ),
    );
  }

  void _previewAvatar(BuildContext context, String avatarUrl) {
    if (avatarUrl.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.width * 0.8,
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderRadiusMedium,
              image: DecorationImage(
                image: cachedImageProvider(avatarUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectAvatarSource(
    BuildContext context,
    ProfileNotifier profileNotifier,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部指示器
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: AppRadius.borderRadiusTiny,
                ),
              ),

              // 拍照选项
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(t.takePhoto),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await profileNotifier.pickImage(
                    ImageSource.camera,
                  );
                  if (file != null) {
                    await profileNotifier.uploadAvatar(file);
                  }
                },
              ),

              // 相册选项
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(t.selectFromAlbum),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await profileNotifier.pickImage(
                    ImageSource.gallery,
                  );
                  if (file != null) {
                    await profileNotifier.uploadAvatar(file);
                  }
                },
              ),

              // 取消选项
              ListTile(
                leading: const Icon(Icons.close),
                title: Text(t.buttonCancel),
                onTap: () => Navigator.pop(context),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

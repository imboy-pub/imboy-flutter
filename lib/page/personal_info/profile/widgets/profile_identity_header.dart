import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/personal_info/profile/profile_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class ProfileIdentityHeader extends StatelessWidget {
  const ProfileIdentityHeader({
    super.key,
    required this.state,
    required this.onPreviewAvatar,
    required this.onEditAvatar,
    required this.onEditBackground,
  });
  final ProfileState state;
  final VoidCallback onPreviewAvatar, onEditAvatar, onEditBackground;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('profile-identity-header'),
    padding: const EdgeInsets.all(AppSpacing.regular),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.background.isNotEmpty) _cover(context),
        Row(
          children: [
            _avatar(context),
            AppSpacing.horizontalRegular,
            Expanded(child: _identity(context)),
            CupertinoButton(
              key: const ValueKey('profile-avatar-edit'),
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(AppSizes.touchTarget),
              onPressed: onEditAvatar,
              child: Icon(
                CupertinoIcons.camera,
                semanticLabel: context.t.common.avatarEditAvatar,
                size: AppSizes.iconSizeMedium,
                color: AppColors.getIosBlue(Theme.of(context).brightness),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _cover(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.regular),
    child: CupertinoButton(
      key: const ValueKey('profile-background-cover'),
      padding: EdgeInsets.zero,
      onPressed: onEditBackground,
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusCell,
        child: Image(
          image: cachedImageProvider(state.background, w: 800),
          width: double.infinity,
          height: AppSizes.avatarSizeXXLarge + AppSpacing.xxxLarge,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            height: AppSizes.avatarSizeXXLarge,
            color: AppColors.getSurfaceColor(Theme.of(context).brightness),
            alignment: Alignment.center,
            child: Text(context.t.common.personalBackground),
          ),
        ),
      ),
    ),
  );

  Widget _avatar(BuildContext context) => CupertinoButton(
    key: const ValueKey('profile-avatar-preview'),
    padding: EdgeInsets.zero,
    onPressed: state.avatar.isEmpty ? null : onPreviewAvatar,
    child: Semantics(
      label: context.t.account.avatar,
      button: true,
      child: Stack(
        children: [
          Avatar(
            imgUri: state.avatar,
            width: AppSizes.avatarSizeXLarge,
            height: AppSizes.avatarSizeXLarge,
          ),
          if (state.isUploading)
            const Positioned.fill(
              child: Center(child: CupertinoActivityIndicator()),
            ),
        ],
      ),
    ),
  );

  Widget _identity(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        state.nickname.isEmpty
            ? context.t.common.nicknameNotSet
            : state.nickname,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.textStyle(
          FontSizeType.title,
          fontWeight: FontWeight.w500,
          color: AppColors.getTextColor(Theme.of(context).brightness),
        ),
      ),
      AppSpacing.verticalTiny,
      Text(
        'ID: ${state.userModel.account}',
        style: context.textStyle(
          FontSizeType.small,
          color: AppColors.getTextColor(
            Theme.of(context).brightness,
            isSecondary: true,
          ),
        ),
      ),
    ],
  );
}

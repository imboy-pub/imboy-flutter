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
    required this.onOpenQrCode,
  });
  final ProfileState state;
  final VoidCallback onPreviewAvatar,
      onEditAvatar,
      onEditBackground,
      onOpenQrCode;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('profile-identity-header'),
    padding: const EdgeInsets.all(AppSpacing.regular),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (state.background.isNotEmpty) _cover(context),
        _avatar(context),
        AppSpacing.verticalRegular,
        _identity(context),
        AppSpacing.verticalRegular,
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.medium,
          runSpacing: AppSpacing.small,
          children: [
            _action(
              context,
              key: const ValueKey('profile-avatar-edit'),
              icon: CupertinoIcons.camera,
              label: context.t.common.avatarEditAvatar,
              onPressed: onEditAvatar,
            ),
            _action(
              context,
              key: const ValueKey('profile-qrcode'),
              icon: CupertinoIcons.qrcode,
              label: context.t.account.myQRCode,
              onPressed: onOpenQrCode,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _action(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final brightness = Theme.of(context).brightness;
    final color = AppColors.getIosBlue(brightness);
    return CupertinoButton(
      key: key,
      color: brightness == Brightness.dark
          ? AppColors.darkSurfaceGroupedTertiary
          : AppColors.lightSurface,
      borderRadius: AppRadius.borderRadiusCell,
      minimumSize: const Size.square(AppSizes.touchTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.medium,
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconSizeSmall, color: color),
          AppSpacing.horizontalSmall,
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.subheadline,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      child: Stack(
        children: [
          Avatar(
            imgUri: state.avatar,
            width: AppSizes.avatarSizeXXLarge,
            height: AppSizes.avatarSizeXXLarge,
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
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        state.nickname.isEmpty
            ? context.t.common.nicknameNotSet
            : state.nickname,
        textAlign: TextAlign.center,
        style: context.textStyle(
          FontSizeType.title,
          fontWeight: FontWeight.w500,
          color: AppColors.getTextColor(Theme.of(context).brightness),
        ),
      ),
      AppSpacing.verticalTiny,
      Text(
        'ID: ${state.userModel.account}',
        textAlign: TextAlign.center,
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

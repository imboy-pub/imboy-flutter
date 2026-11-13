import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

final channelEditAvatarUploadProvider =
    Provider<Future<String?> Function(File)>(
      (ref) => (file) async {
        String? uploaded;
        await AttachmentApi.uploadFileViaPresignCompat(
          'avatar',
          file,
          (Map<String, dynamic> response, String url) {
            if (response['status'] == 'ok' && url.isNotEmpty) uploaded = url;
          },
          (_) {},
          process: true,
        );
        return uploaded;
      },
    );

class ChannelEditAvatar extends StatelessWidget {
  const ChannelEditAvatar({
    super.key,
    required this.file,
    required this.url,
    required this.uploading,
    required this.failed,
    required this.onPick,
    required this.onRetry,
    required this.onRestore,
  });

  final File? file;
  final String? url;
  final bool uploading;
  final bool failed;
  final VoidCallback? onPick;
  final VoidCallback? onRetry;
  final VoidCallback? onRestore;

  static const _size = AppSizes.avatarSizeXXLarge + AppSpacing.small;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final brightness = Theme.of(context).brightness;
    return Column(
      children: [
        CupertinoButton(
          key: const ValueKey('channel-edit-avatar-picker'),
          onPressed: onPick,
          padding: AppSpacing.allSmall,
          child: Semantics(
            label: t.account.avatar,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: _size / 2,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: file != null
                      ? FileImage(file!)
                      : (url?.isNotEmpty ?? false)
                      ? cachedImageProvider(url!, w: _size * 2)
                      : null,
                  child: file == null && (url?.isEmpty ?? true)
                      ? const Icon(
                          CupertinoIcons.camera,
                          size: AppSpacing.xxLarge,
                        )
                      : null,
                ),
                if (uploading) const CupertinoActivityIndicator(),
                if (!uploading)
                  PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: Icon(
                      CupertinoIcons.pencil_circle_fill,
                      color: AppColors.getIosBlue(brightness),
                      size: AppSpacing.xxLarge,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (uploading || failed)
          Semantics(
            liveRegion: true,
            child: Text(
              uploading ? t.common.uploading : t.channel.avatarNotUploaded,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.normal,
                color: failed
                    ? AppColors.getDestructiveText(brightness)
                    : AppColors.getTextColor(brightness, isSecondary: true),
              ),
            ),
          ),
        if (failed)
          Wrap(
            spacing: AppSpacing.small,
            children: [
              CupertinoButton(
                key: const ValueKey('channel-edit-avatar-retry'),
                minimumSize: const Size.square(AppSizes.touchTarget),
                onPressed: onRetry,
                child: Text(t.common.buttonRetry),
              ),
              CupertinoButton(
                key: const ValueKey('channel-edit-avatar-restore'),
                minimumSize: const Size.square(AppSizes.touchTarget),
                onPressed: onRestore,
                child: Text(t.channel.restoreAvatar),
              ),
            ],
          ),
      ],
    );
  }
}

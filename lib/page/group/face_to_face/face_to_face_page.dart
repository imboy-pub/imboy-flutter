import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/numeric_keypad.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 面对面建群页面 - 极致 iOS 17 Premium 风格
class FaceToFacePage extends ConsumerStatefulWidget {
  const FaceToFacePage({super.key});

  @override
  ConsumerState<FaceToFacePage> createState() => _FaceToFacePageState();
}

class _FaceToFacePageState extends ConsumerState<FaceToFacePage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(faceToFaceProvider);
    final notifier = ref.read(faceToFaceProvider.notifier);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return IosPageTemplate(
      title: t.chat.createGroupF2f,
      useLargeTitle: false,
      bottomWidget: Container(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        child: NumericKeypad(
          controller: state.textEditingController,
          onChanged: (value) async {
            notifier.updateResult(value);
            if (value.length == 4) {
              AppLoading.show();
              Map<String, dynamic> res = await notifier.faceToFace(value);
              AppLoading.dismiss();
              notifier.updateErrorInfo(res['error'] as String? ?? '');
              String gid = res['gid'] as String? ?? '';
              if (gid.isNotEmpty && context.mounted) {
                context.push(
                  '/group/face_to_face_confirm',
                  extra: {
                    'code': value,
                    'gid': gid,
                    'memberList': res['memberList'] ?? <dynamic>[],
                  },
                );
              }
              Timer(const Duration(seconds: 3), () {
                notifier.clearInput();
              });
            }
          },
        ),
      ),
      child: Column(
        children: [
          // 提示卡片
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.large,
              AppSpacing.regular,
              AppSpacing.none,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.large),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceGroupedTertiary
                    : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.group_solid,
                    color: AppColors.getIosBlue(brightness),
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.regular),
                  Expanded(
                    child: Text(
                      t.common.createGroupF2fTips,
                      style: context
                          .textStyle(
                            FontSizeType.normal,
                            color: AppColors.iosGray,
                            fontWeight: FontWeight.w500,
                          )
                          .copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxxLarge),

          // 数字输入区 - 极致质感
          _buildNumberBoxes(context, state, isDark, brightness),

          const SizedBox(height: AppSpacing.xLarge),

          // 错误提示
          if (state.errorInfo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxLarge,
              ),
              child: Text(
                state.errorInfo,
                style: context.textStyle(
                  FontSizeType.normal,
                  color: AppColors.iosRed,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNumberBoxes(
    BuildContext context,
    FaceToFaceState state,
    bool isDark,
    Brightness brightness,
  ) {
    final length = state.resultData.length;
    final double screenW = MediaQuery.sizeOf(context).width;
    final double boxSize = screenW <= 360 ? 56 : 64;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final hasValue = index < length;
        final isActive = index == length;

        return Container(
          width: boxSize,
          height: boxSize,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
          decoration: BoxDecoration(
            color: hasValue
                ? (isDark
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.1))
                : (isDark
                      ? AppColors.iosGray.withValues(alpha: 0.05)
                      : AppColors.darkBackground.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? AppColors.getIosBlue(brightness)
                  : (hasValue
                        ? AppColors.getIosBlue(
                            brightness,
                          ).withValues(alpha: 0.3)
                        : AppColors.transparent),
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: hasValue
              ? Text(
                  state.resultData[index],
                  style: context
                      .textStyle(
                        FontSizeType.extraLargeTitle,
                        fontWeight: FontWeight.bold,
                      )
                      .copyWith(letterSpacing: -1),
                )
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.getIosBlue(
                            brightness,
                          ).withValues(alpha: 0.5)
                        : AppColors.iosGray.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
        );
      }),
    );
  }
}

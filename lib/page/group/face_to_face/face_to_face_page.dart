import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/http/http_exceptions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/numeric_keypad.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 输入附近朋友约定的四位暗号。
class FaceToFacePage extends ConsumerStatefulWidget {
  const FaceToFacePage({super.key});

  @override
  ConsumerState<FaceToFacePage> createState() => _FaceToFacePageState();
}

class _FaceToFacePageState extends ConsumerState<FaceToFacePage> {
  bool _isMatching = false;

  Future<void> _match(String code) async {
    if (_isMatching || code.length != 4) return;
    setState(() => _isMatching = true);
    final notifier = ref.read(faceToFaceProvider.notifier);
    notifier.updateErrorInfo('');
    try {
      final result = await notifier.faceToFace(code);
      if (!mounted) return;
      notifier.updateErrorInfo(result['error'] as String? ?? '');
      final gid = '${result['gid'] ?? ''}';
      if (gid.isEmpty || gid == '0') return;
      await context.push(
        '/group/face_to_face_confirm',
        extra: {'code': code, 'gid': gid, 'memberList': result['memberList']},
      );
      if (mounted) notifier.clearInput();
    } catch (error) {
      if (mounted) {
        notifier.updateErrorInfo(
          error is HttpException ? error.message : t.common.tipFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _isMatching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(faceToFaceProvider);
    final notifier = ref.read(faceToFaceProvider.notifier);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return IosPageTemplate(
      title: t.chat.createGroupF2f,
      useLargeTitle: false,
      contentMaxWidth: 480,
      bottomWidget: SafeArea(
        top: false,
        child: Align(
          heightFactor: 1,
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ColoredBox(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              child: NumericKeypad(
                controller: state.textEditingController,
                maxLength: 4,
                enabled: !_isMatching,
                onChanged: (value) {
                  notifier.updateResult(value);
                  notifier.updateErrorInfo('');
                  if (value.length == 4) _match(value);
                },
              ),
            ),
          ),
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
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.getIosBlue(brightness)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.person_2_fill,
                      color: AppColors.getIosBlue(brightness),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.regular),
                  Expanded(
                    child: Text(
                      t.common.createGroupF2fTips,
                      style: context
                          .textStyle(
                            FontSizeType.normal,
                            color: AppColors.getTextSecondary(brightness),
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

          if (_isMatching)
            Semantics(
              liveRegion: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CupertinoActivityIndicator(),
                  const SizedBox(width: AppSpacing.small),
                  Text(t.common.loading),
                ],
              ),
            ),
          // 错误提示
          if (state.errorInfo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxLarge,
              ),
              child: Semantics(
                liveRegion: true,
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
            ),
          if (state.errorInfo.isNotEmpty && state.resultData.length == 4)
            CupertinoButton(
              onPressed: _isMatching ? null : () => _match(state.resultData),
              child: Text(t.common.retry),
            ),
          const SizedBox(height: AppSpacing.large),
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
    final boxSize =
        ((MediaQuery.sizeOf(context).width - AppSpacing.xxLarge) / 4 -
                AppSpacing.regular)
            .clamp(40.0, 64.0);

    return Semantics(
      label: t.common.f2fSecretCode,
      value: state.resultData,
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final hasValue = index < length;
            final isActive = index == length;

            return Container(
              width: boxSize,
              constraints: BoxConstraints(minHeight: boxSize),
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
                            ? AppColors.getIosBlue(brightness)
                                  .withValues(alpha: 0.3)
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
                            ? AppColors.getIosBlue(brightness)
                                  .withValues(alpha: 0.5)
                            : AppColors.iosGray.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
            );
          }),
        ),
      ),
    );
  }
}

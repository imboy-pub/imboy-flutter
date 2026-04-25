import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'set_nickname_provider.dart';

/// 设置昵称页面
class SetNicknamePage extends ConsumerStatefulWidget {
  const SetNicknamePage({super.key});

  @override
  ConsumerState<SetNicknamePage> createState() => _SetNicknamePageState();
}

class _SetNicknamePageState extends ConsumerState<SetNicknamePage> {
  /// 处理键盘事件（macOS 支持）
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // 回车提交（macOS 和其他平台）
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final notifier = ref.read(setNicknameProvider.notifier);
      final canSave = ref.watch(setNicknameProvider).canSave;
      final isSaving = ref.watch(setNicknameProvider).isSaving;

      if (canSave && !isSaving) {
        notifier.saveNickname(ref);
        return KeyEventResult.handled;
      }
    }

    // Cmd+Z 撤销（macOS）
    if (key == LogicalKeyboardKey.keyZ &&
        (event.logicalKey == LogicalKeyboardKey.metaLeft ||
            event.logicalKey == LogicalKeyboardKey.metaRight)) {
      ref.read(setNicknameProvider.notifier).undoChanges(ref);
      return KeyEventResult.handled;
    }

    // Esc 返回
    if (key == LogicalKeyboardKey.escape) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(setNicknameProvider);
    final controller = ref.watch(nicknameControllerProvider);
    final focusNode = ref.watch(nicknameFocusNodeProvider);

    // 初始化控制器文本
    if (controller.text.isEmpty && state.nickname.isNotEmpty) {
      controller.text = state.nickname;
    }

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.setNickname,
        rightDMActions: [
          Container(
            height: AppSpacing.regular * 4,
            margin: EdgeInsets.only(right: AppSpacing.regular * 2),
            decoration: BoxDecoration(
              color: state.canSave && !state.isSaving
                  ? AppColors.primary
                  : (isDark
                        ? AppColors.iosGray3Dark
                        : AppColors.lightBorder),
              borderRadius: BorderRadius.circular(AppSpacing.regular * 2),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.regular * 2),
                onTap: state.canSave && !state.isSaving
                    ? () async {
                        final success = await ref
                            .read(setNicknameProvider.notifier)
                            .saveNickname(ref);
                        if (success && context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      }
                    : null,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.regular * 2,
                  ),
                  alignment: Alignment.center,
                  child: state.isSaving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              state.canSave
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                            ),
                          ),
                        )
                      : Text(
                          t.buttonSave,
                          style: ThemeManager.instance.getTextStyle(
                            FontSizeType.small,
                            fontWeight: FontWeight.w600,
                            color: state.canSave
                                ? Theme.of(context).colorScheme.onPrimary
                                : AppColors.getTextColor(
                                    Theme.of(context).brightness,
                                    isSecondary: true,
                                  ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Focus(
        onKeyEvent: _onKey,
        child: Column(
          children: [
            // 输入框区域
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.regular * 2),
              margin: EdgeInsets.all(AppSpacing.regular * 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppRadius.borderRadiusMedium,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 0.5,
                    offset: const Offset(0, 0.5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.nickname,
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.small,
                      color: AppColors.getTextColor(
                        Theme.of(context).brightness,
                        isSecondary: true,
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.regular * 0.8),
                  Semantics(
                    label: '${t.nickname} - ${t.nicknameHint}',
                    hint: t.nicknameHint,
                    textField: true,
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      maxLength: 24,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      style: ThemeManager.instance.getTextStyle(
                        FontSizeType.medium,
                        fontWeight: FontWeight.w500,
                        color: AppColors.getTextColor(
                          Theme.of(context).brightness,
                        ),
                      ),
                      decoration: InputDecoration(
                        hintText: t.nicknameHint,
                        hintStyle: ThemeManager.instance.getTextStyle(
                          FontSizeType.medium,
                          color: AppColors.getTextColor(
                            Theme.of(context).brightness,
                            isSecondary: true,
                          ),
                        ),
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.only(left: 10),
                      ),
                      onChanged: (value) {
                        ref
                            .read(setNicknameProvider.notifier)
                            .onNicknameChanged(value, ref);
                      },
                      onSubmitted: (_) {
                        if (state.canSave && !state.isSaving) {
                          ref
                              .read(setNicknameProvider.notifier)
                              .saveNickname(ref)
                              .then((success) {
                                if (success && context.mounted) {
                                  Navigator.of(context).pop(true);
                                }
                              });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 字符计数和校验提示区域
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.regular * 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 字符计数
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 校验错误提示
                      Expanded(
                        child: () {
                          final error = state.validationError;
                          if (error.isEmpty) return const SizedBox.shrink();

                          return Semantics(
                            label: '${t.warning}: $error',
                            liveRegion: true,
                            child: Text(
                              error,
                              style: ThemeManager.instance.getTextStyle(
                                FontSizeType.small,
                                color: AppColors.getIosRed(
                                  Theme.of(context).brightness,
                                ),
                              ),
                            ),
                          );
                        }(),
                      ),

                      // 剩余字符数
                      Semantics(
                        label: t.nicknameCharsRemaining(
                          param: state.remainingChars.toString(),
                        ),
                        liveRegion: true,
                        child: Text(
                          t.nicknameCharsRemaining(
                            param: state.remainingChars.toString(),
                          ),
                          style: ThemeManager.instance.getTextStyle(
                            FontSizeType.small,
                            color: state.remainingChars < 0
                                ? AppColors.getIosRed(
                                    Theme.of(context).brightness,
                                  )
                                : AppColors.getTextColor(
                                    Theme.of(context).brightness,
                                    isSecondary: true,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: AppSpacing.regular),

                  // 使用说明
                  Container(
                    padding: EdgeInsets.all(AppSpacing.regular * 1.5),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: AppRadius.borderRadiusSmall,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.tipTips,
                          style: ThemeManager.instance.getTextStyle(
                            FontSizeType.small,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextColor(
                              Theme.of(context).brightness,
                              isSecondary: true,
                            ),
                          ),
                        ),
                        SizedBox(height: AppSpacing.regular * 0.5),
                        Text(
                          t.nicknameRules,
                          style: ThemeManager.instance.getTextStyle(
                            FontSizeType.small,
                            color: AppColors.getTextColor(
                              Theme.of(context).brightness,
                              isSecondary: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // macOS 快捷键提示（仅在 macOS 上显示）
            if (Theme.of(context).platform == TargetPlatform.macOS) ...[
              SizedBox(height: AppSpacing.regular * 2),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.regular * 2,
                ),
                child: Container(
                  padding: EdgeInsets.all(AppSpacing.regular * 1.5),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderRadiusSmall,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '快捷键',
                        style: ThemeManager.instance.getTextStyle(
                          FontSizeType.small,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextColor(
                            Theme.of(context).brightness,
                            isSecondary: true,
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpacing.regular * 0.5),
                      Text(
                        '• Enter: 保存昵称\n• Cmd+Z: 撤销更改\n• Esc: 返回上级',
                        style: ThemeManager.instance.getTextStyle(
                          FontSizeType.small,
                          color: AppColors.getTextColor(
                            Theme.of(context).brightness,
                            isSecondary: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

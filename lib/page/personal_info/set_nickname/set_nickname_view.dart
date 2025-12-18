import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/theme_manager.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'set_nickname_logic.dart';

/// 设置昵称页面
///
/// 功能特性：
/// - 实时字符计数和长度限制（2-24字符）
/// - 输入校验提示（空白、表情、敏感词等）
/// - 保存按钮状态管理（loading/禁用）
/// - macOS 键盘支持（回车提交、Cmd+Z撤销、焦点管理）
/// - 网络错误处理和失败回滚
/// - 无障碍支持和语义化标签
class SetNicknamePage extends StatefulWidget {
  const SetNicknamePage({super.key});

  @override
  State<SetNicknamePage> createState() => _SetNicknamePageState();
}

class _SetNicknamePageState extends State<SetNicknamePage> {
  late final SetNicknameLogic logic = Get.put(SetNicknameLogic());

  @override
  void dispose() {
    Get.delete<SetNicknameLogic>();
    super.dispose();
  }

  /// 处理键盘事件（macOS 支持）
  /// 用途：支持回车提交、Cmd+Z撤销等快捷键
  /// 参数：event 键盘事件
  /// 返回：KeyEventResult
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // 回车提交（macOS 和其他平台）
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (logic.canSave.value && !logic.isSaving.value) {
        logic.saveNickname();
        return KeyEventResult.handled;
      }
    }

    // Cmd+Z 撤销（macOS）
    if (key == LogicalKeyboardKey.keyZ &&
        (event.logicalKey == LogicalKeyboardKey.metaLeft ||
            event.logicalKey == LogicalKeyboardKey.metaRight)) {
      logic.undoChanges();
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

    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'set_nickname'.tr,
        rightDMActions: [
          Obx(
            () => Container(
              height: ThemeManager.instance.mainSpace * 4,
              margin: EdgeInsets.only(
                right: ThemeManager.instance.mainSpace * 2,
              ),
              decoration: BoxDecoration(
                color: logic.canSave.value && !logic.isSaving.value
                    ? AppColors.primaryGreen
                    : (isDark
                          ? const Color(0xFF48484A)
                          : const Color(0xFFE5E5E5)),
                borderRadius: BorderRadius.circular(
                  ThemeManager.instance.mainSpace * 2,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    ThemeManager.instance.mainSpace * 2,
                  ),
                  onTap: logic.canSave.value && !logic.isSaving.value
                      ? logic.saveNickname
                      : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ThemeManager.instance.mainSpace * 2,
                    ),
                    alignment: Alignment.center,
                    child: logic.isSaving.value
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                logic.canSave.value
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                              ),
                            ),
                          )
                        : Text(
                            'button_save'.tr,
                            style: ThemeManager.instance.getTextStyle(
                              FontSizeType.small,
                              fontWeight: FontWeight.w600,
                              color: logic.canSave.value
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
              padding: EdgeInsets.all(ThemeManager.instance.mainSpace * 2),
              margin: EdgeInsets.all(ThemeManager.instance.mainSpace * 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
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
                    'nickname'.tr,
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.small,
                      color: AppColors.getTextColor(
                        Theme.of(context).brightness,
                        isSecondary: true,
                      ),
                    ),
                  ),
                  SizedBox(height: ThemeManager.instance.mainSpace * 0.8),
                  Semantics(
                    label: '${'nickname'.tr} - ${'nickname_hint'.tr}',
                    hint: 'nickname_hint'.tr,
                    textField: true,
                    child: TextField(
                      controller: logic.nicknameController,
                      focusNode: logic.focusNode,
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
                        hintText: 'nickname_hint'.tr,
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
                      onChanged: logic.onNicknameChanged,
                      onSubmitted: (_) {
                        if (logic.canSave.value && !logic.isSaving.value) {
                          logic.saveNickname();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 字符计数和校验提示区域
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ThemeManager.instance.mainSpace * 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 字符计数
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 校验错误提示
                      Expanded(
                        child: Obx(() {
                          final error = logic.validationError.value;
                          if (error.isEmpty) return const SizedBox.shrink();

                          return Semantics(
                            label: '${'warning'.tr}: $error',
                            liveRegion: true,
                            child: Text(
                              error,
                              style: ThemeManager.instance.getTextStyle(
                                FontSizeType.small,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          );
                        }),
                      ),

                      // 剩余字符数
                      Obx(() {
                        final remaining = logic.remainingChars.value;
                        final current = 24 - remaining;
                        final isOverLimit = current > 24;

                        return Semantics(
                          label: 'nickname_chars_remaining'.trArgs([
                            remaining.toString(),
                          ]),
                          liveRegion: true,
                          child: Text(
                            'nickname_chars_remaining'.trArgs([
                              remaining.toString(),
                            ]),
                            style: ThemeManager.instance.getTextStyle(
                              FontSizeType.small,
                              color: isOverLimit
                                  ? Theme.of(context).colorScheme.error
                                  : AppColors.getTextColor(
                                      Theme.of(context).brightness,
                                      isSecondary: true,
                                    ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),

                  SizedBox(height: ThemeManager.instance.mainSpace),

                  // 使用说明
                  Container(
                    padding: EdgeInsets.all(
                      ThemeManager.instance.mainSpace * 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'tip_tips'.tr,
                          style: ThemeManager.instance.getTextStyle(
                            FontSizeType.small,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextColor(
                              Theme.of(context).brightness,
                              isSecondary: true,
                            ),
                          ),
                        ),
                        SizedBox(height: ThemeManager.instance.mainSpace * 0.5),
                        Text(
                          '• 昵称长度为2-24个字符\n• 不能仅包含空白字符或表情符号\n• 不能包含敏感词汇\n• 修改后将在所有聊天中显示',
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
              SizedBox(height: ThemeManager.instance.mainSpace * 2),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ThemeManager.instance.mainSpace * 2,
                ),
                child: Container(
                  padding: EdgeInsets.all(
                    ThemeManager.instance.mainSpace * 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
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
                      SizedBox(height: ThemeManager.instance.mainSpace * 0.5),
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

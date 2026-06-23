import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'set_nickname_provider.dart';

/// 设置昵称页面 - 像素级对齐 iOS 17 高效表单
class SetNicknamePage extends ConsumerStatefulWidget {
  const SetNicknamePage({super.key});

  @override
  ConsumerState<SetNicknamePage> createState() => _SetNicknamePageState();
}

class _SetNicknamePageState extends ConsumerState<SetNicknamePage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(setNicknameProvider);
    final controller = ref.watch(nicknameControllerProvider);
    final focusNode = ref.watch(nicknameFocusNodeProvider);
    final brightness = Theme.of(context).brightness;

    // 初始化控制器文本
    if (controller.text.isEmpty && state.nickname.isNotEmpty) {
      controller.text = state.nickname;
    }

    return IosPageTemplate(
      title: t.account.setNickname,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: state.canSave && !state.isSaving
              ? () async {
                  final success = await ref
                      .read(setNicknameProvider.notifier)
                      .saveNickname(ref);
                  if (success && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                }
              : null,
          child: state.isSaving
              ? const CupertinoActivityIndicator(radius: 10)
              : Text(
                  t.common.buttonSave,
                  style: TextStyle(
                    fontWeight: state.canSave
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: state.canSave
                        ? AppColors.getIosBlue(brightness)
                        : AppColors.iosGray,
                  ),
                ),
        ),
      ],
      child: Column(
        children: [
          // 输入 Section
          ImBoySettingsSection(
            header: Text(t.account.nickname.toUpperCase()),
            footer: Text(t.account.nicknameRules),
            children: [
              CupertinoListTile.notched(
                title: CupertinoTextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLength: 24,
                  autofocus: true,
                  placeholder: t.account.nicknameHint,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 12,
                  ),
                  decoration: null,
                  style: context.textStyle(FontSizeType.body),
                  onChanged: (v) => ref
                      .read(setNicknameProvider.notifier)
                      .onNicknameChanged(v, ref),
                ),
                trailing: Text(
                  state.remainingChars.toString(),
                  style: context.textStyle(
                    FontSizeType.normal,
                    color: state.remainingChars < 0
                        ? AppColors.iosRed
                        : AppColors.iosGray,
                  ),
                ),
              ),
            ],
          ),

          // 校验错误提示
          if (state.validationError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.info_circle,
                    size: 14,
                    color: AppColors.iosRed,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.validationError,
                      style: context.textStyle(
                        FontSizeType.footnote,
                        color: AppColors.iosRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

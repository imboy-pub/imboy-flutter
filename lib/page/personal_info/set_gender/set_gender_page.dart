import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'set_gender_provider.dart';

/// 设置性别页面 - 像素级对齐 iOS 17 高效表单
class SetGenderPage extends ConsumerWidget {
  const SetGenderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(setGenderProvider);
    final brightness = Theme.of(context).brightness;

    // 性别选项列表
    final genderOptions = [
      {'id': '1', 'title': t.main.male, 'icon': CupertinoIcons.person},
      {'id': '2', 'title': t.main.female, 'icon': CupertinoIcons.person_fill},
      {
        'id': '3',
        'title': t.main.keepSecret,
        'icon': CupertinoIcons.question_circle,
      },
    ];

    return IosPageTemplate(
      title: t.account.gender,
      useLargeTitle: false,
      child: ImBoySettingsSection(
        header: Text(t.account.gender.toUpperCase()),
        children: genderOptions.map((option) {
          final isSelected = state.selectedGender == option['id'];
          final isPending =
              state.pendingGender == option['id'] && state.isSaving;

          return ImBoySettingsTile(
            title: Text(option['title'] as String),
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.getIosBlue(brightness)
                    : AppColors.iosGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                option['icon'] as IconData,
                color: AppColors.onPrimary,
                size: 18,
              ),
            ),
            trailing: isPending
                ? const CupertinoActivityIndicator(radius: 8)
                : (isSelected
                      ? Icon(
                          CupertinoIcons.check_mark,
                          color: AppColors.getIosBlue(brightness),
                          size: 18,
                        )
                      : const SizedBox.shrink()),
            onTap: state.isSaving
                ? null
                : () async {
                    final success = await ref
                        .read(setGenderProvider.notifier)
                        .selectGender(option['id'] as String, ref);
                    if (success && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
          );
        }).toList(),
      ),
    );
  }
}

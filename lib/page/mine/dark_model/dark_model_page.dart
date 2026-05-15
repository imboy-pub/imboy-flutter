import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dark_model_page.g.dart';

/// DarkModel 模块的状态
class DarkModelState {
  final bool switchValue;
  final int selectIndex;

  const DarkModelState({this.switchValue = false, this.selectIndex = 2});

  DarkModelState copyWith({bool? switchValue, int? selectIndex}) {
    return DarkModelState(
      switchValue: switchValue ?? this.switchValue,
      selectIndex: selectIndex ?? this.selectIndex,
    );
  }
}

@riverpod
class DarkModelNotifier extends _$DarkModelNotifier {
  @override
  DarkModelState build() {
    final themeState = ref.watch(themeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final followSystem = themeMode == ThemeMode.system;
    final isDark = themeState.isDarkMode;
    return DarkModelState(
      switchValue: followSystem,
      selectIndex: !followSystem ? (isDark ? 3 : 2) : 2,
    );
  }

  void configLocalTheme() {
    final themeState = ref.read(themeProvider);
    final themeMode = ref.read(themeModeProvider);
    final followSystem = themeMode == ThemeMode.system;
    final isDark = themeState.isDarkMode;
    state = DarkModelState(
      switchValue: followSystem,
      selectIndex: !followSystem ? (isDark ? 3 : 2) : 2,
    );
  }

  Future<void> configSwitchOnChanged(bool value) async {
    if (state.switchValue == value) return;
    state = state.copyWith(switchValue: value);
    final themeModeNotifier = ref.read(themeModeProvider.notifier);
    final themeNotifier = ref.read(themeProvider.notifier);
    if (value) {
      themeModeNotifier.setFollowSystem(true);
      themeNotifier.applySystemTheme();
      state = state.copyWith(selectIndex: 2);
    } else {
      themeModeNotifier.setFollowSystem(false);
      configLocalTheme();
    }
  }

  Future<void> tapDarkItem(int index) async {
    if (state.selectIndex == index) return;
    state = state.copyWith(selectIndex: index);
    final themeModeNotifier = ref.read(themeModeProvider.notifier);
    final themeNotifier = ref.read(themeProvider.notifier);
    themeModeNotifier.setFollowSystem(false);
    if (index == 2) {
      await themeNotifier.toggleTheme(isDark: false);
    } else if (index == 3) {
      await themeNotifier.toggleTheme(isDark: true);
    }
  }
}

/// 深色模式设置页面 - 像素级对齐 iOS 设置风
class DarkModelPage extends ConsumerWidget {
  const DarkModelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final state = ref.watch(darkModelProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.main.darkModel,
      useLargeTitle: false,
      child: Column(
        children: [
          ImBoySettingsSection(
            header: Text(t.common.sectionDisplay.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(t.main.followSystem),
                subtitle: Text(t.common.followSystemTips),
                trailing: CupertinoSwitch(
                  value: state.switchValue,
                  activeTrackColor: AppColors.getIosBlue(brightness),
                  onChanged: (val) => ref
                      .read(darkModelProvider.notifier)
                      .configSwitchOnChanged(val),
                ),
              ),
            ],
          ),
          if (!state.switchValue)
            ImBoySettingsSection(
              header: Text(t.common.sectionTheme.toUpperCase()),
              children: [
                ImBoySettingsTile(
                  title: Text(t.main.systemDefault),
                  trailing: state.selectIndex == 2
                      ? Icon(
                          CupertinoIcons.check_mark,
                          size: 18,
                          color: AppColors.getIosBlue(brightness),
                        )
                      : const SizedBox.shrink(),
                  onTap: () =>
                      ref.read(darkModelProvider.notifier).tapDarkItem(2),
                ),
                ImBoySettingsTile(
                  title: Text(t.main.darkModel),
                  trailing: state.selectIndex == 3
                      ? Icon(
                          CupertinoIcons.check_mark,
                          size: 18,
                          color: AppColors.getIosBlue(brightness),
                        )
                      : const SizedBox.shrink(),
                  onTap: () =>
                      ref.read(darkModelProvider.notifier).tapDarkItem(3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/app_loading.dart';
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DarkModelState &&
          runtimeType == other.runtimeType &&
          switchValue == other.switchValue &&
          selectIndex == other.selectIndex;

  @override
  int get hashCode => Object.hash(switchValue, selectIndex);
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

  Future<void> configSwitchOnChanged(bool value) =>
      ref.read(themeModeProvider.notifier).setFollowSystem(value);

  Future<void> tapDarkItem(int index) => ref
      .read(themeModeProvider.notifier)
      .setThemeMode(index == 3 ? ThemeMode.dark : ThemeMode.light);
}

/// 深色模式设置页面 - 像素级对齐 iOS 设置风
class DarkModelPage extends ConsumerWidget {
  const DarkModelPage({super.key});

  Future<void> _apply(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      await AppLoading.showError(t.common.settingFailedPleaseTryAgain);
    }
  }

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
            footer: kIsWeb ? Text(t.common.themeBrowserLocalOnly) : null,
            children: [
              ImBoySettingsTile(
                title: Text(t.main.followSystem),
                subtitle: Text(t.common.followSystemTips),
                // DEF-A11YNEW-02：CupertinoSwitch 自身语义只有 toggled 状态、
                // 没有可访问名（收据 appearance dump：role=switch text=''）。
                // 把行标题挂成开关的语义 label——外层注解沿单子语义链并入
                // 开关节点，引擎渲染为 aria-label，读屏播报「跟随系统, 开关」。
                trailing: Semantics(
                  label: t.main.followSystem,
                  child: CupertinoSwitch(
                    value: state.switchValue,
                    activeTrackColor: AppColors.getIosBlue(brightness),
                    onChanged: (val) => _apply(
                      () => ref
                          .read(darkModelProvider.notifier)
                          .configSwitchOnChanged(val),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!state.switchValue)
            ImBoySettingsSection(
              header: Text(t.common.sectionTheme.toUpperCase()),
              children: [
                MergeSemantics(
                  child: Semantics(
                    selected: state.selectIndex == 2,
                    inMutuallyExclusiveGroup: true,
                    child: ImBoySettingsTile(
                      // 这一项 onTap 走的是 tapDarkItem(2) → toggleTheme(isDark: false)，
                      // 也就是**强制浅色**，跟「跟随系统」没关系（那是上面那个开关）。
                      // 之前却用了 t.main.systemDefault「系统默认」的文案，于是页面上
                      // 出现「跟随系统=关」却选中「系统默认」的自相矛盾，用户也以为
                      // 没有强制浅色选项（QA#56）。功能一直是全的，错的是文案。
                      title: Text(t.main.lightModel),
                      trailing: state.selectIndex == 2
                          ? Icon(
                              CupertinoIcons.check_mark,
                              size: 18,
                              color: AppColors.getIosBlue(brightness),
                            )
                          : const SizedBox.shrink(),
                      onTap: () => _apply(
                        () =>
                            ref.read(darkModelProvider.notifier).tapDarkItem(2),
                      ),
                    ),
                  ),
                ),
                MergeSemantics(
                  child: Semantics(
                    selected: state.selectIndex == 3,
                    inMutuallyExclusiveGroup: true,
                    child: ImBoySettingsTile(
                      title: Text(t.main.darkModel),
                      trailing: state.selectIndex == 3
                          ? Icon(
                              CupertinoIcons.check_mark,
                              size: 18,
                              color: AppColors.getIosBlue(brightness),
                            )
                          : const SizedBox.shrink(),
                      onTap: () => _apply(
                        () =>
                            ref.read(darkModelProvider.notifier).tapDarkItem(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

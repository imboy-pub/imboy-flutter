import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/theme/providers/theme_provider.dart';

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
    // 从 Riverpod provider 读取主题状态
    final themeState = ref.watch(themeProvider);
    final themeMode = ref.watch(themeModeProvider);

    final followSystem = themeMode == ThemeMode.system;
    final isDark = themeState.isDarkMode;

    return DarkModelState(
      switchValue: followSystem,
      selectIndex: !followSystem ? (isDark ? 3 : 2) : 2,
    );
  }

  /// 配置本地主题配置（从外部调用时使用）
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

  /// 点击开关回调 - 切换跟随系统
  Future<void> configSwitchOnChanged(bool value) async {
    if (state.switchValue == value) return;

    state = state.copyWith(switchValue: value);

    // 更新主题设置
    final themeModeNotifier = ref.read(themeModeProvider.notifier);
    final themeNotifier = ref.read(themeProvider.notifier);

    if (value) {
      // 开启跟随系统
      themeModeNotifier.setFollowSystem(true);
      themeNotifier.applySystemTheme();
      // 重置选择索引到浅色模式（跟随系统时的默认显示）
      state = state.copyWith(selectIndex: 2);
    } else {
      // 关闭跟随系统，使用当前系统主题作为固定主题
      themeModeNotifier.setFollowSystem(false);
      // 保持当前主题状态
      configLocalTheme();
    }
  }

  /// 点击主题项 - 选择浅色或深色
  Future<void> tapDarkItem(int index) async {
    if (state.selectIndex == index) {
      return;
    }

    state = state.copyWith(selectIndex: index);

    final themeModeNotifier = ref.read(themeModeProvider.notifier);
    final themeNotifier = ref.read(themeProvider.notifier);

    // 确保不跟随系统
    themeModeNotifier.setFollowSystem(false);

    // 切换主题
    if (index == 2) {
      // 浅色模式
      await themeNotifier.toggleTheme(isDark: false);
    } else if (index == 3) {
      // 深色模式
      await themeNotifier.toggleTheme(isDark: true);
    }
  }

  /// 获取主题类型
  /// 0 白色（浅色）
  /// 1 黑色（深色）
  /// 2 跟随系统
  int getThemeType() {
    final themeState = ref.read(themeProvider);
    final themeMode = ref.read(themeModeProvider);

    if (themeMode == ThemeMode.system) {
      return 2;
    }
    return themeState.isDarkMode ? 1 : 0;
  }
}

class DarkModelPage extends ConsumerWidget {
  const DarkModelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final t = context.t;
    final state = ref.watch(darkModelProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: GlassAppBar(automaticallyImplyLeading: true, title: t.darkModel),
      body: ListView(
        children: [
          SwitchListTile(
            value: state.switchValue,
            title: Text(t.followSystem),
            subtitle: Text(t.followSystemTips),
            onChanged: (val) {
              ref.read(darkModelProvider.notifier).configSwitchOnChanged(val);
            },
          ),
          if (!state.switchValue) ...[
            RadioListTile<int>(
              value: 2,
              // ignore: deprecated_member_use
              groupValue: state.selectIndex,
              // ignore: deprecated_member_use
              onChanged: (val) {
                if (val == null) return;
                ref.read(darkModelProvider.notifier).tapDarkItem(val);
              },
              title: Text(t.systemDefault),
            ),
            RadioListTile<int>(
              value: 3,
              // ignore: deprecated_member_use
              groupValue: state.selectIndex,
              // ignore: deprecated_member_use
              onChanged: (val) {
                if (val == null) return;
                ref.read(darkModelProvider.notifier).tapDarkItem(val);
              },
              title: Text(t.darkModel),
            ),
          ],
        ],
      ),
    );
  }
}

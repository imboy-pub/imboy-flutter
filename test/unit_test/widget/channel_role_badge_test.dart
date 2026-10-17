// ChannelRoleBadge 单一来源测试（T05 / UX-ISSUE-0024）。
//
// 覆盖：角色→颜色映射、角色→文案映射、渲染分支（正常/覆盖文案/
// 无角色零尺寸）、长文案不溢出、Semantics 标签。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/widgets/channel_role_badge.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/providers/theme_provider.dart';

class _FixedThemeNotifier extends ThemeNotifier {
  @override
  ThemeState build() => const ThemeState();

  void useFontSize(FontSizeOption option) {
    state = state.copyWith(fontSizeOption: option);
  }
}

/// TranslationProvider 防止 slang "Please wrap" 异常（对齐仓内模式）。
Widget _wrap(Widget child) => TranslationProvider(
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  late ProviderContainer themeContainer;

  setUpAll(() {
    themeContainer = ProviderContainer(
      overrides: [themeProvider.overrideWith(_FixedThemeNotifier.new)],
    );
    ThemeManager.instance.setProviderContainer(themeContainer);
  });

  setUp(() {
    (themeContainer.read(themeProvider.notifier) as _FixedThemeNotifier)
        .useFontSize(FontSizeOption.normal);
  });

  tearDownAll(() => themeContainer.dispose());

  group('channelRoleColor / channelRoleLabel 映射', () {
    test('creator→primary，admin→iosOrange，editor→iosBlue', () {
      expect(channelRoleColor(ChannelUserRole.creator), AppColors.primary);
      expect(channelRoleColor(ChannelUserRole.admin), AppColors.iosOrange);
      expect(channelRoleColor(ChannelUserRole.editor), AppColors.iosBlue);
    });

    test('subscriber/none→iosGray 且文案为空', () {
      expect(channelRoleColor(ChannelUserRole.subscriber), AppColors.iosGray);
      expect(channelRoleColor(ChannelUserRole.none), AppColors.iosGray);
      expect(channelRoleLabel(ChannelUserRole.subscriber), '');
      expect(channelRoleLabel(ChannelUserRole.none), '');
    });

    test('三个管理角色文案非空且互不相同', () {
      final labels = {
        channelRoleLabel(ChannelUserRole.creator),
        channelRoleLabel(ChannelUserRole.admin),
        channelRoleLabel(ChannelUserRole.editor),
      };
      expect(labels.length, 3);
      expect(labels.every((e) => e.isNotEmpty), isTrue);
    });
  });

  group('ChannelRoleBadge 渲染', () {
    testWidgets('徽标沿用应用内超大字号设置', (tester) async {
      (themeContainer.read(themeProvider.notifier) as _FixedThemeNotifier)
          .useFontSize(FontSizeOption.huge);
      await tester.pumpWidget(
        _wrap(const ChannelRoleBadge(role: ChannelUserRole.creator)),
      );
      final text = tester.widget<Text>(
        find.text(channelRoleLabel(ChannelUserRole.creator)),
      );
      expect(
        text.style!.fontSize,
        FontSizeType.tiny.size * FontSizeOption.huge.scale,
      );
    });

    testWidgets('creator 徽标渲染文案与 Semantics 标签', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const ChannelRoleBadge(role: ChannelUserRole.creator)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(channelRoleLabel(ChannelUserRole.creator)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(channelRoleLabel(ChannelUserRole.creator)),
        findsWidgets,
      );
      semanticsHandle.dispose();
    });

    testWidgets('overridesLabel 覆盖默认文案', (tester) async {
      const custom = '自定义角色';
      await tester.pumpWidget(
        _wrap(
          const ChannelRoleBadge(
            role: ChannelUserRole.admin,
            overridesLabel: custom,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(custom), findsOneWidget);
      expect(find.text(channelRoleLabel(ChannelUserRole.admin)), findsNothing);
    });

    testWidgets('subscriber/none 渲染为零尺寸', (tester) async {
      await tester.pumpWidget(
        _wrap(const ChannelRoleBadge(role: ChannelUserRole.subscriber)),
      );
      await tester.pumpAndSettle();

      final box = tester.getSize(find.byType(ChannelRoleBadge));
      expect(box, Size.zero);
    });

    testWidgets('长文案不横向溢出', (tester) async {
      const longLabel = '一个非常非常长的频道角色名称用于验证徽标在窄约束下不会横向溢出';
      await tester.pumpWidget(
        _wrap(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: const ChannelRoleBadge(
              role: ChannelUserRole.editor,
              overridesLabel: longLabel,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

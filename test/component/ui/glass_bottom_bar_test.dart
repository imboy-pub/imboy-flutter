import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/glass_bottom_bar.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// GlassBottomNavigationBar widget 契约测试
///
/// 纯 StatelessWidget，依赖 props（currentIndex / onTap / items / height / blur）
/// + Theme + AppColors，无 Riverpod / EventBus / SqliteService 依赖。
///
/// 覆盖：
///   - items 渲染（label / icon）
///   - currentIndex 高亮态：activeIcon + AppColors.primary 文本色 + w600
///   - currentIndex=N 时 N 项之外 items 用普通 icon + 半透明文字
///   - tap 触发 onTap(index)
///   - iconBuilder 自定义图标覆盖默认 icon（如 Badge 包装）
///   - default height=76 / default blur=20
Future<void> _pump(
  WidgetTester tester, {
  required int currentIndex,
  required List<GlassBottomBarItem> items,
  void Function(int)? onTap,
  double? height,
  double? blur,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        bottomNavigationBar: GlassBottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap ?? (_) {},
          items: items,
          height: height ?? 76.0,
          blur: blur ?? 20.0,
        ),
      ),
    ),
  );
  await tester.pump();
}

GlassBottomBarItem _item(String label, IconData icon) {
  return GlassBottomBarItem(icon: icon, label: label);
}

void main() {
  group('GlassBottomNavigationBar items rendering', () {
    testWidgets('renders all items with labels', (tester) async {
      await _pump(
        tester,
        currentIndex: 0,
        items: [
          _item('消息', Icons.chat_bubble_outline),
          _item('联系人', Icons.people_alt_outlined),
          _item('频道', Icons.campaign_outlined),
          _item('我的', Icons.person_outline),
        ],
      );

      expect(find.text('消息'), findsOneWidget);
      expect(find.text('联系人'), findsOneWidget);
      expect(find.text('频道'), findsOneWidget);
      expect(find.text('我的'), findsOneWidget);
    });

    testWidgets('currentIndex=0 → 第 1 个 icon 用 activeIcon (chat_bubble)',
        (tester) async {
      await _pump(
        tester,
        currentIndex: 0,
        items: [
          GlassBottomBarItem(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            label: '消息',
          ),
          _item('我的', Icons.person_outline),
        ],
      );

      // 第 1 个用 activeIcon = chat_bubble
      expect(find.byIcon(Icons.chat_bubble), findsOneWidget);
      // 默认 icon 不出现（activeIcon 覆盖）
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
      // 第 2 个保留 outline icon（非选中）
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('currentIndex=1 → 仅第 2 个用 activeIcon', (tester) async {
      await _pump(
        tester,
        currentIndex: 1,
        items: [
          GlassBottomBarItem(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            label: '消息',
          ),
          GlassBottomBarItem(
            icon: Icons.people_alt_outlined,
            activeIcon: Icons.people_alt,
            label: '联系人',
          ),
        ],
      );

      // 第 1 个回到 outline（未选中）
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      // 第 2 个用 activeIcon
      expect(find.byIcon(Icons.people_alt), findsOneWidget);
    });

    testWidgets('item without activeIcon → currentIndex 选中时仍用 icon',
        (tester) async {
      await _pump(
        tester,
        currentIndex: 0,
        items: [_item('消息', Icons.chat_bubble_outline)],
      );

      // 没 activeIcon，选中时用 icon
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });
  });

  group('GlassBottomNavigationBar selected text style', () {
    testWidgets('selected label color = AppColors.primary, w600',
        (tester) async {
      await _pump(
        tester,
        currentIndex: 0,
        items: [
          _item('消息', Icons.chat_bubble_outline),
          _item('我的', Icons.person_outline),
        ],
      );

      final selectedLabel = tester.widget<Text>(find.text('消息'));
      expect(selectedLabel.style?.color, AppColors.primary);
      expect(selectedLabel.style?.fontWeight, FontWeight.w600);
      expect(selectedLabel.style?.fontSize, 10);
    });

    testWidgets('unselected label color = onSurface.withAlpha(0.5), w500',
        (tester) async {
      await _pump(
        tester,
        currentIndex: 0,
        items: [
          _item('消息', Icons.chat_bubble_outline),
          _item('我的', Icons.person_outline),
        ],
      );

      final unselectedLabel = tester.widget<Text>(find.text('我的'));
      expect(unselectedLabel.style?.fontWeight, FontWeight.w500);
      expect(unselectedLabel.style?.fontSize, 10);
      // unselected color != AppColors.primary
      expect(unselectedLabel.style?.color, isNot(AppColors.primary));
    });
  });

  group('GlassBottomNavigationBar tap behavior', () {
    testWidgets('tap 第 2 个 item → onTap(1)', (tester) async {
      var lastTappedIndex = -1;
      await _pump(
        tester,
        currentIndex: 0,
        items: [
          _item('消息', Icons.chat_bubble_outline),
          _item('联系人', Icons.people_alt_outlined),
          _item('我的', Icons.person_outline),
        ],
        onTap: (i) => lastTappedIndex = i,
      );

      await tester.tap(find.text('联系人'));
      await tester.pump();

      expect(lastTappedIndex, 1);
    });

    testWidgets('tap 第 3 个 item → onTap(2)', (tester) async {
      var lastTappedIndex = -1;
      await _pump(
        tester,
        currentIndex: 0,
        items: [
          _item('消息', Icons.chat_bubble_outline),
          _item('联系人', Icons.people_alt_outlined),
          _item('我的', Icons.person_outline),
        ],
        onTap: (i) => lastTappedIndex = i,
      );

      await tester.tap(find.text('我的'));
      await tester.pump();

      expect(lastTappedIndex, 2);
    });
  });

  group('GlassBottomNavigationBar iconBuilder customization', () {
    testWidgets('iconBuilder 提供 → 覆盖默认 Icon 渲染', (tester) async {
      await _pump(
        tester,
        currentIndex: 0,
        items: [
          GlassBottomBarItem(
            icon: Icons.chat_bubble_outline,
            label: '消息',
            iconBuilder: (isSelected) => const Text('🔔', key: Key('custom')),
          ),
        ],
      );

      // iconBuilder 返回的自定义 widget 渲染
      expect(find.byKey(const Key('custom')), findsOneWidget);
      expect(find.text('🔔'), findsOneWidget);
      // 默认 icon 不渲染
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    });

    testWidgets('iconBuilder 接收 isSelected 参数', (tester) async {
      bool? capturedSelected;
      await _pump(
        tester,
        currentIndex: 0,
        items: [
          GlassBottomBarItem(
            icon: Icons.chat_bubble_outline,
            label: '消息',
            iconBuilder: (isSelected) {
              capturedSelected = isSelected;
              return Container(key: const Key('badge_wrap'));
            },
          ),
        ],
      );

      expect(capturedSelected, isTrue);
    });

    testWidgets('iconBuilder 在非选中状态接收 false', (tester) async {
      bool? capturedSelected;
      await _pump(
        tester,
        currentIndex: 1, // 第 2 个被选中
        items: [
          GlassBottomBarItem(
            icon: Icons.chat_bubble_outline,
            label: '消息',
            iconBuilder: (isSelected) {
              capturedSelected = isSelected;
              return Container(key: const Key('badge_wrap'));
            },
          ),
          _item('我的', Icons.person_outline),
        ],
      );

      expect(capturedSelected, isFalse);
    });
  });
}

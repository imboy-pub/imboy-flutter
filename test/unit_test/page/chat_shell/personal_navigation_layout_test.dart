import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/bottom_navigation/bottom_navigation_provider.dart';
import 'package:imboy/page/chat_shell/personal_navigation_layout.dart';
import 'package:imboy/page/web_shell/web_shell_provider.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

class _MobileNavigation extends BottomNavigationNotifier {
  @override
  int build() => 0;

  @override
  void changeIndex(int index) => state = index;
}

class _NavigationEntry extends ConsumerWidget {
  const _NavigationEntry({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = desktop
        ? ref.watch(webShellProvider).currentTab
        : ref.watch(bottomNavigationProvider);
    return Text('${desktop ? 'desktop' : 'mobile'}:$index');
  }
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        bottomNavigationProvider.overrideWith(_MobileNavigation.new),
        currentUserProvider.overrideWith((ref) => null),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpLayout(
    WidgetTester tester,
    double width, {
    bool channelAvailable = true,
    Brightness brightness = Brightness.light,
    ValueChanged<int?>? onMobileBuild,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, 700)),
            child: PersonalNavigationLayout(
              channelAvailable: channelAvailable,
              mobileBuilder: (restoredIndex) {
                onMobileBuild?.call(restoredIndex);
                return const _NavigationEntry(desktop: false);
              },
              desktopEntry: const _NavigationEntry(desktop: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('899 to 900 and back preserves the selected destination', (
    tester,
  ) async {
    await pumpLayout(tester, 899);
    container.read(bottomNavigationProvider.notifier).changeIndex(1);
    await pumpLayout(tester, 900);
    expect(find.text('desktop:1'), findsOneWidget);

    container.read(webShellProvider.notifier).switchTab(3);
    int? restoredIndex;
    await pumpLayout(
      tester,
      899,
      onMobileBuild: (value) => restoredIndex = value,
    );
    expect(find.text('mobile:3'), findsOneWidget);
    expect(restoredIndex, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without channels mobile mine 2 maps to desktop mine 3', (
    tester,
  ) async {
    await pumpLayout(tester, 899, channelAvailable: false);
    container.read(bottomNavigationProvider.notifier).changeIndex(2);
    await pumpLayout(tester, 900, channelAvailable: false);
    expect(find.text('desktop:3'), findsOneWidget);
    await pumpLayout(tester, 899, channelAvailable: false);
    expect(find.text('mobile:2'), findsOneWidget);
  });

  testWidgets('unavailable mobile channel falls back to messages, not mine', (
    tester,
  ) async {
    await pumpLayout(tester, 900, channelAvailable: false);
    container.read(webShellProvider.notifier).switchTab(2);
    await pumpLayout(tester, 899, channelAvailable: false);
    expect(find.text('mobile:0'), findsOneWidget);
  });

  testWidgets('ordinary width and theme rebuilds do not replay navigation', (
    tester,
  ) async {
    await pumpLayout(tester, 899);
    container.read(bottomNavigationProvider.notifier).changeIndex(1);
    await pumpLayout(tester, 900);
    container.read(webShellProvider.notifier).switchTab(3);
    await pumpLayout(tester, 1200, brightness: Brightness.dark);
    expect(find.text('desktop:3'), findsOneWidget);
    expect(container.read(bottomNavigationProvider), 1);
  });

  testWidgets('queued restore does not override a newer destination', (
    tester,
  ) async {
    await pumpLayout(tester, 899);
    container.read(bottomNavigationProvider.notifier).changeIndex(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      container.read(webShellProvider.notifier).switchTab(3);
    });
    await pumpLayout(tester, 900);
    expect(find.text('desktop:3'), findsOneWidget);
    await pumpLayout(tester, 899);
    expect(find.text('mobile:3'), findsOneWidget);
  });

  testWidgets('rapid repeated boundary crossings retain the latest tab', (
    tester,
  ) async {
    await pumpLayout(tester, 899);
    container.read(bottomNavigationProvider.notifier).changeIndex(1);
    for (final width in [900.0, 899.0, 900.0, 899.0, 900.0]) {
      await pumpLayout(tester, width);
      expect(
        find.text('${width < 900 ? 'mobile' : 'desktop'}:1'),
        findsOneWidget,
      );
    }
    container.read(webShellProvider.notifier).switchTab(2);
    await pumpLayout(tester, 899);
    expect(find.text('mobile:2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

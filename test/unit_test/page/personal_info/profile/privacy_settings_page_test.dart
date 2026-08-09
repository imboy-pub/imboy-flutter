import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/personal_info/profile/profile_provider.dart';
import 'package:imboy/page/personal_info/profile/widgets/privacy_settings_page.dart';

class _ProfileStateNotifier extends ProfileNotifier {
  _ProfileStateNotifier(this._initial);

  final ProfileState _initial;

  @override
  ProfileState build() => _initial;
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/privacy',
    routes: [
      GoRoute(path: '/privacy', builder: (_, _) => const PrivacySettingsPage()),
    ],
  );
}

void main() {
  testWidgets('online visibility switch defaults to off', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(
            () => _ProfileStateNotifier(ProfileState()),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp.router(routerConfig: _router()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('显示在线状态'), findsOneWidget);
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches, hasLength(5));
    expect(switches[3].value, isFalse);
  });
}

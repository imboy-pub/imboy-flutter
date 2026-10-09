import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/config/init.dart' show p2pCallScreenOn, p2pEntry;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/people_info/people_info_page.dart';
import 'package:imboy/page/contact/people_info/people_info_provider.dart';

class _FriendNotifier extends PeopleInfoNotifier {
  @override
  PeopleInfoState build() =>
      const PeopleInfoState(isFriend: 1, nickname: 'Peer');

  @override
  Future<void> initData(String id, String scene) async {}
}

void main() {
  tearDown(() => AppFeatureRegistry.replaceSnapshotForTest({}));

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [peopleInfoProvider.overrideWith(_FriendNotifier.new)],
        child: TranslationProvider(
          child: const MaterialApp(
            home: PeopleInfoPage(id: 'rtc-peer', scene: 'contact'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('disabled RTC hides both contact call entries', (tester) async {
    AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.rtc: false});
    await mount(tester);
    expect(find.text(t.common.voiceCall), findsNothing);
    expect(find.text(t.common.videoCall), findsNothing);
    expect(find.text(t.common.messageCall), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compiled product gate overrides remote RTC enablement', (
    tester,
  ) async {
    AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.rtc: true});
    await mount(tester);
    final matcher = compiledProductFeatures.contains(FeatureKeys.rtc)
        ? findsOneWidget
        : findsNothing;
    expect(find.text(t.common.voiceCall), matcher);
    expect(find.text(t.common.videoCall), matcher);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retained call callbacks recheck latest disabled snapshot', (
    tester,
  ) async {
    AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.rtc: true});
    await mount(tester);
    final callbacks = [t.common.voiceCall, t.common.videoCall].map((title) {
      final tile = tester.widget<ImBoySettingsTile>(
        find.ancestor(
          of: find.text(title),
          matching: find.byType(ImBoySettingsTile),
        ),
      );
      return tile.onTap!;
    }).toList();
    AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.rtc: false});
    for (final callback in callbacks) {
      callback();
    }
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(p2pCallScreenOn, isFalse);
    expect(p2pEntry, isNull);
    expect(find.byType(PeopleInfoPage), findsOneWidget);
    expect(find.byType(Overlay), findsOneWidget);
  }, skip: !compiledProductFeatures.contains(FeatureKeys.rtc));
}

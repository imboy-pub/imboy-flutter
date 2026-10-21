import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/customer_service/presentation/cs_queue_view.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:imboy/theme/theme_manager.dart';

import '../support/uiux_harness.dart';
import 'p3_fixtures.dart';

class _FixedThemeNotifier extends ThemeNotifier {
  @override
  ThemeState build() => const ThemeState();
}

void main() {
  testWidgets('p3_claim_font_scales_once_with_bound_theme_manager', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    final container = ProviderContainer(
      overrides: [themeProvider.overrideWith(_FixedThemeNotifier.new)],
    );
    final manager = ThemeManager.instance;
    manager.setProviderContainer(container);
    final previousAdapter = HttpClient.adapterForTest;
    HttpClient.adapterForTest = P3RecordingAdapter(
      queuePayload: p3QueuePagePayload([p3QueueItemWire()]),
    );
    try {
      await pumpUiux(
        tester,
        const CsQueueView(orgId: p3OrgId),
        env: const UiuxEnv(size: Size(1280, 800), scale: 2),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, '接单');
      expect(button, findsOneWidget);
      final text = find.descendant(of: button, matching: find.byType(RichText));
      final paragraph = tester.renderObject<RenderParagraph>(text);
      // Assert the rendered button, not the theme helper's intermediate value.
      expect(paragraph.text.style?.fontSize, 13);
      expect(paragraph.textScaler.scale(13), 26);
      expect(paragraph.text.style?.color, AppColors.sentMessageText);
      expect(paragraph.text.style?.fontFamilyFallback, contains('PingFang SC'));
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      HttpClient.adapterForTest = previousAdapter;
      manager.dispose();
      ThemeManager.resetInstance();
      container.dispose();
    }
  });
}

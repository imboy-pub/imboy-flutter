import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/bot_badge.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/widget/message_inbox_tile.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_duration.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/providers/theme_provider.dart';

const _avatarKey = ValueKey('test-avatar');
const _title = '北京产品设计与研发协作组';
const _preview = '这是一条很长的预览消息，需要保持可读和可缩放';

Widget _tile(
  BuildContext context, {
  int unreadCount = 12,
  bool isMuted = false,
  bool isPinned = false,
  bool hasBotBadge = false,
  bool hasManualPending = false,
  String timeLabel = '09:41',
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  VoidCallback? onTapAvatar,
}) => MessageInboxTile(
  avatar: GestureDetector(
    onTap: onTapAvatar,
    child: const ColoredBox(key: _avatarKey, color: AppColors.primary),
  ),
  title: Row(
    children: [
      Flexible(
        child: Text(
          _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyle(FontSizeType.body),
        ),
      ),
      if (hasBotBadge) ...[
        AppSpacing.horizontalTiny,
        const BotBadge(accountType: 2, dense: true),
      ],
    ],
  ),
  preview: Text(
    _preview,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: context.textStyle(FontSizeType.subheadline),
  ),
  timeLabel: timeLabel,
  unreadCount: unreadCount,
  isMuted: isMuted,
  isPinned: isPinned,
  trailingStatus: hasManualPending
      ? Icon(
          CupertinoIcons.flag_fill,
          size: AppSpacing.medium,
          semanticLabel: context.t.chat.manualPendingBadge,
        )
      : null,
  onTap: onTap,
  onLongPress: onLongPress,
);

Future<void> _pump(
  WidgetTester tester,
  WidgetBuilder builder, {
  double width = 390,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reduceMotion,
            ),
            child: Scaffold(body: Builder(builder: builder)),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Color _badgeColor(WidgetTester tester, String label) {
  final badge = tester.widget<Container>(
    find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
  );
  return (badge.decoration! as BoxDecoration).color!;
}

class _InboxThemeNotifier extends ThemeNotifier {
  @override
  ThemeState build() => const ThemeState();
}

void main() {
  late ProviderContainer themeContainer;
  setUp(() {
    themeContainer = ProviderContainer(
      overrides: [themeProvider.overrideWith(_InboxThemeNotifier.new)],
    );
    // The app root keeps its theme subscription alive. Match that lifecycle so
    // read-only font lookups do not enqueue auto-dispose timers after a frame.
    themeContainer.listen(themeProvider, (_, _) {});
    ThemeManager.instance.setProviderContainer(themeContainer);
  });
  tearDown(() {
    ThemeManager.instance.dispose();
    themeContainer.dispose();
  });

  testWidgets('title and separator align, with time and unread on the right', (
    tester,
  ) async {
    await _pump(tester, (context) => _tile(context));
    expect(
      tester.getTopLeft(find.text(_title)).dx,
      MessageInboxTile.contentIndent,
    );
    expect(
      tester.getSize(find.byKey(_avatarKey)),
      const Size.square(MessageInboxTile.avatarSize),
    );
    expect(tester.getTopRight(find.text('09:41')).dx, 390 - AppSpacing.regular);
    expect(
      tester.getTopLeft(find.text('12')).dx,
      greaterThan(tester.getTopRight(find.byKey(_avatarKey)).dx),
    );
    expect(
      tester.getTopLeft(find.text('12')).dy,
      greaterThan(tester.getTopLeft(find.text('09:41')).dy),
    );
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.4, 2.0]) {
      testWidgets(
        '320pt, ${scale}x text, $brightness keeps all states in bounds',
        (tester) async {
          await _pump(
            tester,
            (context) => _tile(
              context,
              unreadCount: 250,
              isMuted: true,
              isPinned: true,
              hasBotBadge: true,
              hasManualPending: true,
              timeLabel: '2025/10/28',
            ),
            width: 320,
            textScale: scale,
            brightness: brightness,
          );

          expect(tester.takeException(), isNull);
          expect(find.byType(BotBadge), findsOneWidget);
          expect(find.byIcon(CupertinoIcons.flag_fill), findsOneWidget);
          expect(find.text('99+'), findsOneWidget);
          expect(
            tester.getBottomRight(find.text('99+')).dx,
            lessThanOrEqualTo(320 - AppSpacing.regular),
          );
          final previewContext = tester.element(find.text(_preview));
          expect(MediaQuery.textScalerOf(previewContext).scale(10), 10 * scale);
          if (scale > 1) {
            expect(
              tester.getTopLeft(find.text('2025/10/28')).dy,
              greaterThan(tester.getBottomLeft(find.text(_preview)).dy),
              reason: 'Large text must keep metadata below the full-width title/preview',
            );
          }
        },
      );
    }
  }

  testWidgets('muted badges use neutral color while retaining the true count', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await _pump(
        tester,
        (context) => _tile(context, unreadCount: 250, isMuted: true),
      );
      expect(_badgeColor(tester, '99+'), AppColors.iosGray3);
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape(t.common.unreadCount(count: '250'))),
        ),
        findsWidgets,
      );
      // The badge may merge with the row's accessible label, but never reads 99+.
      expect(find.bySemanticsLabel(RegExp(r'99\+')), findsNothing);
      expect(
        tester
            .widget<Icon>(find.byIcon(CupertinoIcons.bell_slash_fill))
            .semanticLabel,
        t.common.muteNotifications,
      );

      await _pump(tester, (context) => _tile(context, unreadCount: 250));
      expect(_badgeColor(tester, '99+'), AppColors.iosRed);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('read rows have no badge and pin state has an accessible label', (
    tester,
  ) async {
    await _pump(
      tester,
      (context) => _tile(context, unreadCount: 0, isPinned: true),
    );
    expect(find.text('0'), findsNothing);
    expect(
      tester.widget<Icon>(find.byIcon(CupertinoIcons.pin_fill)).semanticLabel,
      t.chat.pinned,
    );
  });

  testWidgets('avatar tap, row tap and long press remain distinct actions', (
    tester,
  ) async {
    var avatarTaps = 0;
    var rowTaps = 0;
    var longPresses = 0;
    await _pump(
      tester,
      (context) => _tile(
        context,
        onTapAvatar: () => avatarTaps++,
        onTap: () => rowTaps++,
        onLongPress: () => longPresses++,
      ),
    );

    await tester.tap(find.byKey(_avatarKey));
    expect(avatarTaps, 1);
    expect(rowTaps, 0);
    await tester.tap(find.text(_title));
    expect(rowTaps, 1);
    await tester.longPress(find.text(_title));
    expect(longPresses, 1);
    expect(rowTaps, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('pressed feedback follows the system reduced-motion preference', (
    tester,
  ) async {
    await _pump(tester, (context) => _tile(context));
    expect(
      tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).duration,
      AppDuration.buttonPress,
    );
    await _pump(tester, (context) => _tile(context), reduceMotion: true);
    expect(
      tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).duration,
      Duration.zero,
    );
  });
}

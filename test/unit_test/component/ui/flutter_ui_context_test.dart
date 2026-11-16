import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The root deliberately supplies only the public, extracted UI libraries.
// Legacy Theme/Material/localization wrappers would hide the integration fault.
Widget _newUiRoot(Widget child, ThemeData theme) {
  return ProviderScope(
    child: MaterialApp(
      theme: theme,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    ),
  );
}

ThemeData _theme(Brightness brightness) {
  final theme = ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: brightness,
    ),
  );
  return theme.copyWith(
    disabledColor: brightness == Brightness.dark
        ? Colors.cyanAccent
        : Colors.deepOrange,
    textTheme: theme.textTheme.copyWith(
      labelLarge: theme.textTheme.labelLarge!.copyWith(fontSize: 23),
    ),
  );
}

List<CategoryEmoji> _emojiFixture(Locale locale) => const [
  CategoryEmoji(Category.smileys, [Emoji('😀', 'smile')]),
  CategoryEmoji(Category.animals, [Emoji('🐱', 'cat')]),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'emoji default tabs and search use new UI resources: $brightness',
      (tester) async {
        final selected = <String>[];
        final theme = _theme(brightness);
        await tester.pumpWidget(
          _newUiRoot(
            EmojiPicker(
              onEmojiSelected: (_, emoji) => selected.add(emoji.emoji),
              config: const Config(
                height: 280,
                checkPlatformCompatibility: false,
                emojiSet: _emojiFixture,
                locale: Locale('zh', 'CN'),
                categoryViewConfig: CategoryViewConfig(
                  initCategory: Category.smileys,
                  recentTabBehavior: RecentTabBehavior.none,
                ),
                emojiViewConfig: EmojiViewConfig(columns: 4),
                skinToneConfig: SkinToneConfig(enabled: false),
              ),
            ),
            theme,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(TabBar), findsOneWidget);
        final tabContext = tester.element(find.byType(TabBar));
        expect(Theme.of(tabContext).brightness, brightness);
        expect(MaterialLocalizations.of(tabContext).closeButtonTooltip, '关闭');

        await tester.tap(find.byType(Tab).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('🐱'));
        await tester.pumpAndSettle();
        expect(selected, ['🐱']);

        await tester.tap(find.byType(SearchButton));
        await tester.pumpAndSettle();
        expect(find.byType(DefaultSearchView), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'smile');
        await tester.pumpAndSettle();
        expect(find.text('😀'), findsOneWidget);
        expect(find.text('🐱'), findsNothing);
        await tester.tap(find.text('😀'));
        await tester.pumpAndSettle();
        expect(selected, ['🐱', '😀']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'highlighted words remain tappable under new Material: $brightness',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _newUiRoot(
            TextHighlight(
              text: 'find needle in this message',
              words: {'needle': HighlightedWord(onTap: () => taps++)},
            ),
            _theme(brightness),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('needle'), findsOneWidget);
        await tester.tap(find.text('needle'));
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'slidable actions inherit the new button theme and respond: $brightness',
      (tester) async {
        var taps = 0;
        final theme = _theme(brightness);
        await tester.pumpWidget(
          _newUiRoot(
            Slidable(
              key: const ValueKey('conversation-row'),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.5,
                children: [
                  SlidableAction(
                    label: '归档',
                    icon: Icons.archive,
                    onPressed: (_) => taps++,
                  ),
                ],
              ),
              child: const SizedBox(
                height: 80,
                child: Center(child: Text('Conversation')),
              ),
            ),
            theme,
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(const ValueKey('conversation-row')),
          const Offset(-240, 0),
        );
        await tester.pumpAndSettle();

        final label = find.text('归档');
        expect(label, findsOneWidget);
        expect(
          DefaultTextStyle.of(tester.element(label)).style.fontSize,
          theme.textTheme.labelLarge!.fontSize,
        );
        await tester.tap(label);
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'rating masks use the new theme and selection still changes: $brightness',
      (tester) async {
        double? selected;
        final theme = _theme(brightness);
        await tester.pumpWidget(
          _newUiRoot(
            RatingBar.builder(
              initialRating: 1,
              itemCount: 3,
              itemSize: 40,
              glow: false,
              itemBuilder: (_, index) => Icon(
                Icons.star,
                key: ValueKey('rating-item-$index'),
                color: Colors.amber,
              ),
              onRatingUpdate: (value) => selected = value,
            ),
            theme,
          ),
        );
        await tester.pumpAndSettle();

        final masks = find.descendant(
          of: find.byType(RatingBar),
          matching: find.byType(ColorFiltered),
        );
        expect(masks, findsNWidgets(2));
        expect(
          tester
              .widgetList<ColorFiltered>(masks)
              .map((widget) => widget.colorFilter),
          everyElement(ColorFilter.mode(theme.disabledColor, BlendMode.srcIn)),
        );
        await tester.tap(find.byKey(const ValueKey('rating-item-2')));
        await tester.pumpAndSettle();
        expect(selected, 3);
        expect(masks, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/web_shell/web_group_info_panel.dart';

void main() {
  test('only the current empty scope permits focus restoration', () {
    final currentScope = FocusScopeNode();
    final otherScope = FocusScopeNode();
    final root = FocusScopeNode();
    final otherControl = FocusNode();
    try {
      bool allows(FocusNode? focused) => canRestoreGroupDialogFocus(
        focused: focused,
        currentScope: currentScope,
        rootScope: root,
      );
      expect(allows(null), isTrue);
      expect(allows(root), isTrue);
      expect(allows(currentScope), isTrue);
      expect(allows(otherScope), isFalse);
      expect(allows(otherControl), isFalse);
    } finally {
      currentScope.dispose();
      otherScope.dispose();
      root.dispose();
      otherControl.dispose();
    }
  });

  testWidgets('keyboard focus returns to group info after dialog closes', (
    tester,
  ) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: WebGroupInfoButton(
              groupId: 'fixture',
              panelBuilder: (_) => const Text('synthetic group panel'),
            ),
          ),
        ),
      ),
    );
    final button = find.byKey(const ValueKey('web-group-info'));
    final focus = tester.widget<IconButton>(button).focusNode!;
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('synthetic group panel'), findsOneWidget);
    final close = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(IconButton),
    );
    await tester.tap(close);
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.widget<IconButton>(button).onPressed, isNull);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(focus.hasFocus, isTrue);
  });

  testWidgets(
    'dialog traps forward and reverse traversal and uses theme barrier',
    (tester) async {
      final outside = FocusNode();
      addTearDown(outside.dispose);
      const barrier = Color(0x77010203);
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            theme: ThemeData(
              dialogTheme: const DialogThemeData(barrierColor: barrier),
            ),
            home: Scaffold(
              body: Column(
                children: [
                  TextButton(
                    focusNode: outside,
                    onPressed: () {},
                    child: const Text('outside'),
                  ),
                  WebGroupInfoButton(
                    groupId: 'fixture',
                    panelBuilder: (_) => TextButton(
                      onPressed: () {},
                      child: const Text('inside'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final button = find.byKey(const ValueKey('web-group-info'));
      tester.widget<IconButton>(button).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final dialog = tester.element(find.byType(Dialog));
      final route = ModalRoute.of(dialog)! as DialogRoute<void>;
      expect(route.barrierColor, barrier);
      expect(route.traversalEdgeBehavior, TraversalEdgeBehavior.closedLoop);

      bool insideDialog() {
        final context = FocusManager.instance.primaryFocus?.context;
        if (context == null) return false;
        var inside = false;
        context.visitAncestorElements((ancestor) {
          if (identical(ancestor, dialog)) inside = true;
          return !inside;
        });
        return inside;
      }

      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(insideDialog(), isTrue);
        expect(outside.hasFocus, isFalse);
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(insideDialog(), isTrue);
        expect(outside.hasFocus, isFalse);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    },
  );

  testWidgets('focus moved to another control during closing is preserved', (
    tester,
  ) async {
    final other = FocusNode();
    addTearDown(other.dispose);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                WebGroupInfoButton(
                  groupId: 'fixture',
                  panelBuilder: (_) => const Text('panel'),
                ),
                TextButton(
                  focusNode: other,
                  onPressed: () {},
                  child: const Text('other'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final button = find.byKey(const ValueKey('web-group-info'));
    final original = tester.widget<IconButton>(button).focusNode!;
    original.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    other.requestFocus();
    await tester.pumpAndSettle();
    expect(other.hasFocus, isTrue);
    expect(original.hasFocus, isFalse);
  });

  testWidgets('disposing the originating widget during dialog exit is safe', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: WebGroupInfoButton(
              groupId: 'fixture',
              panelBuilder: (_) => const Text('panel'),
            ),
          ),
        ),
      ),
    );
    final button = find.byKey(const ValueKey('web-group-info'));
    tester.widget<IconButton>(button).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigating during dialog exit keeps focus on the new route', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final destinationFocus = FocusNode();
    addTearDown(destinationFocus.dispose);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: WebGroupInfoButton(
              groupId: 'fixture',
              panelBuilder: (_) => const Text('panel'),
            ),
          ),
        ),
      ),
    );
    final button = find.byKey(const ValueKey('web-group-info'));
    final original = tester.widget<IconButton>(button).focusNode!;
    original.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: TextButton(
            focusNode: destinationFocus,
            autofocus: true,
            onPressed: () {},
            child: const Text('destination'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(destinationFocus.hasFocus, isTrue);
    expect(original.hasFocus, isFalse);
  });

  testWidgets(
    'reopening waits for exit and previous restore does not steal focus',
    (tester) async {
      final inside = FocusNode();
      addTearDown(inside.dispose);
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: WebGroupInfoButton(
                groupId: 'fixture',
                panelBuilder: (_) => TextButton(
                  focusNode: inside,
                  onPressed: () {},
                  child: const Text('inside'),
                ),
              ),
            ),
          ),
        ),
      );
      final button = find.byKey(const ValueKey('web-group-info'));
      final original = tester.widget<IconButton>(button).focusNode!;
      original.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.widget<IconButton>(button).onPressed, isNull);
      await tester.pumpAndSettle();
      expect(original.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      inside.requestFocus();
      await tester.pump();
      expect(inside.hasFocus, isTrue);
      expect(original.hasFocus, isFalse);
    },
  );
}

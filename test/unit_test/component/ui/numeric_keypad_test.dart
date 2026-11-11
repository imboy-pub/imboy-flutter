import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/numeric_keypad.dart';
import 'package:imboy/i18n/strings.g.dart';

Future<void> _pumpKeypad(
  WidgetTester tester,
  NumericKeypadController controller,
  ValueChanged<String> onChanged, {
  int? maxLength,
  bool enabled = true,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 375,
              child: NumericKeypad(
                controller: controller,
                onChanged: onChanged,
                maxLength: maxLength,
                enabled: enabled,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const soundChannel = MethodChannel('imboy/sound');
  final soundCalls = <MethodCall>[];

  setUp(() {
    soundCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(soundChannel, (call) async {
          soundCalls.add(call);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(soundChannel, null);
  });

  testWidgets('实体键盘输入数字和退格复用四位限制', (tester) async {
    final controller = NumericKeypadController('');
    addTearDown(controller.dispose);
    final changes = <String>[];
    await _pumpKeypad(tester, controller, changes.add, maxLength: 4);
    for (final key in [
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ]) {
      await tester.sendKeyEvent(key, character: key.keyLabel);
      await tester.pump();
    }
    expect(controller.value, '0123');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(controller.value, '012');
    expect(changes, ['0', '01', '012', '0123', '012']);
  });

  testWidgets('四位上限与禁用态不能修改输入，删除后可以补位', (tester) async {
    final controller = NumericKeypadController('0123');
    addTearDown(controller.dispose);
    final changes = <String>[];
    await _pumpKeypad(tester, controller, changes.add, maxLength: 4);
    await tester.tap(find.text('4'));
    await tester.pump();
    expect(controller.value, '0123');
    expect(changes, isEmpty);
    await tester.tap(find.bySemanticsLabel(t.common.buttonDelete));
    await tester.pump();
    await tester.tap(find.text('4'));
    await tester.pump();
    expect(controller.value, '0124');
    expect(changes, ['012', '0124']);
    await _pumpKeypad(
      tester,
      controller,
      changes.add,
      maxLength: 4,
      enabled: false,
    );
    await tester.tap(find.bySemanticsLabel(t.common.buttonDelete));
    await tester.pump();
    expect(controller.value, '0124');
  });

  testWidgets('数字与删除保持输入回调，空白格不播放声音或修改内容', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = NumericKeypadController('');
    addTearDown(controller.dispose);
    final changes = <String>[];
    try {
      await _pumpKeypad(tester, controller, changes.add);
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();
      expect(controller.value, '10');
      expect(changes, ['1', '10']);
      expect(soundCalls, hasLength(2));

      // 左下空格位于第一列、零键同一行，保留布局但不能产生按键音。
      await tester.tapAt(
        Offset(
          tester.getCenter(find.text('1')).dx,
          tester.getCenter(find.text('0')).dy,
        ),
      );
      await tester.pump();
      expect(controller.value, '10');
      expect(changes, ['1', '10']);
      expect(soundCalls, hasLength(2));

      final delete = find.bySemanticsLabel(t.common.buttonDelete);
      expect(delete, findsOneWidget);
      expect(tester.getSemantics(delete).flagsCollection.isButton, isTrue);
      for (var i = 0; i < 3; i++) {
        await tester.tap(delete);
        await tester.pump();
      }
      expect(controller.value, isEmpty);
      expect(changes, ['1', '10', '1', '']);
      expect(soundCalls, hasLength(5));
      expect(
        soundCalls.map((call) => call.method),
        everyElement('playMetallicSound'),
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Tab 依次到达数字和具名删除键，Enter 执行同一输入契约', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = NumericKeypadController('');
    addTearDown(controller.dispose);
    final changes = <String>[];
    try {
      await _pumpKeypad(tester, controller, changes.add);
      final labels = [
        for (var digit = 1; digit <= 9; digit++) '$digit',
        '0',
        t.common.buttonDelete,
      ];
      for (final label in labels) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final control = find.bySemanticsLabel(label);
        expect(control, findsOneWidget);
        final node = tester.getSemantics(control);
        expect(node.label, label);
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.flagsCollection.isFocused.toBoolOrNull(), isTrue);
        if (label == '1' || label == '0' || label == t.common.buttonDelete) {
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
        }
      }
      expect(controller.value, '1');
      expect(changes, ['1', '10', '1']);
      expect(soundCalls, hasLength(3));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}

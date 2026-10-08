import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/vote/group_vote_input_fields.dart';

void main() {
  testWidgets('标题和选项使用普通键盘并接受中文 composing', (tester) async {
    final title = TextEditingController();
    final options = TextEditingController();
    await tester.pumpWidget(
      CupertinoApp(
        home: GroupVoteInputFields(
          titleController: title,
          optionsController: options,
        ),
      ),
    );
    final fields = tester
        .widgetList<CupertinoTextField>(find.byType(CupertinoTextField))
        .toList();
    expect(fields.first.keyboardType, TextInputType.text);
    expect(fields.last.keyboardType, TextInputType.multiline);
    for (var i = 0; i < fields.length; i++) {
      expect(fields[i].enableSuggestions, isTrue);
      expect(fields[i].autocorrect, isTrue);
      expect(fields[i].obscureText, isFalse);
      await tester.showKeyboard(find.byType(CupertinoTextField).at(i));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '旅游',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();
      expect(i == 0 ? title.text : options.text, '旅游');
    }
    await tester.pumpWidget(const SizedBox());
    title.dispose();
    options.dispose();
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/attachments/personal_attachment_repository.dart';
import 'package:imboy/modules/attachments/personal_attachments_page.dart';
import 'package:imboy/modules/attachments/personal_attachments_view.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/theme.dart';

class _Repository extends PersonalAttachmentRepository {
  final calls = <(int, String)>[];
  late Future<List<PersonalAttachment>> Function(int, String) respond;

  @override
  Future<List<PersonalAttachment>> page({
    int offset = 0,
    int limit = 40,
    String keyword = '',
  }) {
    calls.add((offset, keyword));
    return respond(offset, keyword);
  }
}

void main() {
  setUp(() async {
    await StorageService.to.setString(Keys.currentUid, 'attachment-fixture');
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  testWidgets('loading failure retry and search use the existing repository', (
    tester,
  ) async {
    final initial = Completer<List<PersonalAttachment>>();
    final repository = _Repository()..respond = (_, _) => initial.future;
    await _pump(tester, PersonalAttachmentsPage(repository: repository));
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    initial.completeError(Exception('synthetic local index failure'));
    await tester.pumpAndSettle();
    expect(find.text(t.attachmentManager.moreFailed), findsOneWidget);
    expect(find.text(t.attachmentManager.emptyLocal), findsNothing);
    repository.respond = (_, keyword) async =>
        keyword.isEmpty ? [_item('1', '设计说明.pdf')] : [];
    await tester.tap(find.byKey(const ValueKey('personal-attachment-retry')));
    await tester.pumpAndSettle();
    expect(find.text('设计说明.pdf'), findsOneWidget);
    await tester.enterText(find.byType(CupertinoSearchTextField), '不存在');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(repository.calls.last, (0, '不存在'));
    expect(find.text(t.attachmentManager.emptySearch), findsOneWidget);
    expect(find.byType(PersonalAttachmentRow), findsNothing);
  });

  testWidgets(
    'pagination keeps stable offsets and refresh resets the first page',
    (tester) async {
      final repository = _Repository()
        ..respond = (offset, _) async => offset == 0
            ? List.generate(40, (i) => _item('$i', '文件$i.pdf'))
            : [_item('last', '最后文件.pdf')];
      await _pump(tester, PersonalAttachmentsPage(repository: repository));
      await tester.pumpAndSettle();
      final more = find.byKey(const ValueKey('personal-attachment-more'));
      await tester.scrollUntilVisible(
        more,
        500,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(repository.calls, [(0, ''), (40, '')]);
      expect(
        find.byKey(const ValueKey('personal-attachment-more')),
        findsNothing,
      );
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refresh.onRefresh();
      await tester.pumpAndSettle();
      expect(repository.calls.last, (0, ''));
    },
  );

  testWidgets('old account response cannot appear after account changes', (
    tester,
  ) async {
    final response = Completer<List<PersonalAttachment>>();
    final repository = _Repository()..respond = (_, _) => response.future;
    await _pump(tester, PersonalAttachmentsPage(repository: repository));
    await StorageService.to.setString(Keys.currentUid, 'other-fixture');
    response.complete([_item('old', '旧账号内容.pdf')]);
    await tester.pumpAndSettle();
    expect(find.text('旧账号内容.pdf'), findsNothing);
    expect(find.byType(PersonalAttachmentsView), findsNothing);
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('attachment rows stay readable at 320 $brightness $scale', (
        tester,
      ) async {
        final search = TextEditingController();
        addTearDown(search.dispose);
        PersonalAttachment? opened;
        final item = _item('sample', '这是一个较长的附件名称并包含版本信息.pdf');
        await _pump(
          tester,
          Scaffold(
            body: PersonalAttachmentsView(
              search: search,
              items: [item],
              loading: false,
              hasMore: false,
              hasError: false,
              onSearchChanged: (_) {},
              onRefresh: () async {},
              onMore: () {},
              onOpen: (item) => opened = item,
            ),
          ),
          brightness: brightness,
          scale: scale,
        );
        final row = find.byKey(const ValueKey('personal-attachment-sample'));
        await tester.tap(row);
        expect(opened, same(item));
        final surface = tester
            .widget<ColoredBox>(
              find.descendant(of: row, matching: find.byType(ColoredBox)).first,
            )
            .color;
        expect(surface, isNot(AppColors.getSurfaceGrouped(brightness)));
        final text = tester.widget<Text>(find.text(item.name));
        expect(text.style!.color, AppColors.getTextColor(brightness));
        expect(tester.takeException(), isNull);
      });
    }
  }
}

PersonalAttachment _item(String id, String name) => PersonalAttachment(
  MessageModel.fromJson({
    'id': id,
    'auto_id': 1,
    'type': 'C2C',
    'from_id': 'attachment-fixture',
    'to_id': 'attachment-peer',
    'payload': jsonEncode({'filename': name}),
    'created_at': 1000,
    'conversation_uk3': 'C2C_attachment-fixture_attachment-peer',
    'is_author': 1,
    'status': 11,
    'msg_type': 'file',
  }),
  name,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(320, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.getDarkTheme()
            : AppTheme.getLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
}

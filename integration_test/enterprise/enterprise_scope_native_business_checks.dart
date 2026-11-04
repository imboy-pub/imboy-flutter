part of 'enterprise_scope_native_test.dart';

Future<void> checkNativeWorkspaceUnread(WidgetTester tester) async {
  // 真机 USB 链路偶发 503/瞬态断连（r1 实证：同请求 curl 200）——退避重试。
  List<WorkspaceConversationModel>? initial;
  for (var i = 0; i < 4; i++) {
    try {
      initial = await tester.runAsync(
        () => WorkspaceApi().conversations('995201'),
      );
      break;
    } on WorkspaceApiException catch (e) {
      if (i == 3) rethrow;
      debugPrint('NATIVE_WS_CONVERSATIONS_RETRY #$i err=$e');
      await tester.runAsync(
        () => Future<void>.delayed(Duration(milliseconds: 500 * (i + 1))),
      );
    }
  }
  expect(initial, isNotNull);
  expect(
    initial!.singleWhere((row) => row.group.groupId == '995301').unreadCount,
    2,
  );
  await selectEnterpriseTab(tester, t.chat.titleMessage);
  const badgeKey = ValueKey('workspace-unread-995301');
  final badge = find.byKey(badgeKey);
  await waitFor(tester, badge);
  final before = tester.widget<BadgeWidget>(badge);
  expect(before.showBadge, isTrue);
  expect((before.content! as Text).data, '2');
  final row = find.byKey(const ValueKey('workspace-message-995301'));
  await waitFor(tester, row.hitTestable());
  await tester.tap(row);
  await waitFor(tester, find.byType(ChatPage));
  await tester.pump(const Duration(milliseconds: 2500));
  // 诊断 dump：气泡文本经 GptMarkdown 渲染，失败时看不出实际内容——
  // 把屏上全部 Text/RichText 纯文本打出来取证（含 E2EE 占位文案情形）。
  final onScreen = find
      .byWidgetPredicate((w) => w is Text || w is RichText)
      .evaluate()
      .map((e) {
        final w = e.widget;
        if (w is Text) return w.data ?? w.textSpan?.toPlainText() ?? '<span>';
        return (w as RichText).text.toPlainText();
      })
      .where((s) => s.trim().isNotEmpty)
      .join(' | ');
  debugPrint(
    'NATIVE_CHAT_TEXTS ${onScreen.length > 1200 ? '${onScreen.substring(0, 1200)}…' : onScreen}',
  );
  for (final body in ['native unread one', 'native unread two']) {
    // 气泡文本经 GptMarkdown（RichText/TextSpan）渲染——find.text 默认不
    // 匹配 RichText，须开 findRichText（r11 实证 fetched=2 但 0 匹配）。
    final bubble = find.text(body, findRichText: true);
    await waitFor(tester, bubble);
    await tester.ensureVisible(bubble);
    await tester.pump(const Duration(milliseconds: 300));
  }
  await waitForNativeGroupRead(tester);
  final back = find.byType(GlassBackButton).hitTestable();
  await waitFor(tester, back);
  await tester.tap(back);
  await waitFor(
    tester,
    find.byWidgetPredicate(
      (widget) =>
          widget is BadgeWidget && widget.key == badgeKey && !widget.showBadge,
    ),
  );
  expect(tester.takeException(), isNull);
  debugPrint('NATIVE_WORKSPACE_UNREAD_READ_CURSOR_UI_PASS');
}

Future<void> waitForNativeGroupRead(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 40));
  while (true) {
    final rows = await tester.runAsync(
      () => WorkspaceApi().conversations('995201'),
    );
    if (rows!.singleWhere((row) => row.group.groupId == '995301').unreadCount ==
        0) {
      break;
    }
    expect(
      DateTime.now().isBefore(deadline),
      isTrue,
      reason: 'Visible messages must persist their read receipt',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
  }
}

Future<void> checkNativeGroupMessage(WidgetTester tester) async {
  const body = 'synthetic native workspace message';
  await selectEnterpriseTab(tester, t.enterpriseOa.workbenchTitle);
  await waitFor(
    tester,
    find.byKey(const ValueKey('workbench-official-website')),
  );
  expect(find.text('https://imboy.pub/'), findsOneWidget);
  await waitFor(tester, find.text(t.workspace.navGroups).hitTestable());
  await tester.tap(find.text(t.workspace.navGroups));
  final group = find.byKey(const ValueKey('workspace-group-tile-995301'));
  await waitFor(tester, group.hitTestable());
  await tester.tap(group);
  await waitFor(tester, find.byType(ChatPage));
  final chat = tester.widget<ChatPage>(find.byType(ChatPage));
  expect(chat.peerId, '995301');
  expect(chat.type, 'C2G');
  expect(AppFeatureRegistry.isEnabled(FeatureKeys.e2ee), isFalse);
  final input = find.byKey(const Key('chat_message_input'));
  await waitFor(tester, input.hitTestable());
  await tester.enterText(input, body);
  await tester.pump(const Duration(milliseconds: 450));
  final send = find.byKey(const ValueKey('send_button_inner')).hitTestable();
  await waitFor(tester, send);
  await tester.tap(send);
  await waitFor(
    tester,
    find.byWidgetPredicate(
      (widget) =>
          widget is CupertinoTextField &&
          widget.key == const Key('chat_message_input') &&
          widget.controller?.text.isEmpty == true,
    ),
  );
  await waitFor(tester, find.text(body, findRichText: true));
  expect(tester.takeException(), isNull);
  final back = find.byType(GlassBackButton).hitTestable();
  await waitFor(tester, back);
  await tester.tap(back);
  await waitFor(tester, group.hitTestable());
  await backDirectory(tester);
  debugPrint('NATIVE_WORKSPACE_GROUP_MESSAGE_UI_PASS');
}

Future<void> checkNativeChannelDiscussion(WidgetTester tester) async {
  await waitFor(tester, find.text(t.channel.title).hitTestable());
  await tester.tap(find.text(t.channel.title));
  final channel = find.byKey(const ValueKey('workspace-channel-tile-995501'));
  await waitFor(tester, channel.hitTestable());
  await tester.tap(channel);
  await waitFor(tester, find.byType(WorkspaceChannelDetailPage));
  expect(
    tester.widget<ChannelDetailPage>(find.byType(ChannelDetailPage)).channelId,
    '995501',
  );
  await waitFor(tester, find.text('intbe02-ch'));
  expect(find.byType(ChatInput), findsNothing);
  final guide = find.byKey(const ValueKey('workspace-channel-discuss-guide'));
  await waitFor(tester, guide.hitTestable());
  await tester.tap(guide);
  await waitFor(
    tester,
    find.byKey(const ValueKey('workspace-group-tile-995301')),
  );
  await backDirectory(tester);
  await waitFor(tester, find.byType(WorkspaceChannelDetailPage));
  final back = find.byType(GlassBackButton).hitTestable();
  await waitFor(tester, back);
  await tester.tap(back);
  await waitFor(tester, channel.hitTestable());
  await backDirectory(tester);
  debugPrint('NATIVE_WORKSPACE_CHANNEL_DISCUSSION_UI_PASS');
}

Future<void> checkNativeGroupFile(WidgetTester tester) async {
  const groupId = '995301';
  const name = 'native-enterprise-file.txt';
  const body = 'synthetic native enterprise file';
  // Purge stale same-name uploads left by earlier failed rounds so the fresh
  // file is the only matching row (tap() below needs a unique target).
  while (true) {
    final before = await tester.runAsync(
      () => GroupFileService.to.getFiles(groupId: groupId),
    );
    final staleRows = (before!['list'] as List)
        .cast<Map<String, dynamic>>()
        .where((row) => row['file_name'] == name)
        .toList();
    if (staleRows.isEmpty) break;
    expect(
      await tester.runAsync(
        () => GroupFileService.to.deleteFile(staleRows.first['id']),
      ),
      isTrue,
    );
  }
  // direct-v1 直传：本地落临时文件后走 register→PUT→finalize→bind。
  final Directory tmp = await Directory.systemTemp.createTemp('ent-group-file');
  final File local = File('${tmp.path}/$name')..writeAsStringSync(body);
  addTearDown(() => tmp.delete(recursive: true));
  final Map<String, dynamic>? created = await tester
      .runAsync<Map<String, dynamic>?>(
        () => GroupFileService.to.uploadFileDirect(
          groupId: groupId,
          file: local,
          fileName: name,
          mime: 'text/plain',
          clientUploadId: newClientUploadId(),
        ),
      );
  expect(created, isNotNull);
  await selectEnterpriseTab(tester, t.enterpriseOa.workbenchTitle);
  await waitFor(tester, find.text(t.chat.groupFile).hitTestable());
  await tester.tap(find.text(t.chat.groupFile));
  final group = find.byKey(const ValueKey('workspace-group-tile-995301'));
  await waitFor(tester, group.hitTestable());
  await tester.tap(group);
  await waitFor(tester, find.byType(GroupFilePage));
  await waitFor(tester, find.text(name).hitTestable());
  await tester.tap(find.text(name));
  await waitFor(tester, find.byType(WebViewWidget));
  await expectNativeFileBody(tester, body);
  final back = find.byType(GlassBackButton).hitTestable();
  await waitFor(tester, back);
  await tester.tap(back);
  await waitFor(tester, find.byType(GroupFilePage));
  await tester.pumpAndSettle();
  expect(find.byType(WebViewWidget), findsNothing);
  await checkDeletedNativeFile(tester, groupId, name);
  await waitFor(tester, back);
  await tester.tap(back);
  await waitFor(tester, group.hitTestable());
  await backDirectory(tester);
}

Future<void> checkDeletedNativeFile(
  WidgetTester tester,
  String groupId,
  String name,
) async {
  final row = find
      .descendant(of: find.byType(GroupFilePage), matching: find.text(name))
      .hitTestable();
  await waitFor(tester, row);
  final payload = await tester.runAsync(
    () => GroupFileService.to.getFiles(groupId: groupId),
  );
  final files = (payload!['list'] as List).cast<Map<String, dynamic>>();
  final file = files.singleWhere((row) => row['file_name'] == name);
  expect(
    await tester.runAsync(() => GroupFileService.to.deleteFile(file['id'])),
    isTrue,
  );
  // Keep the stale row mounted: tapping it must reauthorize and refuse preview.
  await tester.tap(row);
  await waitFor(tester, find.text(t.common.groupFileOpenFailed));
  expect(find.byType(WebViewWidget), findsNothing);
  expect(tester.takeException(), isNull);
  debugPrint('NATIVE_GROUP_FILE_PREVIEW_AND_DELETION_DENIAL_PASS');
}

Future<void> expectNativeFileBody(WidgetTester tester, String body) async {
  final url = tester.widget<WebViewPage>(find.byType(WebViewPage)).url;
  final httpMatches = await tester.runAsync(() async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(Uri.parse(url))).close();
      final bytes = await response.fold<List<int>>(
        [],
        (all, part) => [...all, ...part],
      );
      debugPrint(
        'NATIVE_FILE_HTTP status=${response.statusCode} '
        'mime=${response.headers.contentType?.mimeType} bytes=${bytes.length}',
      );
      return response.statusCode == 200 &&
          response.headers.contentType?.mimeType == 'text/plain' &&
          String.fromCharCodes(bytes) == body;
    } finally {
      client.close(force: true);
    }
  });
  expect(httpMatches, isTrue);
  final controller = tester
      .widget<WebViewWidget>(find.byType(WebViewWidget))
      .platform
      .params
      .controller;
  await tester.pump(const Duration(milliseconds: 600));
  final currentUrl = await tester.runAsync(controller.currentUrl);
  expect(Uri.parse(currentUrl!).path, '/api/v1/attachment/content');
  // The download CSP sandbox forbids JavaScript; the host runner verifies
  // rendered text through Android accessibility instead of weakening the CSP.
  debugPrint('NATIVE_FILE_VISIBILITY_READY');
  const observationSeconds = int.fromEnvironment(
    'TEST_NATIVE_PREVIEW_OBSERVATION_SECONDS',
    defaultValue: 90,
  );
  final deadline = DateTime.now().add(Duration(seconds: observationSeconds));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
}

Future<void> checkNativeOrgGovernance(WidgetTester tester) async {
  await openNativeDepartments(tester);
  final create = find.byTooltip(t.organization.departments.createRootDept);
  await waitFor(tester, create.hitTestable());
  await tester.tap(create);
  await submitDepartmentName(tester, 'native-owner-created');
  await waitFor(tester, find.text('native-owner-created').hitTestable());
  await departmentAction(
    tester,
    'native-owner-created',
    t.organization.common.rename,
  );
  await submitDepartmentName(tester, 'native-owner-renamed');
  await waitFor(tester, find.text('native-owner-renamed').hitTestable());
  expect(find.text('native-owner-created'), findsNothing);
  await departmentAction(
    tester,
    'native-owner-renamed',
    t.organization.departments.archiveDept,
  );
  final dialog = find.byType(AlertDialog);
  await waitFor(tester, dialog);
  await tester.tap(
    find.descendant(of: dialog, matching: find.byType(TextButton)).last,
  );
  await waitFor(tester, find.text('已归档').hitTestable());
  expect(tester.takeException(), isNull);
  await backDirectory(tester);
  await backDirectory(tester);
}

Future<void> openNativeDepartments(WidgetTester tester) async {
  await selectEnterpriseTab(tester, t.common.me);
  final manage = find.text(t.organization.manage.entry);
  await waitFor(tester, manage.hitTestable());
  await tester.tap(manage);
  final zone = find.byKey(const Key('organization-detail-zone-departments'));
  final scroll = find.descendant(
    of: find.byType(OrganizationDetailPage),
    matching: find.byType(Scrollable),
  );
  await waitFor(tester, scroll.hitTestable());
  // scrollUntilVisible 的内部判定不含 hitTestable 过滤，且 BouncingScrollPhysics
  // 会在返回后回弹、把刚滚到的 tile 弹离 lazy 视口（视口外即不 build）——
  // 小步 drag 循环直到 tile 可命中再点（与防浮层 waitFor 模式同族）。
  for (var i = 0; i < 24 && zone.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(scroll, const Offset(0, -180));
    await tester.pump(const Duration(milliseconds: 150));
  }
  await waitFor(tester, zone.hitTestable());
  await tester.tap(zone.hitTestable().first);
  await waitFor(tester, find.byType(OrganizationDepartmentsPage));
}

Future<void> submitDepartmentName(WidgetTester tester, String name) async {
  final dialog = find.byType(AlertDialog);
  await waitFor(tester, dialog);
  await tester.enterText(
    find.descendant(of: dialog, matching: find.byType(TextField)),
    name,
  );
  await tester.tap(
    find.descendant(of: dialog, matching: find.byType(TextButton)).last,
  );
}

Future<void> departmentAction(
  WidgetTester tester,
  String name,
  String action,
) async {
  final row = find.ancestor(
    of: find.text(name),
    matching: find.byType(ListTile),
  );
  await tester.tap(find.descendant(of: row, matching: find.byType(IconButton)));
  await waitFor(tester, find.text(action).hitTestable());
  await tester.tap(find.text(action).hitTestable());
}

Future<void> checkNativeOa(WidgetTester tester) async {
  await selectEnterpriseTab(tester, t.enterpriseOa.workbenchTitle);
  final entry = find.byKey(const Key('workbench-application-intbe02-oa-sso'));
  await waitFor(tester, entry.hitTestable());
  await tester.tap(entry);
  await waitFor(tester, find.byType(WebViewWidget));
  final controller = tester
      .widget<WebViewWidget>(find.byType(WebViewWidget))
      .platform
      .params
      .controller;
  final deadline = DateTime.now().add(const Duration(seconds: 40));
  Object? result;
  while (result != '"995011"' && DateTime.now().isBefore(deadline)) {
    result = await tester.runAsync(
      () => controller.runJavaScriptReturningResult(
        'document.body.dataset.nativeSso || "loading"',
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  expect(result, '"995011"');
  expect(tester.takeException(), isNull);
  final back = find.byType(BackButton).hitTestable();
  await waitFor(tester, back);
  await tester.tap(back);
  await waitFor(tester, entry.hitTestable());
  expect(find.byType(WebViewWidget), findsNothing);
  expect(tester.takeException(), isNull);
}

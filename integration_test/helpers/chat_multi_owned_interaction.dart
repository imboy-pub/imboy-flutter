part of '../chat_multi_select_test.dart';

// Owned-run coordination and the externally driven checkbox challenge.

Future<void> _awaitOwnedRelease(WidgetTester tester, String uid) async {
  const nonce = String.fromEnvironment('CHAT_MULTI_RUN_NONCE');
  final generation = UserRepoLocal.to.sessionGeneration;
  final barrier = await tester.runAsync(
    () => prepareOwnedChatBarrier(
      nonce: nonce,
      uid: uid,
      storageTag: _ownedStorageTag,
    ),
  );
  expect(barrier, isNotNull);
  expect(UserRepoLocal.to.isCurrentSession(generation), isTrue);
  expect(UserRepoLocal.to.currentUid, uid);
  flowLog(
    'W3K-MS OWNED_READY ${jsonEncode({...barrier!.identity, 'releasePath': barrier.release.path})}',
  );
  var released = false;
  final deadline = DateTime.now().add(const Duration(minutes: 6));
  while (!released && DateTime.now().isBefore(deadline)) {
    expect(UserRepoLocal.to.currentUid, uid);
    expect(UserRepoLocal.to.isCurrentSession(generation), isTrue);
    released =
        await tester.runAsync(
          () => ownedChatReleaseMatches(barrier.release, barrier.identity),
        ) ??
        false;
    if (!released) await tester.pump(const Duration(milliseconds: 500));
  }
  expect(UserRepoLocal.to.isCurrentSession(generation), isTrue);
  expect(UserRepoLocal.to.currentUid, uid);
  expect(
    released,
    isTrue,
    reason: 'Controller must release this exact owned run',
  );
}

Future<void> _awaitOwnedCheckboxTap(
  WidgetTester tester,
  Finder chat,
  String firstId,
  String secondId,
  String nonce,
) async {
  final uid = UserRepoLocal.to.currentUid;
  final generation = UserRepoLocal.to.sessionGeneration;
  final container = ProviderScope.containerOf(tester.element(chat));
  final conversation = await ConversationRepo().findByPeerId(
    'C2C',
    const String.fromEnvironment('CHAT_MULTI_SRC_PEER_UID'),
  );
  expect(conversation, isNotNull);
  final provider = messageSelectionProvider(conversation!.uk3);
  final beforeToggles = ChatMultiDriverRunStats.productionToggleUsed;
  expect(ChatMultiDriverRunStats.realLongPressEnterOk, greaterThan(0));
  expect(container.read(provider).selectedIds, unorderedEquals([firstId]));
  expectSelectionCount(tester, 1);
  final checkbox = find.byKey(ValueKey('multi_select_check_$secondId'));
  unawaited(
    container.read(chatProvider.notifier).scrollToMessage('C2C', secondId),
  );
  expect(await waitForFinder(tester, checkbox, maxSeconds: 10), isTrue);
  await tester.ensureVisible(checkbox);
  var rect = tester.getRect(checkbox);
  var stableMs = 0;
  var previouslyVisible = tester.any(checkbox.hitTestable());
  final beforeSemantics = tester.ensureSemantics();
  try {
    for (var attempt = 0; attempt < 100 && stableMs < 400; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(UserRepoLocal.to.currentUid, uid);
      expect(UserRepoLocal.to.isCurrentSession(generation), isTrue);
      expect(container.read(provider).selectedIds, unorderedEquals([firstId]));
      expectSelectionCount(tester, 1);
      if (!tester.any(checkbox.hitTestable())) {
        stableMs = 0;
        previouslyVisible = false;
        continue;
      }
      expect(
        tester.getSemantics(checkbox).flagsCollection.isChecked,
        CheckedState.isFalse,
      );
      final current = tester.getRect(checkbox);
      stableMs = previouslyVisible && current == rect ? stableMs + 100 : 0;
      rect = current;
      previouslyVisible = true;
    }
    expect(
      stableMs,
      greaterThanOrEqualTo(400),
      reason: 'Checkbox must remain visible and stationary for 400ms',
    );
    expect(checkbox.hitTestable(), findsOneWidget);
    expect(tester.getRect(checkbox), rect);
  } finally {
    beforeSemantics.dispose();
  }
  expectSelectionCount(tester, 1);
  final random = Random.secure();
  final challenge = base64Url
      .encode(List<int>.generate(32, (_) => random.nextInt(256)))
      .replaceAll('=', '');
  final binding = tester.binding;
  final previousPropagation = binding.shouldPropagateDevicePointerEvents;
  binding.shouldPropagateDevicePointerEvents = true;
  try {
    flowLog(
      'W3K-MS CHECKBOX_READY ${jsonEncode({
        'nonce': nonce,
        'challenge': challenge,
        'uid': uid,
        'generation': generation,
        'package': 'pub.imboy.app.uiuxqa',
        'messageID': secondId,
        'stableRect': {'x': rect.left, 'y': rect.top, 'w': rect.width, 'h': rect.height},
        'dpr': tester.view.devicePixelRatio,
        'viewport': {'w': tester.view.physicalSize.width, 'h': tester.view.physicalSize.height},
        'coordinateSpace': 'flutter-view-logical',
        'windowOrigin': 'observer-must-verify',
        'viewPadding': {'top': tester.view.viewPadding.top, 'left': tester.view.viewPadding.left},
        'selectedIDsBefore': [firstId],
        'expectedAfter': [firstId, secondId],
      })}',
    );
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!container.read(provider).contains(secondId) &&
        DateTime.now().isBefore(deadline)) {
      expect(UserRepoLocal.to.currentUid, uid);
      expect(UserRepoLocal.to.isCurrentSession(generation), isTrue);
      expect(ChatMultiDriverRunStats.productionToggleUsed, beforeToggles);
      expect(container.read(provider).selectedIds, unorderedEquals([firstId]));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      container.read(provider).selectedIds,
      unorderedEquals([firstId, secondId]),
    );
    expectSelectionCount(tester, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(UserRepoLocal.to.currentUid, uid);
    expect(UserRepoLocal.to.isCurrentSession(generation), isTrue);
    expect(
      container.read(provider).selectedIds,
      unorderedEquals([firstId, secondId]),
    );
    expectSelectionCount(tester, 2);
    expect(ChatMultiDriverRunStats.productionToggleUsed, beforeToggles);
    expect(checkbox.hitTestable(), findsOneWidget);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pump();
      expect(
        tester.getSemantics(checkbox).flagsCollection.isChecked,
        CheckedState.isTrue,
      );
    } finally {
      semantics.dispose();
    }
  } finally {
    binding.shouldPropagateDevicePointerEvents = previousPropagation;
  }
  flowLog(
    'W3K-MS CHECKBOX_VERIFIED ${jsonEncode({'nonce': nonce, 'challenge': challenge})}',
  );
}

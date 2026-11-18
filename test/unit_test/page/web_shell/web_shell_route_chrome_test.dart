/// Component history restoration; native browser back/forward remains separate.
@TestOn('chrome')
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/web_writer_gate.dart';

import 'package:azlistview/azlistview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoNavigationBarBackButton;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/contact/contact_page.dart';
import 'package:imboy/page/contact/contact/contact_provider.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_provider.dart';
import 'package:imboy/page/web_shell/web_shell.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/store/model/contact_model.dart';

import 'web_shell_route_test.dart' as route;

void main() {
  debugPrint = debugPrintSynchronously;
  setUpAll(() async {
    await prepareWebWriter();
    expect(isWebWriterReady, isTrue);
  });
  route.main();
  _contactReturnCases();
}

class _ContactReturnSessions extends ChangeNotifier
    implements AuthSessionReader {
  @override
  AuthSessionScope get current =>
      (uid: 'contact-return-owner', generation: 1, transitioning: false);
  @override
  bool get transitionFailed => false;
  @override
  bool isCurrent(AuthSessionScope captured) => captured == current;
}

class _ContactReturnData extends ContactNotifier {
  _ContactReturnData(this.contacts);
  final List<ContactModel> contacts;
  @override
  ContactState build() => ContactState(
    contactList: contacts,
    isLoading: false,
    indexBarData: const {'A'},
  );
  @override
  Future<void> loadData() async {}
}

class _ContactReturnReminders extends NewFriendRemindNotifier {
  @override
  Set<String> build() => <String>{};
  @override
  Future<void> countReminders() async {}
}

void _contactReturnCases() {
  for (final width in [390.0, 1024.0]) {
    testWidgets('real contact middle-list detail return keeps UID/Y at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final contacts = List.generate(80, (i) {
        final contact = ContactModel(
          peerId: (BigInt.parse('123411316393380000') + BigInt.from(i))
              .toString(),
          nickname: 'A Contact ${i.toString().padLeft(3, '0')}',
          avatar: '',
          status: 'offline',
        );
        contact.nameIndex = 'A';
        return contact;
      });
      expect(
        contacts.map((contact) => contact.peerId).toSet(),
        hasLength(80),
        reason: 'All TSID strings remain unique on Dart Web',
      );
      SuspensionUtil.sortListBySuspensionTag(contacts);
      SuspensionUtil.setShowSuspensionStatus(contacts);
      final sessions = _ContactReturnSessions();
      final container = ProviderContainer(
        overrides: [
          contactProvider.overrideWith(() => _ContactReturnData(contacts)),
          newFriendRemindProvider.overrideWith(_ContactReturnReminders.new),
        ],
      );
      final loads = <String>[];
      late GoRouter router;
      router = GoRouter(
        initialLocation: '/web_shell?tab=contact',
        routes: [
          GoRoute(
            path: '/web_shell',
            builder: (_, state) => WebShellRoute(
              uri: state.uri,
              sessionReader: sessions,
              child: WebShellPage(
                tabMessageLabel: 'Messages',
                tabContactLabel: 'Contacts',
                tabChannelLabel: 'Channels',
                tabMineLabel: 'Mine',
                welcomeTitle: 'Welcome',
                messageTab: const SizedBox(),
                contactTab: const ContactPage(),
                channelTab: const SizedBox(),
                mineTab: const SizedBox(),
                mobileFallback: const SizedBox(),
                // Same shared-content seam as Browser BottomNav.content.
                mobileFallbackBuilder: (content) => content,
                chatBuilder: (_) => const SizedBox(),
                channelBuilder: (_) => const SizedBox(),
                mineBuilder: (_) => const SizedBox(),
                contactBuilder: (selection) => WebContactInfoPanel(
                  selection: selection,
                  sessionReader: sessions,
                  sendButtonLabel: 'Send',
                  closeTooltip: 'Close contact detail',
                  onClose: container
                      .read(webShellProvider.notifier)
                      .clearSelection,
                  onSendMessage: () =>
                      fail('Contact return must not send messages'),
                  contactLoader: (uid) async {
                    loads.add(uid);
                    return contacts.singleWhere(
                      (contact) => contact.peerId == uid,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        router.dispose();
        container.dispose();
        sessions.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final page = find.byType(ContactPage);
      final list = find.descendant(of: page, matching: find.byType(AzListView));
      expect(list, findsOneWidget);
      for (var i = 0; i < 7; i++) {
        await tester.drag(list, const Offset(0, -360));
        await tester.pumpAndSettle();
      }
      final viewport = tester.getRect(list);
      final visible = contacts.where((contact) {
        final row = find.descendant(
          of: page,
          matching: find.text(contact.title),
        );
        if (row.evaluate().length != 1) return false;
        final rect = tester.getRect(row);
        return rect.top > viewport.top + 40 &&
            rect.bottom < viewport.bottom - 40;
      }).toList();
      expect(visible, isNotEmpty);
      final chosen = visible[visible.length ~/ 2];
      final chosenIndex = contacts.indexOf(chosen);
      expect(
        chosenIndex,
        greaterThan(15),
        reason: 'Actual middle/lower contact, not first screen',
      );
      expect(chosenIndex, lessThan(contacts.length - 3));
      final row = find.descendant(of: page, matching: find.text(chosen.title));
      final oldPage = tester.state(page), oldList = tester.state(list);
      final oldElement = tester.element(row);
      final beforeY = tester.getTopLeft(row).dy - viewport.top;
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        container.read(webShellProvider).selectedItem,
        ContactSelection(uid: chosen.peerId),
      );
      expect(find.byType(WebContactInfoPanel), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(WebContactInfoPanel),
          matching: find.text(chosen.title),
        ),
        findsOneWidget,
      );
      expect(loads, [chosen.peerId]);
      expect(router.state.uri.queryParameters['id'], chosen.peerId);
      expect(page, findsNothing, reason: 'Compact detail hides retained list');
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pumpAndSettle();
      expect(container.read(webShellProvider).selectedItem, isNull);
      expect(router.state.uri.queryParameters['tab'], 'contact');
      expect(router.state.uri.queryParameters.containsKey('id'), isFalse);
      expect(tester.state(page), same(oldPage));
      expect(tester.state(list), same(oldList));
      expect(tester.element(row), same(oldElement));
      final afterViewport = tester.getRect(list), after = tester.getRect(row);
      expect(
        after.top - afterViewport.top,
        closeTo(beforeY, 1),
        reason: 'Same positive UID at same viewport-relative position',
      );
      expect(after.top, greaterThanOrEqualTo(afterViewport.top));
      expect(after.bottom, lessThanOrEqualTo(afterViewport.bottom));
      expect(loads, [
        chosen.peerId,
      ], reason: 'Return does not duplicate detail load');
      expect(tester.takeException(), isNull);
      debugPrint(
        'LAY03_ORACLE ${jsonEncode({'journey': 'contact_detail_return', 'viewport_width': width, 'anchor_uid': chosen.peerId, 'anchor_index': chosenIndex, 'before_y': beforeY, 'after_y': after.top - afterViewport.top, 'filter_fixture': 'all contacts', 'theme': Theme.of(tester.element(page)).brightness.name, 'selected_after': container.read(webShellProvider).selectedItem?.runtimeType.toString()})}',
      );
    });
  }
}

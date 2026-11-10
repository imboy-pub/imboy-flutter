import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/conversation/message_inbox_entry.dart';

MessageInboxEntry _entry(
  String key, {
  MessageInboxKind kind = MessageInboxKind.direct,
  String title = 'Conversation',
  String preview = '',
  int lastTime = 0,
  int unreadCount = 0,
  bool isPinned = false,
  bool manualPending = false,
}) => MessageInboxEntry(
  key: key,
  kind: kind,
  title: title,
  preview: preview,
  lastTime: lastTime,
  unreadCount: unreadCount,
  isPinned: isPinned,
  manualPending: manualPending,
  builder: (_) => const SizedBox.shrink(),
);

List<String> _keys(Iterable<MessageInboxEntry> entries) =>
    entries.map((entry) => entry.key).toList();

void main() {
  group('selectMessageInboxEntries', () {
    test('pinned state and recency order apply equally across entry types', () {
      final entries = [
        _entry('direct:newest', lastTime: 900),
        _entry(
          'channel:pinned',
          kind: MessageInboxKind.channel,
          isPinned: true,
          lastTime: 100,
        ),
        _entry('direct:older', lastTime: 50),
        _entry('channel:recent', kind: MessageInboxKind.channel, lastTime: 700),
        _entry(
          'group:pinned',
          kind: MessageInboxKind.group,
          isPinned: true,
          lastTime: 300,
        ),
        _entry('group:recent', kind: MessageInboxKind.group, lastTime: 500),
      ];

      expect(_keys(selectMessageInboxEntries(entries)), [
        'group:pinned',
        'channel:pinned',
        'direct:newest',
        'channel:recent',
        'group:recent',
        'direct:older',
      ]);
    });

    test(
      'equal timestamps use stable keys independently of input ordering',
      () {
        final entries = [
          _entry('group:3', kind: MessageInboxKind.group, lastTime: 100),
          _entry('direct:2', lastTime: 100),
          _entry('channel:1', kind: MessageInboxKind.channel, lastTime: 100),
        ];
        const expected = ['channel:1', 'direct:2', 'group:3'];
        expect(_keys(selectMessageInboxEntries(entries)), expected);
        expect(_keys(selectMessageInboxEntries(entries.reversed)), expected);
      },
    );

    test(
      'more than five channels remain available in both all and channel',
      () {
        final channels = List.generate(
          8,
          (index) => _entry(
            'channel:$index',
            kind: MessageInboxKind.channel,
            lastTime: index + 1,
          ),
        );
        final entries = [_entry('direct:1', lastTime: 20), ...channels];

        expect(selectMessageInboxEntries(entries), hasLength(9));
        expect(
          _keys(
            selectMessageInboxEntries(
              entries,
              filter: MessageInboxFilter.channel,
            ),
          ),
          [
            'channel:7',
            'channel:6',
            'channel:5',
            'channel:4',
            'channel:3',
            'channel:2',
            'channel:1',
            'channel:0',
          ],
        );
      },
    );

    test('type and trimmed case-insensitive title/preview query combine', () {
      final entries = [
        _entry('direct:match', title: 'Release'),
        _entry(
          'group:title',
          kind: MessageInboxKind.group,
          title: 'RELEASE plan',
        ),
        _entry(
          'group:preview',
          kind: MessageInboxKind.group,
          title: 'Design',
          preview: 'Ready for release',
          lastTime: 1,
        ),
        _entry(
          'group:unrelated',
          kind: MessageInboxKind.group,
          title: 'Support',
        ),
        _entry(
          'channel:match',
          kind: MessageInboxKind.channel,
          title: 'Release',
        ),
      ];

      expect(
        _keys(
          selectMessageInboxEntries(
            entries,
            filter: MessageInboxFilter.group,
            query: '  release  ',
          ),
        ),
        ['group:preview', 'group:title'],
      );
      expect(_keys(selectMessageInboxEntries(entries, query: 'DESIGN')), [
        'group:preview',
      ]);
    });

    test(
      'manual pending is in unread without manufacturing unread messages',
      () {
        final pending = _entry('direct:pending', manualPending: true);
        final unread = _entry(
          'group:unread',
          kind: MessageInboxKind.group,
          unreadCount: 3,
        );
        final read = _entry('channel:read', kind: MessageInboxKind.channel);
        final entries = [pending, unread, read];

        final selected = selectMessageInboxEntries(
          entries,
          filter: MessageInboxFilter.unread,
        );
        expect(_keys(selected), ['direct:pending', 'group:unread']);
        expect(selected.first, same(pending));
        expect(pending.unreadCount, 0);
        expect(pending.manualPending, isTrue);
        expect(unread.unreadCount, 3);
        expect(read.unreadCount, 0);
      },
    );

    test(
      'identical titles never merge distinct chat and channel identities',
      () {
        final entries = [
          _entry('direct:1', title: 'Announcements', lastTime: 20),
          _entry(
            'channel:1',
            kind: MessageInboxKind.channel,
            title: 'Announcements',
          ),
          _entry(
            'channel:2',
            kind: MessageInboxKind.channel,
            title: 'Announcements',
          ),
        ];
        expect(
          _keys(selectMessageInboxEntries(entries, query: 'Announcements')),
          ['direct:1', 'channel:1', 'channel:2'],
        );
      },
    );

    test(
      'each kind filter excludes unrelated rows and all retains other types',
      () {
        final entries = [
          _entry('direct:1'),
          _entry('group:1', kind: MessageInboxKind.group),
          _entry('channel:1', kind: MessageInboxKind.channel),
          _entry('other:1', kind: MessageInboxKind.other),
        ];
        expect(selectMessageInboxEntries(entries), hasLength(4));
        expect(
          _keys(
            selectMessageInboxEntries(
              entries,
              filter: MessageInboxFilter.direct,
            ),
          ),
          ['direct:1'],
        );
        expect(
          _keys(
            selectMessageInboxEntries(
              entries,
              filter: MessageInboxFilter.group,
            ),
          ),
          ['group:1'],
        );
        expect(
          _keys(
            selectMessageInboxEntries(
              entries,
              filter: MessageInboxFilter.channel,
            ),
          ),
          ['channel:1'],
        );
      },
    );

    test('empty data and searches with no match stay empty', () {
      for (final filter in MessageInboxFilter.values) {
        expect(selectMessageInboxEntries([], filter: filter), isEmpty);
      }
      expect(
        selectMessageInboxEntries([_entry('direct:1')], query: 'missing'),
        isEmpty,
      );
    });

    test('sorting does not mutate the provider-owned source list', () {
      final older = _entry('direct:older', lastTime: 1);
      final newer = _entry('direct:newer', lastTime: 2);
      final source = [older, newer];
      final selected = selectMessageInboxEntries(source);
      expect(source, [same(older), same(newer)]);
      expect(selected, [same(newer), same(older)]);
      expect(selected, isNot(same(source)));
    });
  });
}

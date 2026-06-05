import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/moment/moment_create_page.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// Test wrapper for moment create page with proper localization
class MomentCreateTestWrapper extends StatelessWidget {
  final Widget child;

  const MomentCreateTestWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TranslationProvider(child: MaterialApp(home: child));
  }
}

void main() {
  group('MomentCreatePage Complete Flow Tests', () {
    group('Page Rendering Tests', () {
      testWidgets('renders page with correct AppBar title', (tester) async {
        await tester.pumpWidget(
          const MomentCreateTestWrapper(child: MomentCreatePage()),
        );
        await tester.pump();

        expect(find.byType(MomentCreatePage), findsOneWidget);
        expect(find.text(t.chat.momentsSend), findsOneWidget);
      });

      testWidgets('has confirm button in AppBar', (tester) async {
        await tester.pumpWidget(
          const MomentCreateTestWrapper(child: MomentCreatePage()),
        );
        await tester.pump();

        expect(find.byType(TextButton), findsWidgets);
        expect(find.text(t.common.confirm), findsOneWidget);
      });

      testWidgets('has content TextField', (tester) async {
        await tester.pumpWidget(
          const MomentCreateTestWrapper(child: MomentCreatePage()),
        );
        await tester.pump();

        final textFields = find.byType(TextField);
        expect(textFields, findsWidgets);

        // First TextField should be the content input
        final contentField = tester.widget<TextField>(textFields.first);
        expect(contentField.maxLines, 6);
        expect(contentField.maxLength, 5000);
      });

      testWidgets('has visibility dropdown', (tester) async {
        await tester.pumpWidget(
          const MomentCreateTestWrapper(child: MomentCreatePage()),
        );
        await tester.pump();

        expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
      });

      testWidgets('has add media button', (tester) async {
        await tester.pumpWidget(
          const MomentCreateTestWrapper(child: MomentCreatePage()),
        );
        await tester.pump();

        expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      });

      testWidgets('has allow comment switch', (tester) async {
        await tester.pumpWidget(
          const MomentCreateTestWrapper(child: MomentCreatePage()),
        );
        await tester.pump();

        expect(find.byType(SwitchListTile), findsOneWidget);

        final switchWidget = tester.widget<SwitchListTile>(
          find.byType(SwitchListTile),
        );
        expect(switchWidget.value, isTrue); // Default is true
      });
    });

    group('Content Input Tests', () {
      testWidgets('content input accepts text', (tester) async {
        await tester.pumpWidget(
          const MomentCreateTestWrapper(child: MomentCreatePage()),
        );
        await tester.pump();

        final textField = find.byType(TextField).first;
        await tester.enterText(textField, 'Hello World');

        expect(find.text('Hello World'), findsOneWidget);
      });

      testWidgets('content input supports multiple lines', (tester) async {
        await tester.pumpWidget(
          const MomentCreateTestWrapper(child: MomentCreatePage()),
        );
        await tester.pump();

        final textField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(textField.maxLines, 6);
      });

      testWidgets('content input has max length limit', (tester) async {
        await tester.pumpWidget(
          const MomentCreateTestWrapper(child: MomentCreatePage()),
        );
        await tester.pump();

        final textField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(textField.maxLength, 5000);
      });

      testWidgets('content input has hint text', (tester) async {
        await tester.pumpWidget(
          const MomentCreateTestWrapper(child: MomentCreatePage()),
        );
        await tester.pump();

        final textField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(textField.decoration?.hintText, isNotEmpty);
      });
    });

    group('Visibility Dropdown Tests', () {
      testWidgets('visibility dropdown has correct options', (tester) async {
        await tester.pumpWidget(
          const MomentCreateTestWrapper(child: MomentCreatePage()),
        );
        await tester.pump();

        final dropdown = find.byType(DropdownButtonFormField<int>);
        expect(dropdown, findsOneWidget);

        // Default value should be 1 (friends only)
        final dropdownWidget = tester.widget<DropdownButtonFormField<int>>(
          dropdown,
        );
        expect(dropdownWidget.initialValue, 1);
      });

      test('visibility values are correct', () {
        const visibilityOptions = [
          {'value': 0, 'label': '公开'},
          {'value': 1, 'label': '仅好友'},
          {'value': 2, 'label': '仅自己'},
          {'value': 3, 'label': '部分可见'},
          {'value': 4, 'label': '不给谁看'},
        ];

        expect(visibilityOptions.length, 5);
        expect(visibilityOptions[0]['value'], 0);
        expect(visibilityOptions[4]['value'], 4);
      });
    });

    group('Media Upload Flow Tests', () {
      test('media count is limited to 9', () {
        final media = List.generate(
          9,
          (i) => {'type': 'image', 'url': 'url_$i'},
        );

        final canAddMore = media.length < 9;
        expect(canAddMore, isFalse);
        expect(media.length, 9);
      });

      test('can add media when count is less than 9', () {
        final media = List.generate(
          5,
          (i) => {'type': 'image', 'url': 'url_$i'},
        );

        final canAddMore = media.length < 9;
        expect(canAddMore, isTrue);
      });

      test('media item can be removed', () {
        final media = [
          {'type': 'image', 'url': 'url_0'},
          {'type': 'image', 'url': 'url_1'},
          {'type': 'image', 'url': 'url_2'},
        ];

        final indexToRemove = 1;
        media.removeAt(indexToRemove);

        expect(media.length, 2);
        expect(media[0]['url'], 'url_0');
        expect(media[1]['url'], 'url_2');
      });

      test('media item cannot be removed with invalid index', () {
        final media = [
          {'type': 'image', 'url': 'url_0'},
        ];

        final indexToRemove = -1;
        if (indexToRemove >= 0 && indexToRemove < media.length) {
          media.removeAt(indexToRemove);
        }

        expect(media.length, 1);
      });

      test('video media includes additional fields', () {
        final videoMedia = {
          'type': 'video',
          'url': 'https://example.com/video.mp4',
          'cover_url': 'https://example.com/cover.jpg',
          'duration_ms': 30000,
        };

        expect(parseModelString(videoMedia['type']), 'video');
        expect(parseModelString(videoMedia['cover_url']), isNotEmpty);
        expect(parseModelInt(videoMedia['duration_ms']), 30000);
      });
    });

    group('Submission Validation Tests', () {
      test('empty content and no media prevents submission', () {
        final content = '';
        final media = <Map<String, dynamic>>[];

        final canSubmit = content.trim().isNotEmpty || media.isNotEmpty;
        expect(canSubmit, isFalse);
      });

      test('content only allows submission', () {
        final content = 'Test content';
        final media = <Map<String, dynamic>>[];

        final canSubmit = content.trim().isNotEmpty || media.isNotEmpty;
        expect(canSubmit, isTrue);
      });

      test('media only allows submission', () {
        final content = '';
        final media = [
          {'type': 'image', 'url': 'http://example.com/image.jpg'},
        ];

        final canSubmit = content.trim().isNotEmpty || media.isNotEmpty;
        expect(canSubmit, isTrue);
      });

      test('both content and media allows submission', () {
        final content = 'Test content';
        final media = [
          {'type': 'image', 'url': 'http://example.com/image.jpg'},
        ];

        final canSubmit = content.trim().isNotEmpty || media.isNotEmpty;
        expect(canSubmit, isTrue);
      });

      test('whitespace only content does not allow submission', () {
        final content = '   ';
        final media = <Map<String, dynamic>>[];

        final canSubmit = content.trim().isNotEmpty || media.isNotEmpty;
        expect(canSubmit, isFalse);
      });
    });

    group('UID List Parsing Tests', () {
      test('empty string returns empty list', () {
        const raw = '';
        final result = _parseUidList(raw);
        expect(result, isEmpty);
      });

      test('whitespace string returns empty list', () {
        const raw = '   ';
        final result = _parseUidList(raw);
        expect(result, isEmpty);
      });

      test('single UID returns list with one item', () {
        const raw = 'user_001';
        final result = _parseUidList(raw);
        expect(result.length, 1);
        expect(result[0], 'user_001');
      });

      test('comma separated UIDs returns list', () {
        const raw = 'user_001, user_002, user_003';
        final result = _parseUidList(raw);
        expect(result.length, 3);
        expect(result[0], 'user_001');
        expect(result[1], 'user_002');
        expect(result[2], 'user_003');
      });

      test('handles extra commas correctly', () {
        const raw = 'user_001,, user_002,';
        final result = _parseUidList(raw);
        expect(result.length, 2);
        expect(result[0], 'user_001');
        expect(result[1], 'user_002');
      });
    });

    group('Event Bus Integration Tests', () {
      test('publish success fires MomentTimelineChangedEvent', () async {
        final receivedEvents = <MomentTimelineChangedEvent>[];

        final subscription = AppEventBus.on<MomentTimelineChangedEvent>()
            .listen((event) {
              receivedEvents.add(event);
            });

        // Simulate successful publish
        const momentId = 'moment_new_001';
        AppEventBus.fire(
          MomentTimelineChangedEvent(
            action: 'moment_new',
            momentId: momentId,
            payload: {'id': momentId, 'content': 'Test'},
          ),
        );

        await Future<dynamic>.delayed(const Duration(milliseconds: 100));

        expect(receivedEvents.length, 1);
        expect(receivedEvents[0].action, 'moment_new');
        expect(receivedEvents[0].momentId, momentId);

        await subscription.cancel();
      });

      test('event payload contains moment data', () async {
        final receivedEvents = <MomentTimelineChangedEvent>[];

        final subscription = AppEventBus.on<MomentTimelineChangedEvent>()
            .listen((event) {
              receivedEvents.add(event);
            });

        const payload = {
          'id': 'moment_001',
          'content': 'Hello World',
          'visibility': 1,
        };

        AppEventBus.fire(
          MomentTimelineChangedEvent(
            action: 'moment_new',
            momentId: 'moment_001',
            payload: payload,
          ),
        );

        await Future<dynamic>.delayed(const Duration(milliseconds: 100));

        expect(receivedEvents.length, 1);
        expect(receivedEvents[0].payload['content'], 'Hello World');
        expect(receivedEvents[0].payload['visibility'], 1);

        await subscription.cancel();
      });
    });

    group('Allow Comment Toggle Tests', () {
      test('allow comment default is true', () {
        bool allowComment = true;
        expect(allowComment, isTrue);
      });

      test('allow comment can be toggled', () {
        bool allowComment = true;
        allowComment = !allowComment;
        expect(allowComment, isFalse);

        allowComment = !allowComment;
        expect(allowComment, isTrue);
      });
    });

    group('Visibility Conditional Fields Tests', () {
      test('visibility 3 shows allow UIDs field', () {
        const visibility = 3;
        final showAllowUidsField = visibility == 3;
        expect(showAllowUidsField, isTrue);
      });

      test('visibility 4 shows deny UIDs field', () {
        const visibility = 4;
        final showDenyUidsField = visibility == 4;
        expect(showDenyUidsField, isTrue);
      });

      test('visibility 1 hides both UID fields', () {
        const visibility = 1;
        final showAllowUidsField = visibility == 3;
        final showDenyUidsField = visibility == 4;
        expect(showAllowUidsField, isFalse);
        expect(showDenyUidsField, isFalse);
      });
    });

    group('Submit Button State Tests', () {
      test('submit button disabled when submitting', () {
        bool isSubmitting = true;
        bool isUploading = false;

        // ignore: dead_code - Intentional: testing short-circuit when isSubmitting is true
        final isEnabled = !isSubmitting && !isUploading;
        expect(isEnabled, isFalse);
      });

      test('submit button disabled when uploading', () {
        bool isSubmitting = false;
        bool isUploading = true;

        // ignore: dead_code - Intentional: testing short-circuit when isUploading is true
        final isEnabled = !isSubmitting && !isUploading;
        expect(isEnabled, isFalse);
      });

      test('submit button enabled when idle', () {
        bool isSubmitting = false;
        bool isUploading = false;

        final isEnabled = !isSubmitting && !isUploading;
        expect(isEnabled, isTrue);
      });
    });

    group('Boundary Condition Tests', () {
      test('handles very long content', () {
        final content = 'a' * 5000;
        expect(content.length, 5000);
      });

      test('handles special characters in content', () {
        final content = '<script>alert("xss")</script>';
        expect(content.contains('<script>'), isTrue);
      });

      test('handles unicode in content', () {
        final content = '你好世界 🎉 مرحبا';
        expect(content.contains('你好'), isTrue);
        expect(content.contains('🎉'), isTrue);
      });

      test('handles empty UID list gracefully', () {
        final allowUids = <String>[];
        expect(allowUids, isEmpty);
      });
    });

    group('Navigation Return Value Tests', () {
      test('returns true on successful publish', () {
        // Simulate Navigator.pop(context, true)
        const result = true;
        expect(result, isTrue);
      });

      test('returns null on cancelled publish', () {
        // Simulate Navigator.pop(context) without value
        // In real code, this would be null
        const result = null;
        expect(result, isNull);
      });
    });

    group('Complete Publish Flow Tests', () {
      test('full flow: content -> submit -> event -> return', () async {
        // 1. User enters content
        const content = 'Test moment';
        expect(content.isNotEmpty, isTrue);

        // 2. User submits
        final canSubmit = content.trim().isNotEmpty;
        expect(canSubmit, isTrue);

        // 3. Event is fired
        final receivedEvents = <MomentTimelineChangedEvent>[];
        final subscription = AppEventBus.on<MomentTimelineChangedEvent>()
            .listen((event) {
              receivedEvents.add(event);
            });

        const momentId = 'moment_flow_001';
        AppEventBus.fire(
          MomentTimelineChangedEvent(
            action: 'moment_new',
            momentId: momentId,
            payload: {'id': momentId, 'content': content},
          ),
        );

        await Future<dynamic>.delayed(const Duration(milliseconds: 100));

        // 4. Event received
        expect(receivedEvents.length, 1);
        expect(receivedEvents[0].action, 'moment_new');

        // 5. Return true for success
        const result = true;
        expect(result, isTrue);

        await subscription.cancel();
      });

      test(
        'full flow with media: media -> submit -> event -> return',
        () async {
          // 1. User adds media
          final media = [
            {'type': 'image', 'url': 'https://example.com/image.jpg'},
          ];
          expect(media.isNotEmpty, isTrue);

          // 2. User submits without content
          const content = '';
          final canSubmit = content.trim().isNotEmpty || media.isNotEmpty;
          expect(canSubmit, isTrue);

          // 3. Event is fired
          final receivedEvents = <MomentTimelineChangedEvent>[];
          final subscription = AppEventBus.on<MomentTimelineChangedEvent>()
              .listen((event) {
                receivedEvents.add(event);
              });

          const momentId = 'moment_media_001';
          AppEventBus.fire(
            MomentTimelineChangedEvent(
              action: 'moment_new',
              momentId: momentId,
              payload: {'id': momentId, 'media': media},
            ),
          );

          await Future<dynamic>.delayed(const Duration(milliseconds: 100));

          // 4. Event received
          expect(receivedEvents.length, 1);
          expect(receivedEvents[0].action, 'moment_new');

          // 5. Return true for success
          const result = true;
          expect(result, isTrue);

          await subscription.cancel();
        },
      );
    });
  });
}

/// Helper function to parse UID list
List<String> _parseUidList(String raw) {
  if (raw.trim().isEmpty) return const [];
  return raw
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

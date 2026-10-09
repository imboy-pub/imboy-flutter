import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show showCupertinoDialog;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/widgets/channel_discussion_entry.dart';
import 'package:imboy/page/channel/widgets/channel_message_feed.dart';
import 'package:imboy/page/channel/channel_message_item.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';

class RecordingApi extends ChannelApi {
  final calls = <({String method, String uri, Object? data})>[];
  final responses = <IMBoyHttpResponse>[];
  IMBoyHttpResponse _record(String method, String uri, Object? data) {
    calls.add((method: method, uri: uri, data: data));
    return responses.removeAt(0);
  }

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async => _record('GET', uri, queryParameters);
  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async => _record('POST', uri, data);
  @override
  Future<IMBoyHttpResponse> put(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    httpTransformer,
  }) async => _record('PUT', uri, data);
}

void profile(String value, {bool? enabled = true}) {
  AppManifestService.replaceForTest({
    'policy': {'profile': value},
    'features': enabled == null
        ? <String, dynamic>{}
        : <String, dynamic>{'channel': enabled},
  });
  AppFeatureRegistry.replaceSnapshotForTest({'channel': true});
}

ChannelModel channel({
  bool subscribed = true,
  bool paid = false,
  bool purchased = true,
}) => ChannelModel.fromJson({
  'id': 2,
  'name': 'fixture',
  'creator_uid': 99,
  'visibility': 0,
  'access_type': paid ? 1 : 0,
  'join_policy': paid ? 3 : 0,
  'is_subscribed': subscribed,
  'has_purchased': purchased,
  'discussion_group_id': 3,
});

void main() {
  setUp(() => profile('community'));
  test(
    'admin and creator can search and filter essence without subscribing',
    () {
      for (final role in [2, 3]) {
        final managed = ChannelModel.fromJson({
          'id': 2,
          'user_role': role,
          'is_subscribed': false,
        });
        expect(managed.isManaged, isTrue);
        expect(ChannelMessageFeed.contentToolsAvailable(managed), isTrue);
        profile('phase1_delivery');
        expect(ChannelMessageFeed.contentToolsAvailable(managed), isFalse);
        profile('community');
      }
    },
  );
  test('new DTO fields preserve native Android IDs above 2^53', () {
    const largeId = 9007199254740993;
    final dto = ChannelModel.fromJson({
      'id': largeId,
      'discussion_group_id': largeId + 2,
    });
    final roundTrip = ChannelModel.fromJson(dto.toJson());
    expect(roundTrip.id, largeId);
    expect(roundTrip.discussionGroupId, largeId + 2);
    final message = ChannelMessageModel.fromJson({
      'id': largeId,
      'channel_id': largeId + 2,
      'is_essence': true,
    });
    expect(ChannelMessageModel.fromJson(message.toJson()).id, largeId);
  });
  test('nullable discussion IDs survive wire snapshots and explicit clearing', () {
    final value = channel();
    expect(value.discussionGroupId, 3);
    expect(ChannelModel.fromJson(value.toJson()).discussionGroupId, 3);
    expect(
      value.copyWith(clearDiscussionGroup: true).discussionGroupId,
      isNull,
    );
    expect(
      ChannelModel.fromJson({'id': 2, 'discussion_group_id': null})
          .discussionGroupId,
      isNull,
    );
    // No silent SQLite schema extension: binding always comes from a fresh GET.
    expect(value.toMap().containsKey('discussion_group_id'), isFalse);
  });
  test(
    'essence stays independent of pin and tags preserve other payload fields',
    () {
      final value = ChannelMessageModel.fromJson({
        'id': 4,
        'channel_id': 2,
        'is_essence': true,
        'is_pinned': false,
        'payload': {
          'tags': ['tag'],
          'attachment': {'key': 'keep'},
        },
      });
      expect(value.isEssence, isTrue);
      expect(value.isPinned, isFalse);
      expect(value.tags, ['tag']);
      expect(value.copyWith(isPinned: true).isEssence, isTrue);
      expect(
        ChannelMessageModel.fromJson(value.toJson()).payload?['attachment'],
        {'key': 'keep'},
      );
    },
  );
  test(
    'search uses page/size and combines q/tag/essence without a message cursor',
    () async {
      final api = RecordingApi()
        ..responses.add(
          IMBoyHttpResponse.success({
            'list': <Map<String, dynamic>>[],
            'total': 11,
            'page': 1,
            'size': 10,
          }),
        );
      final result = await api.searchPosts(
        channelId: '2',
        q: 'body',
        tag: 'tag',
        essence: true,
      );
      expect(result.hasMore, isTrue);
      expect(api.calls.single.uri, '/api/v1/channel/2/posts');
      expect(api.calls.single.data, {
        'page': 1,
        'size': 10,
        'q': 'body',
        'tag': 'tag',
        'essence': 'true',
      });
    },
  );
  test(
    'failed search throws rather than displaying an empty successful page',
    () async {
      final api = RecordingApi()
        ..responses.add(
          IMBoyHttpResponse.failure(errCode: 403, errMsg: 'denied'),
        );
      await expectLater(api.searchPosts(channelId: '2'), throwsA(anything));
    },
  );
  test('discussion requires an explicit valid nullable binding', () async {
    for (final value in [
      <String, dynamic>{},
      {'discussion_group_id': 0},
    ]) {
      final api = RecordingApi()
        ..responses.add(IMBoyHttpResponse.success(value));
      await expectLater(api.getDiscussion('2'), throwsFormatException);
    }
    final api = RecordingApi()
      ..responses.add(IMBoyHttpResponse.success({'discussion_group_id': null}));
    expect(await api.getDiscussion('2'), isNull);
  });
  test(
    'search rejects cross-channel entries and malformed list members',
    () async {
      for (final list in [
        <Object>[
          {'id': 4, 'channel_id': 9},
        ],
        <Object>['invalid'],
      ]) {
        final api = RecordingApi()
          ..responses.add(
            IMBoyHttpResponse.success({
              'list': list,
              'total': 1,
              'page': 1,
              'size': 10,
            }),
          );
        await expectLater(
          api.searchPosts(channelId: '2'),
          throwsFormatException,
        );
      }
    },
  );
  test('metadata requests keep channel/message scope and only send the changed field', () async {
    final api = RecordingApi()
      ..responses.addAll([
        IMBoyHttpResponse.success(<String, dynamic>{}),
        IMBoyHttpResponse.success(<String, dynamic>{}),
      ]);
    await api.setPostEssence('2', '4', true);
    await api.setPostTags('2', '4', []);
    expect(api.calls[0].method, 'PUT');
    expect(api.calls[0].uri, '/api/v1/channel/2/posts/4/essence');
    expect(api.calls[0].data, {'is_essence': true});
    expect(api.calls[1].method, 'PUT');
    expect(api.calls[1].uri, '/api/v1/channel/2/posts/4/tags');
    expect(api.calls[1].data, {'tags': <String>[]});
  });
  test(
    'phase1 and unknown/stale manifest fail before any network call',
    () async {
      for (final mode in ['phase1_delivery', 'unknown', '']) {
        profile(mode);
        final api = RecordingApi();
        await expectLater(api.getDiscussion('2'), throwsStateError);
        await expectLater(api.joinDiscussion('2'), throwsStateError);
        await expectLater(api.searchPosts(channelId: '2'), throwsStateError);
        expect(api.calls, isEmpty);
      }
      profile('community', enabled: null);
      expect(ChannelApi.microCommunityEnabled, isFalse);
    },
  );
  testWidgets('tag editor confirms comma-containing tags without data loss', (
    tester,
  ) async {
    List<String>? result;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showCupertinoDialog<List<String>>(
                  context: context,
                  builder: (_) =>
                      const PostTagsDialog(initialTags: ['a,b', 'other']),
                );
              },
              child: const Text('edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mc_post_tags_confirm')));
    await tester.pumpAndSettle();
    expect(result, ['a,b', 'other']);
  });
  testWidgets(
    'fresh binding read has no automatic join; explicit confirmation uses existing chat route',
    (tester) async {
      final api = RecordingApi()
        ..responses.addAll([
          IMBoyHttpResponse.success({'discussion_group_id': 3}),
          IMBoyHttpResponse.success({'discussion_group_id': 3}),
          IMBoyHttpResponse.success({
            'discussion_group_id': 3,
            'title': 'group',
          }),
        ]);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                Scaffold(body: ChannelDiscussionEntry(channel: channel())),
          ),
          GoRoute(
            path: '/chat/:id',
            builder: (_, state) => Text(
              'chat:${state.pathParameters['id']}:${(state.extra as Map)['type']}',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [channelApiProvider.overrideWithValue(api)],
          child: TranslationProvider(
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.calls.map((c) => c.method), ['GET']);
      await tester.tap(find.byKey(const Key('mc_discussion_join')));
      await tester.pumpAndSettle();
      expect(api.calls.length, 1);
      await tester.tap(find.byKey(const Key('mc_join_confirm')));
      await tester.pumpAndSettle();
      expect(api.calls.map((c) => c.method), ['GET', 'GET', 'POST']);
      expect(find.text('chat:3:C2G'), findsOneWidget);
    },
  );
  testWidgets(
    'paid subscription without valid purchase never shows join action',
    (tester) async {
      final api = RecordingApi()
        ..responses.add(IMBoyHttpResponse.success({'discussion_group_id': 3}));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [channelApiProvider.overrideWithValue(api)],
          child: TranslationProvider(
            child: MaterialApp(
              home: ChannelDiscussionEntry(
                channel: channel(paid: true, purchased: false),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mc_discussion_join')), findsNothing);
      expect(api.calls.where((c) => c.method == 'POST'), isEmpty);
    },
  );
  testWidgets('phase1 ignores cached binding and makes no discussion request', (
    tester,
  ) async {
    profile('phase1_delivery');
    final api = RecordingApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [channelApiProvider.overrideWithValue(api)],
        child: TranslationProvider(
          child: MaterialApp(home: ChannelDiscussionEntry(channel: channel())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mc_discussion_join')), findsNothing);
    expect(api.calls, isEmpty);
  });
}

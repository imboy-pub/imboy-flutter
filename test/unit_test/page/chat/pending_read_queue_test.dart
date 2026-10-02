import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/store/api/workspace_api.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

const _queue = 'imboy.pending_read_receipts.v1';

class _Voice extends VoicePlaybackService {
  @override
  VoicePlaybackState build() => const VoicePlaybackState();
}

class _DeferredApi extends WorkspaceApi {
  final calls = <List<String>>[];
  final entered = List.generate(4, (_) => Completer<void>());
  final gates = List.generate(4, (_) => Completer<void>());

  @override
  Future<void> markGroupRead(
    String groupId,
    List<String> ids, {
    required String owner,
  }) async {
    expect(groupId, '995301');
    expect(owner, '995011');
    final index = calls.length;
    calls.add(List.of(ids));
    entered[index].complete();
    await gates[index].future;
  }
}

Future<List<dynamic>> _pending() async {
  final prefs = await SharedPreferences.getInstance();
  return jsonDecode(prefs.getString(_queue) ?? '[]') as List;
}

Future<void> _waitForQueue(bool Function(List<dynamic>) predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!predicate(await _pending())) {
    expect(DateTime.now().isBefore(deadline), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'new reads survive an in-flight flush, foreign records and retry',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await _seedQueue();
      final db = await openFixtureDatabaseAtVersion(version: 32);
      SqliteService.setDbForTest(db);
      await db.insert('conversation', {
        'user_id': 995011,
        'peer_id': 995301,
        'type': 'C2G',
        'unread_num': 3,
        'last_time': 1790931169467,
      });
      final api = _DeferredApi();
      final container = ProviderContainer(
        overrides: [
          workspaceApiProvider.overrideWithValue(api),
          voicePlaybackServiceProvider.overrideWith(_Voice.new),
        ],
      );
      final keepAlive = container.listen(chatProvider, (_, _) {});
      final notifier = container.read(chatProvider.notifier);
      addTearDown(() async {
        keepAlive.close();
        container.dispose();
        MessageService.to.dispose();
        SqliteService.setDbForTest(null);
        await db.close();
      });
      await _checkInFlightEnqueue(notifier, api);
      await _checkFailedRetry(notifier, api);
    },
  );
}

Future<void> _seedQueue() async {
  SharedPreferences.setMockInitialValues({
    Keys.currentUid: '995011',
    _queue: jsonEncode([
      {
        'id': 'foreign',
        'from': '995099',
        'type': 'C2G',
        'to': '995301',
        'payload': {
          'msg_ids': ['foreign-message'],
        },
      },
    ]),
  });
  await StorageService.init();
}

Future<void> _checkInFlightEnqueue(
  ChatNotifier notifier,
  _DeferredApi api,
) async {
  expect(await notifier.markAsRead('C2G', '995301', ['1001']), isTrue);
  await api.entered[0].future.timeout(const Duration(seconds: 3));
  expect(await notifier.markAsRead('C2G', '995301', ['1002']), isTrue);
  await Future<void>.delayed(const Duration(milliseconds: 400));
  expect(api.calls, [
    ['1001'],
  ]);
  expect(await _pending(), hasLength(3));
  api.gates[0].complete();
  await api.entered[1].future.timeout(const Duration(seconds: 3));
  expect(api.calls, [
    ['1001'],
    ['1002'],
  ]);
  expect((await _pending()).any((item) => item['id'] == 'foreign'), isTrue);
  api.gates[1].complete();
  await _waitForQueue(
    (items) => items.length == 1 && items.single['id'] == 'foreign',
  );
}

Future<void> _checkFailedRetry(ChatNotifier notifier, _DeferredApi api) async {
  expect(await notifier.markAsRead('C2G', '995301', ['1003']), isTrue);
  await api.entered[2].future.timeout(const Duration(seconds: 3));
  api.gates[2].completeError(
    const WorkspaceApiException(503, 'synthetic retry'),
  );
  await api.entered[3].future.timeout(const Duration(seconds: 8));
  expect(api.calls.skip(2), [
    ['1003'],
    ['1003'],
  ]);
  expect(await _pending(), hasLength(2));
  api.gates[3].complete();
  await _waitForQueue(
    (items) => items.length == 1 && items.single['id'] == 'foreign',
  );
}

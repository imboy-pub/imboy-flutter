import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/service/storage.dart';

import '../../../../../integration_test/helpers/chat_multi_fixtures.dart';

const _enabled = <String, dynamic>{
  ChatMultiFlags.multiSelect: true,
  ChatMultiFlags.historyBundle: true,
  ChatMultiFlags.exportShare: true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    AppFeatureRegistry.bindScope(
      endpoint: 'http://127.0.0.1:29921',
      uid: 'unit',
    );
    await AppFeatureRegistry.clear();
  });

  tearDown(() => AppFeatureRegistry.clear());

  test('requires two successful fresh snapshots', () async {
    var calls = 0;
    await verifyChatMultiServerFlags(() async {
      calls++;
      return {..._enabled};
    });
    expect(calls, 2);
    expect(AppFeatureRegistry.snapshot, _enabled);
  });

  for (final key in _enabled.keys) {
    test('rejects first snapshot missing $key', () async {
      await expectLater(
        verifyChatMultiServerFlags(() async => {..._enabled}..remove(key)),
        throwsStateError,
      );
    });
    for (final value in <Object?>[null, false, 'true', 1]) {
      test('rejects non-literal true $key=$value', () async {
        var calls = 0;
        await expectLater(
          verifyChatMultiServerFlags(() async {
            calls++;
            return {..._enabled}..[key] = value;
          }),
          throwsStateError,
        );
        expect(calls, 1);
      });
    }
  }

  test('rejects a key removed from the second snapshot', () async {
    var calls = 0;
    await expectLater(
      verifyChatMultiServerFlags(() async {
        calls++;
        return calls == 1
            ? {..._enabled}
            : ({..._enabled}..remove(ChatMultiFlags.historyBundle));
      }),
      throwsStateError,
    );
    expect(calls, 2);
    expect(
      AppFeatureRegistry.snapshot.containsKey(ChatMultiFlags.historyBundle),
      isFalse,
    );
  });

  test('rejects second refresh disabling a previously enabled key', () async {
    var calls = 0;
    await expectLater(
      verifyChatMultiServerFlags(
        () async => {..._enabled, ChatMultiFlags.multiSelect: ++calls == 1},
      ),
      throwsStateError,
    );
    expect(calls, 2);
    expect(AppFeatureRegistry.snapshot[ChatMultiFlags.multiSelect], isFalse);
  });

  for (final failsOn in [1, 2]) {
    for (final throws in [false, true]) {
      test('cached true cannot mask failed refresh $failsOn/$throws', () async {
        AppFeatureRegistry.replaceSnapshotForTest({..._enabled});
        var calls = 0;
        await expectLater(
          verifyChatMultiServerFlags(() async {
            calls++;
            if (calls == failsOn) {
              if (throws) throw StateError('synthetic fetch failure');
              return null;
            }
            return {..._enabled};
          }),
          throwsStateError,
        );
        expect(calls, failsOn);
      });
    }
  }

  test('widget-only override never replays over a server refresh', () async {
    AppFeatureRegistry.replaceSnapshotForTest({'core': true});
    final override = ChatMultiFlagOverride()..enableAll();
    addTearDown(override.restore);
    expect(AppFeatureRegistry.snapshot[ChatMultiFlags.multiSelect], isTrue);
    expect(
      await AppFeatureRegistry.refresh(
        fetch: () async => {for (final key in _enabled.keys) key: false},
      ),
      isTrue,
    );
    expect(AppFeatureRegistry.snapshot[ChatMultiFlags.multiSelect], isFalse);
    override.restore();
    expect(AppFeatureRegistry.snapshot, {'core': true});
  });
}

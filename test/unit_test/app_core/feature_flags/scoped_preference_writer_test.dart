import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/app_core/feature_flags/scoped_preference_writer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test(
    'delayed older native write cannot overwrite newer scoped record',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final old = ScopedPreferenceWriter.write(
        isCurrent: () => true,
        operation: () async {
          entered.complete();
          await release.future;
          await StorageService.setMap('scoped-A', {'project': true});
        },
      );
      await entered.future;
      final latest = ScopedPreferenceWriter.write(
        isCurrent: () => true,
        operation: () async {
          await StorageService.setMap('scoped-A', {'project': false});
        },
      );
      release.complete();
      await old;
      await latest;
      expect(StorageService.getMap('scoped-A')['project'], isFalse);
    },
  );

  test(
    'clear waits for a native write without deleting another account',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      await StorageService.setMap('scoped-B', {'moment': true});
      final old = ScopedPreferenceWriter.write(
        isCurrent: () => true,
        operation: () async {
          entered.complete();
          await release.future;
          await StorageService.setMap('scoped-A', {'project': true});
        },
      );
      await entered.future;
      final clear = ScopedPreferenceWriter.write(
        isCurrent: () => true,
        operation: () async {
          await StorageService.to.remove('scoped-A');
        },
      );
      release.complete();
      await old;
      await clear;
      expect(StorageService.getMap('scoped-A'), isEmpty);
      expect(StorageService.getMap('scoped-B')['moment'], isTrue);
    },
  );

  test(
    'write faults reach caller and do not poison later account writes',
    () async {
      await expectLater(
        ScopedPreferenceWriter.write(
          isCurrent: () => true,
          operation: () async {
            throw StateError('synthetic-write-fault');
          },
        ),
        throwsStateError,
      );
      expect(
        await ScopedPreferenceWriter.write(
          isCurrent: () => true,
          operation: () async {
            await StorageService.setMap('scoped-B', {'moment': true});
          },
        ),
        isTrue,
      );
      expect(StorageService.getMap('scoped-B')['moment'], isTrue);
    },
  );
}

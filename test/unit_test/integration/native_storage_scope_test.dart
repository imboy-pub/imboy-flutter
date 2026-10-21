import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/enterprise/macos_storage_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android token cleanup stays in the native test namespace', () async {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final spaces = <String, Map<String, String>>{
      'original': {'token': 'original-token'},
    };
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final options = Map<String, dynamic>.from(args['options'] as Map);
      final namespace = options['storageNamespace'] as String;
      expect(namespace, 'imboy-enterprise-native-regression');
      final values = spaces.putIfAbsent(namespace, () => {});
      switch (call.method) {
        case 'write':
          values[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return values[args['key'] as String];
        case 'deleteAll':
          values.clear();
          return null;
        default:
          throw StateError('Unexpected storage operation');
      }
    });
    try {
      final scoped = androidScopedSecureStorage(
        'imboy-enterprise-native-regression',
      );
      await scoped.write(key: 'token', value: 'test-token', options: {});
      expect(await scoped.read(key: 'token', options: {}), 'test-token');
      await scoped.deleteAll(options: {});
      expect(await scoped.read(key: 'token', options: {}), isNull);
      expect(spaces['original'], {'token': 'original-token'});
      expect(calls.map((call) => call.method), [
        'write',
        'read',
        'deleteAll',
        'read',
      ]);
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });
}

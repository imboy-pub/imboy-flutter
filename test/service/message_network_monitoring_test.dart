import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessagingFacade network monitoring', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
    });

    test('fires retry request when websocket becomes connected', () async {
      final facade = MessagingFacade.instance;

      String? source;
      String? reason;
      final completer = Completer<void>();

      final sub = AppEventBus.on<RetryMessagesRequestedEvent>().listen((event) {
        source = event.source;
        reason = event.reason;
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      // ensure microtask-based subscription in the legacy messaging service is ready
      await Future<void>.delayed(const Duration(milliseconds: 30));

      AppEventBus.fire(const WebSocketStatusChangedEvent(status: 'connected'));

      await completer.future.timeout(const Duration(seconds: 2));
      expect(facade.isOnline, isTrue);
      expect(source, 'WebSocketConnected');
      expect(reason, 'WebSocket 连接恢复');

      await sub.cancel();
    });
  });
}

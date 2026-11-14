import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/uiux/location_poi_response_gate.dart';

class _RecordingGate extends LocationPoiResponseGate {
  int clientsCreated = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clientsCreated++;
    return super.createHttpClient(context);
  }
}

void main() {
  test(
    'global override observes root callbacks missed by a child zone',
    () async {
      final previous = Zone.root.run(() => HttpOverrides.current);
      final gate = _RecordingGate();
      final callback = Zone.root.bindCallback(() => HttpClient()..close());
      try {
        await HttpOverrides.runZoned(
          () async => callback(),
          createHttpClient: gate.createHttpClient,
        );
        expect(gate.clientsCreated, 0);
        HttpOverrides.global = gate;
        callback();
        expect(gate.clientsCreated, 1);
      } finally {
        HttpOverrides.global = previous;
        gate.close();
      }
      expect(Zone.root.run(() => HttpOverrides.current), same(previous));
    },
  );

  test('installing after startup restores the startup override', () async {
    final previous = Zone.root.run(() => HttpOverrides.current);
    final startup = _RecordingGate();
    final gate = _RecordingGate();
    final callback = Zone.root.bindCallback(() => HttpClient()..close());
    try {
      HttpOverrides.global = gate;
      HttpOverrides.global = startup; // AppInitializer replaces the global.
      callback();
      expect(gate.clientsCreated, 0);
      final afterStartup = Zone.root.run(() => HttpOverrides.current);
      HttpOverrides.global = gate;
      try {
        callback();
        expect(gate.clientsCreated, 1);
      } finally {
        HttpOverrides.global = afterStartup;
      }
      expect(Zone.root.run(() => HttpOverrides.current), same(startup));
    } finally {
      HttpOverrides.global = previous;
      startup.close();
      gate.close();
    }
  });

  late HttpServer server;
  late HttpClient client;
  late LocationPoiResponseGate gate;
  setUp(() async {
    gate = LocationPoiResponseGate();
    client = gate.createHttpClient(null);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"status":"1","pois":[]}');
      unawaited(request.response.close());
    });
  });
  tearDown(() async {
    client.close(force: true);
    gate.close();
    await server.close(force: true);
  });
  Future<HttpClientResponse> response(String path) async {
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/'),
    );
    return gate
        .wrap(Uri.parse('https://restapi.amap.com/v5/place/$path'), request)
        .close();
  }

  test(
    'real response counts only after Dio-compatible cast consumption',
    () async {
      final result = await response('around');
      expect(gate.aroundResponses, 0);
      final bytes = await result.cast<Uint8List>().fold<List<int>>(
        [],
        (all, chunk) => all..addAll(chunk),
      );
      expect(String.fromCharCodes(bytes), '{"status":"1","pois":[]}');
      expect(gate.aroundResponses, 1);
    },
  );
  test(
    'replacing subscription onDone cannot bypass consumption tracking',
    () async {
      final result = await response('around');
      final subscription = result.cast<Uint8List>().listen((_) {});
      await subscription.asFuture<void>();
      expect(gate.aroundResponses, 1);
    },
  );
  test(
    'held response stays unavailable until explicit release and consumption',
    () async {
      gate.arm('held');
      var completed = false;
      final pending = response('text?keywords=held').then((value) {
        completed = true;
        return value;
      });
      await gate.observed;
      expect(gate.held, 1);
      expect(completed, isFalse);
      expect(gate.consumed, 0);
      gate.release();
      final result = await pending;
      expect(gate.consumed, 0);
      await result.cast<Uint8List>().drain<void>();
      expect(gate.released, 1);
      expect(gate.consumed, 1);
    },
  );
}

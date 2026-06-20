/// AttachmentApi presign 直传编排 + PUT 指数退避重试单元测试
///
/// 测试目标（全程注入 fake seam，不触网、不真实等待、不依赖 widget binding）：
/// 1. putWithRetry：首次失败二次成功 / 连续失败耗尽重试 / 退避序列 / 快乐路径
/// 2. uploadViaPresign：校验失败 / presign 失败 / 缺字段 / confirm 失败 / 快乐路径编排
library;

import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/attachment_api.dart';

void main() {
  final Uint8List bytes = Uint8List.fromList(
    List<int>.generate(64, (int i) => i),
  );
  final String expectedMd5 = md5.convert(bytes).toString();

  group('putWithRetry - PUT 指数退避重试', () {
    test('首次失败、二次成功 → 完成，put 调 2 次，退避 1 次(500ms)', () async {
      int putCalls = 0;
      final List<Duration> delays = <Duration>[];
      await AttachmentApi.putWithRetry(
        'https://garage.local/put',
        bytes,
        'image/png',
        process: false,
        singlePut: (String url, Uint8List b, String m, bool p) async {
          putCalls++;
          if (putCalls == 1) throw Exception('first fail');
        },
        delay: (Duration d) async => delays.add(d),
      );
      expect(putCalls, 2);
      expect(delays, <Duration>[const Duration(milliseconds: 500)]);
    });

    test('连续 3 次失败 → 抛异常(已重试 3 次)，put 3 次，退避 2 次(500/1000ms)', () async {
      int putCalls = 0;
      final List<Duration> delays = <Duration>[];
      await expectLater(
        AttachmentApi.putWithRetry(
          'https://garage.local/put',
          bytes,
          'image/png',
          process: false,
          singlePut: (String url, Uint8List b, String m, bool p) async {
            putCalls++;
            throw Exception('always fail');
          },
          delay: (Duration d) async => delays.add(d),
        ),
        throwsA(predicate((Object? e) => e.toString().contains('已重试 3 次'))),
      );
      expect(putCalls, 3);
      expect(delays, <Duration>[
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 1000),
      ]);
    });

    test('快乐路径 → put 仅 1 次，无退避', () async {
      int putCalls = 0;
      final List<Duration> delays = <Duration>[];
      await AttachmentApi.putWithRetry(
        'https://garage.local/put',
        bytes,
        'image/png',
        process: false,
        singlePut: (String url, Uint8List b, String m, bool p) async {
          putCalls++;
        },
        delay: (Duration d) async => delays.add(d),
      );
      expect(putCalls, 1);
      expect(delays, isEmpty);
    });
  });

  group('uploadViaPresign - presign→put→confirm 编排', () {
    // 默认成功的 presign 响应
    IMBoyHttpResponse okPresign() =>
        IMBoyHttpResponse.success(<String, dynamic>{
          'put_url': 'https://garage.local/put?sig=x',
          'object_key': 'u1/file_1_a/x.png',
        });

    test('校验失败（空字节）→ 抛异常，不调用 presign', () async {
      bool presignCalled = false;
      await expectLater(
        AttachmentApi.uploadViaPresign(
          Uint8List(0),
          'x.png',
          'image/png',
          process: false,
          presignFn: (String f, String m) async {
            presignCalled = true;
            return okPresign();
          },
          putFn: (String u, Uint8List b, String m, bool p) async {},
          confirmFn: (Map<String, dynamic> body) async =>
              IMBoyHttpResponse.success(<String, dynamic>{}),
        ),
        throwsException,
      );
      expect(presignCalled, isFalse);
    });

    test('presign ok=false → 抛异常，不调用 PUT/confirm', () async {
      bool putCalled = false;
      bool confirmCalled = false;
      await expectLater(
        AttachmentApi.uploadViaPresign(
          bytes,
          'x.png',
          'image/png',
          process: false,
          presignFn: (String f, String m) async =>
              IMBoyHttpResponse.failure(errMsg: 'boom', errCode: 500),
          putFn: (String u, Uint8List b, String m, bool p) async =>
              putCalled = true,
          confirmFn: (Map<String, dynamic> body) async {
            confirmCalled = true;
            return IMBoyHttpResponse.success(<String, dynamic>{});
          },
        ),
        throwsA(predicate((Object? e) => e.toString().contains('presign 失败'))),
      );
      expect(putCalled, isFalse);
      expect(confirmCalled, isFalse);
    });

    test('presign 缺 put_url/object_key → 抛异常，不调用 PUT', () async {
      bool putCalled = false;
      await expectLater(
        AttachmentApi.uploadViaPresign(
          bytes,
          'x.png',
          'image/png',
          process: false,
          presignFn: (String f, String m) async =>
              IMBoyHttpResponse.success(<String, dynamic>{'object_key': ''}),
          putFn: (String u, Uint8List b, String m, bool p) async =>
              putCalled = true,
          confirmFn: (Map<String, dynamic> body) async =>
              IMBoyHttpResponse.success(<String, dynamic>{}),
        ),
        throwsA(
          predicate((Object? e) => e.toString().contains('presign 响应缺少')),
        ),
      );
      expect(putCalled, isFalse);
    });

    test('confirm ok=false → 抛异常', () async {
      await expectLater(
        AttachmentApi.uploadViaPresign(
          bytes,
          'x.png',
          'image/png',
          process: false,
          presignFn: (String f, String m) async => okPresign(),
          putFn: (String u, Uint8List b, String m, bool p) async {},
          confirmFn: (Map<String, dynamic> body) async =>
              IMBoyHttpResponse.failure(errMsg: 'db down', errCode: 500),
        ),
        throwsA(predicate((Object? e) => e.toString().contains('confirm 失败'))),
      );
    });

    test('快乐路径 → 返回 object_key，PUT/confirm 参数正确', () async {
      String? putUrlSeen;
      String? putMimeSeen;
      Map<String, dynamic>? confirmBody;
      final String objectKey = await AttachmentApi.uploadViaPresign(
        bytes,
        'x.png',
        'image/png',
        process: false,
        presignFn: (String f, String m) async {
          expect(f, 'x.png');
          expect(m, 'image/png');
          return okPresign();
        },
        putFn: (String u, Uint8List b, String m, bool p) async {
          putUrlSeen = u;
          putMimeSeen = m;
        },
        confirmFn: (Map<String, dynamic> body) async {
          confirmBody = body;
          return IMBoyHttpResponse.success(<String, dynamic>{});
        },
      );
      expect(objectKey, 'u1/file_1_a/x.png');
      expect(putUrlSeen, 'https://garage.local/put?sig=x');
      expect(putMimeSeen, 'image/png');
      // 默认 scope=private（保持既有非聊天面行为），不带 scope_ref。
      expect(confirmBody, <String, dynamic>{
        'object_key': 'u1/file_1_a/x.png',
        'md5': expectedMd5,
        'mime_type': 'image/png',
        'size': bytes.length,
        'scope': 'private',
      });
    });

    test('scope=public → confirmBody 带 scope=public、不带 scope_ref', () async {
      Map<String, dynamic>? confirmBody;
      await AttachmentApi.uploadViaPresign(
        bytes,
        'a.jpg',
        'image/jpeg',
        process: false,
        scope: 'public',
        presignFn: (String f, String m) async => okPresign(),
        putFn: (String u, Uint8List b, String m, bool p) async {},
        confirmFn: (Map<String, dynamic> body) async {
          confirmBody = body;
          return IMBoyHttpResponse.success(<String, dynamic>{});
        },
      );
      expect(confirmBody?['scope'], 'public');
      expect(confirmBody?.containsKey('scope_ref'), isFalse);
    });

    test(
      'scope=c2c + scopeRef → confirmBody 带 scope=c2c、scope_ref 透传',
      () async {
        Map<String, dynamic>? confirmBody;
        await AttachmentApi.uploadViaPresign(
          bytes,
          'a.jpg',
          'image/jpeg',
          process: false,
          scope: 'c2c',
          scopeRef: 'c2c:1:2',
          presignFn: (String f, String m) async => okPresign(),
          putFn: (String u, Uint8List b, String m, bool p) async {},
          confirmFn: (Map<String, dynamic> body) async {
            confirmBody = body;
            return IMBoyHttpResponse.success(<String, dynamic>{});
          },
        );
        expect(confirmBody?['scope'], 'c2c');
        expect(confirmBody?['scope_ref'], 'c2c:1:2');
      },
    );
  });
}

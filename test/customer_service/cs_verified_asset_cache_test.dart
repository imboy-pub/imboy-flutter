import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_verified_asset_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('temporary empty content can be requested again', () async {
    final cache = CsVerifiedAssetCache();
    var calls = 0;
    Future<CsVerifiedAssetContent?> load() async {
      calls++;
      return null;
    }

    await cache.get('9', load);
    await cache.get('9', load);
    expect(calls, 2);
  });

  test('failed content does not permanently poison retry', () async {
    final cache = CsVerifiedAssetCache();
    var calls = 0;
    Future<CsVerifiedAssetContent?> load() async {
      calls++;
      throw StateError('synthetic temporary failure');
    }

    await expectLater(cache.get('9', load), throwsStateError);
    await expectLater(cache.get('9', load), throwsStateError);
    expect(calls, 2);
  });

  test('late failure after clear cannot evict a new pending request', () async {
    final cache = CsVerifiedAssetCache();
    final old = Completer<CsVerifiedAssetContent?>();
    final current = Completer<CsVerifiedAssetContent?>();
    final first = cache.get('9', () => old.future);
    final rejected = expectLater(first, throwsStateError);
    cache.clear();
    final second = cache.get('9', () => current.future);
    old.completeError(StateError('synthetic old failure'));
    await rejected;
    var replacements = 0;
    final third = cache.get('9', () {
      replacements++;
      return Future.value(null);
    });
    expect(identical(second, third), isTrue);
    expect(replacements, 0);
    current.complete(null);
    await second;
  });
}

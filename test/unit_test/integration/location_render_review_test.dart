import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/uiux/location_render_review.dart';

void main() {
  const tag = 'synthetic-run';
  const stage = 'before-native-drag';
  const hash = 'synthetic-screenshot-sha';
  Map<String, dynamic> valid() => {
    'run_tag': tag,
    'stage': stage,
    'screenshot_sha256': hash,
    'map_visible': true,
    'placeholder_absent': true,
  };
  bool accepts(Object? value, {bool changed = false}) =>
      matchesLocationRenderReview(
        value,
        runTag: tag,
        stage: stage,
        screenshotSha256: hash,
        requireSceneChanged: changed,
      );

  test('accepts exact observations and tolerates root provenance fields', () {
    expect(accepts({...valid(), 'reviewer': 'root-agent'}), isTrue);
  });
  test('rejects missing required fields', () {
    for (final key in valid().keys) {
      expect(accepts(valid()..remove(key)), isFalse, reason: key);
    }
  });
  test('rejects wrong nonce, stage or screenshot', () {
    for (final key in ['run_tag', 'stage', 'screenshot_sha256']) {
      expect(accepts({...valid(), key: 'different'}), isFalse, reason: key);
    }
  });
  test('requires actual true observation booleans', () {
    for (final key in ['map_visible', 'placeholder_absent']) {
      for (final value in [false, 'true', 1, null]) {
        expect(accepts({...valid(), key: value}), isFalse, reason: key);
      }
    }
  });
  test('after-drag additionally requires explicit scene change', () {
    expect(accepts(valid(), changed: true), isFalse);
    expect(
      accepts({...valid(), 'scene_changed': false}, changed: true),
      isFalse,
    );
    expect(
      accepts({...valid(), 'scene_changed': 'true'}, changed: true),
      isFalse,
    );
    expect(accepts({...valid(), 'scene_changed': true}, changed: true), isTrue);
  });
  test('rejects malformed decoded receipt shapes', () {
    for (final value in [null, true, 'receipt', <Object>[], <int, Object>{}]) {
      expect(accepts(value), isFalse);
    }
  });
}

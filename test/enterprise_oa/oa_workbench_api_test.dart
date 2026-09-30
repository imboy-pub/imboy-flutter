import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/enterprise_oa/data/oa_workbench_api.dart';

void main() {
  Map<String, Object> entry(int org, String redirect) => {
    'kind': 'oa',
    'organization_id': org,
    'application_id': 101,
    'application_key': 'shared-oa-key',
    'label': '办公',
    'redirect_uri': redirect,
  };
  test('配置只来自当前企业；HTTPS 同源配置复用现有模型', () {
    final configs = parseOaWorkbenchEntries({
      'entries': [
        entry(10, 'https://oa.example.com/a'),
        entry(20, 'https://oa.example.com/b'),
      ],
    }, '10');
    expect(configs, hasLength(1));
    expect(configs.single.redirectUri, 'https://oa.example.com/a');
    expect(configs.single.brand.oaOrigin, 'https://oa.example.com');
    expect(configs.single.runtimeEntryEnabled, isTrue);
    expect(configs.single.oaTabLabel, '办公');
  });
  test('坏条目和无企业配置不能打开 OA', () {
    for (final redirect in [
      'http://oa.example.com/a',
      'javascript:alert(1)',
      'https://fake@oa.example.com/a',
      'https://oa.example.com/a#fragment',
    ]) {
      expect(
        parseOaWorkbenchEntries({
          'entries': [entry(10, redirect)],
        }, '10'),
        isEmpty,
      );
    }
    expect(
      parseOaWorkbenchEntries({
        'entries': [null, <String, dynamic>{}],
      }, '10'),
      isEmpty,
    );
    expect(
      parseOaWorkbenchEntries({
        'entries': [entry(10, 'https://oa.example.com/a')],
      }, ''),
      isEmpty,
    );
  });
  test('配置响应上限保持 20 条', () {
    expect(
      parseOaWorkbenchEntries({
        'entries': List.generate(
          25,
          (_) => entry(10, 'https://oa.example.com/a'),
        ),
      }, '10'),
      hasLength(20),
    );
  });
}

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
  test('实例级返回全部条目（定位修订：organization 不参与过滤）；HTTPS 同源配置复用现有模型', () {
    final configs = parseOaWorkbenchEntries({
      'entries': [
        entry(10, 'https://oa.example.com/a'),
        entry(20, 'https://oa.example.com/b'),
      ],
    });
    expect(configs, hasLength(2));
    expect(configs.first.redirectUri, 'https://oa.example.com/a');
    expect(configs.first.brand.oaOrigin, 'https://oa.example.com');
    expect(configs.first.runtimeEntryEnabled, isTrue);
    expect(configs.first.oaTabLabel, '办公');
    expect(configs.last.redirectUri, 'https://oa.example.com/b');
  });
  test('坏条目不能打开 OA（形态校验保留）', () {
    for (final redirect in [
      'http://oa.example.com/a',
      'javascript:alert(1)',
      'https://fake@oa.example.com/a',
      'https://oa.example.com/a#fragment',
    ]) {
      expect(
        parseOaWorkbenchEntries({
          'entries': [entry(10, redirect)],
        }),
        isEmpty,
      );
    }
    expect(
      parseOaWorkbenchEntries({
        'entries': [null, <String, dynamic>{}],
      }),
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
      }),
      hasLength(20),
    );
  });
}

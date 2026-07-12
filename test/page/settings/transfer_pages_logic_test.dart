import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/service/e2ee_transfer_service.dart';

/// lib/page/settings/e2ee_transfer_page.dart /
/// e2ee_transfer_send_page.dart / e2ee_transfer_receive_page.dart
/// 的可提纯逻辑单测。
///
/// 页面本身不可 widget 渲染测试：send 页依赖 E2EEKeyService/
/// StorageSecureService（平台通道），receive 页依赖 MobileScanner
/// （相机平台通道），均为静态调用无注入点。此处覆盖两页之间的
/// 二维码数据契约：send 页 generateQRCodeData → receive 页
/// parseQRCodeData 必须往返一致。
void main() {
  group('generateQRCodeData（send 页）', () {
    test('生成含 type 与 session_id 的 JSON', () {
      final qr = E2EETransferService.generateQRCodeData('sess-123');
      final map = jsonDecode(qr) as Map<String, dynamic>;
      expect(map['type'], 'e2ee_transfer');
      expect(map['session_id'], 'sess-123');
    });

    test('extra 字段合并进二维码数据', () {
      final qr = E2EETransferService.generateQRCodeData(
        'sess-1',
        extra: {'from_device_id': 'dev-9'},
      );
      final map = jsonDecode(qr) as Map<String, dynamic>;
      expect(map['from_device_id'], 'dev-9');
      expect(map['session_id'], 'sess-1');
    });
  });

  group('parseQRCodeData（receive 页扫码入口）', () {
    test('send 页生成的数据可无损往返解析', () {
      final qr = E2EETransferService.generateQRCodeData('sess-abc');
      final parsed = E2EETransferService.parseQRCodeData(qr);
      expect(parsed, isNotNull);
      expect(parsed!['session_id'], 'sess-abc');
      expect(parsed['type'], 'e2ee_transfer');
    });

    test('非 JSON 字符串返回 null（扫到无关码不崩溃）', () {
      expect(E2EETransferService.parseQRCodeData('not json'), isNull);
      expect(E2EETransferService.parseQRCodeData(''), isNull);
    });

    test('type 不是 e2ee_transfer 返回 null', () {
      final qr = jsonEncode({'type': 'other', 'session_id': 's1'});
      expect(E2EETransferService.parseQRCodeData(qr), isNull);
    });

    test('JSON 非对象返回 null', () {
      expect(E2EETransferService.parseQRCodeData('[1,2,3]'), isNull);
      expect(E2EETransferService.parseQRCodeData('"str"'), isNull);
    });

    test('缺 session_id 时返回 Map 且 session_id 为 null（页面侧兜底）', () {
      // receive 页 _onDetect 对 data['session_id'] == null 直接 return，
      // 此契约保证解析层不抛异常。
      final qr = jsonEncode({'type': 'e2ee_transfer'});
      final parsed = E2EETransferService.parseQRCodeData(qr);
      expect(parsed, isNotNull);
      expect(parsed!['session_id'], isNull);
    });
  });
}

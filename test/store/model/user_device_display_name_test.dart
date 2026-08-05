import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/user_device_model.dart';

/// 真机实测：登录设备管理页 8 台设备，7 台只有图标没有名字 ——
/// 后端 `device_name` 是登录时客户端上报的 dname，历史/web 登录可能为空。
/// 这个页面的全部意义就是"认出可疑设备并踢掉"，空名等于功能失效。
UserDeviceModel _d({
  String name = '',
  String type = 'android',
  Map<dynamic, dynamic> vsn = const {},
}) => UserDeviceModel(
  deviceId: 'did-1',
  deviceName: name,
  deviceType: type,
  lastActiveAt: 0,
  deviceVsn: vsn,
);

void main() {
  group('UserDeviceModel.displayName', () {
    test('有上报名字时原样返回', () {
      expect(_d(name: 'HUAWEIMRD-AL00').displayName, 'HUAWEIMRD-AL00');
    });

    test('名字为空时回退到 device_vsn 里的型号', () {
      expect(_d(vsn: {'model': 'MRD-AL00'}).displayName, 'MRD-AL00');
    });

    test('名字和型号都空时回退到平台+系统版本', () {
      expect(_d(vsn: {'version.sdkInt': 33}).displayName, 'android 33');
    });

    test('全空也不返回空串（否则列表渲染成空白条目）', () {
      final v = _d(name: '', type: '').displayName;
      expect(v, isNotEmpty);
      expect(v, t.account.otherDevice);
    });
  });
}

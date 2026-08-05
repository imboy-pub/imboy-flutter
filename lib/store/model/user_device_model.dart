import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

class UserDeviceModel {
  String deviceId;
  String deviceName;
  String deviceType;
  int lastActiveAt;
  bool online;
  Map<dynamic, dynamic> deviceVsn;

  UserDeviceModel({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.lastActiveAt,
    this.online = false,
    required this.deviceVsn,
  });

  /// 列表/详情里展示用的设备名。
  ///
  /// 历史登录（老客户端、web 扫码）可能没上报 dname，后端 `device_name` 存的就是
  /// 空串，直接渲染会得到一行只有图标的空白条目 —— 而"登录设备管理"这个页面的
  /// 全部意义就是让用户认出哪台是自己的、哪台该踢掉。
  /// 兜底顺序：上报的名字 → device_vsn 里的型号 → 平台+系统版本 → 通用文案。
  String get displayName {
    if (deviceName.isNotEmpty) return deviceName;
    final model = parseModelString(deviceVsn['model']);
    if (model.isNotEmpty) return model;
    final type = showType.trim();
    return type.isNotEmpty ? type : t.account.otherDevice;
  }

  String get showType {
    if (deviceType == 'android') {
      return "$deviceType ${deviceVsn['version.sdkInt'] ?? ''}";
    } else if (deviceType == 'ios') {
      return "iPhone iOS ${deviceVsn['systemVersion'] ?? ''}";
    }
    return deviceType;
  }

  factory UserDeviceModel.fromJson(Map<String, dynamic> json) {
    final deviceVsn = parseModelJsonMap(json['device_vsn']) ?? {};
    return UserDeviceModel(
      deviceId: parseModelString(json['device_id']),
      deviceName: parseModelString(json['device_name']),
      deviceType: parseModelString(json['device_type']),
      lastActiveAt: DateTimeHelper.parseTimestamp(json['last_active_at']),
      // 本地数据库 online ，线上获取有 online
      online: parseModelBool(json['online']),
      deviceVsn: deviceVsn,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['device_id'] = deviceId;
    data['device_name'] = deviceName;
    data['device_type'] = deviceType;
    data['last_active_at'] = lastActiveAt;
    data['online'] = online;
    data['device_vsn'] = deviceVsn;
    return data;
  }
}

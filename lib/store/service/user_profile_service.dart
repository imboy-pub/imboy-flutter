import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 用户资料更新服务。
///
/// 统一封装「PUT /api/v1/user/update 更新单个字段 + 同步本地 UserRepoLocal 缓存」逻辑，
/// 消除 PersonalInfoPage 与 ProfilePage 各自手写、且行为不一致的重复实现（DRY）。
///
/// 隐私设置类字段写入 `payload['setting']`，其余字段写顶层，与后端数据结构对齐。
/// 通过可选回调注入 HttpClient / UserRepoLocal 单例，便于纯单元测试。
class UserProfileService {
  const UserProfileService._();

  /// 隐私设置字段集合：这些字段在本地缓存中归属 `setting` 子对象。
  static const Set<String> settingFields = {
    'allow_search',
    'allow_add_by_phone',
    'allow_add_by_qr',
    'show_online_status',
    'allow_nearby_visible',
  };

  /// 更新用户单个字段：PUT 后端，成功后同步本地缓存。
  ///
  /// 返回是否成功。PUT 失败时不写本地缓存。
  ///
  /// [httpPut]/[readCurrent]/[saveLocal] 仅用于测试注入，生产环境使用默认实现。
  static Future<bool> updateField(
    String field,
    dynamic value, {
    Future<IMBoyHttpResponse> Function(Map<String, dynamic> data)? httpPut,
    Map<String, dynamic> Function()? readCurrent,
    void Function(Map<String, dynamic> payload)? saveLocal,
  }) async {
    final put =
        httpPut ?? (data) => HttpClient.client.put(API.userUpdate, data: data);
    final readCur = readCurrent ?? () => UserRepoLocal.to.current.toMap();
    final save = saveLocal ?? (p) => UserRepoLocal.to.changeInfo(p);

    // allow_search 后端权威值域为 int 1|2（user_agg:validate_allow_search），
    // bool 直传会被后端拒绝导致写入无效——这曾造成设置页与隐私页
    // 两处同义开关状态长期矛盾（QA#18）。
    if (field == 'allow_search' && value is bool) {
      value = value ? 1 : 2;
    }

    final resp = await put({'field': field, 'value': value});
    if (!resp.ok) return false;

    final payload = readCur();
    if (settingFields.contains(field)) {
      final existing = payload['setting'];
      final setting = existing is Map<String, dynamic>
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{};
      setting[field] = value;
      payload['setting'] = setting;
    } else {
      payload[field] = value;
    }
    save(payload);
    return true;
  }
}

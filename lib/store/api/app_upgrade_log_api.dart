import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// APP 升级事件上报 API
///
/// 上报升级过程中的关键事件到服务端，用于版本分布统计和问题排查。
/// 上报失败静默忽略，不影响用户体验。
class AppUpgradeLogApi {
  static const String _reportPath = '/v1/app_upgrade/report';

  /// 上报升级事件
  ///
  /// [event] 事件类型：check / prompted / download_start / download_done
  ///                    verify_ok / verify_fail / install / cancel / error
  /// [clientVsn] 客户端当前版本
  /// [targetVsn] 目标版本（可选）
  /// [upgradeType] 升级类型：force / recommend / silent / none
  /// [extra] 额外信息（可选）
  static Future<void> report({
    required String event,
    String? targetVsn,
    String upgradeType = '',
    Map<String, dynamic>? extra,
  }) async {
    try {
      final uid = UserRepoLocal.to.isLoggedIn
          ? UserRepoLocal.to.currentUid
          : '0';

      await HttpClient.client.post(
        _reportPath,
        data: {
          'event': event,
          'client_vsn': appVsn,
          'target_vsn': targetVsn ?? '',
          'upgrade_type': upgradeType,
          'uid': uid,
          'extra': extra ?? {},
        },
      );
    } catch (e) {
      // 上报失败静默忽略
      iPrint('AppUpgradeLogApi.report failed: $e');
    }
  }
}

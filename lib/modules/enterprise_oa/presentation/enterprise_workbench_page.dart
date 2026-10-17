import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/web_view.dart';

import '../data/oa_bridge_auth_code.dart';
import '../enterprise_oa_runtime_config.dart';
// ApiOaSsoIssueLauncher（SSO 签发出口）定义于 oa_tab_page.dart。
import 'oa_tab_page.dart' show ApiOaSsoIssueLauncher;

/// 企业工作台页：资源入口 + 应用联调入口。
///
/// 产品裁决（2026-10-17）：不再展示 OA 应用列表（「办公」入口），工作台
/// 只保留「应用」联调入口；已登记 OA 应用仍服务于桥 getAuthCode 按需签发。
class EnterpriseWorkbenchPage extends StatelessWidget {
  const EnterpriseWorkbenchPage({
    super.key,
    required this.entries,
    required this.accountKey,
    required this.organizationId,
    this.resourceEntries = const [],
  });
  final List<EnterpriseOaRuntimeConfig> entries;
  final String accountKey;
  final String organizationId;
  final List<Widget> resourceEntries;

  /// 应用入口联调页，点击后经应用内 WebView 打开；imboy.pub 域名会自动挂
  /// imboyJSBridge 通道（见 component/web_view.dart）。
  static const String appsUrl = 'https://imboy.pub/test_oa.html';

  /// 桥 getAuthCode 注入实现：用实例内已登记 OA 应用按需签发一次性
  /// code（仅 H5 主动调用时发生；打开页面不预取）。定位修订（2026-10-12）：
  /// organization 不参与授权，签发不携带企业字段。
  Future<ImboyBridgeAuthCode> _issueBridgeAuthCode(String? applicationKey) {
    return OaBridgeAuthCodeService(issue: ApiOaSsoIssueLauncher().launch)
        .getAuthCode(entries: entries, applicationKey: applicationKey);
  }

  Future<void> _openApps(BuildContext context) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<dynamic>(
        builder: (_) => WebViewPage(
          appsUrl,
          t.enterpriseOa.apps,
          allowOaDevicePermissions: true,
          oaAuthCodeHandler: _issueBridgeAuthCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (resourceEntries.isNotEmpty)
          CupertinoListSection.insetGrouped(children: resourceEntries),
        if ((!kIsWeb && defaultTargetPlatform == TargetPlatform.android))
          for (final entry in entries.where(
            (entry) => entry.inboundLoginEnabled,
          ))
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  title: Text(t.enterpriseOa.confirmLink),
                  onTap: () => context.push('/oa/login', extra: entry),
                ),
              ],
            ),
        // 联调入口常驻：按需免登（桥 getAuthCode）依赖已登记 OA 应用——
        // 联调页若只在"无配置"时可见，配置完成后反而永远取不到码。
        CupertinoListSection.insetGrouped(
          children: [
            CupertinoListTile(
              key: const ValueKey('workbench-apps-entry'),
              leading: const Icon(CupertinoIcons.square_grid_2x2),
              title: Text(t.enterpriseOa.apps),
              trailing: const CupertinoListTileChevron(),
              onTap: () => _openApps(context),
            ),
          ],
        ),
      ],
    );
  }
}

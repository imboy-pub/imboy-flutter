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
          _GroupedSection(children: resourceEntries),
        if ((!kIsWeb && defaultTargetPlatform == TargetPlatform.android))
          for (final entry in entries.where(
            (entry) => entry.inboundLoginEnabled,
          ))
            _GroupedSection(
              children: [
                CupertinoListTile(
                  // P2-04/D02：辅助登录行补统一 24×24 图标槽（命中高 ≥48）。
                  leading: const SizedBox.square(
                    dimension: 24,
                    child: Center(
                      widthFactor: 1,
                      child: Icon(CupertinoIcons.person_crop_circle, size: 20),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  title: Text(t.enterpriseOa.confirmLink),
                  onTap: () => context.push('/oa/login', extra: entry),
                ),
              ],
            ),
        // 联调入口常驻：按需免登（桥 getAuthCode）依赖已登记 OA 应用——
        // 联调页若只在"无配置"时可见，配置完成后反而永远取不到码。
        _GroupedSection(
          children: [
            CupertinoListTile(
              key: const ValueKey('workbench-apps-entry'),
              padding: const EdgeInsets.symmetric(vertical: 10),
              leading: const SizedBox.square(
                dimension: 24,
                child: Center(
                  widthFactor: 1,
                  child: Icon(CupertinoIcons.square_grid_2x2, size: 20),
                ),
              ),
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

/// P2-01/P2-05/D04 统一分组容器：背景/圆角/边距与
/// `CupertinoListSection.insetGrouped` 同 token 同节奏，但**高度由子项
/// 自然收缩**——insetGrouped 的固定 margin/divider 会把全不可见的子项
///（如 CS 入口 gate 隐藏后的 SizedBox.shrink）仍撑出一个空壳卡；此处
/// Column 在全 shrink 子项下高度为 0，容器无视觉残留。
/// 可见性判定仍留在子 widget 的既有 gate 内，本容器不复制权限规则。
class _GroupedSection extends StatelessWidget {
  const _GroupedSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // insetGrouped 的同款组间距节奏。
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemGroupedBackground.resolveFrom(
            context,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: children),
      ),
    );
  }
}

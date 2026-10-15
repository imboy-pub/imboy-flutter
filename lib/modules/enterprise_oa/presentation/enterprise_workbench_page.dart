import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/web_view.dart';

import '../data/oa_bridge_auth_code.dart';
import '../enterprise_oa_runtime_config.dart';
import 'oa_tab_page.dart';

/// 只在用户选择应用后启动 SSO，不在后台自动加载 WebView。
class EnterpriseWorkbenchPage extends StatefulWidget {
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

  @override
  State<EnterpriseWorkbenchPage> createState() =>
      _EnterpriseWorkbenchPageState();
}

class _EnterpriseWorkbenchPageState extends State<EnterpriseWorkbenchPage> {
  String? _applicationKey;

  @override
  void didUpdateWidget(covariant EnterpriseWorkbenchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountKey != widget.accountKey ||
        oldWidget.organizationId != widget.organizationId) {
      _applicationKey = null;
    }
  }

  /// 桥 getAuthCode 注入实现：用实例内已登记 OA 应用按需签发一次性
  /// code（仅 H5 主动调用时发生；打开页面不预取）。定位修订（2026-10-12）：
  /// organization 不参与授权，签发不携带企业字段。应用在调用时现读
  /// `widget`（State.widget 恒指向最新配置），无过期闭包捕获。
  Future<ImboyBridgeAuthCode> _issueBridgeAuthCode(String? applicationKey) {
    return OaBridgeAuthCodeService(issue: ApiOaSsoIssueLauncher().launch)
        .getAuthCode(entries: widget.entries, applicationKey: applicationKey);
  }

  Future<void> _openApps() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<dynamic>(
        builder: (_) => WebViewPage(
          EnterpriseWorkbenchPage.appsUrl,
          t.enterpriseOa.apps,
          allowOaDevicePermissions: true,
          oaAuthCodeHandler: _issueBridgeAuthCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.entries
        .where((entry) => entry.runtimeEntryEnabled)
        .toList();
    final selected = available
        .where((entry) => entry.applicationKey == _applicationKey)
        .firstOrNull;
    if (selected == null) {
      _applicationKey = null;
      return ListView(
        children: [
          if (widget.resourceEntries.isNotEmpty)
            CupertinoListSection.insetGrouped(children: widget.resourceEntries),
          if ((!kIsWeb && defaultTargetPlatform == TargetPlatform.android))
            for (final entry in widget.entries.where(
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
          if (available.isNotEmpty)
            CupertinoListSection.insetGrouped(
              children: [
                for (final entry in available)
                  CupertinoListTile(
                    key: ValueKey(
                      'workbench-application-${entry.applicationKey}',
                    ),
                    title: Text(
                      entry.oaTabLabel.isEmpty
                          ? t.enterpriseOa.title
                          : entry.oaTabLabel,
                    ),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () =>
                        setState(() => _applicationKey = entry.applicationKey),
                  ),
              ],
            ),
          // 联调入口常驻：按需免登（桥 getAuthCode）依赖已登记 OA 应用，
          // 而上方应用入口走的是无桥 redirect 容器（OaTabPage）——联调页
          // 若只在"无配置"时可见，配置完成后反而永远取不到码。
          CupertinoListSection.insetGrouped(
            children: [
              CupertinoListTile(
                key: const ValueKey('workbench-apps-entry'),
                title: Text(t.enterpriseOa.apps),
                subtitle: const Text(EnterpriseWorkbenchPage.appsUrl),
                trailing: const CupertinoListTileChevron(),
                onTap: _openApps,
              ),
            ],
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: BackButton(
          onPressed: () => setState(() => _applicationKey = null),
        ),
        title: Text(
          selected.oaTabLabel.isEmpty
              ? t.enterpriseOa.title
              : selected.oaTabLabel,
        ),
      ),
      body: OaTabPage(
        key: ValueKey((
          widget.accountKey,
          widget.organizationId,
          selected.applicationKey,
          selected.redirectUri,
        )),
        config: selected,
        accountKey: widget.accountKey,
        organizationId: widget.organizationId,
      ),
    );
  }
}

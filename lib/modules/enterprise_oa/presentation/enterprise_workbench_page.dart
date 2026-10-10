import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/helper/safe_launcher.dart';
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

  /// webview_flutter 仅 Android/iOS 有平台实现（macOS/Web 无实现包），
  /// 其余平台保持系统浏览器兜底。
  bool get _inAppWebViewSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// 桥 getAuthCode 注入实现：用当前企业上下文与已登记 OA 应用按需签发
  /// 一次性 code（仅 H5 主动调用时发生；打开页面不预取）。组织/应用在
  /// 调用时现读 `widget`（State.widget 恒指向最新配置），无过期闭包捕获，
  /// 取码始终使用当时登录身份对应的企业上下文。
  Future<ImboyBridgeAuthCode> _issueBridgeAuthCode(String? applicationKey) {
    return OaBridgeAuthCodeService(
      issue: ApiOaSsoIssueLauncher(organizationId: widget.organizationId)
          .launch,
    ).getAuthCode(entries: widget.entries, applicationKey: applicationKey);
  }

  Future<void> _openApps() async {
    if (_inAppWebViewSupported) {
      if (!mounted) return;
      await Navigator.of(context).push(
        CupertinoPageRoute<dynamic>(
          builder: (_) => WebViewPage(
            EnterpriseWorkbenchPage.appsUrl,
            t.enterpriseOa.apps,
            oaAuthCodeHandler: _issueBridgeAuthCode,
          ),
        ),
      );
      return;
    }
    var opened = false;
    try {
      opened = await SafeLauncher.safeLaunchUrl(
        Uri.parse(EnterpriseWorkbenchPage.appsUrl),
      );
    } catch (_) {
      // 系统浏览器不可用时给出与无法打开链接相同的提示。
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.common.cannotOpenWebpage)));
    }
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
          if (available.isEmpty)
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

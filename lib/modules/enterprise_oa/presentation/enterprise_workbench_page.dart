import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';

import '../enterprise_oa_runtime_config.dart';
import 'oa_tab_page.dart';

/// 只在用户选择应用后启动 SSO，不在后台自动加载 WebView。
class EnterpriseWorkbenchPage extends StatefulWidget {
  const EnterpriseWorkbenchPage({
    super.key,
    required this.entries,
    required this.accountKey,
    required this.organizationId,
  });
  final List<EnterpriseOaRuntimeConfig> entries;
  final String accountKey;
  final String organizationId;

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

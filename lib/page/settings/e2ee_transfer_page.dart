import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/settings/e2ee_transfer_send_page.dart';
import 'package:imboy/page/settings/e2ee_transfer_receive_page.dart';
import 'package:imboy/service/e2ee_transfer_service.dart';

/// E2EE 设备间传输入口页面
class E2EETransferPage extends StatelessWidget {
  const E2EETransferPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.e2eeTransferPageTitle)),
      body: ListView(
        children: [
          _buildSectionHeader(t.e2eeTransferToNewDevice),
          _buildTransferCard(
            context,
            icon: Icons.qr_code_scanner,
            title: t.e2eeTransferSendTitle,
            description: t.e2eeTransferSendDesc,
            onTap: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => const E2EETransferSendPage(),
                ),
              );
            },
          ),
          _buildTransferCard(
            context,
            icon: Icons.qr_code_2,
            title: t.e2eeTransferFromOldDevice,
            description: t.e2eeTransferReceiveDesc,
            onTap: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => const E2EETransferReceivePage(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(t.e2eeTransferPendingSection),
          _buildPendingTransfersCard(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildTransferCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(icon, size: 32, color: CupertinoColors.activeBlue),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(CupertinoIcons.forward, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildPendingTransfersCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: E2EETransferService.getPendingTransfers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CupertinoActivityIndicator()),
            );
          }

          if (snapshot.hasError) {
            return ListTile(
              title: Text(t.e2eeTransferLoadFailed),
              subtitle: Text(t.e2eeTransferLoadFailedDesc),
            );
          }

          final transfers = snapshot.data ?? [];

          if (transfers.isEmpty) {
            return ListTile(
              title: Text(t.e2eeTransferNoPending),
              subtitle: Text(t.e2eeTransferNoPendingDesc),
            );
          }

          return Column(
            children: transfers.map((transfer) {
              return ListTile(
                title: Text(t.e2eeTransferPendingItem),
                subtitle: Text(t.e2eeTransferPendingItemDesc),
                trailing: CupertinoButton(
                  child: Text(t.e2eeTransferView),
                  onPressed: () {
                    // 跳转到接收页面
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => E2EETransferReceivePage(
                          sessionId: transfer['session_id'],
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/page/settings/e2ee_transfer_send_page.dart';
import 'package:imboy/page/settings/e2ee_transfer_receive_page.dart';
import 'package:imboy/service/e2ee_transfer_service.dart';

/// E2EE 设备间传输入口页面
class E2EETransferPage extends StatelessWidget {
  const E2EETransferPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设备间传输')),
      body: ListView(
        children: [
          _buildSectionHeader('传输到新设备'),
          _buildTransferCard(
            context,
            icon: Icons.qr_code_scanner,
            title: '发送密钥到新设备',
            description: '通过二维码将密钥传输到新设备',
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
            title: '从旧设备接收密钥',
            description: '扫描旧设备二维码接收密钥',
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
          _buildSectionHeader('待处理的传输'),
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
            return const ListTile(
              title: Text('加载失败'),
              subtitle: Text('无法加载待处理的传输，请重试'),
            );
          }

          final transfers = snapshot.data ?? [];

          if (transfers.isEmpty) {
            return const ListTile(
              title: Text('暂无待处理的传输'),
              subtitle: Text('当有设备向您发送密钥时，会显示在这里'),
            );
          }

          return Column(
            children: transfers.map((transfer) {
              return ListTile(
                title: const Text('待处理的密钥传输'),
                subtitle: const Text('点击查看详情'),
                trailing: CupertinoButton(
                  child: const Text('查看'),
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

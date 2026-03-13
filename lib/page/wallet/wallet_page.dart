import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111111)
          : const Color(0xFFEDEDED),
      appBar: AppBar(
        title: Text(t.wallet),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {
              // TODO(后端对接): 钱包设置页面
              // 需要：
              // - 后端钱包 API 支持
              // - 支付系统集成
              // - 账单明细接口
              EasyLoading.showToast(t.comingSoon);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Balance Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              color: primaryColor,
              width: double.infinity,
              child: Column(
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    size: 56,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  // TODO(后端对接): 钱包余额需要从后端 API 获取
                  // 需要实现 GET /api/wallet/balance 接口
                  // 目前显示功能开发中提示
                  Text(
                    t.comingSoon,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.totalAssets,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),

            // Payment Functions Grid (Money, Cards)
            Container(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTopActionItem(
                    context,
                    icon: Icons.qr_code_scanner,
                    label: t.receivePayment,
                    color: primaryColor,
                    // TODO(后端对接): 收款功能需要后端支付系统集成
                    onTap: () {
                      EasyLoading.showToast(t.comingSoon);
                    },
                  ),
                  _buildTopActionItem(
                    context,
                    icon: Icons.account_balance,
                    label: t.smallChange,
                    color: Colors.orange,
                    // TODO(后端对接): 零钱余额需要从后端 API 获取
                    onTap: () {
                      EasyLoading.showToast(t.comingSoon);
                    },
                  ),
                  _buildTopActionItem(
                    context,
                    icon: Icons.credit_card,
                    label: t.bankCard,
                    color: Colors.blue,
                    // TODO(后端对接): 银行卡数量需要从后端 API 获取
                    onTap: () {
                      EasyLoading.showToast(t.comingSoon);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Service Grid Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    t.tencentService,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Services Grid
            Container(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 0,
                crossAxisSpacing: 0,
                childAspectRatio: 1.2,
                padding: EdgeInsets.zero,
                children: [
                  _buildGridServiceItem(
                    context,
                    icon: Icons.credit_score,
                    label: t.creditCardRepayment,
                    color: Colors.green,
                    onTap: () {
                      EasyLoading.showToast(t.comingSoon);
                    },
                  ),
                  _buildGridServiceItem(
                    context,
                    icon: Icons.mobile_friendly,
                    label: t.mobileRecharge,
                    color: Colors.green,
                    onTap: () {
                      EasyLoading.showToast(t.comingSoon);
                    },
                  ),
                  _buildGridServiceItem(
                    context,
                    icon: Icons.savings,
                    label: t.financialManagement,
                    color: Colors.orange,
                    onTap: () {
                      EasyLoading.showToast(t.comingSoon);
                    },
                  ),
                  _buildGridServiceItem(
                    context,
                    icon: Icons.bolt,
                    label: t.lifePayment,
                    color: Colors.green,
                    onTap: () {
                      EasyLoading.showToast(t.comingSoon);
                    },
                  ),
                  _buildGridServiceItem(
                    context,
                    icon: Icons.local_hospital,
                    label: t.medicalHealth,
                    color: Colors.blue,
                    onTap: () {
                      EasyLoading.showToast(t.comingSoon);
                    },
                  ),
                  _buildGridServiceItem(
                    context,
                    icon: Icons.directions_car,
                    label: t.traffic,
                    color: Colors.green,
                    onTap: () {
                      EasyLoading.showToast(t.comingSoon);
                    },
                  ),
                  _buildGridServiceItem(
                    context,
                    icon: Icons.shopping_bag,
                    label: t.jdShopping,
                    color: Colors.red,
                    onTap: () {
                      EasyLoading.showToast(t.comingSoon);
                    },
                  ),
                  _buildGridServiceItem(
                    context,
                    icon: Icons.local_mall,
                    label: t.meituanDelivery,
                    color: Colors.orange,
                    onTap: () {
                      EasyLoading.showToast(t.comingSoon);
                    },
                  ),
                  _buildGridServiceItem(
                    context,
                    icon: Icons.movie,
                    label: t.entertainment,
                    color: Colors.red,
                    onTap: () {
                      EasyLoading.showToast(t.comingSoon);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTopActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusSmall,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGridServiceItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: isDark
                    ? Colors.white10
                    : Colors.grey.withValues(alpha: 0.1),
                width: 0.5,
              ),
              bottom: BorderSide(
                color: isDark
                    ? Colors.white10
                    : Colors.grey.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

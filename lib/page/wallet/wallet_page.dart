import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/page/wallet/wallet_provider.dart'
    show WalletState, WalletTransaction, walletProvider;

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 页面初始化时加载余额和流水
    Future.microtask(() {
      ref.read(walletProvider.notifier).loadBalance();
      ref.read(walletProvider.notifier).loadTransactions();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      ref.read(walletProvider.notifier).loadMoreTransactions();
    }
  }

  /// 显示充值对话框
  void _showTopupDialog(BuildContext context) {
    final controller = TextEditingController();
    final t = context.t;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.account.rechargeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.account.rechargeAmountHint),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                prefixText: '¥ ',
                hintText: t.account.rechargeAmountExample,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.common.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final input = controller.text.trim();
              final yuan = double.tryParse(input);
              if (yuan == null || yuan < 1 || yuan > 10000) {
                EasyLoading.showError(t.common.rechargeAmountError);
                return;
              }
              final amountFen = (yuan * 100).round();
              Navigator.of(ctx).pop();
              final ok = await ref
                  .read(walletProvider.notifier)
                  .topup(amountFen);
              if (ok) {
                EasyLoading.showSuccess(t.common.rechargeSuccess);
              }
            },
            child: Text(t.common.rechargeConfirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;
    final walletState = ref.watch(walletProvider);

    // 格式化余额显示：¥ X.XX
    final balanceYuan = walletState.balance / 100.0;
    final balanceText = '¥ ${balanceYuan.toStringAsFixed(2)}';

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111111)
          : AppColors.lightSurfaceContainer,
      appBar: AppBar(
        title: Text(t.account.wallet),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: t.account.rechargeTitle,
            onPressed: () => _showTopupDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {
              EasyLoading.showToast(t.common.comingSoon);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(walletProvider.notifier).loadBalance();
          await ref.read(walletProvider.notifier).loadTransactions();
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
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
                    // 余额显示区域
                    walletState.isLoading
                        ? const SizedBox(
                            height: 36,
                            width: 36,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            balanceText,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                    const SizedBox(height: 8),
                    Text(
                      t.main.totalAssets,
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
                color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTopActionItem(
                      context,
                      icon: Icons.qr_code_scanner,
                      label: t.chat.receivePayment,
                      color: primaryColor,
                      onTap: () {
                        EasyLoading.showToast(t.common.comingSoon);
                      },
                    ),
                    _buildTopActionItem(
                      context,
                      icon: Icons.account_balance,
                      label: t.common.smallChange,
                      color: Colors.orange,
                      // 零钱和余额共用同一数据
                      subtitle: walletState.isLoading ? '...' : balanceText,
                      onTap: () {
                        EasyLoading.showToast(t.common.comingSoon);
                      },
                    ),
                    _buildTopActionItem(
                      context,
                      icon: Icons.credit_card,
                      label: t.chat.bankCard,
                      color: Colors.blue,
                      onTap: () {
                        EasyLoading.showToast(t.common.comingSoon);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Service Grid Title
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Text(
                      t.main.tencentService,
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
                color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
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
                      label: t.common.creditCardRepayment,
                      color: Colors.green,
                      onTap: () {
                        EasyLoading.showToast(t.common.comingSoon);
                      },
                    ),
                    _buildGridServiceItem(
                      context,
                      icon: Icons.mobile_friendly,
                      label: t.account.mobileRecharge,
                      color: Colors.green,
                      onTap: () {
                        EasyLoading.showToast(t.common.comingSoon);
                      },
                    ),
                    _buildGridServiceItem(
                      context,
                      icon: Icons.savings,
                      label: t.group.financialManagement,
                      color: Colors.orange,
                      onTap: () {
                        EasyLoading.showToast(t.common.comingSoon);
                      },
                    ),
                    _buildGridServiceItem(
                      context,
                      icon: Icons.bolt,
                      label: t.main.lifePayment,
                      color: Colors.green,
                      onTap: () {
                        EasyLoading.showToast(t.common.comingSoon);
                      },
                    ),
                    _buildGridServiceItem(
                      context,
                      icon: Icons.local_hospital,
                      label: t.main.medicalHealth,
                      color: Colors.blue,
                      onTap: () {
                        EasyLoading.showToast(t.common.comingSoon);
                      },
                    ),
                    _buildGridServiceItem(
                      context,
                      icon: Icons.directions_car,
                      label: t.main.traffic,
                      color: Colors.green,
                      onTap: () {
                        EasyLoading.showToast(t.common.comingSoon);
                      },
                    ),
                    _buildGridServiceItem(
                      context,
                      icon: Icons.shopping_bag,
                      label: t.chat.jdShopping,
                      color: Colors.red,
                      onTap: () {
                        EasyLoading.showToast(t.common.comingSoon);
                      },
                    ),
                    _buildGridServiceItem(
                      context,
                      icon: Icons.local_mall,
                      label: t.main.meituanDelivery,
                      color: Colors.orange,
                      onTap: () {
                        EasyLoading.showToast(t.common.comingSoon);
                      },
                    ),
                    _buildGridServiceItem(
                      context,
                      icon: Icons.movie,
                      label: t.main.entertainment,
                      color: Colors.red,
                      onTap: () {
                        EasyLoading.showToast(t.common.comingSoon);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 流水记录
              _buildTransactionSection(context, walletState, isDark),

              if (walletState.isTxLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionSection(
    BuildContext context,
    WalletState walletState,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.common.transactionHistory2,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Container(
          color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
          child: walletState.transactions.isEmpty && !walletState.isTxLoading
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      t.common.noTransactionHistory,
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    ...walletState.transactions.map(
                      (tx) => _buildTransactionTile(tx, isDark),
                    ),
                    if (!walletState.txHasMore &&
                        walletState.transactions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          t.common.allLoaded,
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(WalletTransaction tx, bool isDark) {
    final amountYuan = (tx.amount.abs() / 100.0).toStringAsFixed(2);
    final amountText = tx.isIncome ? '+¥$amountYuan' : '-¥$amountYuan';
    final amountColor = tx.isIncome ? Colors.green : Colors.red;
    final typeLabel = tx.isIncome
        ? t.common.transactionTypeIncome
        : t.common.transactionTypeExpense;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: tx.isIncome
              ? Colors.green.withValues(alpha: 0.12)
              : Colors.red.withValues(alpha: 0.12),
          child: Icon(
            tx.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: amountColor,
            size: 18,
          ),
        ),
        title: Text(
          tx.remark.isNotEmpty ? tx.remark : typeLabel,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          tx.createdAt,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.grey,
          ),
        ),
        trailing: Text(
          amountText,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: amountColor,
          ),
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

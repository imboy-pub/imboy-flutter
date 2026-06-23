import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/service/payment_launcher.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/wallet/wallet_provider.dart'
    show WalletState, WalletTransaction, walletProvider;

/// 钱包页面 - 极致 iOS 17 Premium 风格重构
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

  void _showTopupDialog(BuildContext context) {
    final controller = TextEditingController();
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.account.rechargeTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Text(
                t.account.rechargeAmountHint,
                style: context.textStyle(FontSizeType.footnote),
              ),
              AppSpacing.verticalMedium,
              CupertinoTextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                prefix: Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    '¥',
                    style: context.textStyle(
                      FontSizeType.body,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                placeholder: t.account.rechargeAmountExample,
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.common.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final input = controller.text.trim();
              final yuan = double.tryParse(input);
              if (yuan == null || yuan < 1 || yuan > 10000) {
                EasyLoading.showError(t.common.rechargeAmountError);
                return;
              }
              final amountFen = (yuan * 100).round();
              Navigator.of(ctx).pop();
              _showPayMethodSheet(amountFen);
            },
            child: Text(t.common.rechargeConfirm),
          ),
        ],
      ),
    );
  }

  /// 金额确认后弹出支付方式选择。
  /// mock 走开发即时入账链路；支付宝/微信暂未接入 SDK，提示即将开通（待 S4）。
  void _showPayMethodSheet(int amountFen) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(t.account.payMethodTitle),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _doRecharge(amountFen, 'mock');
            },
            child: Text(t.account.payMethodMock),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _doRecharge(amountFen, 'alipay');
            },
            child: Text(t.account.payMethodAlipay),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _doRecharge(amountFen, 'wechat');
            },
            child: Text(t.account.payMethodWechat),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.common.cancel),
        ),
      ),
    );
  }

  /// 钱包更多操作菜单。当前仅「提现」一项（后端 withdraw 已就绪，此前钱包
  /// 首页无任何入口可达 withdraw_page，本菜单为其收口）。
  void _showMoreSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/wallet/withdraw');
            },
            child: Text(t.common.withdraw),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.common.cancel),
        ),
      ),
    );
  }

  /// 执行充值：创建订单 → 拉起支付（mock 即时入账 / 第三方唤起收银台）→ 轮询
  /// → 刷新余额。失败时按第三方唤起结果差异化提示。
  Future<void> _doRecharge(int amountFen, String method) async {
    EasyLoading.show(status: t.main.payingDots);
    final ok = await ref
        .read(walletProvider.notifier)
        .recharge(amountFen, paymentMethod: method);
    EasyLoading.dismiss();
    if (ok) {
      EasyLoading.showSuccess(t.common.rechargeSuccess);
      return;
    }
    switch (ref.read(walletProvider).lastLaunchResult) {
      case PaymentLaunchResult.notConfigured:
        EasyLoading.showToast(t.account.payMethodComingSoon);
      case PaymentLaunchResult.cancelled:
        EasyLoading.showToast(t.account.payCancelled);
      case PaymentLaunchResult.failed:
      case PaymentLaunchResult.success:
      case null:
        EasyLoading.showError(t.common.purchaseFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final balanceYuan = walletState.balance / 100.0;
    final balanceText = '¥ ${balanceYuan.toStringAsFixed(2)}';

    return IosPageTemplate(
      title: t.account.wallet,
      useLargeTitle: false,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add_circled, size: 22),
          onPressed: () => _showTopupDialog(context),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
          onPressed: () => _showMoreSheet(context),
        ),
      ],
      backgroundColor: isDark
          ? AppColors.darkSurfaceGrouped
          : AppColors.lightSurfaceGrouped,
      child: Column(
        children: [
          // 余额卡片 - 采用 Premium 悬浮质感
          _buildBalanceCard(
            context,
            walletState,
            balanceText,
            isDark,
            brightness,
          ),

          // 核心功能区
          _buildActionGrid(
            context,
            walletState,
            balanceText,
            isDark,
            brightness,
          ),

          // 服务推荐 Section
          ImBoySettingsSection(
            header: Text(t.main.tencentService.toUpperCase()),
            children: [_buildServiceGrid(context, isDark, brightness)],
          ),

          // 交易流水 Section
          _buildTransactionSection(context, walletState, isDark, brightness),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    WalletState state,
    String balance,
    bool isDark,
    Brightness b,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        width: double.infinity,
        padding: AppSpacing.allXLarge,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    AppColors.walletCardGradientDarkStart,
                    AppColors.walletCardGradientDarkEnd,
                  ]
                : [AppColors.primary, AppColors.walletCardGradientLightEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.lightTextPrimary.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              CupertinoIcons.money_yen_circle_fill,
              size: 48,
              color: AppColors.onPrimary.withValues(alpha: 0.7),
            ),
            AppSpacing.verticalRegular,
            Text(
              t.main.totalAssets,
              style: context.textStyle(
                FontSizeType.normal,
                color: AppColors.onPrimary.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            AppSpacing.verticalSmall,
            state.isLoading
                ? const CupertinoActivityIndicator(color: AppColors.onPrimary)
                : Text(
                    balance,
                    style: context
                        .textStyle(
                          FontSizeType.extraLargeTitle,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onPrimary,
                        )
                        .copyWith(letterSpacing: -1),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(
    BuildContext context,
    WalletState state,
    String balance,
    bool isDark,
    Brightness b,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildActionItem(
            context,
            CupertinoIcons.qrcode_viewfinder,
            t.chat.receivePayment,
            AppColors.iosPurple,
            isDark,
          ),
          AppSpacing.horizontalMedium,
          _buildActionItem(
            context,
            CupertinoIcons.money_yen,
            t.common.smallChange,
            AppColors.iosOrange,
            isDark,
            subtitle: state.isLoading ? '...' : balance,
          ),
          AppSpacing.horizontalMedium,
          _buildActionItem(
            context,
            CupertinoIcons.creditcard,
            t.chat.bankCard,
            AppColors.iosBlue,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    bool isDark, {
    String? subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceGroupedTertiary
              : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            AppSpacing.verticalSmall,
            Text(
              label,
              style: context.textStyle(
                FontSizeType.footnote,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: context.textStyle(
                  FontSizeType.caption2,
                  color: AppColors.iosGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceGrid(BuildContext context, bool isDark, Brightness b) {
    final services = [
      {
        'icon': CupertinoIcons.creditcard_fill,
        'label': t.common.creditCardRepayment,
        'color': AppColors.iosGreen,
      },
      {
        'icon': CupertinoIcons.phone_fill,
        'label': t.account.mobileRecharge,
        'color': AppColors.iosSkyBlue,
      },
      {
        'icon': CupertinoIcons.briefcase_fill,
        'label': t.group.financialManagement,
        'color': AppColors.iosOrange,
      },
      {
        'icon': CupertinoIcons.bolt_fill,
        'label': t.main.lifePayment,
        'color': AppColors.iosYellow,
      },
      {
        'icon': CupertinoIcons.heart_fill,
        'label': t.main.medicalHealth,
        'color': AppColors.iosPink,
      },
      {
        'icon': CupertinoIcons.car_fill,
        'label': t.main.traffic,
        'color': AppColors.iosBlue,
      },
    ];

    return Container(
      padding: AppSpacing.allSmall,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.1,
        ),
        itemCount: services.length,
        itemBuilder: (context, i) {
          final s = services[i];
          return CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => EasyLoading.showToast(t.common.comingSoon),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  s['icon'] as IconData,
                  size: 26,
                  color: s['color'] as Color,
                ),
                AppSpacing.verticalSmall,
                Text(
                  s['label'] as String,
                  style: context.textStyle(
                    FontSizeType.small,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionSection(
    BuildContext context,
    WalletState state,
    bool isDark,
    Brightness b,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 16, 8),
          child: Text(
            t.common.transactionHistory2.toUpperCase(),
            style: context.textStyle(
              FontSizeType.footnote,
              fontWeight: FontWeight.w600,
              color: AppColors.iosGray,
            ),
          ),
        ),
        if (state.transactions.isEmpty && !state.isTxLoading)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(
                t.common.noTransactionHistory,
                style: const TextStyle(color: AppColors.iosGray),
              ),
            ),
          )
        else
          ImBoySettingsSection(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            children: state.transactions
                .map((tx) => _buildTransactionTile(tx, isDark, b))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildTransactionTile(
    WalletTransaction tx,
    bool isDark,
    Brightness b,
  ) {
    final amountYuan = (tx.amount.abs() / 100.0).toStringAsFixed(2);
    final amountText = tx.isIncome ? '+¥$amountYuan' : '-¥$amountYuan';
    final amountColor = tx.isIncome
        ? AppColors.getIosGreen(b)
        : AppColors.getIosRed(b);

    return ImBoyListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: amountColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          tx.isIncome ? CupertinoIcons.arrow_down : CupertinoIcons.arrow_up,
          color: amountColor,
          size: 18,
        ),
      ),
      title: Text(
        tx.remark.isNotEmpty
            ? tx.remark
            : (tx.isIncome
                  ? t.common.transactionTypeIncome
                  : t.common.transactionTypeExpense),
      ),
      subtitle: Text(tx.createdAt),
      trailing: Text(
        amountText,
        style: TextStyle(
          fontSize: FontSizeType.body.size,
          fontWeight: FontWeight.bold,
          color: amountColor,
          letterSpacing: -0.5,
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }
}

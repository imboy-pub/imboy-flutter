import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

enum AlipaySimStep {
  selectMethod,
  confirmPay,
  pinVerification,
  alipaySuccess,
  merchantSuccess,
}

/// A highly polished, interactive 5-screen simulated Alipay payment checkout flow.
class AlipaySimulator extends StatefulWidget {
  final double amountYuan;
  final String? merchantName;

  const AlipaySimulator({
    super.key,
    required this.amountYuan,
    this.merchantName,
  });

  static Future<bool?> show(
    BuildContext context, {
    required double amountYuan,
    String? merchantName,
  }) {
    return Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            AlipaySimulator(amountYuan: amountYuan, merchantName: merchantName),
      ),
    );
  }

  @override
  State<AlipaySimulator> createState() => _AlipaySimulatorState();
}

class _AlipaySimulatorState extends State<AlipaySimulator> {
  AlipaySimStep _currentStep = AlipaySimStep.selectMethod;
  String _pin = '';
  bool _isProcessingPin = false;

  void _onKeyPress(String key) {
    if (_isProcessingPin) return;
    if (key == 'backspace') {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
        });
      }
    } else {
      if (_pin.length < 6) {
        setState(() {
          _pin += key;
        });
        if (_pin.length == 6) {
          _processPin();
        }
      }
    }
  }

  Future<void> _processPin() async {
    setState(() {
      _isProcessingPin = true;
    });
    // Brief processing animation for realism
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() {
        _isProcessingPin = false;
        _currentStep = AlipaySimStep.alipaySuccess;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Underlying backdrop dim/tint
          _buildBackdrop(),

          // Step UI switch
          Positioned.fill(child: SafeArea(child: _buildStepContent(t, isDark))),
        ],
      ),
    );
  }

  Widget _buildBackdrop() {
    switch (_currentStep) {
      case AlipaySimStep.selectMethod:
      case AlipaySimStep.confirmPay:
      case AlipaySimStep.pinVerification:
        return Container(color: AppColors.alipaySimBackdropColor);
      case AlipaySimStep.alipaySuccess:
        return Container(color: AppColors.alipaySimBlue); // Alipay Success Blue
      case AlipaySimStep.merchantSuccess:
        return Container(
          color: AppColors.alipaySimKeypadDarkBg,
        ); // Merchant Success Dark grey
    }
  }

  Widget _buildStepContent(Translations t, bool isDark) {
    switch (_currentStep) {
      case AlipaySimStep.selectMethod:
        return _buildSelectMethodStep(t, isDark);
      case AlipaySimStep.confirmPay:
        return _buildConfirmPayStep(t, isDark);
      case AlipaySimStep.pinVerification:
        return _buildPinVerificationStep(t, isDark);
      case AlipaySimStep.alipaySuccess:
        return _buildAlipaySuccessStep(t, isDark);
      case AlipaySimStep.merchantSuccess:
        return _buildMerchantSuccessStep(t, isDark);
    }
  }

  // --- Step 1: Select Payment Method Sheet ---
  Widget _buildSelectMethodStep(Translations t, bool isDark) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: isDark
            ? AppColors.alipaySimDarkOverlay
            : AppColors.alipaySimLightOverlay,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title & Close Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32),
                  Text(
                    t.account.alipaySim.selectMethod,
                    style: TextStyle(
                      fontSize: FontSizeType.body.size,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.lightSurface
                          : AppColors.lightTextPrimary.withValues(alpha: 0.87),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Alipay row (Selected)
            ListTile(
              leading: const Icon(
                Icons.payment,
                color: AppColors.alipaySimBlue,
                size: 28,
              ),
              title: Text(
                t.account.payMethodAlipay,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: FontSizeType.medium.size,
                ),
              ),
              trailing: const Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: AppColors.alipaySimBlue,
                size: 24,
              ),
              onTap: () {},
            ),
            const Divider(height: 1, indent: 56),

            // Huabei row
            ListTile(
              leading: const Icon(
                Icons.credit_card,
                color: AppColors.alipaySimSuccessGreen,
                size: 28,
              ),
              title: Text(
                t.account.alipaySim.huabei,
                style: TextStyle(
                  color: isDark
                      ? AppColors.alipaySimTextGrey
                      : AppColors.slateText,
                  fontSize: FontSizeType.medium.size,
                ),
              ),
              trailing: Icon(
                CupertinoIcons.circle,
                color: isDark ? AppColors.iosGray3Dark : AppColors.iosGray2,
                size: 24,
              ),
              onTap: () {},
            ),

            const SizedBox(height: 24),

            // Confirm Red Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors
                        .alipaySimRed, // Alipay Red confirmation button style
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    setState(() {
                      _currentStep = AlipaySimStep.confirmPay;
                    });
                  },
                  child: Text(
                    t.common.confirm,
                    style: TextStyle(
                      color: AppColors.lightSurface,
                      fontSize: FontSizeType.medium.size,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // --- Step 2: Confirm Payment Bottom Sheet ---
  Widget _buildConfirmPayStep(Translations t, bool isDark) {
    final storeName = widget.merchantName ?? t.account.alipaySim.storeName;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: isDark
            ? AppColors.alipaySimDarkOverlay
            : AppColors.alipaySimLightOverlay,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close & Password text link Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    onPressed: () {
                      setState(() {
                        _currentStep = AlipaySimStep.selectMethod;
                      });
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _currentStep = AlipaySimStep.pinVerification;
                      });
                    },
                    child: const Text(
                      '使用密码',
                      style: TextStyle(
                        color: AppColors.alipaySimBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Merchant / Store Info
            const SizedBox(height: 8),
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.alipaySimBlue.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.store,
                color: AppColors.alipaySimBlue,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              storeName,
              style: TextStyle(
                fontSize: FontSizeType.medium.size,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.alipaySimTextWhite70
                    : AppColors.lightTextPrimary.withValues(alpha: 0.87),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¥ ${widget.amountYuan.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: FontSizeType.extraLargeTitle.size * 1.3,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.lightSurface
                    : AppColors.darkBackground,
              ),
            ),
            const SizedBox(height: 24),

            // Account Balance detail row
            ListTile(
              leading: const Icon(
                CupertinoIcons.creditcard,
                color: AppColors.alipaySimBlue,
              ),
              title: Text(t.account.alipaySim.balanceSource),
              trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
            ),
            const Divider(height: 1),

            // Green Energy banner
            Container(
              width: double.infinity,
              color: AppColors.alipaySimEnergyBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.energy_savings_leaf,
                    color: AppColors.alipaySimSuccessGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.account.alipaySim.energy,
                      style: TextStyle(
                        color: AppColors.alipaySimEnergyGreen,
                        fontSize: FontSizeType.footnote.size,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Blue Confirm button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.alipaySimBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    setState(() {
                      _currentStep = AlipaySimStep.pinVerification;
                    });
                  },
                  child: Text(
                    t.account.alipaySim.confirmPay,
                    style: TextStyle(
                      color: AppColors.lightSurface,
                      fontSize: FontSizeType.medium.size,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // --- Step 3: Enter Payment Password ---
  Widget _buildPinVerificationStep(Translations t, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Upper Dialog Box
        Expanded(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.alipaySimDarkOverlay
                    : AppColors.alipaySimLightOverlay,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 4,
                    left: 4,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        setState(() {
                          _pin = '';
                          _currentStep = AlipaySimStep.confirmPay;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          t.account.alipaySim.enterPassword,
                          style: TextStyle(
                            fontSize: FontSizeType.large.size,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${t.account.alipaySim.paymentAmount}${widget.amountYuan.toStringAsFixed(2)}${t.account.wallet == '钱包' ? '元' : ' CNY'}',
                          style: TextStyle(
                            fontSize: FontSizeType.normal.size,
                            color: AppColors.alipaySimTextGrey,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 6 Pin boxes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(6, (index) {
                            final showDot = index < _pin.length;
                            return Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.iosGray3Dark
                                      : AppColors.iosGray5,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: showDot
                                    ? Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isDark
                                              ? AppColors.lightSurface
                                              : AppColors.darkBackground,
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          }),
                        ),

                        if (_isProcessingPin) ...[
                          const SizedBox(height: 20),
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.alipaySimBlue,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Custom Numeric Keypad at the bottom
        Container(
          color: isDark ? AppColors.darkBackground : AppColors.alipaySimGreyBg,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildKeypadRow(['1', '2', '3']),
              _buildKeypadRow(['4', '5', '6']),
              _buildKeypadRow(['7', '8', '9']),
              _buildKeypadRow(['', '0', 'backspace']),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        if (key.isEmpty) {
          return Expanded(child: Container());
        }
        final isBackspace = key == 'backspace';
        return Expanded(
          child: InkWell(
            onTap: () => _onKeyPress(key),
            child: Container(
              margin: const EdgeInsets.all(4),
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.alipaySimDarkOverlay
                    : AppColors.alipaySimLightOverlay,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.darkBackground.withValues(alpha: 0.12),
                    offset: const Offset(0, 1),
                    blurRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: isBackspace
                    ? const Icon(CupertinoIcons.delete_left, size: 20)
                    : Text(
                        key,
                        style: TextStyle(
                          fontSize: FontSizeType.title.size,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- Step 4: Alipay Payment Success Screen ---
  Widget _buildAlipaySuccessStep(Translations t, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Upper success confirmation details
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.lightSurface,
                ),
                child: const Icon(
                  Icons.check,
                  color: AppColors.alipaySimBlue,
                  size: 42,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t.account.alipaySim.alipaySuccess,
                style: TextStyle(
                  color: AppColors.lightSurface,
                  fontSize: FontSizeType.extraLarge.size,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '¥ ${widget.amountYuan.toStringAsFixed(2)}',
                style: TextStyle(
                  color: AppColors.lightSurface,
                  fontSize: FontSizeType.extraLargeTitle.size * 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),

              // Details block card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildSuccessDetailRow(
                      widget.merchantName ?? t.account.alipaySim.storeName,
                      '¥ ${widget.amountYuan.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 12),
                    _buildSuccessDetailRow('交易方式', '余额'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Done button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightSurface,
                foregroundColor: AppColors.alipaySimBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: () {
                setState(() {
                  _currentStep = AlipaySimStep.merchantSuccess;
                });
              },
              child: Text(
                '完成',
                style: TextStyle(
                  fontSize: FontSizeType.medium.size,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.alipaySimTextWhite70,
            fontSize: FontSizeType.normal.size,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.lightSurface,
            fontSize: FontSizeType.normal.size,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --- Step 5: Merchant APP Success Screen ---
  Widget _buildMerchantSuccessStep(Translations t, bool isDark) {
    return Column(
      children: [
        // Upper merchant mock space
        Expanded(
          child: Container(
            color: isDark
                ? AppColors.darkBackground
                : AppColors.lightSurfaceContainer,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 48),
                Text(
                  '交易剩余时间 29:43',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.alipaySimTextGrey
                        : AppColors.slateText,
                    fontSize: FontSizeType.footnote.size,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '¥ ${widget.amountYuan.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: FontSizeType.extraLargeTitle.size * 1.15,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.lightSurface
                        : AppColors.lightTextPrimary.withValues(alpha: 0.87),
                  ),
                ),
                const Spacer(),

                // Slide up White Success Card inside Merchant App
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.alipaySimDarkOverlay
                        : AppColors.alipaySimLightOverlay,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.darkBackground.withValues(alpha: 0.12),
                        offset: const Offset(0, 4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.alipaySimSuccessGreen,
                        size: 54,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '支付成功  ¥ ${widget.amountYuan.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: FontSizeType.large.size,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.payment,
                            size: 16,
                            color: AppColors.alipaySimBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.account.payMethodAlipay,
                            style: TextStyle(
                              color: AppColors.alipaySimTextGrey,
                              fontSize: FontSizeType.footnote.size,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // Red prominent Done button inside Merchant App
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors
                                .alipaySimRed, // Red merchant completion button
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(true);
                          },
                          child: Text(
                            '完成',
                            style: TextStyle(
                              color: AppColors.lightSurface,
                              fontSize: FontSizeType.medium.size,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

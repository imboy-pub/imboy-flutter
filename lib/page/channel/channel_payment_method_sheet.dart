import 'package:flutter/cupertino.dart';

import 'package:imboy/i18n/strings.g.dart';

/// 付费频道购买的支付方式选择。
///
/// 返回选中的支付方式：`wallet`（钱包余额，可用）/ `alipay` / `wechat`；
/// 用户取消返回 `null`。第三方（支付宝/微信）SDK 待 S4 接入，调用方应在
/// 收到 `alipay`/`wechat` 时提示"即将开通"。
///
/// [walletBalanceText] 钱包余额展示文案（如 `¥12.00`），为空则不展示。
Future<String?> showChannelPaymentMethodSheet(
  BuildContext context, {
  String? walletBalanceText,
}) {
  final t = context.t;
  final walletLabel = walletBalanceText == null
      ? t.account.payMethodWallet
      : '${t.account.payMethodWallet}  $walletBalanceText';

  return showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(t.account.payMethodTitle),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop('wallet'),
          child: Text(walletLabel),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop('alipay'),
          child: Text(t.account.payMethodAlipay),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop('wechat'),
          child: Text(t.account.payMethodWechat),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(ctx).pop(),
        child: Text(t.common.cancel),
      ),
    ),
  );
}

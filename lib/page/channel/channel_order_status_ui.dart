import 'package:flutter/material.dart';

import 'package:imboy/store/model/channel_order_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 订单状态 → (本地化标签, 语义色)。频道订单列表与详情页共用。
(String, Color) channelOrderStatusStyle(int status, Translations t) =>
    switch (status) {
      ChannelOrderStatus.paid => (t.channel.orderStatusPaid, AppColors.success),
      ChannelOrderStatus.pending => (
        t.channel.orderStatusPending,
        AppColors.warning,
      ),
      ChannelOrderStatus.refunded => (
        t.channel.orderStatusRefunded,
        AppColors.iosRed,
      ),
      ChannelOrderStatus.cancelled => (
        t.channel.orderStatusCancelled,
        AppColors.slateText,
      ),
      ChannelOrderStatus.expired => (
        t.channel.orderStatusExpired,
        AppColors.slateText,
      ),
      _ => (t.channel.orderStatusPending, AppColors.slateText),
    };

import 'package:flutter/cupertino.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// BUG#119：消息存在但归档历史不可取时的可见状态，保留重试入口。
class ChatHistoryUnavailableView extends StatelessWidget {
  const ChatHistoryUnavailableView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.clock, size: 48, color: AppColors.textSecondary),
          SizedBox(height: AppSpacing.small),
          Text(
            t.chat.historyUnavailable,
            style: TextStyle(
              fontSize: FontSizeType.normal.size,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: AppSpacing.tiny),
          Text(
            t.chat.historyUnavailableHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: FontSizeType.small.size,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: AppSpacing.medium),
          CupertinoButton(
            onPressed: onRetry,
            child: Text(t.common.buttonRetry),
          ),
        ],
      ),
    );
  }
}

/// BUG#119：归档历史回填失败的状态，与服务端确认无数据的空态区分。
class ChatHistorySyncFailedView extends StatelessWidget {
  const ChatHistorySyncFailedView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle,
            size: 48,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: AppSpacing.small),
          Text(
            t.chat.pleaseTryAgainLater,
            style: TextStyle(
              fontSize: FontSizeType.normal.size,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: AppSpacing.medium),
          CupertinoButton(
            onPressed: onRetry,
            child: Text(t.common.buttonRetry),
          ),
        ],
      ),
    );
  }
}

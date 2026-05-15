import 'package:flutter/material.dart';
import 'package:imboy/component/helper/user_online_time_helper.dart';
import 'package:imboy/i18n/strings.g.dart';

class UserOnlineStatusWidget extends StatelessWidget {
  final bool isOnline;
  final int? lastSeenTimestamp;
  final bool hideOnlineStatus;
  final String? nickname;
  final TextStyle? textStyle;
  final double? indicatorSize;

  const UserOnlineStatusWidget({
    super.key,
    required this.isOnline,
    this.lastSeenTimestamp,
    this.hideOnlineStatus = false,
    this.nickname,
    this.textStyle,
    this.indicatorSize = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final status = UserOnlineTimeHelper.calculateOnlineStatus(
      isOnline: isOnline,
      lastSeenTimestamp: lastSeenTimestamp,
      hideOnlineStatus: hideOnlineStatus,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusIndicator(status, context),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _getStatusText(status),
            style:
                textStyle ??
                Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: UserOnlineTimeHelper.getStatusColor(
                    status.status,
                    context,
                  ),
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(UserOnlineStatus status, BuildContext context) {
    final color = UserOnlineTimeHelper.getStatusColor(status.status, context);

    return Container(
      width: indicatorSize,
      height: indicatorSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }

  String _getStatusText(UserOnlineStatus status) {
    if (nickname != null && status.isOnline) {
      return '${nickname!} ${status.statusText}';
    }
    return status.statusText ?? '';
  }
}

class UserOnlineStatusDetailWidget extends StatelessWidget {
  final bool isOnline;
  final int? lastSeenTimestamp;
  final bool hideOnlineStatus;

  const UserOnlineStatusDetailWidget({
    super.key,
    required this.isOnline,
    this.lastSeenTimestamp,
    this.hideOnlineStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = UserOnlineTimeHelper.calculateOnlineStatus(
      isOnline: isOnline,
      lastSeenTimestamp: lastSeenTimestamp,
      hideOnlineStatus: hideOnlineStatus,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: UserOnlineTimeHelper.getStatusColor(
                  status.status,
                  context,
                ),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status.statusText ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: UserOnlineTimeHelper.getStatusColor(
                    status.status,
                    context,
                  ),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        if (status.lastSeenAt != null && !status.isOnline) ...[
          const SizedBox(height: 4),
          Text(
            t.main.lastSeenExactTime(
              param: UserOnlineTimeHelper.formatExactTime(status.lastSeenAt!),
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ],
    );
  }
}

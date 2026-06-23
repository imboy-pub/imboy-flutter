/// channel_detail_page 纯决策函数
///
/// 从 channel_detail_page.dart 提取的零依赖纯函数，
/// 便于单元测试和跨 widget 复用。
library;

import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/component/helper/datetime.dart';

/// CD-1 付费频道是否处于锁定状态
///
/// 满足全部条件时返回 true：
///   1. channel 不为 null
///   2. type == ChannelType.paid
///   3. 未订阅（!isSubscribed）
///   4. 非管理员（!isManaged，即 userRole 不是 admin/creator）
bool isPaidChannelLocked(ChannelModel? channel) {
  if (channel == null) return false;
  return channel.type == ChannelType.paid &&
      !channel.isSubscribed &&
      !channel.isManaged;
}

/// CD-2 消息列表中 index 位置是否需要显示日期分割线
///
/// 规则：
///   - index == 0 → 始终显示
///   - 当前消息与前一条消息日期（年/月/日）不同 → 显示
///   - 其余 → 不显示
bool shouldShowDateDivider(List<ChannelMessageModel> messages, int index) {
  if (index == 0) return true;

  final current = messages[index];
  final previous = messages[index - 1];

  final currentDate = DateTime(
    current.createdAt.year,
    current.createdAt.month,
    current.createdAt.day,
  );
  final previousDate = DateTime(
    previous.createdAt.year,
    previous.createdAt.month,
    previous.createdAt.day,
  );

  return currentDate != previousDate;
}

/// CD-3 大数字格式化（K / M）
///
/// - < 1000 → 原始字符串
/// - < 1,000,000 → "x.xK"
/// - >= 1,000,000 → "x.xM"
String formatChannelNumber(int number) {
  if (number < 1000) return number.toString();
  if (number < 1000000) return '${(number / 1000).toStringAsFixed(1)}K';
  return '${(number / 1000000).toStringAsFixed(1)}M';
}

/// CD-4 字节数格式化（B / KB / MB / GB）
///
/// - < 1024 → "x B"
/// - < 1024^2 → "x.x KB"
/// - < 1024^3 → "x.x MB"
/// - >= 1024^3 → "x.x GB"
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// CD-5 消息相对时间格式化
///
/// 以 [now]（默认 `DateTime.now()`）为参考点：
///   - diff < 60 分钟  → "${diff.inMinutes}m ago"
///   - diff < 24 小时  → "${diff.inHours}h ago"
///   - diff < 7 天     → "${diff.inDays}d ago"
///   - 其余            → "MM-dd HH:mm"（intl DateFormat）
///
/// 注入 [now] 参数便于单元测试时固定时间基准，生产调用方可省略。
String formatMessageTime(DateTime time, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(time);

  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateTimeHelper.dateTimeFmt(
    time,
    pattern: 'MM-dd HH:mm',
    relative: false,
  );
}

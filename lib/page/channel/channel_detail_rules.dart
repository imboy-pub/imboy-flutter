/// channel_detail_page 纯决策函数
///
/// 从 channel_detail_page.dart 提取的零依赖纯函数，
/// 便于单元测试和跨 widget 复用。
library;

import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';

String? channelTargetId(ChannelModel? channel, String target) {
  if (channel == null || channel.id == '0') return null;
  final id = channel.id.toString();
  return target == id || target == channel.customId ? id : null;
}

/// 叠页归属过滤（J07）：多个页面/组件共享单一全局详情 provider 时，
/// 判定 [observed] 是否属于 [target]——频道匹配、正在为首载请求该目标，
/// 或全局仍为初始空态（尚未承载任何目标）。
bool channelDetailOwnsTarget(
  ChannelDetailState observed,
  String? requested,
  String target,
) {
  if (channelTargetId(observed.channel, target) != null) return true;
  if (requested != null) return requested == target;
  return observed.channel == null;
}

/// 归属过滤渲染：全局状态不属于 [target] 时改用该目标的最近快照，
/// 均无则退加载态，绝不渲染其他目标的内容。
ChannelDetailState ownChannelDetailState(
  ChannelDetailState observed,
  String? requested,
  String target,
  ChannelDetailState? snapshot,
) {
  if (channelDetailOwnsTarget(observed, requested, target)) return observed;
  return snapshot ?? const ChannelDetailState(isLoading: true);
}

/// CD-1 付费频道是否处于锁定状态
///
/// 满足全部条件时返回 true：
///   1. channel 不为 null
///   2. access_type == 1（付费）
///   3. 未购买（!hasPurchased）；订阅关系不能替代付费订单
///   4. 非管理员（!isManaged，即 userRole 不是 admin/creator）
bool isPaidChannelLocked(ChannelModel? channel) {
  if (channel == null) return false;
  if (!channel.hasSupportedAccessPolicy) return !channel.isManaged;
  return channel.accessType == 1 && !channel.hasPurchased && !channel.isManaged;
}

/// CD-1b 空消息流是否可以按”有权限但暂无内容”展示。
///
/// 公共频道沿用客户端的访客关注引导；私有频道需要订阅；付费频道
/// 只认购买订单，不能用历史订阅关系替代购买权益。
bool hasChannelContentAccess(ChannelModel? channel) {
  if (channel == null || channel.isManaged) return false;
  if (!channel.hasSupportedAccessPolicy) return false;
  if (channel.accessType == 1) return channel.hasPurchased;
  if (channel.visibility == 1) return channel.isSubscribed;
  return channel.isSubscribed || channel.hasPurchased;
}

/// CD-2 消息列表中 index 位置是否需要显示日期分割线
///
/// 规则：
///   - index == 0 → 始终显示
///   - 当前消息与前一条消息日期（年/月/日）不同 → 显示
///   - 其余 → 不显示
bool shouldShowDateDivider(List<ChannelMessageModel> messages, int index) {
  if (index == 0) return true;

  final current = messages[index].createdAt.toLocal();
  final previous = messages[index - 1].createdAt.toLocal();
  final currentDate = DateTime.utc(current.year, current.month, current.day);
  final previousDate = DateTime.utc(
    previous.year,
    previous.month,
    previous.day,
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

/// 频道日期标签；now 可注入以验证跨午夜及夏令时边界。
String formatChannelDateDivider(
  DateTime time,
  Translations t, {
  DateTime? now,
}) {
  final local = time.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  // UTC 在这里仅承载本地年月日，避免用 23/25 小时的真实日长推算日历差。
  final day = DateTime.utc(local.year, local.month, local.day);
  final today = DateTime.utc(reference.year, reference.month, reference.day);
  final days = today.difference(day).inDays;
  if (days == 0) return t.channel.today;
  if (days == 1) return t.channel.yesterday;
  if (days > 1 && days < 7) return '$days ${t.channel.daysAgo}';
  return DateTimeHelper.dateTimeFmt(
    time,
    pattern: 'yyyy-MM-dd',
    relative: false,
  );
}

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'notification.dart';

part 'notification_provider.g.dart';

/// 通知服务 Provider
///
/// 提供 NotificationService 单例实例
/// 使用 Riverpod 管理通知服务的生命周期
///
/// 使用示例：
/// ```dart
/// // 在 ConsumerWidget 中使用
/// class MyPage extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final notificationService = ref.watch(notificationServiceProvider);
///
///     // 显示通知
///     onPressed: () async {
///       await notificationService.show(
///         title: '新消息',
///         body: '您有一条新消息',
///       );
///     }
///   }
/// }
/// ```
///
/// 或者在业务逻辑中使用：
/// ```dart
/// // 读取 Provider（不监听变化）
/// final notificationService = ref.read(notificationServiceProvider);
/// await notificationService.initialize();
/// ```
@riverpod
NotificationService notificationService(Ref ref) {
  return NotificationService();
}

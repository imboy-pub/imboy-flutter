// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(notificationService)
final notificationServiceProvider = NotificationServiceProvider._();

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

final class NotificationServiceProvider
    extends
        $FunctionalProvider<
          NotificationService,
          NotificationService,
          NotificationService
        >
    with $Provider<NotificationService> {
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
  NotificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationServiceHash();

  @$internal
  @override
  $ProviderElement<NotificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationService create(Ref ref) {
    return notificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationService>(value),
    );
  }
}

String _$notificationServiceHash() =>
    r'cda5ea9d196dce85bee56839a4a0f035021752e3';

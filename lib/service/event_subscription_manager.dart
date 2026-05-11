/// 事件订阅管理器
///
/// 提供统一的事件订阅管理功能，自动处理订阅的生命周期
///
/// 设计原则：
/// - KISS: 简单的 mixin，只管理订阅的创建和销毁
/// - DRY: 避免在每个服务中重复编写订阅管理代码
/// - 自动管理: 自动跟踪所有订阅，统一取消
///
/// 使用示例：
/// ```dart
/// // 方式1：在单例服务中使用（推荐）
/// class MyService with EventSubscriptionManager {
///   static MyService? _instance;
///   static MyService get instance {
///     _instance ??= MyService._internal();
///     return _instance!;
///   }
///
///   MyService._internal() {
///     _init();
///   }
///
///   void _init() {
///     // 订阅单个事件
///     subscribeTo(
///       AppEventBus.on<UserLoginEvent>().listen((event) {
///         print('用户登录: ${event.username}');
///       })
///     );
///
///     // 订阅多个事件
///     subscribeAll([
///       AppEventBus.on<MessageEvent>().listen((event) { ... }),
///       AppEventBus.on<NetworkEvent>().listen((event) { ... }),
///     ]);
///   }
///
///   void dispose() {
///     cancelAllSubscriptions(); // 一次性取消所有订阅
///   }
/// }
///
/// // 方式2：在 Riverpod Notifier 中使用
/// @riverpod
/// class MyNotifier extends _$MyNotifier {
///   final List<StreamSubscription<dynamic>> _subscriptions = [];
///
///   @override
///   MyState build() {
///     // 订阅事件
///     _subscriptions.add(
///       AppEventBus.on<UserLoginEvent>().listen((event) {
///         // 更新状态
///       }),
///     );
///     ref.onDispose(() {
///       // 取消所有订阅
///       for (final sub in _subscriptions) {
///         sub.cancel();
///       }
///     });
///     return MyState();
///   }
/// }
/// ```
///
/// 注意事项：
/// - 单例服务：在 dispose() 方法中调用 cancelAllSubscriptions
/// - Riverpod Notifier：使用 ref.onDispose() 回调中调用 cancelAllSubscriptions
/// - subscribeTo 返回的订阅会被自动管理，无需手动取消
/// - cancelAllSubscriptions 可以安全调用多次
library;

import 'dart:async';

/// 事件订阅管理器 Mixin
///
/// 提供统一的事件订阅管理功能，自动处理订阅的生命周期
///
/// 特性：
/// - 自动跟踪所有订阅
/// - 批量订阅支持
/// - 统一取消接口
/// - 线程安全
mixin EventSubscriptionManager {
  /// 所有订阅的集合
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// 订阅事件并自动管理生命周期
  ///
  /// [subscription] `StreamSubscription<dynamic>` 对象
  ///
  /// 返回传入的订阅对象，支持链式调用
  ///
  /// 示例：
  /// ```dart
  /// subscribeTo(
  ///   AppEventBus.on<UserLoginEvent>().listen((event) {
  ///     print('用户登录: \${event.username}');
  ///   })
  /// );
  /// ```
  StreamSubscription<T> subscribeTo<T extends Object>(
    StreamSubscription<T> subscription,
  ) {
    _subscriptions.add(subscription);
    return subscription;
  }

  /// 批量订阅事件
  ///
  /// [subscriptions] `StreamSubscription<dynamic>` 列表
  ///
  /// 示例：
  /// ```dart
  /// subscribeAll([
  ///   AppEventBus.on<MessageEvent>().listen((event) { ... }),
  ///   AppEventBus.on<NetworkEvent>().listen((event) { ... }),
  /// ]);
  /// ```
  void subscribeAll(List<StreamSubscription<dynamic>> subscriptions) {
    _subscriptions.addAll(subscriptions);
  }

  /// 取消所有订阅
  ///
  /// 会取消所有通过 subscribeTo 和 subscribeAll 添加的订阅
  /// 可以安全调用多次
  ///
  /// 示例：
  /// ```dart
  /// // 单例服务中
  /// void dispose() {
  ///   cancelAllSubscriptions();
  /// }
  ///
  /// // Riverpod Notifier 中
  /// @override
  /// MyState build() {
  ///   ref.onDispose(() {
  ///     cancelAllSubscriptions();
  ///   });
  ///   return MyState();
  /// }
  /// ```
  void cancelAllSubscriptions() {
    for (final subscription in _subscriptions) {
      // 忽略已取消的订阅
      try {
        subscription.cancel();
      } catch (e) {
        // 订阅可能已经取消，忽略错误
      }
    }
    _subscriptions.clear();
  }

  /// 获取订阅数量
  ///
  /// 返回当前管理的订阅数量
  ///
  /// 示例：
  /// ```dart
  /// print('当前订阅数: \${subscriptionCount}');
  /// ```
  int get subscriptionCount => _subscriptions.length;

  /// 检查是否有活跃订阅
  ///
  /// 返回 true 如果至少有一个订阅
  bool get hasSubscriptions => _subscriptions.isNotEmpty;
}

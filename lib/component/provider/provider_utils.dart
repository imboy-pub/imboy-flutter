/// Provider 工具类
/// 提供 Riverpod Provider 的辅助函数
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider 辅助工具类
///
/// 提供安全的 Provider 访问方法，避免 Provider 未注册时的错误
class ProviderUtils {
  ProviderUtils._();

  /// 安全地读取 Provider
  ///
  /// 如果 Provider 未注册或读取失败，返回 null
  /// 适用于可选的 Provider 读取场景
  ///
  /// 示例:
  /// ```dart
  /// final user = ProviderUtils.readOrNull(userProvider, ref);
  /// if (user != null) {
  ///   // 使用 user
  /// }
  /// ```
  static T? readOrNull<T>(dynamic provider, WidgetRef ref) {
    try {
      return ref.read(provider);
    } catch (_) {
      return null;
    }
  }

  /// 安全地监听 Provider
  ///
  /// 如果 Provider 未注册或读取失败，返回默认值
  ///
  /// 示例:
  /// ```dart
  /// final count = ProviderUtils.watchOrDefault(counterProvider, ref, 0);
  /// ```
  static T watchOrDefault<T>(dynamic provider, WidgetRef ref, T defaultValue) {
    try {
      return ref.watch(provider);
    } catch (_) {
      return defaultValue;
    }
  }

  /// 检查 Provider 是否可访问
  ///
  /// 通过尝试读取来判断 Provider 是否已正确注册
  ///
  /// 示例:
  /// ```dart
  /// if (ProviderUtils.isAccessible(userProvider, ref)) {
  ///   final user = ref.read(userProvider);
  /// }
  /// ```
  static bool isAccessible<T>(dynamic provider, WidgetRef ref) {
    try {
      ref.read(provider);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Riverpod WidgetRef 扩展方法
extension ProviderWidgetRefExtension on WidgetRef {
  /// 安全地读取 Provider
  ///
  /// 如果 Provider 未注册或读取失败，返回 null
  ///
  /// 示例:
  /// ```dart
  /// final user = ref.readOrNull(userProvider);
  /// if (user != null) {
  ///   // 使用 user
  /// }
  /// ```
  T? readOrNull<T>(dynamic provider) {
    return ProviderUtils.readOrNull<T>(provider, this);
  }

  /// 安全地监听 Provider
  ///
  /// 如果 Provider 未注册或读取失败，返回默认值
  ///
  /// 示例:
  /// ```dart
  /// final count = ref.watchOrDefault(counterProvider, 0);
  /// ```
  T watchOrDefault<T>(dynamic provider, T defaultValue) {
    return ProviderUtils.watchOrDefault<T>(provider, this, defaultValue);
  }

  /// 检查 Provider 是否可访问
  ///
  /// 示例:
  /// ```dart
  /// if (ref.isAccessible(userProvider)) {
  ///   final user = ref.read(userProvider);
  /// }
  /// ```
  bool isAccessible<T>(dynamic provider) {
    return ProviderUtils.isAccessible<T>(provider, this);
  }
}

/// Riverpod Ref 扩展方法（用于 Provider 内部）
extension ProviderRefExtension on Ref {
  /// 安全地读取其他 Provider
  ///
  /// 如果 Provider 未注册或读取失败，返回 null
  ///
  /// 示例:
  /// ```dart
  /// @riverpod
  /// class MyNotifier extends _$MyNotifier {
  ///   @override
  ///   Model build() {
  ///     final user = ref.readOrNull(userProvider);
  ///     // ...
  ///   }
  /// }
  /// ```
  T? readOrNull<T>(dynamic provider) {
    try {
      return read(provider);
    } catch (_) {
      return null;
    }
  }

  /// 安全地监听其他 Provider
  ///
  /// 如果 Provider 未注册或读取失败，返回默认值
  ///
  /// 示例:
  /// ```dart
  /// final count = ref.watchOrDefault(counterProvider, 0);
  /// ```
  T watchOrDefault<T>(dynamic provider, T defaultValue) {
    try {
      return watch(provider);
    } catch (_) {
      return defaultValue;
    }
  }
}

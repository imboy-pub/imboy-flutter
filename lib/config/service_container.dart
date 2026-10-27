part of 'init.dart';

/// 服务容器
///
/// 提供单例服务的注册和获取功能
class ServiceContainer {
  static final ServiceContainer _instance = ServiceContainer._internal();
  factory ServiceContainer() => _instance;
  ServiceContainer._internal();

  final Map<Type, dynamic> _services = {};
  final Map<Type, dynamic Function()> _factories = {};

  /// 注册单例服务
  T put<T>(T service) {
    _services[T] = service;
    return service;
  }

  /// 注册延迟初始化的服务
  T lazyPut<T>(T Function() factory) {
    _factories[T] = factory;
    return factory();
  }

  /// 获取服务
  T get<T>() {
    // 首先检查是否已注册
    if (_services.containsKey(T)) {
      return _services[T] as T;
    }

    // 检查是否有工厂函数
    if (_factories.containsKey(T)) {
      final factory = _factories[T];
      if (factory != null) {
        return factory() as T;
      }
    }

    throw Exception('Service $T not registered');
  }

  /// 检查服务是否已注册
  bool isRegistered<T>() {
    return _services.containsKey(T) || _factories.containsKey(T);
  }

  /// 清空所有服务（仅用于测试）
  void clear() {
    _services.clear();
    _factories.clear();
  }
}

final class CapabilityLocator {
  CapabilityLocator._();
  static final _instance = CapabilityLocator._();
  static CapabilityLocator get I => _instance;

  final _registry = <Type, Object>{};

  void register<T extends Object>(T impl) => _registry[T] = impl;

  T get<T extends Object>() {
    final impl = _registry[T];
    if (impl == null) throw StateError('Capability $T not registered');
    return impl as T;
  }

  bool has<T extends Object>() => _registry.containsKey(T);
}

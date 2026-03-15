import 'package:imboy/plugins/contracts/app_plugin.dart';

class PluginRegistry<T extends AppPlugin> {
  PluginRegistry({required String Function(T plugin) keyOf}) : _keyOf = keyOf;

  final String Function(T plugin) _keyOf;
  final Map<String, T> _plugins = <String, T>{};

  Iterable<T> get allPlugins => _plugins.values;

  Iterable<T> get activePlugins =>
      _plugins.values.where((plugin) => plugin.isEnabled);

  bool contains(String key) => _plugins.containsKey(key);

  T? lookup(String key) => _plugins[key];

  void register(T plugin) {
    final key = _keyOf(plugin);
    if (_plugins.containsKey(key)) {
      throw StateError('Plugin already registered for key: $key');
    }
    _plugins[key] = plugin;
  }

  void registerAll(Iterable<T> plugins) {
    for (final plugin in plugins) {
      register(plugin);
    }
  }
}

import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/plugins/registry/plugin_registry.dart';
import 'package:imboy/service/message_type_constants.dart';

class MessageTypeRegistry {
  MessageTypeRegistry({this.fallbackType = MessageType.unsupported})
    : _registry = PluginRegistry<MessageTypePlugin>(
        keyOf: (plugin) => plugin.type,
      );

  final String fallbackType;
  final PluginRegistry<MessageTypePlugin> _registry;

  Iterable<MessageTypePlugin> get activePlugins => _registry.activePlugins;

  bool contains(String type) => _registry.contains(type);

  MessageTypePlugin? lookup(String type) => _registry.lookup(type);

  void register(MessageTypePlugin plugin) => _registry.register(plugin);

  void registerAll(Iterable<MessageTypePlugin> plugins) =>
      _registry.registerAll(plugins);

  MessageTypePlugin resolve(String type) {
    final plugin = _registry.lookup(type);
    if (plugin != null && plugin.isEnabled) {
      return plugin;
    }

    final fallback = _registry.lookup(fallbackType);
    if (fallback == null || !fallback.isEnabled) {
      throw StateError('No active fallback plugin registered for type: $type');
    }
    return fallback;
  }
}

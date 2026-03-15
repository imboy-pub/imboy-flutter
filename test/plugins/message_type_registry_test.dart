import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/plugins/registry/message_type_registry.dart';

class _FakeMessageTypePlugin implements MessageTypePlugin {
  const _FakeMessageTypePlugin({required this.type, this.isEnabled = true});

  @override
  final String type;

  @override
  String get id => 'fake:$type';

  @override
  final bool isEnabled;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return const SizedBox.shrink();
  }
}

void main() {
  group('MessageTypeRegistry', () {
    test('registers plugin by type', () {
      final registry = MessageTypeRegistry();
      const plugin = _FakeMessageTypePlugin(type: 'text');

      registry.register(plugin);

      expect(registry.resolve('text'), same(plugin));
    });

    test('rejects duplicate type registration', () {
      final registry = MessageTypeRegistry();

      registry.register(const _FakeMessageTypePlugin(type: 'text'));

      expect(
        () => registry.register(const _FakeMessageTypePlugin(type: 'text')),
        throwsStateError,
      );
    });

    test('resolves unknown type to fallback plugin', () {
      final registry = MessageTypeRegistry();
      const fallback = _FakeMessageTypePlugin(type: 'unsupported');

      registry.register(fallback);

      expect(registry.resolve('unknown-type'), same(fallback));
    });

    test('skips inactive plugin and falls back to unsupported', () {
      final registry = MessageTypeRegistry();
      const disabled = _FakeMessageTypePlugin(type: 'image', isEnabled: false);
      const fallback = _FakeMessageTypePlugin(type: 'unsupported');

      registry
        ..register(disabled)
        ..register(fallback);

      expect(registry.resolve('image'), same(fallback));
      expect(registry.activePlugins, isNot(contains(disabled)));
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat/widget/chat_background_manager.dart';
import 'package:imboy/service/storage.dart';

/// ChatBackgroundManager 契约测试（QA #21）
///
/// pattern_1/2/3 引用的 assets/images/chat_backgrounds/ 资源从未随包发布，
/// 已从选项池下架；存量用户本地存的 pattern 值须归一为 default。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('backgroundOptions 不含已下架 pattern 且与名称映射键一致', () {
    const options = ChatBackgroundManager.backgroundOptions;
    expect(options.where((o) => o.startsWith('pattern_')), isEmpty);
    expect(ChatBackgroundManager.backgroundNames.keys.toSet(), options.toSet());
  });

  test('存量 pattern_1 值归一为 default', () async {
    await StorageService.to.setString('chat_background', 'pattern_1');
    addTearDown(() => StorageService.to.remove('chat_background'));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(chatBackgroundManagerProvider);
    expect(state.currentBackground, 'default');
  });

  test('合法存量值原样保留', () async {
    await StorageService.to.setString('chat_background', 'gradient_1');
    addTearDown(() => StorageService.to.remove('chat_background'));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(chatBackgroundManagerProvider);
    expect(state.currentBackground, 'gradient_1');
  });
}

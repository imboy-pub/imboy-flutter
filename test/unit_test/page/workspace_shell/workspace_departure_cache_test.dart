import 'dart:async';

import 'package:imboy/service/asset_url_resolver.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/model/workspace_conversation_model.dart';
import 'package:imboy/store/api/workspace_api.dart';

void main() {
  test('departure clears signed attachment URLs', () async {
    final resolver = AssetUrlResolver.instance;
    resolver.clear();
    var calls = 0;
    resolver.fetcherOverride = (_) async => 'https://example.com/${++calls}';
    addTearDown(() {
      resolver.clear();
      resolver.fetcherOverride = null;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await resolver.resolve('u1/file_1_a/x.png');
    container.read(workspaceShellProvider.notifier).forgetOrganization('10');
    expect(
      await resolver.resolve('u1/file_1_a/x.png'),
      'https://example.com/2',
    );
  });

  test(
    'departure refreshes its message/channel caches and preserves other org',
    () async {
      final messages = <String, int>{};
      final channels = <String, int>{};
      final container = ProviderContainer(
        overrides: [
          workspaceConversationsProvider.overrideWith((ref, id) async {
            messages.update(id, (count) => count + 1, ifAbsent: () => 1);
            return [];
          }),
          workspaceChannelsProvider.overrideWith((ref, id) async {
            channels.update(id, (count) => count + 1, ifAbsent: () => 1);
            return [];
          }),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(workspaceShellProvider.notifier);
      for (final (id, org) in [('100', '10'), ('101', '10'), ('200', '20')]) {
        notifier.applyJoined(
          WorkspaceModel(id: id, name: id, ownerId: '1', organizationId: org),
        );
        container.listen(workspaceConversationsProvider(id), (_, _) {});
        container.listen(workspaceChannelsProvider(id), (_, _) {});
        await container.read(workspaceConversationsProvider(id).future);
        await container.read(workspaceChannelsProvider(id).future);
      }
      notifier.forgetOrganization('10');
      await container.pump();
      expect(messages, {'100': 2, '101': 2, '200': 1});
      expect(channels, {'100': 2, '101': 2, '200': 1});
      expect(
        container
            .read(workspaceShellProvider)
            .workspaces
            .map((workspace) => workspace.id),
        ['200'],
      );
    },
  );
  test(
    'late message request cannot replace the post-departure denial',
    () async {
      final old = Completer<List<WorkspaceConversationModel>>();
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          workspaceConversationsProvider.overrideWith((ref, id) {
            if (++calls == 1) return old.future;
            throw const WorkspaceApiException(403, 'membership ended');
          }),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(workspaceShellProvider.notifier);
      notifier.applyJoined(
        const WorkspaceModel(
          id: '100',
          name: 'A',
          ownerId: '1',
          organizationId: '10',
        ),
      );
      final provider = workspaceConversationsProvider('100');
      container.listen(provider, (_, _) {});
      await container.pump();
      notifier.forgetOrganization('10');
      await container.pump();
      expect(calls, 2);
      expect(container.read(provider).hasError, isTrue);
      old.complete([]);
      await container.pump();
      expect(container.read(provider).hasError, isTrue);
      expect(container.read(provider).error, isA<WorkspaceApiException>());
    },
  );
}

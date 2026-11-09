import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/repository/channel_inbox_preference_repo_sqlite.dart';

final channelInboxPreferenceRepoProvider = Provider<ChannelInboxPreferenceRepo>(
  (ref) => ChannelInboxPreferenceRepo(),
);

final channelInboxHiddenIdsProvider =
    AsyncNotifierProvider<ChannelInboxHiddenIdsNotifier, Set<String>>(
      ChannelInboxHiddenIdsNotifier.new,
    );

class ChannelInboxHiddenIdsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final repo = ref.watch(channelInboxPreferenceRepoProvider);
    final scope = repo.captureScope();
    void authChanged() {
      if (repo.isCurrent(scope)) return;
      // Previous data must never survive account/session changes, including a
      // re-login under the same uid.
      state = const AsyncData({});
      ref.invalidateSelf();
    }

    repo.session.addListener(authChanged);
    ref.onDispose(() => repo.session.removeListener(authChanged));
    return repo.hiddenIds(scope);
  }

  Future<bool> setHidden(
    ChannelInboxPreferenceScope scope,
    String channelId,
    bool hidden,
  ) async {
    final repo = ref.read(channelInboxPreferenceRepoProvider);
    if (!repo.isCurrent(scope)) return false;
    final changed = await repo.setHidden(scope, channelId, hidden);
    if (!ref.mounted || !repo.isCurrent(scope) || !changed) return false;
    // Let Riverpod discard a concurrently loading, older preference snapshot.
    ref.invalidateSelf();
    try {
      await future;
      return ref.mounted && repo.isCurrent(scope);
    } catch (_) {
      return false;
    }
  }
}

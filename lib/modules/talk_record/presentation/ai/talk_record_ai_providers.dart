import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../talk_record_auth.dart';

class TalkRecordAiIdentity {
  const TalkRecordAiIdentity(this.scope, this.epoch);
  final TalkRecordAiCredentialScope scope;
  final int epoch;

  bool matches(TalkRecordAiIdentity? other) =>
      other != null && epoch == other.epoch && scope.matches(other.scope);
}

TalkRecordAiIdentity? _currentIdentity() {
  final user = UserRepoLocal.to;
  if (user.isAuthTransitioning) return null;
  final String uid;
  try {
    uid = user.currentUid;
  } on Exception {
    // Widget 测试可能未初始化 StorageService；无存储等价于无登录身份，
    // 静默返回 null（生产 main() 必然先完成初始化，不会走到这里）。
    return null;
  }
  if (uid.isEmpty) return null;
  final uri = Uri.tryParse(Env().apiBaseUrl);
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  try {
    return TalkRecordAiIdentity(
      TalkRecordAiCredentialScope(
        deploymentOrigin: uri.origin,
        accountId: user.currentUid,
      ),
      user.sessionGeneration,
    );
  } on FormatException {
    return null;
  } on TalkRecordAiCredentialException {
    return null;
  }
}

final talkRecordAiIdentityReaderProvider =
    Provider<TalkRecordAiIdentity? Function()>((ref) => _currentIdentity);

final talkRecordAiSessionProvider = Provider<TalkRecordAiIdentity?>((ref) {
  final cancel = ref.read(talkRecordAuthSubscribeProvider)(ref.invalidateSelf);
  ref.onDispose(cancel);
  return ref.watch(talkRecordAiIdentityReaderProvider)();
});

// Null selects the shared native secure adapter. Tests inject one shared backend.
final talkRecordAiSecureStoreProvider = Provider<TalkRecordAiSecureStore?>(
  (ref) => null,
);

final talkRecordAiCredentialsProvider = Provider<TalkRecordAiCredentials?>((
  ref,
) {
  final identity = ref.watch(talkRecordAiSessionProvider);
  if (identity == null) return null;
  final readIdentity = ref.watch(talkRecordAiIdentityReaderProvider);
  return TalkRecordAiCredentials(
    scope: identity.scope,
    currentScope: () => readIdentity()?.scope,
    authSessionEpoch: identity.epoch,
    currentAuthSessionEpoch: () => readIdentity()?.epoch,
    store: ref.watch(talkRecordAiSecureStoreProvider),
  );
});

final talkRecordAiStatusProvider = FutureProvider.autoDispose
    .family<TalkRecordAiCredentialStatus, TalkRecordAiProvider>((
      ref,
      provider,
    ) async {
      final credentials = ref.watch(talkRecordAiCredentialsProvider);
      if (credentials == null) {
        throw const TalkRecordAiCredentialException('account_changed');
      }
      return credentials.status(provider);
    });

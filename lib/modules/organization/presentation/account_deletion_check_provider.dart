import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

import '../domain/organization_models.dart';
import 'organization_entry_provider.dart';

typedef AccountCheckAuthSubscribe = void Function() Function(void Function());
final accountCheckAuthSubscribeProvider = Provider<AccountCheckAuthSubscribe>(
  (ref) => (changed) {
    UserRepoLocal.to.addAuthListener(changed);
    return () => UserRepoLocal.to.removeAuthListener(changed);
  },
);
final accountCheckIdentityProvider = Provider<String>(
  (ref) => ref.watch(currentUserProvider.select((user) => user?.uid)) ?? '',
);
final accountCheckTransitionProvider = Provider<bool Function()>(
  (ref) =>
      () => UserRepoLocal.to.isAuthTransitioning,
);
final accountDeletionCheckProvider =
    NotifierProvider.autoDispose<
      AccountDeletionCheckNotifier,
      AsyncValue<DeletionPreflightReport>
    >(AccountDeletionCheckNotifier.new);

/// Every auth event clears the report, including a same-UID reauthentication.
class AccountDeletionCheckNotifier
    extends Notifier<AsyncValue<DeletionPreflightReport>> {
  int _epoch = 0;

  @override
  AsyncValue<DeletionPreflightReport> build() {
    ref.watch(accountCheckIdentityProvider);
    final remove = ref.read(accountCheckAuthSubscribeProvider)(() {
      _epoch++;
      state = const AsyncLoading();
      Future.microtask(refresh);
    });
    ref.onDispose(() {
      _epoch++;
      remove();
    });
    Future.microtask(refresh);
    return const AsyncLoading();
  }

  Future<void> refresh() async {
    if (!ref.mounted) return;
    final epoch = ++_epoch;
    final uid = ref.read(accountCheckIdentityProvider);
    state = const AsyncLoading();
    bool current() =>
        ref.mounted &&
        epoch == _epoch &&
        uid == ref.read(accountCheckIdentityProvider) &&
        !ref.read(accountCheckTransitionProvider)();
    if (uid.isEmpty || ref.read(accountCheckTransitionProvider)()) return;
    try {
      final report = await ref
          .read(organizationApiProvider)
          .deletionPreflight();
      if (!current()) return;
      if (report.subjectUserId != uid) {
        state = AsyncError(
          StateError('Preflight subject mismatch'),
          StackTrace.current,
        );
        return;
      }
      state = AsyncData(report);
    } catch (error, stack) {
      if (current()) state = AsyncError(error, stack);
    }
  }
}

part of 'message_retry.dart';

/// Register before the first database/network await. The session generation is
/// revoked before cleanup starts; existing guards then stop the operation and
/// the registry awaits its final writes before the database is removed.
Future<T> _runAccountRetryTask<T>({
  required T cancelled,
  required Future<T> Function() operation,
}) async {
  final actor = UserRepoLocal.to;
  if (actor.currentUid.isEmpty || actor.isAuthTransitioning) return cancelled;
  final owner = AccountLocalTaskOwner.capture();
  try {
    return await AccountLocalTaskRegistry.instance.run<T>(
      owner,
      operation: (_) => operation(),
    );
  } on AccountLocalTaskCancelledException {
    return cancelled;
  }
}

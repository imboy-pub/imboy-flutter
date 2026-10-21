/// Auth subscription is injectable so stale-request tests need no account store.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

typedef TalkRecordAuthSubscribe = void Function() Function(void Function());
final talkRecordAuthSubscribeProvider = Provider<TalkRecordAuthSubscribe>((
  ref,
) {
  return (changed) {
    UserRepoLocal.to.addAuthListener(changed);
    return () => UserRepoLocal.to.removeAuthListener(changed);
  };
});

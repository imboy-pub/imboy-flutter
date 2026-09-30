import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

import 'data/oa_workbench_api.dart';
import 'enterprise_oa_runtime_config.dart';

final oaWorkbenchApiProvider = Provider<OaWorkbenchApi>(
  (ref) => OaWorkbenchApi(),
);

/// 账号参与缓存键；旧账号的结果不能作为新账号配置消费。
final oaWorkbenchEntriesProvider = FutureProvider.autoDispose
    .family<
      List<EnterpriseOaRuntimeConfig>,
      ({String accountKey, EntityId organizationId})
    >((ref, scope) async {
      final uid = ref.watch(
        currentUserProvider.select((user) => user?.uid ?? ''),
      );
      if (uid.isEmpty ||
          uid != scope.accountKey ||
          scope.organizationId.isEmpty) {
        return const [];
      }
      final result = await ref
          .watch(oaWorkbenchApiProvider)
          .entries(scope.organizationId);
      if (ref.mounted &&
          ref.read(currentUserProvider)?.uid == scope.accountKey) {
        return result;
      }
      return const [];
    }, retry: (_, _) => null);

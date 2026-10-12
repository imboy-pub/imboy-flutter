import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

import 'data/oa_workbench_api.dart';
import 'enterprise_oa_runtime_config.dart';

final oaWorkbenchApiProvider = Provider<OaWorkbenchApi>(
  (ref) => OaWorkbenchApi(),
);

/// 账号参与缓存键；旧账号的结果不能作为新账号配置消费。
/// 定位修订（2026-10-12）：发现不依赖企业上下文，键从
/// (accountKey, organizationId) 简化为 accountKey。
final oaWorkbenchEntriesProvider = FutureProvider.autoDispose
    .family<List<EnterpriseOaRuntimeConfig>, String>((ref, accountKey) async {
      final uid = ref.watch(
        currentUserProvider.select((user) => user?.uid ?? ''),
      );
      if (uid.isEmpty || uid != accountKey) {
        return const [];
      }
      final result = await ref.watch(oaWorkbenchApiProvider).entries();
      if (ref.mounted && ref.read(currentUserProvider)?.uid == accountKey) {
        return result;
      }
      return const [];
    }, retry: (_, _) => null);

/// 首页仅有 personal 和 workspace（企业）两种模式。
/// 安装级默认值保留解析兼容，但不能替用户选择企业或首页模式。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

/// /api/v1/init 下发的 experience 字段名（与后端 T1 约定一致）。
const String kEffectiveProductExperienceField = 'effective_product_experience';

/// workspace 仅表示已选择企业的企业布局。
enum ProductExperience {
  personal('personal'),
  workspace('workspace');

  final String wireName;
  const ProductExperience(this.wireName);
}

/// 兼容服务端旧值；chat、缺失和未知值均按 personal 解析。
ProductExperience parseProductExperience(String? raw) {
  if (raw == ProductExperience.workspace.wireName) {
    return ProductExperience.workspace;
  }
  return ProductExperience.personal;
}

/// 解析旧安装配置，仅用于兼容，不决定用户首页。
ProductExperience resolveProductExperienceFromPayload(
  Map<String, dynamic>? payload,
) {
  if (payload == null) return ProductExperience.personal;
  final dynamic raw = payload[kEffectiveProductExperienceField];
  return parseProductExperience(raw is String ? raw : null);
}

/// 读取旧安装配置缓存，不作为首页模式的默认值。
ProductExperience readCachedProductExperience() {
  return parseProductExperience(
    StorageService.to.getString(Keys.effectiveProductExperience),
  );
}

/// 账号隔离的本机模式；兼容旧版本保存的 chat/全局偏好。
ProductExperience? readLocalProductExperience(String accountId) {
  final scoped = StorageService.to.getString(
    '${Keys.localProductExperience}_$accountId',
  );
  final raw = scoped.isEmpty
      ? StorageService.to.getString(Keys.localProductExperience)
      : scoped;
  if (raw == 'chat') return ProductExperience.personal;
  for (final experience in ProductExperience.values) {
    if (raw == experience.wireName) return experience;
  }
  return null;
}

/// 未选择企业时始终进入个人模式；旧 workspace 偏好不能打开第三套布局。
ProductExperience resolveCurrentProductExperience({
  required String accountId,
  required String organizationId,
}) {
  if (accountId.isEmpty || organizationId.isEmpty) {
    return ProductExperience.personal;
  }
  return readLocalProductExperience(accountId) ?? ProductExperience.personal;
}

class ProductExperienceNotifier extends Notifier<ProductExperience> {
  Future<void> _pending = Future.value();

  @override
  ProductExperience build() {
    final accountId = ref.watch(
      currentUserProvider.select((user) => user?.uid ?? ''),
    );
    final organizationId = ref.watch(
      workspaceShellProvider.select((shell) => shell.organizationId),
    );
    return resolveCurrentProductExperience(
      accountId: accountId,
      organizationId: organizationId,
    );
  }

  /// 保存成功后才切换界面；连续操作共用同一写入顺序。
  Future<void> select(ProductExperience experience) {
    final accountId = ref.read(currentUserProvider)?.uid ?? '';
    return _enqueue(() async {
      if (!ref.mounted ||
          (ref.read(currentUserProvider)?.uid ?? '') != accountId) {
        throw StateError('Account changed before selecting mode');
      }
      if (experience == ProductExperience.workspace &&
          (accountId.isEmpty ||
              ref.read(workspaceShellProvider).organizationId.isEmpty)) {
        throw StateError(
          'Select an organization before entering workspace mode',
        );
      }
      await StorageService.to.persistPreference(
        () => StorageService.to.setString(
          '${Keys.localProductExperience}_$accountId',
          experience.wireName,
        ),
      );
      if (ref.mounted &&
          (ref.read(currentUserProvider)?.uid ?? '') == accountId) {
        state = resolveCurrentProductExperience(
          accountId: accountId,
          organizationId: ref.read(workspaceShellProvider).organizationId,
        );
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() change) {
    final next = _pending.then((_) => change());
    // Return the original failure to the caller, while allowing the next retry.
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}

final productExperienceProvider =
    NotifierProvider<ProductExperienceNotifier, ProductExperience>(
      ProductExperienceNotifier.new,
    );

/// 当前企业指针（GZAPP-04 G9）——本地 UI 偏好，**不是 membership 真源**。
///
/// 语义边界（对齐 [OrganizationCache] 的隔离契约）：
/// - 指针按账号 scope 隔离：`org_current_<accountKey>` 持久化（登录 UID）；
/// - 指针只回答「用户最后停留在哪个企业」（切换器/WS picker 顶部企业行
///   的展示与上下文），**绝不**作为 membership/role 判定依据——企业列表
///   每次都从服务端 mine() 刷新，指针指向的 org 可能已被移出，届时
///   消费方须以服务端事实为准（不在 mine 列表 → 回落空态/第一项）；
/// - 切换动作的缓存失效清单见 OrganizationPickerPage（G11）。
library;

import 'dart:convert' as json;

import 'package:flutter/foundation.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/service/storage.dart';

/// 当前企业存储键前缀（拼账号 UID）。
const String kCurrentOrgStoragePrefix = 'org_current_';

/// 账号 scope 的当前企业指针（[ValueNotifier] 供 chip/顶部企业行监听）。
class CurrentOrganizationStore {
  CurrentOrganizationStore._(this.accountKey);

  final String accountKey;
  final ValueNotifier<Organization?> _notifier = ValueNotifier<Organization?>(
    null,
  );
  bool _loaded = false;

  static final Map<String, CurrentOrganizationStore> _byAccount =
      <String, CurrentOrganizationStore>{};

  /// 取（或建）某账号的指针 scope。accountKey 为空串时抛 ArgumentError
  /// （与 [OrganizationCache.forAccount] 同款 fail-closed）。
  static CurrentOrganizationStore forAccount(String accountKey) {
    if (accountKey.isEmpty) {
      throw ArgumentError('accountKey must not be empty');
    }
    final store = _byAccount.putIfAbsent(
      accountKey,
      () => CurrentOrganizationStore._(accountKey),
    );
    store._ensureLoaded();
    return store;
  }

  /// 登出时清理 scope（不动持久化以外的其他账号）。
  static void disposeAccount(String accountKey) {
    _byAccount.remove(accountKey);
    StorageService.to.remove('$kCurrentOrgStoragePrefix$accountKey');
  }

  Organization? get value => _notifier.value;

  /// 指针变更监听（chip / WS picker 顶部企业行）。
  ValueListenable<Organization?> get listenable => _notifier;

  /// 切换当前企业（**先持久化后内存**——持久化失败时抛出且内存保持旧值，
  /// 保证补偿路径看到一致的旧状态；调用方须 await）。
  Future<void> set(Organization org) async {
    await _write(org);
    _notifier.value = org;
  }

  /// 补偿专用：恢复到先前任一指针值（[previous] 可为 null=清空指针）。
  /// 与 [set] 同序（先持久化后内存），失败抛出、内存不变。
  Future<void> restore(Organization? previous) async {
    await _write(previous);
    _notifier.value = previous;
  }

  /// 服务端已撤权：即使偏好删除失败，也不能在当前界面继续展示已退出企业。
  Future<void> forget(EntityId orgId) async {
    if (value?.id != orgId) return;
    _notifier.value = null;
    final removed = await StorageService.to.remove(
      '$kCurrentOrgStoragePrefix$accountKey',
    );
    if (!removed) {
      throw StateError('Could not clear revoked organization preference');
    }
  }

  Future<void> _write(Organization? org) async {
    final key = '$kCurrentOrgStoragePrefix$accountKey';
    if (org == null) {
      await StorageService.to.remove(key);
      return;
    }
    await StorageService.to.setString(
      key,
      json.jsonEncode(<String, dynamic>{'id': org.id, 'name': org.name}),
    );
  }

  void _ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = StorageService.to.getString(
        '$kCurrentOrgStoragePrefix$accountKey',
      );
      if (raw.isEmpty) return;
      final map = json.jsonDecode(raw);
      if (map is Map<String, dynamic> &&
          (map['id'] as String? ?? '').isNotEmpty) {
        _notifier.value = Organization(
          id: map['id'] as String,
          name: (map['name'] as String?) ?? '',
        );
      }
    } on Object {
      // StorageService 未 init（无存储环境）/ 损坏偏好：指针非真源，
      // 静默回落「未选择」，绝不向上抛。
    }
  }
}

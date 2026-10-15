library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Native plugin test seam, already installed by shared_preferences.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _PreferenceStore extends SharedPreferencesStorePlatform {
  final values = <String, Object>{};
  final writes = <String>[];
  String failure = '';
  Completer<void>? pending;

  Future<bool> _write(String key, Object? value) async {
    writes.add(value?.toString() ?? 'remove');
    final gate = pending;
    pending = null;
    if (gate != null) await gate.future;
    if (failure == 'throw') throw StateError('synthetic preference failure');
    if (failure == 'false') return false;
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      _write(key, value);
  @override
  Future<bool> remove(String key) => _write(key, null);
  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async => Map.of(values);
}

Future<_PreferenceStore> _installStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = _PreferenceStore();
  SharedPreferencesStorePlatform.instance = store;
  await StorageService.init();
  addTearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });
  return store;
}

class _Account extends Notifier<UserModel?> {
  @override
  UserModel? build() => UserModel(uid: 'mode-a', account: 'synthetic');
  void select(String uid) =>
      state = uid.isEmpty ? null : UserModel(uid: uid, account: 'synthetic');
}

final _account = NotifierProvider<_Account, UserModel?>(_Account.new);

ProviderContainer _container() => ProviderContainer(
  overrides: [currentUserProvider.overrideWith((ref) => ref.watch(_account))],
);

void main() {
  late ProviderContainer container;
  setUp(() async {
    await StorageService.to.remove(Keys.localProductExperience);
    await StorageService.to.remove(Keys.effectiveProductExperience);
    for (final uid in ['mode-a', 'mode-b']) {
      CurrentOrganizationStore.disposeAccount(uid);
      await StorageService.to.remove('${Keys.localProductExperience}_$uid');
    }
    container = _container();
  });
  tearDown(() => container.dispose());

  Future<void> chooseOrganization() async {
    final uid = container.read(currentUserProvider)!.uid;
    await CurrentOrganizationStore.forAccount(uid)
        .set(const Organization(id: 'org-a', name: 'synthetic'));
    await container
        .read(workspaceShellProvider.notifier)
        .selectOrganization('org-a', () async => '');
  }

  test('只有 personal/workspace；旧 chat 值兼容为 personal', () {
    expect(ProductExperience.values.map((e) => e.wireName), [
      'personal',
      'workspace',
    ]);
    for (final raw in [null, '', 'chat', 'personal', 'unknown']) {
      expect(parseProductExperience(raw), ProductExperience.personal);
    }
    expect(parseProductExperience('workspace'), ProductExperience.workspace);
    expect(
      resolveProductExperienceFromPayload({'effective_product_experience': 42}),
      ProductExperience.personal,
    );
    expect(kEffectiveProductExperienceField, Keys.effectiveProductExperience);
  });

  for (final legacy in ['', 'workspace', 'chat']) {
    test('未选企业：服务端 workspace 与旧偏好 $legacy 均不能改变个人默认模式', () async {
      await StorageService.to.setString(
        Keys.effectiveProductExperience,
        'workspace',
      );
      await StorageService.to.setString(Keys.localProductExperience, legacy);
      expect(readCachedProductExperience(), ProductExperience.workspace);
      expect(
        container.read(productExperienceProvider),
        ProductExperience.personal,
      );
      expect(container.read(workspaceShellProvider).organizationId, isEmpty);
      await expectLater(
        container
            .read(productExperienceProvider.notifier)
            .select(ProductExperience.workspace),
        throwsStateError,
      );
      expect(
        container.read(productExperienceProvider),
        ProductExperience.personal,
      );
    });
  }

  test('已加入工作区但未选企业仍为 personal', () {
    container
        .read(workspaceShellProvider.notifier)
        .applyJoined(
          const WorkspaceModel(
            id: 'workspace-a',
            name: 'synthetic',
            ownerId: 'mode-a',
            organizationId: 'org-a',
          ),
        );
    expect(container.read(workspaceShellProvider).hasWorkspace, isTrue);
    expect(
      container.read(productExperienceProvider),
      ProductExperience.personal,
    );
  });

  test('明确选择企业后可进入 workspace，重启恢复，切回个人后也能恢复', () async {
    await chooseOrganization();
    expect(
      container.read(productExperienceProvider),
      ProductExperience.personal,
    );
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.workspace);
    expect(
      container.read(productExperienceProvider),
      ProductExperience.workspace,
    );
    final restarted = _container();
    addTearDown(restarted.dispose);
    expect(
      restarted.read(productExperienceProvider),
      ProductExperience.workspace,
    );
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.personal);
    final personalRestart = _container();
    addTearDown(personalRestart.dispose);
    expect(
      personalRestart.read(productExperienceProvider),
      ProductExperience.personal,
    );
  });

  test('旧 workspace 偏好只有已明确选择过企业才可恢复', () async {
    await StorageService.to.setString(Keys.localProductExperience, 'workspace');
    expect(
      container.read(productExperienceProvider),
      ProductExperience.personal,
    );
    await chooseOrganization();
    expect(
      container.read(productExperienceProvider),
      ProductExperience.workspace,
    );
  });

  test('换账号、登出、退出当前企业立即回到个人模式', () async {
    await chooseOrganization();
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.workspace);
    container.read(_account.notifier).select('mode-b');
    expect(
      container.read(productExperienceProvider),
      ProductExperience.personal,
    );
    await chooseOrganization();
    expect(
      container.read(productExperienceProvider),
      ProductExperience.personal,
      reason: '账号 B 不能继承账号 A 的模式，即使企业相同',
    );
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.workspace);
    container.read(workspaceShellProvider.notifier).forgetOrganization('org-a');
    expect(
      container.read(productExperienceProvider),
      ProductExperience.personal,
    );
    container.read(_account.notifier).select('');
    expect(
      container.read(productExperienceProvider),
      ProductExperience.personal,
    );
  });

  for (final failure in ['false', 'throw']) {
    test('偏好保存 $failure：失败不切布局、不污染缓存，支持重试', () async {
      final store = await _installStore();
      await chooseOrganization();
      final notifier = container.read(productExperienceProvider.notifier);
      await notifier.select(ProductExperience.personal);
      store.failure = failure;
      await expectLater(
        notifier.select(ProductExperience.workspace),
        throwsStateError,
      );
      expect(
        container.read(productExperienceProvider),
        ProductExperience.personal,
      );
      expect(
        StorageService.to.getString('${Keys.localProductExperience}_mode-a'),
        'personal',
      );
      store.failure = '';
      await notifier.select(ProductExperience.workspace);
      expect(
        container.read(productExperienceProvider),
        ProductExperience.workspace,
      );
    });
    test('企业指针保存 $failure：不发布未持久化企业', () async {
      final native = await _installStore();
      final pointer = CurrentOrganizationStore.forAccount('mode-a');
      await pointer.set(const Organization(id: '10', name: 'synthetic old'));
      native.failure = failure;
      await expectLater(
        pointer.set(const Organization(id: '20', name: 'synthetic new')),
        throwsStateError,
      );
      expect(pointer.value?.id, '10');
      expect(
        StorageService.to.getString('${kCurrentOrgStoragePrefix}mode-a'),
        contains('synthetic old'),
      );
      native.failure = '';
    });
  }

  test('连续选择先保存后切换，并保持写入顺序', () async {
    final store = await _installStore();
    await chooseOrganization();
    store.writes.clear();
    final gate = Completer<void>();
    store.pending = gate;
    final notifier = container.read(productExperienceProvider.notifier);
    final first = notifier.select(ProductExperience.workspace);
    await Future<void>.delayed(Duration.zero);
    final second = notifier.select(ProductExperience.personal);
    expect(
      container.read(productExperienceProvider),
      ProductExperience.personal,
    );
    expect(store.writes, ['workspace']);
    gate.complete();
    await Future.wait([first, second]);
    expect(store.writes, ['workspace', 'personal']);
    expect(
      container.read(productExperienceProvider),
      ProductExperience.personal,
    );
  });

  test('保存期间换账号：旧保存不能切换新账号的首页，排队操作不能写入新账号', () async {
    final store = await _installStore();
    await chooseOrganization();
    final gate = Completer<void>();
    store.pending = gate;
    final notifier = container.read(productExperienceProvider.notifier);
    final first = notifier.select(ProductExperience.workspace);
    await Future<void>.delayed(Duration.zero);
    final queued = notifier.select(ProductExperience.personal);
    final rejected = expectLater(queued, throwsStateError);
    container.read(_account.notifier).select('mode-b');
    expect(
      container.read(productExperienceProvider),
      ProductExperience.personal,
    );
    gate.complete();
    await first;
    await rejected;
    expect(
      container.read(productExperienceProvider),
      ProductExperience.personal,
    );
    expect(
      StorageService.to.getString('${Keys.localProductExperience}_mode-b'),
      isEmpty,
    );
  });
}

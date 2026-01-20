// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bottom_navigation_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 底部导航状态提供者

@ProviderFor(BottomNavigationNotifier)
final bottomNavigationProvider = BottomNavigationNotifierProvider._();

/// 底部导航状态提供者
final class BottomNavigationNotifierProvider
    extends $NotifierProvider<BottomNavigationNotifier, int> {
  /// 底部导航状态提供者
  BottomNavigationNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bottomNavigationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bottomNavigationNotifierHash();

  @$internal
  @override
  BottomNavigationNotifier create() => BottomNavigationNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$bottomNavigationNotifierHash() =>
    r'b427d2cc8689cbbad5516ef4ec10364118311718';

/// 底部导航状态提供者

abstract class _$BottomNavigationNotifier extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// 新好友提醒计数器提供者

@ProviderFor(NewFriendRemindNotifier)
final newFriendRemindProvider = NewFriendRemindNotifierProvider._();

/// 新好友提醒计数器提供者
final class NewFriendRemindNotifierProvider
    extends $NotifierProvider<NewFriendRemindNotifier, Set<String>> {
  /// 新好友提醒计数器提供者
  NewFriendRemindNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'newFriendRemindProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$newFriendRemindNotifierHash();

  @$internal
  @override
  NewFriendRemindNotifier create() => NewFriendRemindNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$newFriendRemindNotifierHash() =>
    r'893bf75bc6b43496f4e1b1faea678634c6285577';

/// 新好友提醒计数器提供者

abstract class _$NewFriendRemindNotifier extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

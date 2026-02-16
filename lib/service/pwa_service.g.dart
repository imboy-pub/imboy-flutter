// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pwa_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// PWA 服务 Provider
///
/// 使用 Riverpod 的 @riverpod 注解模式

@ProviderFor(PWANotifier)
final pwaNotifierProvider = PWANotifierProvider._();

/// PWA 服务 Provider
///
/// 使用 Riverpod 的 @riverpod 注解模式
final class PWANotifierProvider extends $NotifierProvider<PWANotifier, PWAState> {
  /// PWA 服务 Provider
  ///
  /// 使用 Riverpod 的 @riverpod 注解模式
  PWANotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pwaNotifierProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pwaNotifierHash();

  @$internal
  @override
  PWANotifier create() => PWANotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PWAState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PWAState>(value),
    );
  }
}

String _$pwaNotifierHash() => r'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6';

/// PWA 服务 Provider
///
/// 使用 Riverpod 的 @riverpod 注解模式

abstract class _$PWANotifier extends $Notifier<PWAState> {
  PWAState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PWAState, PWAState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PWAState, PWAState>,
              PWAState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

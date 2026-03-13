// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'passport_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Passport 模块 Riverpod Notifier
/// 管理 Passport 模块的状态和业务逻辑

@ProviderFor(PassportNotifier)
final passportProvider = PassportNotifierProvider._();

/// Passport 模块 Riverpod Notifier
/// 管理 Passport 模块的状态和业务逻辑
final class PassportNotifierProvider
    extends $NotifierProvider<PassportNotifier, PassportState> {
  /// Passport 模块 Riverpod Notifier
  /// 管理 Passport 模块的状态和业务逻辑
  PassportNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'passportProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$passportNotifierHash();

  @$internal
  @override
  PassportNotifier create() => PassportNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PassportState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PassportState>(value),
    );
  }
}

String _$passportNotifierHash() => r'cd5526fec3f22d22dc57b5c6d51b88a8a1717bc4';

/// Passport 模块 Riverpod Notifier
/// 管理 Passport 模块的状态和业务逻辑

abstract class _$PassportNotifier extends $Notifier<PassportState> {
  PassportState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PassportState, PassportState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PassportState, PassportState>,
              PassportState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

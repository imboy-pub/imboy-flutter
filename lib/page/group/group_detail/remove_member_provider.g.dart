// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remove_member_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 移除群成员 Notifier

@ProviderFor(RemoveMemberNotifier)
final removeMemberProvider = RemoveMemberNotifierProvider._();

/// 移除群成员 Notifier
final class RemoveMemberNotifierProvider
    extends $NotifierProvider<RemoveMemberNotifier, RemoveMemberState> {
  /// 移除群成员 Notifier
  RemoveMemberNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'removeMemberProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$removeMemberNotifierHash();

  @$internal
  @override
  RemoveMemberNotifier create() => RemoveMemberNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemoveMemberState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemoveMemberState>(value),
    );
  }
}

String _$removeMemberNotifierHash() =>
    r'33e4884332917b686684ca6604bdd54ee7e7a5d7';

/// 移除群成员 Notifier

abstract class _$RemoveMemberNotifier extends $Notifier<RemoveMemberState> {
  RemoveMemberState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<RemoveMemberState, RemoveMemberState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RemoveMemberState, RemoveMemberState>,
              RemoveMemberState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

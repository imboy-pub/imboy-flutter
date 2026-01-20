// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scanner_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Scanner Provider - 使用 @riverpod 注解

@ProviderFor(ScannerNotifier)
final scannerProvider = ScannerNotifierProvider._();

/// Scanner Provider - 使用 @riverpod 注解
final class ScannerNotifierProvider
    extends $NotifierProvider<ScannerNotifier, ScannerState> {
  /// Scanner Provider - 使用 @riverpod 注解
  ScannerNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scannerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scannerNotifierHash();

  @$internal
  @override
  ScannerNotifier create() => ScannerNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScannerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScannerState>(value),
    );
  }
}

String _$scannerNotifierHash() => r'e8958574082e07e7de699c20af9d137bcd3dc9a1';

/// Scanner Provider - 使用 @riverpod 注解

abstract class _$ScannerNotifier extends $Notifier<ScannerState> {
  ScannerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ScannerState, ScannerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ScannerState, ScannerState>,
              ScannerState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

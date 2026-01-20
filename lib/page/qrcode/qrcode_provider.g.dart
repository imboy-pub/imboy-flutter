// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qrcode_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// QrCode Provider - 使用 @riverpod 注解

@ProviderFor(QrCodeNotifier)
final qrCodeProvider = QrCodeNotifierProvider._();

/// QrCode Provider - 使用 @riverpod 注解
final class QrCodeNotifierProvider
    extends $NotifierProvider<QrCodeNotifier, QrCodeModel> {
  /// QrCode Provider - 使用 @riverpod 注解
  QrCodeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'qrCodeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$qrCodeNotifierHash();

  @$internal
  @override
  QrCodeNotifier create() => QrCodeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QrCodeModel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QrCodeModel>(value),
    );
  }
}

String _$qrCodeNotifierHash() => r'4239c6c9763585102c0f9648b85f9df23e1ff05a';

/// QrCode Provider - 使用 @riverpod 注解

abstract class _$QrCodeNotifier extends $Notifier<QrCodeModel> {
  QrCodeModel build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<QrCodeModel, QrCodeModel>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<QrCodeModel, QrCodeModel>,
              QrCodeModel,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

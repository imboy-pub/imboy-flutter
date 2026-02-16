// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_login_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// QR 码登录状态管理

@ProviderFor(QRLogin)
final qRLoginProvider = QRLoginProvider._();

/// QR 码登录状态管理
final class QRLoginProvider extends $NotifierProvider<QRLogin, QRLoginState> {
  /// QR 码登录状态管理
  QRLoginProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'qRLoginProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$qRLoginHash();

  @$internal
  @override
  QRLogin create() => QRLogin();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QRLoginState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QRLoginState>(value),
    );
  }
}

String _$qRLoginHash() => r'c4e3b2a1d0f9e8d7c6b5a4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b7c6d5e4';

/// QR 码登录状态管理

abstract class _$QRLogin extends $Notifier<QRLoginState> {
  QRLoginState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<QRLoginState, QRLoginState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<QRLoginState, QRLoginState>,
              QRLoginState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

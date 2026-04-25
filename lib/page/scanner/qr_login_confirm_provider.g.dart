// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_login_confirm_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// QR 登录确认状态 Notifier。
///
/// 典型生命周期：
/// ```
/// container.read(qrLoginConfirmProvider)            // → Idle
///   → notifier.scan('token')                        // → Scanning → AwaitingConfirm
///   → notifier.confirm('token')                     // → Confirming → Success
///   或 → notifier.cancelByMe()                      // → CancelledByMe
/// ```

@ProviderFor(QrLoginConfirm)
final qrLoginConfirmProvider = QrLoginConfirmProvider._();

/// QR 登录确认状态 Notifier。
///
/// 典型生命周期：
/// ```
/// container.read(qrLoginConfirmProvider)            // → Idle
///   → notifier.scan('token')                        // → Scanning → AwaitingConfirm
///   → notifier.confirm('token')                     // → Confirming → Success
///   或 → notifier.cancelByMe()                      // → CancelledByMe
/// ```
final class QrLoginConfirmProvider
    extends $NotifierProvider<QrLoginConfirm, QrLoginConfirmState> {
  /// QR 登录确认状态 Notifier。
  ///
  /// 典型生命周期：
  /// ```
  /// container.read(qrLoginConfirmProvider)            // → Idle
  ///   → notifier.scan('token')                        // → Scanning → AwaitingConfirm
  ///   → notifier.confirm('token')                     // → Confirming → Success
  ///   或 → notifier.cancelByMe()                      // → CancelledByMe
  /// ```
  QrLoginConfirmProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'qrLoginConfirmProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$qrLoginConfirmHash();

  @$internal
  @override
  QrLoginConfirm create() => QrLoginConfirm();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QrLoginConfirmState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QrLoginConfirmState>(value),
    );
  }
}

String _$qrLoginConfirmHash() => r'7389ba81d6dc97a359ec53c23d87c47c3d756f4e';

/// QR 登录确认状态 Notifier。
///
/// 典型生命周期：
/// ```
/// container.read(qrLoginConfirmProvider)            // → Idle
///   → notifier.scan('token')                        // → Scanning → AwaitingConfirm
///   → notifier.confirm('token')                     // → Confirming → Success
///   或 → notifier.cancelByMe()                      // → CancelledByMe
/// ```

abstract class _$QrLoginConfirm extends $Notifier<QrLoginConfirmState> {
  QrLoginConfirmState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<QrLoginConfirmState, QrLoginConfirmState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<QrLoginConfirmState, QrLoginConfirmState>,
              QrLoginConfirmState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

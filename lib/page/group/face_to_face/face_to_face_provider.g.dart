// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'face_to_face_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 面对面建群 Notifier

@ProviderFor(FaceToFaceNotifier)
final faceToFaceProvider = FaceToFaceNotifierProvider._();

/// 面对面建群 Notifier
final class FaceToFaceNotifierProvider
    extends $NotifierProvider<FaceToFaceNotifier, FaceToFaceState> {
  /// 面对面建群 Notifier
  FaceToFaceNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'faceToFaceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$faceToFaceNotifierHash();

  @$internal
  @override
  FaceToFaceNotifier create() => FaceToFaceNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FaceToFaceState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FaceToFaceState>(value),
    );
  }
}

String _$faceToFaceNotifierHash() =>
    r'f310e6a57792c3b0868294fa5ec1f126b2116499';

/// 面对面建群 Notifier

abstract class _$FaceToFaceNotifier extends $Notifier<FaceToFaceState> {
  FaceToFaceState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<FaceToFaceState, FaceToFaceState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FaceToFaceState, FaceToFaceState>,
              FaceToFaceState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

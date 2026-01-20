// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_gallery.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ImageGalleryNotifier)
final imageGalleryProvider = ImageGalleryNotifierProvider._();

final class ImageGalleryNotifierProvider
    extends $NotifierProvider<ImageGalleryNotifier, ImageGalleryState> {
  ImageGalleryNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imageGalleryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imageGalleryNotifierHash();

  @$internal
  @override
  ImageGalleryNotifier create() => ImageGalleryNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImageGalleryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImageGalleryState>(value),
    );
  }
}

String _$imageGalleryNotifierHash() =>
    r'9dbc03dd234c63d3d8933aec42f79b8275077838';

abstract class _$ImageGalleryNotifier extends $Notifier<ImageGalleryState> {
  ImageGalleryState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ImageGalleryState, ImageGalleryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ImageGalleryState, ImageGalleryState>,
              ImageGalleryState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

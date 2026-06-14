import 'package:flutter/widgets.dart';

enum MediaType { image, video, audio, any }

final class PickedMedia {
  const PickedMedia({required this.path, required this.type, this.thumbnail});
  final String path;
  final MediaType type;
  final String? thumbnail;
}

// UI-triggering capabilities require BuildContext — callers hold the context.
abstract interface class MediaPickerCapability {
  Future<List<PickedMedia>> pickImages(
    BuildContext context, {
    int maxCount = 9,
    bool allowCamera = true,
  });
  Future<PickedMedia?> pickVideo(BuildContext context, {Duration? maxDuration});
  Future<PickedMedia?> pickSingle(BuildContext context, MediaType type);
}

import 'package:material_ui/material_ui.dart';

/// Keep PhotoView's loading dimensions and download progress while using the
/// same Material theme as the surrounding image preview.
Widget buildPhotoViewLoading(BuildContext context, ImageChunkEvent? event) {
  final expectedBytes = event?.expectedTotalBytes;
  final loadedBytes = event?.cumulativeBytesLoaded;
  final value = loadedBytes != null && expectedBytes != null
      ? loadedBytes / expectedBytes
      : null;
  return Center(
    child: SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(value: value),
    ),
  );
}

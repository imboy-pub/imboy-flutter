import 'package:mime/mime.dart';

/// Native gallery exports can give an image a misleading file extension.
/// Prefer recognized file signatures, retaining extension fallback for text.
String resolveUploadMime(String filename, List<int> bytes) =>
    lookupMimeType(filename, headerBytes: bytes) ?? 'application/octet-stream';

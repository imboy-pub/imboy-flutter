import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart' as mime;

class CsUnsupportedSeatAttachment implements Exception {}

/// 文件超过服务端单文件上限（25 MiB）或为空。
///
/// 与 [CsUnsupportedSeatAttachment] 分开：上限是「换个小文件即可」，
/// 类型不成立是「换一种格式」，两者都不该被展示成「上传失败，请重试」。
class CsOversizeSeatAttachment implements Exception {}

/// 坐席附件 MIME 白名单——与后端逐项对齐。
///
/// 真源：`imboy/src/features/enterprise_business/application/asset/
/// eb_asset_content.erl` 的 `?ALLOWED_MIMES`。服务端不在表内一律 422
/// `invalid_mime`，客户端重试同一文件永远不会成功，因此在准备阶段就拒绝，
/// 并给出「暂不支持该文件类型」的可解释提示。
///
/// 收录口径是「市面常见的图片/视频/音频/文档/压缩包」，且每个类型在服务端
/// 都有可机械复核的魔数规则。刻意**不含**：
///   * `text/html`（附件回显可变成同源页面）、
///   * `application/vnd.android.package-archive` 等可执行体（IM 派发安装包）、
///   * `application/octet-stream`（会让白名单退化为恒真）。
/// 扩表纪律：本集合与 `eb_asset_content.erl` 的 `?ALLOWED_MIMES` 必须同步，
/// 服务端已有「每个 MIME 必须有正负例」的可执行断面兜底。
const Set<String> kSeatAttachmentAllowedMimes = {
  // 静态图
  'image/png',
  'image/jpeg',
  'image/gif',
  'image/webp',
  'image/bmp',
  'image/svg+xml',
  'image/tiff',
  'image/avif',
  'image/x-icon',
  'image/heic',
  'image/heif',
  'image/vnd.adobe.photoshop',
  'image/vnd.dwg',
  // 视频
  'video/mp4',
  'video/webm',
  'video/quicktime',
  'video/x-matroska',
  'video/x-msvideo',
  'video/mpeg',
  'video/x-ms-wmv',
  'video/x-flv',
  'video/3gpp',
  'video/x-m4v',
  // 音频
  'audio/mpeg',
  'audio/mp4',
  'audio/aac',
  'audio/wav',
  'audio/x-wav',
  'audio/ogg',
  'audio/flac',
  'audio/x-flac',
  // 文档
  'application/pdf',
  'text/plain',
  'text/markdown',
  'text/csv',
  'application/json',
  'application/xml',
  'text/xml',
  'application/msword',
  'application/vnd.ms-excel',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'application/vnd.oasis.opendocument.text',
  'application/vnd.oasis.opendocument.spreadsheet',
  'application/vnd.oasis.opendocument.presentation',
  'application/epub+zip',
  'application/rtf',
  'text/rtf',
  // 压缩包
  'application/zip',
  'application/x-zip-compressed',
  'application/x-7z-compressed',
  'application/gzip',
  'application/x-rar-compressed',
  'application/vnd.rar',
  'application/x-tar',
  'application/x-bzip2',
  'application/x-xz',
};

/// mime 包的兜底缺口：`media_types.g.dart` 里没有 `gz`/`tgz` 的扩展名映射，
/// 也没有 gzip/xz 的魔数，只靠包会把 .gz 判成「不支持」。这里补两条**最窄**
/// 的前缀规则，仍然只覆盖白名单内的类型。
const Map<String, List<int>> _kMagicFallbacks = {
  'application/gzip': [0x1F, 0x8B],
  'application/x-xz': [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00],
};

/// 服务端单文件上限（`eb_asset_content:?MAX_SIZE_BYTES`）。
const int kSeatAttachmentMaxBytes = 25 * 1024 * 1024;

class CsPreparedSeatAttachment {
  final String mime, fileName;
  final Uint8List bytes;
  const CsPreparedSeatAttachment(this.mime, this.fileName, this.bytes);
}

/// Attachment preparation stops at every asynchronous boundary before any write.
class CsSessionAttachmentPreparation {
  CsSessionAttachmentPreparation({
    Future<List<PlatformFile>> Function()? pickFiles,
    Future<Uint8List> Function(File)? readHead,
    Future<Uint8List> Function(File)? readBytes,
    Future<int> Function(File)? readLength,
  }) : _pick = pickFiles ?? _pickFiles,
       _head = readHead ?? _readHead,
       _bytes = readBytes ?? _readBytes,
       _length = readLength ?? _readLength;
  final Future<List<PlatformFile>> Function() _pick;
  final Future<Uint8List> Function(File) _head, _bytes;
  final Future<int?> Function(File) _length;

  Future<CsPreparedSeatAttachment?> prepare({
    required bool Function() canWrite,
  }) async {
    if (!canWrite()) return null;
    final files = await _pick();
    if (!canWrite() || files.length != 1 || files.single.path == null) {
      return null;
    }
    final picked = files.single, file = File(files.single.path!);
    // 先判大小再读字节：超限文件不进内存，也不发任何请求。
    // 读不到长度（已删除/云端占位）时不在这里否决，交给读后的字节长度兜底。
    final size = await _length(file);
    if (!canWrite()) return null;
    if (size != null && (size <= 0 || size > kSeatAttachmentMaxBytes)) {
      throw CsOversizeSeatAttachment();
    }
    final header = await _head(file);
    if (!canWrite()) return null;
    final detected = _detect(picked.path!, header);
    if (detected == null) throw CsUnsupportedSeatAttachment();
    final bytes = await _bytes(file);
    if (!canWrite()) return null;
    if (bytes.isEmpty || bytes.length > kSeatAttachmentMaxBytes) {
      throw CsOversizeSeatAttachment();
    }
    return CsPreparedSeatAttachment(detected, picked.name, bytes);
  }

  /// 选一个「服务端会接受、且与内容不冲突」的 mime。
  ///
  /// 顺序：内容魔数 → 扩展名 → 本文件补的极小魔数兜底（见 [_kMagicFallbacks]）。
  /// 不只用魔数的原因：mime 包的魔数表比扩展名表**窄**——EBML 头被统一认成
  /// `audio/weba`，`.webm`/`.mkv` 一律落到它下面而判成「不支持」。服务端在
  /// PUT 时仍会用声明 mime 复核内容魔数，所以「客户端选哪个 mime」放宽
  /// 不构成内容伪造面：选错只会在服务端 415/422 被拦。
  static String? _detect(String path, Uint8List header) {
    final byContent = mime.lookupMimeType(path, headerBytes: header);
    if (byContent != null && kSeatAttachmentAllowedMimes.contains(byContent)) {
      return byContent;
    }
    final byName = mime.lookupMimeType(path);
    if (byName != null && kSeatAttachmentAllowedMimes.contains(byName)) {
      return byName;
    }
    for (final entry in _kMagicFallbacks.entries) {
      if (_hasPrefix(header, entry.value)) return entry.key;
    }
    return null;
  }

  static bool _hasPrefix(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  static Future<List<PlatformFile>> _pickFiles() =>
      FilePicker.pickFiles(type: FileType.any);
  static Future<Uint8List> _readBytes(File file) => file.readAsBytes();
  static Future<int?> _readLength(File file) async {
    try {
      return await file.length();
    } on FileSystemException {
      return null;
    }
  }

  static Future<Uint8List> _readHead(File file) async {
    final length = await file.length();
    if (length <= 0) return Uint8List(0);
    final raf = await file.open(mode: FileMode.read);
    try {
      return await raf.read(length > 64 ? 64 : length);
    } finally {
      await raf.close();
    }
  }
}

part of 'talk_record_no_ffmpeg_gate_test.dart';

// ---------------------------------------------------------------------------
// NC-3：静态扫描设施
// ---------------------------------------------------------------------------

/// FFmpeg 家族 token（库名/CLI/FFI so 名全覆盖：ffmpeg/ffprobe/ffplay、
/// libav*、avcodec/avformat/avfilter/avutil、swscale/swresample）。
final RegExp kBannedFfmpegTokens = RegExp(
  r'ffmpeg|ffprobe|ffplay|libav|avcodec|avformat|avfilter|avutil|swscale|swresample',
  caseSensitive: false,
);

/// talk_record 音频链内禁止外部进程派生（合同：App 合成是纯 Dart 字节
/// 拼接，不起 ffmpeg/外部二进制）。
final RegExp kProcessSpawn = RegExp(r'\bProcess\s*\.');

/// talk_record 音频链内禁止 FFI 绑定。
final RegExp kDartFfiImport = RegExp(r'dart:ffi');

/// Dart 注释剥除（保留换行与字符串内容）。
///
/// 覆盖：行注释 //、块注释 /* */、普通/三引号字符串、原始字符串 r''/r""。
/// 已知限制：字符串插值内的内容按字符串保留（宁可多扫不漏扫）。
/// 换行原样保留，违规定位可到 file:line。
String stripDartComments(String source) {
  final out = StringBuffer();
  const code = 0, lineComment = 1, blockComment = 2;
  const sq = 3, dq = 4, tsq = 5, tdq = 6, rawSq = 7, rawDq = 8;
  var state = code;
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    final two = i + 1 < source.length ? source.substring(i, i + 2) : '';
    final three = i + 2 < source.length ? source.substring(i, i + 3) : '';
    if (state == code) {
      if (two == '//') {
        state = lineComment;
        out.write('  ');
        i += 2;
      } else if (two == '/*') {
        state = blockComment;
        out.write('  ');
        i += 2;
      } else if (three == "'''") {
        state = tsq;
        out.write('   ');
        i += 3;
      } else if (three == '"""') {
        state = tdq;
        out.write('   ');
        i += 3;
      } else if (two == "r'") {
        state = rawSq;
        out.write('  ');
        i += 2;
      } else if (two == 'r"') {
        state = rawDq;
        out.write('  ');
        i += 2;
      } else if (c == "'") {
        state = sq;
        out.write(c);
        i++;
      } else if (c == '"') {
        state = dq;
        out.write(c);
        i++;
      } else {
        out.write(c);
        i++;
      }
    } else if (state == lineComment) {
      if (c == '\n' || c == '\r') {
        state = code;
        out.write(c);
      } else {
        out.write(' ');
      }
      i++;
    } else if (state == blockComment) {
      if (two == '*/') {
        state = code;
        out.write('  ');
        i += 2;
      } else {
        out.write(c == '\n' || c == '\r' ? c : ' ');
        i++;
      }
    } else if (state == sq) {
      if (c == r'\') {
        out.write('  ');
        i += 2;
      } else {
        if (c == "'") state = code;
        out.write(c);
        i++;
      }
    } else if (state == dq) {
      if (c == r'\') {
        out.write('  ');
        i += 2;
      } else {
        if (c == '"') state = code;
        out.write(c);
        i++;
      }
    } else if (state == tsq) {
      if (three == "'''") {
        state = code;
        out.write('   ');
        i += 3;
      } else {
        out.write(c);
        i++;
      }
    } else if (state == tdq) {
      if (three == '"""') {
        state = code;
        out.write('   ');
        i += 3;
      } else {
        out.write(c);
        i++;
      }
    } else {
      // rawSq / rawDq：无转义，引号即结束。
      if ((state == rawSq && c == "'") || (state == rawDq && c == '"')) {
        state = code;
      }
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

/// YAML（pubspec）# 注释剥除。
String stripYamlComments(String source) => source
    .split('\n')
    .map((line) {
      final hash = line.indexOf('#');
      return hash < 0 ? line : line.substring(0, hash);
    })
    .join('\n');

/// 在剥除后的内容里按行找违规，返回 file:line 明细。
List<String> findBannedLines(String path, String stripped) {
  final out = <String>[];
  final lines = stripped.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final match = kBannedFfmpegTokens.firstMatch(lines[i]);
    if (match != null) {
      out.add('$path:${i + 1}: "${match.group(0)}"');
    }
  }
  return out;
}

/// pubspec.lock 包名（`name: xxx` 行）。
List<String> lockPackageNames(String stripped) => stripped
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.startsWith('name: '))
    .map((line) => line.substring('name: '.length).trim())
    .toList();

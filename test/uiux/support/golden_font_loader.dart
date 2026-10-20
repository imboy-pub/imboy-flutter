/// T05.a 视觉（金图）字体与环境冻结 — imboy-enterprise-uiux-v1
///
/// 只登记与校验本地已有的授权字体资产（路径 + sha256 + 来源许可），
/// 不分发、不下载任何系统字体。字体缺失 / hash 不匹配 / Ahem 假字体
/// 一律返回 [GoldenFontStatus.visualBlocked]：仅阻塞视觉验收，
/// 不影响结构/交互测试（STRUCTURE_ENV.md）。
///
/// 与结构环境的边界：本文件不参与任何结构测试挂载；金图只在
/// [goldenEnvironmentHash] 完全一致的环境间比较（GOLDEN_ENV.md）。
library;

import 'dart:convert' show jsonEncode;
import 'dart:io' show File, Platform;
import 'dart:typed_data' show ByteData, Uint8List;

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/material.dart' show ThemeData;
import 'package:flutter/services.dart' show FontLoader;

/// 视觉字体解析结果。
enum GoldenFontStatus {
  /// 本地找到登记字体且通过全部校验（hash + cmap 覆盖）。
  ok,

  /// 缺字体 / hash 不匹配 / 疑似 Ahem：仅视觉验收被阻塞。
  visualBlocked,
}

/// 登记的字体资产（不分发：仅本地路径探测与 hash 校验）。
class GoldenFontAsset {
  final String path;
  final String sha256Hex;

  /// 来源与许可说明（登记用，不得省略）。
  final String licenseNote;

  const GoldenFontAsset({
    required this.path,
    required this.sha256Hex,
    required this.licenseNote,
  });
}

/// 候选资产（按序探测）。macOS 系统附带字体，仅本机测试使用、不随
/// 仓库分发；hash 是接受判据，跨机器漂移时按缺字体处理。
const List<GoldenFontAsset> kGoldenFontAssets = [
  GoldenFontAsset(
    path: '/Library/Fonts/Arial Unicode.ttf',
    // 探测登记 2026-10-19：macOS 附带，TrueType，cmap(3,1) format 4。
    sha256Hex:
        '876af2cd4854644e7f3e7feb2f688997fdb3343c6df6693611209c9dfb47ccec',
    licenseNote:
        'macOS system-bundled font (Arial Unicode MS); local test use only, '
        'not distributed with the repository. Full CJK coverage (BMP).',
  ),
];

/// 金图 fontFamily 名（FontLoader 注册名，与真实 App 字体无关）。
const String kGoldenFontFamily = 'UiuxGoldenFont';

/// 必需 CJK 码点：简体中文常用字样本 + 中文标点 + 全角符号 + 省略号。
/// 金图 fixture 中的全部中文样本必须落在此集合的覆盖验证范围内。
const List<int> kRequiredCjkCodepoints = <int>[
  0x4E2D, // 中
  0x6587, // 文
  0x6D4B, // 测
  0x8BD5, // 试
  0x9891, // 频
  0x9053, // 道
  0x6D88, // 消
  0x606F, // 息
  0x8054, // 联
  0x7CFB, // 系
  0x4F01, // 企
  0x4E1A, // 业
  0x59D3, // 姓
  0x540D, // 名
  0x91CD, // 重
  0x8F7D, // 载
  0x5931, // 失
  0x8D25, // 败
  0xFF0C, // ，
  0x3002, // 。
  0xFF01, // ！
  0xFF1F, // ？
  0xFF08, // （
  0xFF09, // ）
  0x3010, // 【
  0x3011, // 】
  0x3001, // 、
  0x2026, // …
];

/// emoji 显式策略：Arial Unicode 无彩色 emoji 字形，emoji 由系统
/// fallback（Apple Color Emoji）渲染，跨机器不可复现——金图 fixture
/// **禁止**包含任何 emoji 码点；未来确需 emoji 样张时必须先改本策略
/// 并登记确定性 fallback 字体，不得直接入图。
const String kEmojiPolicy =
    'forbidden-in-golden-fixtures: emoji fallback is not deterministic '
    'across machines (Apple Color Emoji); fixtures must not contain emoji '
    'codepoints; changing this requires a registered deterministic emoji '
    'font first.';

/// 用于策略自检的已知 emoji 样例（fixture 违规检测的输入，不是 fixture）。
const List<int> kKnownEmojiSampleCodepoints = <int>[
  0x1F600, // 😀
  0x1F642, // 🙂
  0x2764, // ❤
];

/// 字体解析结果。
class GoldenFontResolution {
  final GoldenFontStatus status;

  /// 命中的资产（status=ok 时非空）。
  final GoldenFontAsset? asset;

  /// 字体文件字节（status=ok 时非空，供 FontLoader 使用）。
  final ByteData? fontBytes;

  /// status=visualBlocked 时的人读原因。
  final String reason;

  const GoldenFontResolution({
    required this.status,
    this.asset,
    this.fontBytes,
    required this.reason,
  });
}

/// 解析本地字体资产：存在性 → sha256 → cmap 必需码点覆盖。
/// 任何一步失败都返回 [GoldenFontStatus.visualBlocked]，绝不静默
/// 降级为测试默认字体（Ahem）继续视觉比较。
GoldenFontResolution resolveGoldenFont() =>
    resolveGoldenFontFromAssets(kGoldenFontAssets);

/// [resolveGoldenFont] 的可注入核心（合同测试用合成资产覆盖
/// hash 不匹配 / 缺失分支；生产路径只走上面的常量清单）。
GoldenFontResolution resolveGoldenFontFromAssets(List<GoldenFontAsset> assets) {
  for (final GoldenFontAsset asset in assets) {
    final File file = File(asset.path);
    if (!file.existsSync()) continue;
    final Uint8List bytes = file.readAsBytesSync();
    final String digest = sha256.convert(bytes).toString();
    if (digest != asset.sha256Hex) {
      // hash 不匹配：可能是被替换/损坏/Ahem 假字体，一律拒绝。
      return GoldenFontResolution(
        status: GoldenFontStatus.visualBlocked,
        reason:
            'font hash mismatch at ${asset.path}: '
            'expected ${asset.sha256Hex}, got $digest',
      );
    }
    final String? missing = missingRequiredGlyphs(bytes);
    if (missing != null) {
      return GoldenFontResolution(
        status: GoldenFontStatus.visualBlocked,
        reason: 'font at ${asset.path} misses required glyphs: $missing',
      );
    }
    return GoldenFontResolution(
      status: GoldenFontStatus.ok,
      asset: asset,
      fontBytes: ByteData.sublistView(bytes),
      reason: 'ok',
    );
  }
  return const GoldenFontResolution(
    status: GoldenFontStatus.visualBlocked,
    reason: 'no registered golden font asset found on this machine',
  );
}

/// 图标字体资产（本机 Flutter SDK / pub 缓存路径；只登记不分发）。
const List<(String, String)> kGoldenIconFontAssets = <(String, String)>[
  (
    '/Users/leeyi/dev/flutter/bin/cache/artifacts/material_fonts/'
        'MaterialIcons-Regular.otf',
    'MaterialIcons',
  ),
  (
    '/Users/leeyi/.pub-cache/hosted/pub.dev/cupertino_icons-2.0.0/assets/'
        'CupertinoIcons.ttf',
    'CupertinoIcons',
  ),
];

/// 金图字体注册的 family 名清单（第四轮 review 修正）。
///
/// 应用文本的实际解析路径是 `ThemeManager._fallbackTextStyle` /
/// `ThemeNotifier.getTextStyle`：无主 family、`fontFamilyFallback` 为
/// `PingFang SC / Heiti SC / Microsoft YaHei / sans-serif`；Material 与
/// Cupertino 默认排版又分别命中 Roboto / CupertinoSystemText(.SF)。
/// 只注册 `UiuxGoldenFont` 单名时这些路径全部落空 → 测试默认字体
/// （Ahem）把中文渲染成方块。故同一份字节按命中名单多名注册。
const List<String> kGoldenFontApplyFamilies = <String>[
  kGoldenFontFamily,
  'Roboto',
  'PingFang SC',
  'Heiti SC',
  'Microsoft YaHei',
  'sans-serif',
  'CupertinoSystemText',
  'CupertinoSystemDisplay',
  '.SF Pro Text',
  '.SF Pro Display',
  '.SF UI Text',
  '.SF UI Display',
];

/// 把 [resolution] 的字体注册进测试绑定（真实可渲染）。
/// 仅 status=ok 时调用；否则抛 StateError（调用方契约错误）。
Future<void> loadGoldenFont(GoldenFontResolution resolution) async {
  if (resolution.status != GoldenFontStatus.ok ||
      resolution.fontBytes == null) {
    throw StateError(
      'loadGoldenFont called with non-ok resolution: ${resolution.reason}',
    );
  }
  for (final String family in kGoldenFontApplyFamilies) {
    final FontLoader loader = FontLoader(family);
    loader.addFont(Future<ByteData>.value(resolution.fontBytes));
    await loader.load();
  }
  // 图标字体（本机 SDK/包缓存资产，容错式：缺失时图标退化为方块，
  // golden 仍确定性）。P1-05 方向指示、P2-04 图标槽的视觉基线需要它。
  for (final (String path, String family) in kGoldenIconFontAssets) {
    final File f = File(path);
    if (!f.existsSync()) continue;
    final FontLoader loader = FontLoader(family);
    loader.addFont(
      Future<ByteData>.value(ByteData.sublistView(f.readAsBytesSync())),
    );
    await loader.load();
  }
}

/// [resolveGoldenFont] 结果能否进入视觉验收；缺字体的金图测试必须
/// 前置此判断并整体标记 VISUAL_BLOCKED（跳过图像比较而非报失败）。
bool goldenVisualAllowed(GoldenFontResolution resolution) =>
    resolution.status == GoldenFontStatus.ok;

/// Flutter 版本钉（取自 flutter --version；Dart 版本运行时读取，Flutter
/// 版本在测试内无 API，改为登记常量并写入 GOLDEN_ENV.md，升级 SDK 时
/// 必须同步更新此常量与 flutter-sdk resource key）。
const String kFlutterVersionPin = '3.47.7';

/// 环境清单（进入 [goldenEnvironmentHash] 的全部字段）。
/// 任何字段变化都必须改变 hash —— 金图只在 hash 一致的环境间比较。
Map<String, Object> goldenEnvironmentManifest({
  required GoldenFontResolution resolution,
  String flutterVersion = kFlutterVersionPin,
  String locale = 'zh-CN',
  double devicePixelRatio = 1.0,
}) {
  return <String, Object>{
    'fontSha256': resolution.asset?.sha256Hex ?? 'none',
    'fontFamily': resolution.status == GoldenFontStatus.ok
        ? kGoldenFontFamily
        : 'unavailable',
    'flutterVersion': flutterVersion,
    'dartVersion': Platform.version,
    'os': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    'locale': locale,
    'devicePixelRatio': devicePixelRatio,
    'animations': 'disabled',
    'clock': 'static-frame',
    'emojiPolicy': kEmojiPolicy,
  };
}

/// 环境 hash：字体或 SDK 任一变化都会改变输出。
String goldenEnvironmentHash({
  required GoldenFontResolution resolution,
  String flutterVersion = kFlutterVersionPin,
  String locale = 'zh-CN',
  double devicePixelRatio = 1.0,
}) {
  final String canonical = jsonEncode(
    goldenEnvironmentManifest(
      resolution: resolution,
      flutterVersion: flutterVersion,
      locale: locale,
      devicePixelRatio: devicePixelRatio,
    ),
  );
  return sha256.convert(canonical.codeUnits).toString();
}

/// 检查 [ttfBytes] 的 cmap(3,1) format 4 是否覆盖全部
/// [kRequiredCjkCodepoints]；全部覆盖返回 null，否则返回缺失码点描述。
/// 只查 BMP 子表（Arial Unicode 的 CJK 覆盖全在 BMP）。
String? missingRequiredGlyphs(Uint8List ttfBytes) {
  final Uint8List? subtable = _cmap31Format4Subtable(ttfBytes);
  if (subtable == null) return 'no cmap(3,1) format4 subtable found';
  final Set<int> covered = _coveredCodepoints(subtable);
  final List<int> missing = <int>[];
  for (final int cp in kRequiredCjkCodepoints) {
    if (!covered.contains(cp)) {
      missing.add(cp);
    }
  }
  if (missing.isEmpty) return null;
  return missing
      .map(
        (int cp) =>
            'U+${cp.toRadixString(16).toUpperCase().padLeft(4, '0')}(${String.fromCharCode(cp)})',
      )
      .join(', ');
}

// ---- 最小 TrueType cmap(3,1) format 4 解析（仅本文件使用） ----

int _u16(Uint8List b, int off) => (b[off] << 8) | b[off + 1];

int _u32(Uint8List b, int off) =>
    (b[off] << 24) | (b[off + 1] << 16) | (b[off + 2] << 8) | b[off + 3];

Uint8List? _cmap31Format4Subtable(Uint8List b) {
  if (b.length < 12 || _u32(b, 0) != 0x00010000) return null;
  final int numTables = _u16(b, 4);
  for (int i = 0; i < numTables; i++) {
    final int rec = 12 + i * 16;
    if (rec + 16 > b.length) return null;
    final int tag = _u32(b, rec);
    if (tag != 0x636D6170) continue; // 'cmap'
    final int cmapOff = _u32(b, rec + 8);
    if (cmapOff + 4 > b.length) return null;
    final int n = _u16(b, cmapOff + 2);
    for (int j = 0; j < n; j++) {
      final int e = cmapOff + 4 + j * 8;
      if (e + 8 > b.length) return null;
      final int pid = _u16(b, e);
      final int eid = _u16(b, e + 2);
      final int off = _u32(b, e + 4);
      if (pid == 3 && eid == 1) {
        final int st = cmapOff + off;
        if (st + 2 > b.length) return null;
        if (_u16(b, st) != 4) return null; // 仅支持 format 4
        final int length = _u16(b, st + 2);
        if (st + length > b.length) return null;
        return Uint8List.sublistView(b, st, st + length);
      }
    }
    return null;
  }
  return null;
}

/// 返回该 format 4 子表中映射到非 0 glyph id 的全部 BMP 码点。
/// 段总长 ≤ 0x10000，物化为 Set 一次性完成，之后 O(1) 查询。
Set<int> _coveredCodepoints(Uint8List st) {
  final int segCountX2 = _u16(st, 6);
  final int segCount = segCountX2 ~/ 2;
  int p = 14;
  final List<int> endCodes = <int>[];
  for (int i = 0; i < segCount; i++, p += 2) {
    endCodes.add(_u16(st, p));
  }
  p += 2; // reservedPad
  final List<int> startCodes = <int>[];
  for (int i = 0; i < segCount; i++, p += 2) {
    startCodes.add(_u16(st, p));
  }
  final List<int> idDeltas = <int>[];
  for (int i = 0; i < segCount; i++, p += 2) {
    idDeltas.add(_i16(st, p));
  }
  final List<int> idRangeOffsets = <int>[];
  for (int i = 0; i < segCount; i++, p += 2) {
    idRangeOffsets.add(_u16(st, p));
  }
  final int glyphArrayBase = p;

  final Set<int> covered = <int>{};
  for (int i = 0; i < segCount; i++) {
    if (endCodes[i] == 0xFFFF && startCodes[i] == 0xFFFF) continue;
    for (int cp = startCodes[i]; cp <= endCodes[i]; cp++) {
      final int ro = idRangeOffsets[i];
      int gid;
      if (ro == 0) {
        gid = (cp + idDeltas[i]) & 0xFFFF;
      } else {
        final int addr = glyphArrayBase + i * 2 + ro + (cp - startCodes[i]) * 2;
        if (addr + 1 >= st.length) continue;
        final int g = _u16(st, addr);
        gid = g == 0 ? 0 : (g + idDeltas[i]) & 0xFFFF;
      }
      if (gid != 0) covered.add(cp);
    }
  }
  return covered;
}

int _i16(Uint8List b, int off) {
  final int v = _u16(b, off);
  return v >= 0x8000 ? v - 0x10000 : v;
}

/// 把登记字体应用到主题（金图 pump 专用，第四轮 review 修正）。
///
/// AppTheme 本体不指定 fontFamily（跟随宿主系统字体），而 Flutter 测试
/// 环境的默认字体（Ahem）没有 CJK 字形——只 FontLoader 注册而不注入主题
/// 时，金图中的中文一律渲染为 tofu 方块（GOLDEN_COVERAGE_CORRECTION.md
/// 记录的缺陷）。金图 pump 必须经由本助手构造主题，确保文本真实落字形。
ThemeData applyGoldenFont(ThemeData theme) {
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: kGoldenFontFamily),
    primaryTextTheme: theme.primaryTextTheme.apply(
      fontFamily: kGoldenFontFamily,
    ),
  );
}

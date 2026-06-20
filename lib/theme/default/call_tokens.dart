import 'package:flutter/material.dart';

/// 音视频通话界面专用设计 token。
///
/// 通话叠层（半透明白/黑压在视频上、深色电影感渐变）不属于品牌调色板，
/// 但仍需集中管理避免散落硬编码。集中定义于 `lib/theme/`（design-tokens
/// 门禁豁免区），供通话页面统一引用。
class CallTokens {
  CallTokens._();

  // ── 基础叠层色（白/黑 + 命名色阶）────────────────────────────
  static const Color white = Colors.white;
  static const Color white24 = Colors.white24;
  static const Color white30 = Colors.white30;
  static const Color white38 = Colors.white38;
  static const Color white54 = Colors.white54;
  static const Color white60 = Colors.white60;
  static const Color white70 = Colors.white70;
  static const Color black = Colors.black;
  static const Color black54 = Colors.black54;

  // ── 半透明白（alpha 8/12/18/22%）────────────────────────────
  static const Color whiteA08 = Color(0x14FFFFFF);
  static const Color whiteA12 = Color(0x1FFFFFFF);
  static const Color whiteA18 = Color(0x2EFFFFFF);
  static const Color whiteA22 = Color(0x38FFFFFF);

  // ── 半透明黑（scrim，alpha 32/35/45/55/75/82%）──────────────
  static const Color blackA32 = Color(0x52000000);
  static const Color blackA35 = Color(0x59000000);
  static const Color blackA45 = Color(0x73000000);
  static const Color blackA55 = Color(0x8C000000);
  static const Color blackA75 = Color(0xBF000000);
  static const Color blackA82 = Color(0xD1000000);

  // ── 深色电影感背景/渐变 hex ─────────────────────────────────
  static const Color bgDeep = Color(0xFF0A1322); // 兜底/最深
  static const Color bg080E1A = Color(0xFF080E1A);
  static const Color bg0E1A2B = Color(0xFF0E1A2B);
  static const Color bg121E33 = Color(0xFF121E33);
  static const Color bg1A1A1A = Color(0xFF1A1A1A); // 摄像头关闭占位
  static const Color bg1C2B44 = Color(0xFF1C2B44);

  // ── 字号 ────────────────────────────────────────────────────
  static const double fs11 = 11;
  static const double fs12 = 12;
  static const double fs13 = 13;
  static const double fs15 = 15;
  static const double fs18 = 18;
  static const double fs26 = 26;
  static const double fs28 = 28;
}

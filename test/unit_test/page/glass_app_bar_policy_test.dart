// GlassAppBar 返回键策略守卫（源码级 ratchet）
//
// 背景（2026-09-15 用户报障）：频道内容详情页左上角没有返回上一页按钮。
// 根因不是「忘了写」，而是 `GlassAppBar.automaticallyImplyLeading` 的
// **默认值是 false**（lib/component/ui/common_bar.dart），只要调用点不显式
// 打开，被 push 进来的子页就永远长不出返回键——而且**不会有任何报错**，
// 静态分析也不会提示，只能靠人眼看出来。同日全仓排查又揪出 10 个文件
// 共 12 处同样的漏写（含 3 个「错误态页面无任何退路」）。
//
// 组件行为本身已由 common_bar_test.dart 覆盖；本文件补的是**页面级**契约：
// 让「漏写」在 CI 阶段就变红，而不是等用户点进去发现出不来。
//
// 两条规则：
//   R1 每个 `GlassAppBar(...)` 调用点必须**显式表态**：要么写
//      `automaticallyImplyLeading:`，要么提供 `leading:`。禁止「靠默认值」。
//   R2 显式写了 `automaticallyImplyLeading: false` 的，必须同时给
//      `leading:`（自定义返回/关闭入口）。否则该头部**没有任何返回入口**，
//      正是本次 bug 的形态。
//
// 为什么不做「是否被 push ⇒ 必须有返回键」的行为级全量测试：这些页面各自
// 依赖不同 provider（钱包 / 频道订单 / 搜索…），逐页 pump 的成本远高于收益，
// 且「被 push」本身要从 router 推导。故采用源码级契约 + 代表性页面行为测试
// （channel_article_page_test / channel_order_list_page_error_retry_test /
// channel_invitation_page_test）两层。
//
// 运行方式 / How to run:
//   flutter test test/unit_test/page/glass_app_bar_policy_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 单一调用点的解析结果。
class _Site {
  _Site(this.file, this.line, this.args);

  final String file;
  final int line;
  final String args;

  /// 顶层具名参数名（如 `title` / `automaticallyImplyLeading`）。
  late final Set<String> namedArgs = _topLevelNamedArgs(args);

  String get where => '$file:$line';
}

/// 取 `GlassAppBar(` 的参数文本（括号配平，跳过字符串内的括号）。
/// 返回 [(行号, 参数文本)]。
List<(int, String)> _callSites(String src) {
  final out = <(int, String)>[];
  final re = RegExp(r'\bGlassAppBar\s*\(');
  for (final m in re.allMatches(src)) {
    var depth = 0;
    var i = m.end - 1; // 指向 '('
    String? inStr;
    for (; i < src.length; i++) {
      final c = src[i];
      if (inStr != null) {
        if (c == r'\') {
          i++;
          continue;
        }
        if (c == inStr) inStr = null;
        continue;
      }
      if (c == "'" || c == '"') {
        inStr = c;
      } else if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
        if (depth == 0) break;
      }
    }
    final args = src.substring(m.end, i);
    // 跳过构造器定义本身（`const GlassAppBar({ super.key, ... })`）：
    // 具名参数声明块以 `{` 开头，而所有使用点都不会。
    if (args.trimLeft().startsWith('{')) continue;
    final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
    out.add((line, args));
  }
  return out;
}

/// 抽取**顶层**具名参数名（depth == 0 处的 `name:`），避免把嵌套子 widget
/// 的 `leading:` 误判成本 AppBar 的参数。
Set<String> _topLevelNamedArgs(String args) {
  final names = <String>{};
  var depth = 0;
  String? inStr;
  var i = 0;
  // 上一个非空白字符（用于判定 `:` 之前是标识符而非 `?:` 三元等）
  String prevSignificant = '';
  while (i < args.length) {
    final c = args[i];
    if (inStr != null) {
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (c == inStr) inStr = null;
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      inStr = c;
      i++;
      continue;
    }
    if (c == '(' || c == '[' || c == '{') {
      depth++;
      i++;
      continue;
    }
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      i++;
      continue;
    }
    if (c == ':' &&
        depth == 0 &&
        prevSignificant != '?' &&
        prevSignificant != ':') {
      // 向左回读标识符
      var j = i - 1;
      while (j >= 0 && (args[j] == ' ' || args[j] == '\n' || args[j] == '\t')) {
        j--;
      }
      final end = j + 1;
      while (j >= 0 && (RegExp(r'[A-Za-z0-9_]').hasMatch(args[j]))) {
        j--;
      }
      final name = args.substring(j + 1, end);
      if (name.isNotEmpty) names.add(name);
    }
    if (!RegExp(r'\s').hasMatch(c)) prevSignificant = c;
    i++;
  }
  return names;
}

void main() {
  late List<_Site> sites;

  setUpAll(() {
    final files = <File>[];
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      if (e.path.endsWith('.g.dart')) continue;
      files.add(e);
    }
    files.sort((a, b) => a.path.compareTo(b.path));

    sites = <_Site>[];
    for (final f in files) {
      final src = f.readAsStringSync();
      if (!src.contains('GlassAppBar')) continue;
      for (final (line, args) in _callSites(src)) {
        sites.add(_Site(f.path, line, args));
      }
    }
  });

  test('扫描器自身有效：确实扫到了全仓 GlassAppBar 调用点', () {
    // 防「扫描器坏了 ⇒ 零命中 ⇒ 全绿」的假绿。只设下界、不锁死精确值
    // （页面增删会让数量自然波动）。基线：2026-09-15 实测 75 处，
    // 与独立实现的 Python 扫描器逐一对齐过。
    expect(
      sites.length,
      greaterThanOrEqualTo(60),
      reason: 'lib/ 下 GlassAppBar 调用点异常稀少，扫描器可能已失效',
    );
    // 构造器定义本身必须被排除掉（它没有 automaticallyImplyLeading 具名参数）
    expect(
      sites
          .where((s) => s.where.endsWith('component/ui/common_bar.dart'))
          .length,
      0,
      reason: 'common_bar.dart 里只有 GlassAppBar 的构造器定义，不该被当成调用点',
    );
  });

  test('R1 每个 GlassAppBar 调用点都必须显式声明返回键策略', () {
    final offenders = sites
        .where(
          (s) =>
              !s.namedArgs.contains('automaticallyImplyLeading') &&
              !s.namedArgs.contains('leading'),
        )
        .map((s) => s.where)
        .toList();

    expect(
      offenders,
      isEmpty,
      reason:
          'GlassAppBar.automaticallyImplyLeading 默认是 false，靠默认值 = 该页'
          '左上角没有返回键（用户报过的「频道内容详情页回不去」就是这个）。'
          '请显式写 automaticallyImplyLeading: true（被 push 的子页）或提供 '
          'leading:（自定义入口）。',
    );
  });

  test('R2 显式关闭返回键时必须提供自定义 leading，杜绝无出口的头部', () {
    final offenders = sites
        .where(
          (s) =>
              s.namedArgs.contains('automaticallyImplyLeading') &&
              !s.namedArgs.contains('leading'),
        )
        .where(
          (s) =>
              RegExp(r'automaticallyImplyLeading\s*:\s*false').hasMatch(s.args),
        )
        .map((s) => s.where)
        .toList();

    expect(offenders, isEmpty, reason: '关闭了自动返回键又没给 leading：该头部没有任何返回/关闭入口。');
  });
}

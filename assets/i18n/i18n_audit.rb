#!/usr/bin/env ruby
# frozen_string_literal: true

# i18n_audit.rb — IMBoy slang 源文件审计器（assets/i18n/）。
#
# P1 加固点（相对旧版）：
# * locale 白名单：只有 LEGAL_LOCALES 里的目录算语言；点开头目录
#   （.dart_tool 等构建残留）静默忽略；其他未登记目录视为结构错误。
# * plural 感知键模型：`key(plural)` 节点与 zero/one/two/few/many/other
#   分支折叠为节点本身。locale 特有分支（如英语 one）不再误报 extra；
#   指向 plural 节点的 "@:ns.key" alias 不再误报缺失目标。
# * 参数键 `key(param)` / `key(plural)` 修饰符在逻辑键中剥除，
#   与 Dart 侧 `t.ns.key(...)` 调用形态对齐。
# * YAML 重复键检测：走 Psych 解析树（YAML.load 的同名后者覆盖前者，
#   静默丢数据，靠 load 是测不出来的）。
# * placeholder 归一化：$name / ${name} / {name} 都归一为参数名再比对。
# * 静态引用 + unused 分析：结果只给 candidate / unknown / indirect，
#   永不输出 confirmed_unused —— 删除属 P3/P4 裁决且必须人工确认。
#
# 用法：ruby i18n_audit.rb help
#
# check 退出码约定：
#   exit 1 —— 重复键 / 空值 / null / 非字符串叶子 / YAML 语法错误 /
#             placeholder 不一致 / 非法 alias / 真性 extra / 未登记 locale 目录
#   exit 0 —— 结构干净。missing / used_missing / unused 候选只作为信息项打印；
#             设 I18N_AUDIT_STRICT=1 时 missing 或 used_missing > 0 也判失败
#             （完整发布门，供 P16/P17 使用）。

require "yaml"
require "set"

I18N_ROOT = File.expand_path(ENV["I18N_AUDIT_ROOT"] || __dir__)
# I18N_ROOT 形如 <repo>/assets/i18n，仓库根是其上两级（assets 不是仓库根）
REPO_ROOT = File.expand_path(ENV["I18N_AUDIT_REPO_ROOT"] || File.join(I18N_ROOT, "..", ".."))

# 10 个合法产品 locale。新增语言必须同时更新 slang.yaml 与此清单。
LEGAL_LOCALES = %w[ar-SA de-DE en-US fr-FR it-IT ja-JP ko-KR ru-RU zh-CN zh-Hant].freeze
PLURAL_BRANCHES = %w[zero one two few many other].freeze
# 静态引用扫描根目录（相对仓库根），只扫 .dart 且排除 *.g.dart。
SCAN_DIRS = %w[lib test integration_test tool config].freeze

def slang_base_locale
  path = File.join(REPO_ROOT, "slang.yaml")
  cfg = YAML.safe_load_file(path, aliases: true)
  cfg.is_a?(Hash) && cfg["base_locale"].is_a?(String) ? cfg["base_locale"] : "zh-CN"
rescue StandardError
  "zh-CN"
end

BASE_LOCALE = slang_base_locale

# LocaleData: 一个 locale 的 plural 感知模型。
#   logical      —— 逻辑键 => String 叶子值 或 {branch=>String}（plural 节点）
#   plural_nodes —— plural 节点逻辑键集合
#   aliases      —— 逻辑键 => "@:target"（原样字符串）
#   empty/nulls/non_string/dups/errors —— 结构问题清单
LocaleData = Struct.new(:locale, :logical, :plural_nodes, :aliases, :leaf_count,
                        :empty, :nulls, :non_string, :dups, :errors,
                        keyword_init: true)

def split_key(raw)
  m = raw.match(/\A([^(]+?)\s*\(([^)]*)\)\s*\z/)
  m ? [m[1], m[2].strip] : [raw, nil]
end

# YAML 1.2 core schema 标量解析（与 Dart yaml 包对齐）。
# 仅对 PLAIN 风格生效；引号/字面量块一律为 String。
# 这是 Psych 1.1 类型化（把 on/off/yes/no 也变布尔）导致幽灵键问题的根治。
def yaml12_scalar(node)
  return node.value if node.style != Psych::Nodes::Scalar::PLAIN
  case node.value
  when "", "~", "null", "Null", "NULL" then nil
  when "true", "True", "TRUE" then true
  when "false", "False", "FALSE" then false
  when /\A[-+]?\d+\z/ then node.value.to_i
  when /\A[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][-+]?\d+)?\z/ then Float(node.value)
  when /\A[-+]?\.inf\z/i then node.value.start_with?("-") ? -Float::INFINITY : Float::INFINITY
  when /\A\.nan\z/i then Float::NAN
  else node.value
  end
rescue ArgumentError
  node.value
end

# 由 Psych 树构建数据：键名用原始文本（on 保持 "on"，不类型化为 true），
# 与 slang 实际解析行为一致。
def build_data(node)
  case node
  when Psych::Nodes::Document then build_data(node.root)
  when Psych::Nodes::Mapping
    node.children.each_slice(2).to_h { |k, v| [k.value.to_s, build_data(v)] }
  when Psych::Nodes::Sequence then node.children.map { |c| build_data(c) }
  when Psych::Nodes::Scalar then yaml12_scalar(node)
  else node.value
  end
end

def parse_yaml_file(path)
  tree = YAML.parse_file(path)
  dups = []
  walk = lambda do |node|
    case node
    when Psych::Nodes::Document then walk.call(node.root)
    when Psych::Nodes::Mapping
      seen = Hash.new(0)
      node.children.each_slice(2) do |k, _|
        seen[k.value] += 1 if k.respond_to?(:value) && !k.value.nil?
      end
      seen.each { |k, n| dups << k.to_s if n > 1 }
      node.children.each_slice(2) { |_, v| walk.call(v) }
    when Psych::Nodes::Sequence then node.children.each { |c| walk.call(c) }
    end
  end
  walk.call(tree)
  data = build_data(tree)
  [data, dups, nil]
rescue Psych::SyntaxError => e
  [nil, [], e.message]
end

def load_locale(locale)
  logical = {}
  plural_nodes = Set.new
  aliases = {}
  empty = []; nulls = []; non_string = []; dups = []; errors = []
  leaf_count = 0

  Dir.glob(File.join(I18N_ROOT, locale, "*.i18n.yaml")).sort.each do |f|
    ns = File.basename(f, ".i18n.yaml")
    data, file_dups, err = parse_yaml_file(f)
    dups.concat(file_dups.map { |k| "#{ns}.#{k}" })
    errors << "#{ns}.i18n.yaml: #{err}" if err
    next unless data.is_a?(Hash)

    walk = lambda do |node, prefix, plural_parent|
      node.each do |k, v|
        name, modifier = split_key(k.to_s)
        path = prefix.empty? ? name : "#{prefix}.#{name}"
        if v.is_a?(Hash)
          plural_nodes << path if modifier == "plural"
          walk.call(v, path, modifier == "plural")
          next
        end
        leaf_count += 1
        if plural_parent
          # prefix 即 plural 节点路径；分支叶子折叠进节点自身
          if PLURAL_BRANCHES.include?(name) && v.is_a?(String)
            (logical[prefix] ||= {})[name] = v
          else
            non_string << path
          end
        elsif modifier == "plural"
          non_string << "#{path} (scalar plural node)"
        elsif v.is_a?(String)
          if v.strip.empty? then empty << path
          elsif v.start_with?("@:") then aliases[path] = v
          end
          logical[path] = v
        elsif v.nil?
          nulls << path
        else
          non_string << "#{path} (#{v.class})"
        end
      end
    end
    walk.call(data, ns, false)
  end

  LocaleData.new(locale: locale, logical: logical, plural_nodes: plural_nodes,
                 aliases: aliases, leaf_count: leaf_count, empty: empty,
                 nulls: nulls, non_string: non_string, dups: dups, errors: errors)
end

# $name / ${name} / {name} 全部归一为参数名。
def placeholder_names(value)
  names = Set.new
  strs = case value
         when String then [value]
         when Hash then value.values.grep(String)
         else []
         end
  strs.each do |s|
    s.scan(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/) { |m| names << m[0] }
    s.scan(/\$([A-Za-z_][A-Za-z0-9_]*)/)    { |m| names << m[0] }
    s.scan(/\{([A-Za-z_][A-Za-z0-9_]*)\}/)  { |m| names << m[0] }
  end
  names
end

# 静态引用扫描：t.ns.key 形态（含 t.ns.key(args) 调用），把每条引用的
# 所有前缀都记为已引用（保守方向：宁可漏报 unused，不可误报可删）。
# t.ns[...] / t[...] 动态形态单独收集，命中命名空间内的 unused 候选
# 只能标 unknown。
def scan_refs
  static = Set.new
  dynamic_ns = Set.new
  dynamic_hits = []
  roots = ENV["I18N_AUDIT_SCAN_DIRS"]&.split(",") || SCAN_DIRS
  roots.select { |d| File.directory?(File.join(REPO_ROOT, d)) }.each do |root|
    Dir.glob(File.join(REPO_ROOT, root, "**", "*.dart")).each do |f|
      next if File.basename(f).end_with?(".g.dart")
      src = File.read(f, encoding: "UTF-8", invalid: :replace, undef: :replace)
      src.scan(/\bt(?:\.[A-Za-z0-9_]+)+/).each do |m|
        parts = m.delete_prefix("t.").split(".")
        parts.each_index { |i| static << parts.take(i + 1).join(".") }
      end
      # 别名访问器形态（如 final tr = translations ?? t 的可注入翻译模式）
      # 同样构成真实引用；unused 判定宁可多算 used（保守），不可漏算导致误删
      src.scan(/\btr(?:\.[A-Za-z0-9_]+)+/).each do |m|
        parts = m.delete_prefix("tr.").split(".")
        parts.each_index { |i| static << parts.take(i + 1).join(".") }
      end
      src.scan(/\bt(?:\.[A-Za-z0-9_]+)*\s*\[/).each do |m|
        # 排除转义序列（如字符串中的 \t[）与测试代码里的同名变量
        # （slang 的 t 类没有 [] 操作符，可编译的 t[...] 必然不是翻译对象；
        #  但 test/ 里的巧合命中不构成生产动态键风险，也不影响 unused 判定）
        next if m.include?("\\")
        next if root.include?("test")
        segs = m.sub(/\s*\[\z/, "").delete_prefix("t.").split(".").reject(&:empty?)
        dynamic_ns << (segs.empty? ? "*" : segs.first)
        dynamic_hits << "#{root}/#{File.basename(f)}: #{m}"
      end
    end
  end
  [static, dynamic_ns, dynamic_hits]
end

def discover_locales
  legal = []; ignored = []; unknown = []
  Dir.children(I18N_ROOT).sort.each do |name|
    full = File.join(I18N_ROOT, name)
    next unless File.directory?(full)
    if name.start_with?(".") then ignored << name
    elsif LEGAL_LOCALES.include?(name) then legal << name
    else unknown << name
    end
  end
  [legal.sort, ignored.sort, unknown.sort]
end

def placeholder_diff(base, loc)
  base.logical.keys.filter_map do |k|
    lv = loc.logical[k]
    next if lv.nil?
    k unless placeholder_names(base.logical[k]) == placeholder_names(lv)
  end
end

def illegal_aliases(loc)
  loc.aliases.filter_map do |k, v|
    target = v.delete_prefix("@:")
    # 仓库惯例是绝对路径 @:ns.key；同文件相对目标按键所在 ns 兜底解析
    resolved = loc.logical.key?(target) || loc.logical.key?("#{k.split('.').first}.#{target}")
    k unless resolved
  end
end

def per_locale_diffs(base, loc, refs_static)
  missing = base.logical.keys - loc.logical.keys
  extra = loc.logical.keys - base.logical.keys
  used_missing = missing.select { |k| refs_static.include?(k) }
  [missing, extra, used_missing]
end

def classify_unused(base, refs_static, dynamic_ns)
  alias_targets = Set.new
  base.aliases.each do |k, v|
    t = v.delete_prefix("@:")
    # 相对目标按键所在 ns 兜底解析（与 illegal_aliases 同规则）
    t = "#{k.split('.').first}.#{t}" unless base.logical.key?(t)
    alias_targets << t
  end
  base.logical.keys.reject { |k| refs_static.include?(k) }.map do |k|
    ns = k.split(".").first
    cls = if alias_targets.include?(k)
            "indirect"
          elsif dynamic_ns.include?("*") || dynamic_ns.include?(ns)
            "unknown"
          else
            "candidate"
          end
    [k, cls]
  end
end

def fmt_missing(loc, keys)
  limit = (ENV["LIST"] || "0").to_i
  head = keys.take(limit).map { |k| "    #{loc}  #{k}" }
  (["  #{loc} missing=#{keys.size}"] + head + (keys.size > limit && limit.positive? ? ["    ..."] : []))
end

# ---------------------------------------------------------------- modes ----

def mode_help
  puts <<~TEXT
    Usage: ruby i18n_audit.rb <mode> [args]
      check                  结构门禁（重复/空值/占位符/alias/extra/未登记 locale）
                             I18N_AUDIT_STRICT=1 时 missing/used_missing 也判失败
      summary                每 locale 概览（仅白名单 locale）
      refs                   静态 t.* 引用扫描统计
      missing <locale>       列出该 locale 缺失键 + zh-CN 源文案（tab 分隔）
      unused [LIST=n]        无静态引用的 base 键分类（candidate/unknown/indirect）
                             I18N_AUDIT_JSON=1 时输出 JSON
      aliases                alias 报告（plural 感知）
      untranslated [locale]  与某 Han 基准同值的未翻译残留
      unexpected-scripts     字符脚本白名单违例
      longest <locale>       最长文案 TOP N（TOP=n）
      spaces <locale>        首尾空白检查
      help
    Env: I18N_AUDIT_ROOT / I18N_AUDIT_REPO_ROOT（测试夹具用）,
         I18N_AUDIT_STRICT, I18N_AUDIT_SCAN_DIRS, LIST, TOP, I18N_AUDIT_JSON
  TEXT
end

def mode_summary(base, legal, ignored)
  puts "BASE=#{BASE_LOCALE} keys=#{base.logical.size} leaves=#{base.leaf_count}"
  puts "ignored dirs: #{ignored.join(', ')}" unless ignored.empty?
  legal.each do |loc|
    next if loc == BASE_LOCALE
    d = load_locale(loc)
    missing = base.logical.keys - d.logical.keys
    extra = d.logical.keys - base.logical.keys
    ph = placeholder_diff(base, d)
    same = base.logical.count { |k, bv| d.logical[k] == bv }
    han = d.logical.count { |_, v| v.is_a?(String) && v.match?(/\p{Han}/) }
    latin = d.logical.count { |_, v| v.is_a?(String) && v.match?(/[A-Za-z]/) }
    cyr = d.logical.count { |_, v| v.is_a?(String) && v.match?(/\p{Cyrillic}/) }
    arb = d.logical.count { |_, v| v.is_a?(String) && v.match?(/\p{Arabic}/) }
    puts [
      loc.ljust(10),
      "keys=#{d.logical.size.to_s.ljust(5)}",
      "missing=#{missing.size.to_s.ljust(4)}",
      "extra=#{extra.size.to_s.ljust(4)}",
      "placeholder_mismatch=#{ph.size.to_s.ljust(3)}",
      "same_as_base=#{same.to_s.ljust(5)}",
      "empty=#{d.empty.size + d.nulls.size}",
      "han=#{han} latin=#{latin} cyrillic=#{cyr} arabic=#{arb}"
    ].join(" ")
  end
end

def mode_check(base, legal, ignored, unknown)
  refs_static, dynamic_ns, dynamic_hits = scan_refs
  failures = [] # [category, message]
  unknown.each { |d| failures << ["locale", "unregistered locale directory: #{d} — 加入 LEGAL_LOCALES 或移除"] }
  unless LEGAL_LOCALES.include?(BASE_LOCALE)
    failures << ["locale", "base locale #{BASE_LOCALE} 不在白名单"]
  end

  per_locale_missing = {}
  legal.each do |loc|
    d = load_locale(loc)
    d.errors.each  { |e| failures << ["yaml", "#{loc}: #{e}"] }
    d.dups.each    { |k| failures << ["duplicate", "#{loc}: #{k}"] }
    d.empty.each   { |k| failures << ["empty", "#{loc}: #{k}"] }
    d.nulls.each   { |k| failures << ["null", "#{loc}: #{k}"] }
    d.non_string.each { |k| failures << ["non_string", "#{loc}: #{k}"] }
    illegal_aliases(d).each { |k| failures << ["alias", "#{loc}: #{k}"] }
    next if loc == BASE_LOCALE
    missing, extra, used_missing = per_locale_diffs(base, d, refs_static)
    per_locale_missing[loc] = [missing.size, used_missing.size]
    placeholder_diff(base, d).each { |k| failures << ["placeholder", "#{loc}: #{k}"] }
    extra.each { |k| failures << ["extra", "#{loc}: #{k}（plural 分支之外的多余键）"] }
  end

  unused = classify_unused(base, refs_static, dynamic_ns)
  miss_total = per_locale_missing.values.sum(&:first)
  usedmiss_total = per_locale_missing.values.sum(&:last)

  puts "== i18n audit check =="
  puts "locales: #{legal.size} legal | ignored: #{ignored.empty? ? '-' : ignored.join(', ')} | base=#{BASE_LOCALE}"
  cats = failures.group_by(&:first).transform_values(&:count)
  if failures.empty?
    puts "structural: duplicate=0 empty=0 null=0 non_string=0 syntax=0 placeholder=0 illegal_alias=0 extra=0 unknown_locale=0"
  else
    puts "structural defects:"
    failures.first(40).each { |c, m| puts "  [#{c}] #{m}" }
    puts "  ... total=#{failures.size}" if failures.size > 40
  end
  puts "INFO missing=#{miss_total} used_missing=#{usedmiss_total} slots（信息项，非结构缺陷）"
  per_locale_missing.sort.each { |loc, (m, um)| puts "INFO   #{loc.ljust(10)} missing=#{m} used_missing=#{um}" }
  puts "INFO unused classification: candidate=#{unused.count { |_, c| c == 'candidate' }} " \
       "unknown=#{unused.count { |_, c| c == 'unknown' }} indirect=#{unused.count { |_, c| c == 'indirect' }} " \
       "（candidate ≠ confirmed_unused，删除须 P3/P4 人工裁决）"
  puts "INFO dynamic access risk: #{dynamic_hits.size} hit(s)#{dynamic_hits.first(3).map { |h| "  #{h}" }.join}"
  strict = ENV["I18N_AUDIT_STRICT"] == "1"
  if strict && (miss_total.positive? || usedmiss_total.positive? || dynamic_hits.any?)
    puts "RESULT: FAIL (strict: missing/used_missing/dynamic > 0)"
    exit 1
  elsif failures.empty?
    puts "RESULT: PASS#{strict ? ' (strict)' : ''} —— 结构门通过；missing 为信息项，完整发布门用 I18N_AUDIT_STRICT=1"
    exit 0
  else
    puts "RESULT: FAIL (#{failures.size} structural defect(s))"
    exit 1
  end
end

def mode_refs
  refs, dynamic_ns, hits = scan_refs
  puts "static ref prefixes: #{refs.size}"
  puts "dynamic access: #{hits.size} hit(s), namespaces: #{dynamic_ns.to_a.join(',')}"
  hits.first(10).each { |h| puts "  #{h}" }
end

# 列出某 locale 相对 base 缺失的逻辑键 + zh-CN 源文案（tab 分隔），
# 供 locale 专员逐键补译。
def mode_missing(base, target)
  abort "usage: ruby i18n_audit.rb missing <locale>" unless LEGAL_LOCALES.include?(target)
  d = load_locale(target)
  base.logical.sort.each do |k, bv|
    next if d.logical.key?(k)
    src = case bv
          when String then bv
          when Hash then bv.map { |b, s| "#{b}: #{s}" }.join(" | ")
          else bv.inspect
          end
    puts "#{k}\t#{src}"
  end
end

def mode_unused(base)
  refs, dynamic_ns, _ = scan_refs
  classified = classify_unused(base, refs, dynamic_ns)
  if ENV["I18N_AUDIT_JSON"] == "1"
    require "json"
    puts JSON.generate(classified.map { |k, c| { "key" => k, "class" => c } })
    return
  end
  counts = classified.group_by { |_, c| c }.transform_values(&:count)
  puts "unused (no static ref) total=#{classified.size} " \
       "candidate=#{counts['candidate'].to_i} unknown=#{counts['unknown'].to_i} indirect=#{counts['indirect'].to_i}"
  limit = (ENV["LIST"] || "12").to_i
  %w[candidate unknown indirect].each do |cls|
    keys = classified.select { |_, c| c == cls }.map(&:first)
    next if keys.empty?
    puts "#{cls} (#{keys.size}):"
    keys.take(limit).each { |k| puts "  #{k}" }
    puts "  ..." if keys.size > limit
  end
end

def mode_aliases
  legal, = discover_locales
  bad_total = 0
  legal.each do |loc|
    d = load_locale(loc)
    illegal = illegal_aliases(d)
    next if illegal.empty?
    bad_total += illegal.size
    puts "#{loc} missing_alias_targets count=#{illegal.size}"
    illegal.take((ENV["TOP"] || "12").to_i).each { |k| puts "  #{k} -> #{d.aliases[k]}" }
  end
  puts "aliases: all targets resolve (plural-aware)" if bad_total.zero?
end

def allowed_scripts_for(locale)
  case locale
  when /\Azh-/ then Set[:han, :latin]
  when /\Aja-/ then Set[:han, :latin]
  when /\Ako-/ then Set[:latin]
  when /\Aru-/ then Set[:cyrillic, :latin]
  when /\Aar-/ then Set[:arabic, :latin]
  else Set[:latin]
  end
end

def mode_unexpected_scripts
  legal, = discover_locales
  legal.each do |loc|
    d = load_locale(loc)
    allowed = allowed_scripts_for(loc)
    bad = d.logical.filter_map do |k, v|
      next unless v.is_a?(String)
      present = Set.new
      present << :han if v.match?(/\p{Han}/)
      present << :cyrillic if v.match?(/\p{Cyrillic}/)
      present << :arabic if v.match?(/\p{Arabic}/)
      present << :latin if v.match?(/[A-Za-z]/)
      k if !(present - allowed).empty?
    end
    next if bad.empty?
    puts "#{loc} unexpected_scripts count=#{bad.size}"
    bad.take((ENV["TOP"] || "12").to_i).each { |k| puts "  #{k}" }
  end
end

def mode_untranslated(base_locale)
  legal, = discover_locales
  cur_base = load_locale(base_locale)
  legal.each do |loc|
    next if loc == base_locale
    d = load_locale(loc)
    keys = cur_base.logical.filter_map do |k, bv|
      next unless bv.is_a?(String) && d.logical[k].is_a?(String)
      next if bv.start_with?("@:")
      next unless bv.match?(/\p{Han}/)
      k if d.logical[k] == bv
    end
    next if keys.empty?
    puts "#{loc} untranslated_from_#{base_locale} count=#{keys.size}"
    keys.take((ENV["TOP"] || "12").to_i).each { |k| puts "  #{k}" }
  end
end

def mode_longest(target)
  d = load_locale(target)
  rows = d.logical.filter_map { |k, v| v.is_a?(String) ? [k, v.size, v] : nil }
  rows.sort_by! { |(_, len, _)| -len }
  rows.take((ENV["TOP"] || "12").to_i).each { |k, len, v| puts "#{target} #{len} #{k}=#{v.inspect}" }
end

def mode_spaces(target)
  d = load_locale(target)
  leading = []; trailing = []
  d.logical.each do |k, v|
    next unless v.is_a?(String)
    leading << k if v.match?(/\A\s+/)
    trailing << k if v.match?(/\s+\z/)
  end
  puts "leading_space count=#{leading.size}"
  leading.take((ENV["TOP"] || "12").to_i).each { |k| puts "  #{k}" }
  puts "trailing_space count=#{trailing.size}"
  trailing.take((ENV["TOP"] || "12").to_i).each { |k| puts "  #{k}" }
end

# ----------------------------------------------------------------- main ----

mode = ARGV[0] || "summary"
legal, ignored, unknown = discover_locales

if mode == "help" || ARGV.empty?
  mode_help
  exit 0
end

unless LEGAL_LOCALES.include?(BASE_LOCALE) || mode == "check"
  abort "base locale #{BASE_LOCALE.inspect} 不在 LEGAL_LOCALES 白名单"
end
base = load_locale(BASE_LOCALE)

case mode
when "check"              then mode_check(base, legal, ignored, unknown)
when "summary"            then mode_summary(base, legal, ignored)
when "refs"               then mode_refs
when "missing"            then mode_missing(base, ARGV[1])
when "unused"             then mode_unused(base)
when "aliases"            then mode_aliases
when "unexpected-scripts" then mode_unexpected_scripts
when "untranslated"       then mode_untranslated(ARGV[1] || BASE_LOCALE)
when "longest"            then mode_longest(ARGV[1] || BASE_LOCALE)
when "spaces"             then mode_spaces(ARGV[1] || BASE_LOCALE)
else abort "unknown mode: #{mode.inspect}"
end

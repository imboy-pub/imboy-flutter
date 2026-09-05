#!/usr/bin/env ruby
# frozen_string_literal: true

# i18n_key_prune.rb — P4 键删除工具（先验证，后删除；删除需显式 --approve）
#
# 背景：i18n_audit.rb 的 unused 分类只做证据收集（candidate ≠ confirmed），
# 真正删除键必须走任务书 P4 硬门：用户确认具体清单后才可执行。
# 本工具把"执行"与"验证"绑定为原子操作：apply 前强制重跑 verify，
# 任何 hard fail（键不存在 / 生产或测试代码引用 / 动态访问风险 / 被 alias
# 指向）都整体中止、一个键都不删 —— 宁可 BLOCKED，也不误删。
#
# 用法：
#   ruby assets/i18n/i18n_key_prune.rb verify  <list-file>   # 逐键重验证，exit 1=有 hard fail
#   ruby assets/i18n/i18n_key_prune.rb apply   <list-file> --approve
#                                                            # verify 全过后从 10 locale YAML 手术删除
#   ruby assets/i18n/i18n_key_prune.rb selftest             # 行级删除算法自测
#
# list-file 格式：每行一个键（# 开头的注释行忽略），如 `common.appSettings`。
# apply 后必须依次执行：dart run slang → i18n_audit.rb check（strict）→
# flutter analyze（lib/i18n 相关）→ i18n 相关测试。

require "yaml"
require "psych"
require "set"

I18N_ROOT = File.expand_path(__dir__)
REPO_ROOT = File.expand_path(ENV["I18N_AUDIT_REPO_ROOT"] || File.join(I18N_ROOT, "..", ".."))
LEGAL_LOCALES = %w[ar-SA de-DE en-US fr-FR it-IT ja-JP ko-KR ru-RU zh-CN zh-Hant].freeze
BASE = "zh-CN"
SCAN_DIRS = %w[lib integration_test test].freeze

# 与 i18n_audit.rb scan_refs 同一套规则（改动须两边同步）：
# 静态形态 t.ns.key(...) 全前缀入集合；动态形态 t[...] / t.ns[...] 单独收集。
def scan_refs
  static = Set.new
  dynamic_ns = Set.new
  roots = SCAN_DIRS.select { |d| File.directory?(File.join(REPO_ROOT, d)) }
  roots.each do |root|
    Dir.glob(File.join(REPO_ROOT, root, "**", "*.dart")).each do |f|
      next if File.basename(f).end_with?(".g.dart")
      src = File.read(f, encoding: "UTF-8", invalid: :replace, undef: :replace)
      src.scan(/\bt(?:\.[A-Za-z0-9_]+)+/).each do |m|
        parts = m.delete_prefix("t.").split(".")
        parts.each_index { |i| static << parts.take(i + 1).join(".") }
      end
      src.scan(/\bt(?:\.[A-Za-z0-9_]+)*\s*\[/).each do |m|
        next if m.include?("\\")
        next if root == "test"
        segs = m.sub(/\s*\[\z/, "").delete_prefix("t.").split(".").reject(&:empty?)
        dynamic_ns << (segs.empty? ? "*" : segs.first)
      end
    end
  end
  [static, dynamic_ns]
end

# 展开一个 locale 目录的全部 YAML → { "ns.a.b" => value }；alias 行同审计口径
def flat_locale(locale)
  flat = {}
  aliases = {}
  Dir.glob(File.join(I18N_ROOT, locale, "*.i18n.yaml")).sort.each do |f|
    ns = File.basename(f, ".i18n.yaml")
    walk = lambda do |node, prefix|
      node.each do |k, v|
        # slang 参数键 `name(param)` / 复数键 `name(plural)`：与审计器同口径，
        # 逻辑键名剥掉括号后缀
        name = k.to_s.sub(/\([^)]*\)\z/, "")
        key = prefix.empty? ? name : "#{prefix}.#{name}"
        if v.is_a?(Hash)
          walk.call(v, key)
        elsif v.to_s.start_with?("@:")
          # 与 i18n_audit.rb 同口径：alias 键同时进 flat（logical）与
          # aliases 两表 —— alias 本身也是一个可删的键
          aliases[key] = v.to_s.delete_prefix("@:")
          flat[key] = v
        else
          flat[key] = v
        end
      end
    end
    tree = YAML.safe_load(File.read(f), aliases: false) || {}
    walk.call(tree, ns)
  end
  [flat, aliases]
end

# ── 手术式行删除：用 Psych 解析树拿每个映射条目的行号，按行区间删除 ──
# 返回删除的行数（0=未找到键）。保持文件其余部分逐字节不变。

# 在 mapping 节点里找 path[0] 条目，返回 [key_node, value_node, next_key_line]
def find_entry(mapping, name)
  kids = mapping.children
  kids.each_slice(2).with_index do |(k, v), idx|
    next unless k.respond_to?(:value) && k.value == name
    next_key = kids[(idx + 1) * 2]
    return [k, v, next_key&.start_line]
  end
  nil
end

def delete_key_from_file(file_path, segments)
  src = File.read(file_path)
  doc = Psych.parse(src)
  return 0 unless doc.is_a?(Psych::Nodes::Document)
  root = doc.children.first
  return 0 unless root.is_a?(Psych::Nodes::Mapping)
  state = { ranges: [] }
  total_lines = src.lines.size
  removed = 0
  k, v, next_line = find_entry(root, segments.first)
  return 0 unless k
  if segments.size == 1
    state[:ranges] << [k.start_line, next_line || total_lines]
    removed = (next_line || total_lines) - k.start_line
  elsif v.is_a?(Psych::Nodes::Mapping)
    # 先在子层递归收集区间
    child_count = v.children.size / 2
    removed = collect_and_delete(v, segments.drop(1), state, next_line || total_lines)
    # 子映射被删空 → 级联删除父条目
    if removed.positive? && child_count == 1
      state[:ranges] << [k.start_line, next_line || total_lines]
    end
  end
  ranges = state[:ranges].uniq.sort_by { |a, _| a }
  merged = ranges.reduce([]) do |acc, (s, e)|
    if acc.any? && s <= acc.last[1]
      acc.last[1] = [acc.last[1], e].max
      acc
    else
      acc << [s, e]
      acc
    end
  end
  unless merged.empty?
    lines = src.lines
    merged.reverse_each { |s, e| lines[s...e] = [] }
    File.write(file_path, lines.join)
    removed = merged.sum { |s, e| e - s }
  end
  removed
end

# 在 mapping 内定位 path[0]，命中即记录区间；未命中返回 0
def collect_and_delete(mapping, path, state, eof_line)
  kids = mapping.children
  kids.each_slice(2).with_index do |(k, v), idx|
    next unless k.respond_to?(:value) && k.value == path.first
    next_key = kids[(idx + 1) * 2]
    stop = next_key&.start_line || eof_line
    if path.size == 1
      state[:ranges] << [k.start_line, stop]
      return stop - k.start_line
    end
    return 0 unless v.is_a?(Psych::Nodes::Mapping)
    inner_count = v.children.size / 2
    r = collect_and_delete(v, path.drop(1), state, stop)
    return r unless r.positive?
    if inner_count == 1
      state[:ranges] << [k.start_line, stop]
    end
    return r
  end
  0
end

# ── verify ──

def verify_keys(keys, base_flat, base_aliases, refs_static, dynamic_ns)
  alias_targets = Set.new
  base_aliases.each do |k, v|
    t = v
    t = "#{k.split('.').first}.#{t}" unless base_flat.key?(t)
    alias_targets << t
  end
  hard = []
  warn = []
  keys.each do |key|
    ns = key.split(".").first
    if alias_targets.include?(key)
      hard << [key, "被其他键的 alias 指向（indirect 使用）"]
    elsif dynamic_ns.include?("*") || dynamic_ns.include?(ns)
      hard << [key, "动态访问风险（t[...] 命中该命名空间），无法静态确认"]
    elsif refs_static.include?(key)
      hard << [key, "静态引用命中（lib/ 或测试代码）"]
    elsif !base_flat.key?(key)
      hard << [key, "zh-CN 中不存在（拼写错误或已被删除）"]
    end
  end
  [hard, warn]
end

def load_list(path)
  File.readlines(path).map(&:strip).reject { |l| l.empty? || l.start_with?("#") }
end

# ── main ──

case ARGV[0]
when "selftest"
  require "tmpdir"
  fixture = <<~YAML
    # header comment
    alpha: 保留A
    group:
      # group comment
      keepMe: 保留B
      dropMe: 删除我
      nested:
        deep: 保留C
    pluralKey:
      one: "1 个"
      other: "$n 个"
    last: 保留D
  YAML
  Dir.mktmpdir do |dir|
    f = File.join(dir, "t.i18n.yaml")
    File.write(f, fixture)
    n = delete_key_from_file(f, %w[group dropMe])
    out = File.read(f)
    ok1 = n == 1 && out.include?("keepMe: 保留B") && out.include?("deep: 保留C") &&
          !out.include?("dropMe") && out.include?("# group comment") && out.include?("last: 保留D")
    n2 = delete_key_from_file(f, %w[group nested deep])
    out2 = File.read(f)
    ok2 = n2 == 2 && !out2.include?("nested") && out2.include?("keepMe: 保留B")
    n3 = delete_key_from_file(f, %w[pluralKey])
    out3 = File.read(f)
    ok3 = n3 == 3 && !out3.include?("pluralKey") && out3.include?("one:") == false &&
          out3.include?("alpha: 保留A") && out3.include?("last: 保留D")
    n4 = delete_key_from_file(f, %w[group 不存在])
    ok4 = n4.zero? && File.read(f) == out3
    if ok1 && ok2 && ok3 && ok4
      puts "selftest: 4/4 passed"
      exit 0
    else
      puts "selftest FAIL: leaf=#{ok1} cascade=#{ok2} block=#{ok3} missing=#{ok4}"
      puts out3
      exit 1
    end
  end
when "verify", "apply"
  list_file = ARGV[1]
  approve = ARGV.include?("--approve")
  abort("usage: i18n_key_prune.rb {verify|apply} <list-file> [--approve]") unless list_file
  keys = load_list(list_file)
  abort("list file empty: #{list_file}") if keys.empty?
  puts "== i18n_key_prune #{ARGV[0]} =="
  puts "keys=#{keys.size} approve=#{approve}"
  base_flat, base_aliases = flat_locale(BASE)
  refs_static, dynamic_ns = scan_refs
  hard, _warn = verify_keys(keys, base_flat, base_aliases, refs_static, dynamic_ns)
  if hard.any?
    puts "HARD FAIL #{hard.size} key(s) — 未删除任何键："
    hard.each { |k, why| puts "  #{k} — #{why}" }
    exit 1
  end
  puts "verify: #{keys.size} key(s) 全部通过（zh-CN 在场、零静态引用、零动态风险、零 alias 依赖）"
  exit 0 if ARGV[0] == "verify" || !approve
  # apply：逐 locale 手术删除
  total = 0
  LEGAL_LOCALES.each do |loc|
    by_file = Hash.new { |h, k2| h[k2] = [] }
    keys.each do |key|
      parts = key.split(".")
      by_file[parts.first] << parts.drop(1)
    end
    removed_loc = 0
    by_file.each do |ns, paths|
      f = File.join(I18N_ROOT, loc, "#{ns}.i18n.yaml")
      next unless File.file?(f)
      paths.each { |segs| removed_loc += delete_key_from_file(f, segs) }
    end
    puts "  #{loc}: -#{removed_loc} 行"
    total += removed_loc
  end
  puts "apply: 完成，共删除 #{total} 行（含级联父键）。"
  # 删后校验：逐键实测已从全部 locale 消失（防 YAML 1.1 布尔键等
  # 解析形态差异导致的静默跳过——on/off 曾因此 no-op）
  base_after, = flat_locale(BASE)
  missed = keys.select { |k| base_after.key?(k) }
  if missed.any?
    puts "POST-VERIFY FAIL：#{missed.size} 键仍存在于 zh-CN（可能为 YAML 1.1 布尔键别名，如 on/off→true/false）："
    missed.each { |k| puts "  #{k}" }
    exit 1
  end
  puts "post-verify: #{keys.size} key(s) 已确认全部消失。"
  puts "后续必须执行：dart run slang && I18N_AUDIT_STRICT=1 ruby assets/i18n/i18n_audit.rb check && flutter test test/unit_test/i18n_ui_gate_test.dart"
else
  puts "usage: i18n_key_prune.rb {verify|apply} <list-file> [--approve] | selftest"
  exit 2
end

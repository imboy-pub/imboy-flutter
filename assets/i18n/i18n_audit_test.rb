#!/usr/bin/env ruby
# frozen_string_literal: true

# i18n_audit_test.rb — 审计器最小回归测试（P1）。
#
# 运行：ruby assets/i18n/i18n_audit_test.rb
# 零第三方依赖：在临时目录构造夹具仓库，通过 I18N_AUDIT_ROOT /
# I18N_AUDIT_REPO_ROOT 环境变量驱动真实 CLI，断言退出码与输出。
#
# 覆盖用例：
#   1. .dart_tool 等点目录不计为 locale；未登记 locale 目录判失败
#   2. 指向 plural 节点的 alias 不误报
#   3. placeholder 不匹配必须失败（$name vs ${name} 归一为同名）
#   4. 重复 YAML 键必须失败
#   5. locale 特有 plural 分支（one）不算 extra
#   6. 嵌套键扁平化与静态引用匹配
#   7. 动态键访问 => unused 标 unknown，绝不标 confirmed_unused
#   8. 空值必须失败
#   9. missing 是信息项（check 通过）；I18N_AUDIT_STRICT=1 时判失败
#  10. used_missing 检出（代码引用了但 locale 缺失）

require "tmpdir"
require "fileutils"
require "open3"
require "rbconfig"

AUDIT = File.join(__dir__, "i18n_audit.rb")
RUBY = RbConfig.ruby

TESTS = []
def test(name, &block) = TESTS << [name, block]

def assert(cond, msg)
  raise "assert failed: #{msg}" unless cond
end

def write_fixture(dir, locales:, dart: {})
  i18n = File.join(dir, "assets", "i18n")
  locales.each do |loc, files|
    files.each do |fname, content|
      path = File.join(i18n, loc, fname)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end
  end
  dart.each do |rel, content|
    path = File.join(dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end
  i18n
end

def run_audit(i18n_root, repo_root, *args, env_extra: {})
  env = { "I18N_AUDIT_ROOT" => i18n_root, "I18N_AUDIT_REPO_ROOT" => repo_root }.merge(env_extra)
  Open3.capture3(env, RUBY, AUDIT, *args)
end

ZH_BASE = <<~YAML
  hello: "你好 $name"
  plain: 普通文案
  unusedThing: 没有代码引用我
  dialog:
    confirm: 确定
    cancel: 取消
  timeAgo(plural):
    other: $n分钟前
  lastSeenAgo: "@:timeAgo"
YAML

# 1 ── .dart_tool 排除 + 未登记 locale 目录报错
test "dot_tool_excluded_and_unknown_locale_flagged" do |dir|
  i18n = write_fixture(dir, locales: { "zh-CN" => { "common.i18n.yaml" => ZH_BASE } })
  FileUtils.mkdir_p(File.join(i18n, ".dart_tool", "junk"))
  File.write(File.join(i18n, ".dart_tool", "junk", "junk.i18n.yaml"), "ghost: 幽灵键")

  out, err, status = run_audit(i18n, dir, "summary")
  assert status.success?, "summary exited #{status.exitstatus}: #{err}"
  assert out !~ /^\.dart_tool\s+keys=/, ".dart_tool must not be listed as a locale row"

  FileUtils.mkdir_p(File.join(i18n, "klingon-XY"))
  File.write(File.join(i18n, "klingon-XY", "common.i18n.yaml"), "hello: qapla")
  _o, _e, status = run_audit(i18n, dir, "check")
  assert status.exitstatus == 1, "unregistered locale must fail check"
end

# 2 ── 指向 plural 节点的 alias 不误报
test "plural_alias_not_false_positive" do |dir|
  i18n = write_fixture(dir, locales: {
    "zh-CN" => { "common.i18n.yaml" => ZH_BASE },
    "en-US" => { "common.i18n.yaml" => <<~YAML }
      hello: "hi $name"
      plain: plain text
      dialog:
        confirm: OK
        cancel: Cancel
      timeAgo(plural):
        one: $n minute ago
        other: $n minutes ago
      lastSeenAgo: "@:timeAgo"
    YAML
  })
  out, _e, status = run_audit(i18n, dir, "aliases")
  assert status.success?, "aliases exited #{status.exitstatus}"
  assert out.include?("all targets resolve"), "plural-node alias target must resolve, got: #{out}"

  _o, _e, status = run_audit(i18n, dir, "check")
  assert status.exitstatus == 0, "check must pass with plural alias"
end

# 3 ── placeholder 不匹配必须失败；$name 与 ${name} 同名归一
test "placeholder_mismatch_fails_and_normalization" do |dir|
  i18n = write_fixture(dir, locales: {
    "zh-CN" => { "common.i18n.yaml" => ZH_BASE },
    "en-US" => { "common.i18n.yaml" => "hello: \"hi ${name}\"\nplain: plain\n" }
  })
  _o, _e, status = run_audit(i18n, dir, "check")
  assert status.exitstatus == 0, "${name} must normalize to $name (got fail)"

  i18n = write_fixture(dir, locales: {
    "zh-CN" => { "common.i18n.yaml" => ZH_BASE },
    "en-US" => { "common.i18n.yaml" => "hello: \"hi $user\"\nplain: plain\n" }
  })
  out, _e, status = run_audit(i18n, dir, "check")
  assert status.exitstatus == 1, "placeholder mismatch must fail"
  assert out.include?("[placeholder]"), "failure must be categorized as placeholder"
end

# 4 ── 重复 YAML 键必须失败
test "duplicate_yaml_key_fails" do |dir|
  i18n = write_fixture(dir, locales: {
    "zh-CN" => { "common.i18n.yaml" => "ok: 第一次\nok: 第二次\n" }
  })
  out, _e, status = run_audit(i18n, dir, "check")
  assert status.exitstatus == 1, "duplicate key must fail (YAML.load silently drops one)"
  assert out.include?("[duplicate]"), "failure must be categorized as duplicate"
end

# 5 ── locale 特有 plural 分支（one）不算 extra
test "locale_plural_branch_not_extra" do |dir|
  i18n = write_fixture(dir, locales: {
    "zh-CN" => { "common.i18n.yaml" => ZH_BASE },
    "en-US" => { "common.i18n.yaml" => <<~YAML }
      plain: plain text
      timeAgo(plural):
        one: $n minute ago
        other: $n minutes ago
    YAML
  })
  out, _e, status = run_audit(i18n, dir, "summary")
  assert status.success?, "summary exited #{status.exitstatus}"
  line = out.lines.find { |l| l.start_with?("en-US") }
  assert line.include?("extra=0"), "plural one-branch must not be extra: #{line}"
  # base 逻辑键 7 个（dialog.confirm/cancel 各算一个，plural 节点算一个），
  # en 只有 plain + timeAgo 节点 => missing=5
  assert line.include?("missing=5"), "missing counts logical keys: #{line}"
  _o, _e, status = run_audit(i18n, dir, "check")
  assert status.exitstatus == 0, "locale-specific plural branch must not fail check"
end

# 6 ── 嵌套键扁平化 + 静态引用匹配
test "nested_key_flattening_and_refs" do |dir|
  i18n = write_fixture(dir, locales: {
    "zh-CN" => { "common.i18n.yaml" => ZH_BASE },
    "en-US" => { "common.i18n.yaml" => "plain: plain\ndialog:\n  confirm: OK\n" }
  }, dart: {
    "lib/page.dart" => "final a = t.common.dialog.confirm;\n"
  })
  out, _e, status = run_audit(i18n, dir, "unused")
  assert status.success?, "unused exited #{status.exitstatus}"
  # 只有 dialog.confirm 被静态引用；timeAgo 是（相对）alias 目标 => indirect
  assert out.include?("candidate=5"), "unusedThing/hello/dialog.cancel/lastSeenAgo + hello 系 candidate: #{out}"
  assert out.include?("indirect=1"), "alias target timeAgo must classify indirect: #{out}"

  # param 修饰符键与 t.ns.key(...) 调用形态匹配
  i18n = write_fixture(dir, locales: {
    "zh-CN" => { "common.i18n.yaml" => "unreadCount(count): \"${count} 条\"\noldKey: 旧键\n" }
  }, dart: {
    "lib/page.dart" => "final b = t.common.unreadCount(c: 3);\n"
  })
  out, _e, status = run_audit(i18n, dir, "unused")
  assert out.include?("candidate=1"), "param-key must strip (count) modifier for ref match: #{out}"
end

# 7 ── 动态键访问 => unknown，绝不 confirmed_unused
test "dynamic_usage_classified_unknown" do |dir|
  i18n = write_fixture(dir, locales: {
    "zh-CN" => { "common.i18n.yaml" => "plain: 文案\ncommonOnly: 仅动态可达\n" }
  }, dart: {
    "lib/dyn.dart" => "final k = t.common[whichKey];\n"
  })
  out, _e, status = run_audit(i18n, dir, "unused")
  assert out.include?("unknown=2"), "both dynamic-namespace keys must be unknown: #{out}"
  assert !out.downcase.include?("confirmed_unused"), "auditor must never claim confirmed_unused"

  _o, _e, status = run_audit(i18n, dir, "check", env_extra: { "I18N_AUDIT_STRICT" => "1" })
  assert status.exitstatus == 1, "strict check must fail on dynamic risk"
end

# 8 ── 空值必须失败
test "empty_value_fails" do |dir|
  i18n = write_fixture(dir, locales: {
    "zh-CN" => { "common.i18n.yaml" => "blank: \"\"\nnormal: 正常\n" }
  })
  out, _e, status = run_audit(i18n, dir, "check")
  assert status.exitstatus == 1, "empty value must fail"
  assert out.include?("[empty]"), "failure must be categorized as empty"
end

# 9 ── missing 信息项不阻断 check；strict 模式阻断；used_missing 检出
test "missing_informational_but_strict_gates_and_used_missing" do |dir|
  i18n = write_fixture(dir, locales: {
    "zh-CN" => { "common.i18n.yaml" => ZH_BASE },
    "en-US" => { "common.i18n.yaml" => "plain: plain\nhello: \"hi $name\"\ndialog:\n  confirm: OK\n" }
  }, dart: {
    "lib/page.dart" => "final c = t.common.unusedThing;\n"
  })
  _o, _e, status = run_audit(i18n, dir, "check")
  assert status.exitstatus == 0, "missing alone must not fail structural check"

  out, _e, status = run_audit(i18n, dir, "check", env_extra: { "I18N_AUDIT_STRICT" => "1" })
  assert status.exitstatus == 1, "strict check must fail while missing > 0"
  assert out.include?("used_missing"), "strict output must report used_missing"

  out, _e, _s = run_audit(i18n, dir, "check")
  assert out.include?("used_missing=1"), "unusedThing is referenced => used_missing for en-US: #{out}"

  out, _e, _s = run_audit(i18n, dir, "missing", "en-US")
  assert out.include?("common.unusedThing"), "missing mode lists key + zh-CN source: #{out}"
end

# ── runner ──────────────────────────────────────────────────────────────
failures = []
TESTS.each do |name, block|
  begin
    Dir.mktmpdir { |dir| block.call(dir) }
    puts "PASS  #{name}"
  rescue StandardError => e
    puts "FAIL  #{name}: #{e.message}"
    failures << name
  end
end
puts "#{TESTS.size - failures.size}/#{TESTS.size} passed"
exit(failures.empty? ? 0 : 1)

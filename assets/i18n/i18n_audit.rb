require "yaml"
require "set"

def flatten(node, prefix = "", out = {})
  case node
  when Hash
    node.each do |k, v|
      key = prefix.empty? ? k.to_s : "#{prefix}.#{k}"
      flatten(v, key, out)
    end
  when Array
    node.each_with_index do |v, i|
      key = "#{prefix}[#{i}]"
      flatten(v, key, out)
    end
  else
    out[prefix] = node
  end
  out
end

def placeholders(str)
  return Set.new unless str.is_a?(String)
  s = Set.new
  str.scan(/\$[A-Za-z_][A-Za-z0-9_]*/).each { |m| s << m }
  str.scan(/\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}/).each { |m| s << "{#{m[0]}}" }
  s
end

def stat(flat)
  values = flat.values
  strings = values.select { |v| v.is_a?(String) }
  {
    total: flat.size,
    strings: strings.size,
    empty_strings: strings.count { |s| s.strip.empty? },
    leading_space: strings.count { |s| s.match?(/\A\s+/) },
    trailing_space: strings.count { |s| s.match?(/\s+\z/) },
    has_han: strings.count { |s| s.match?(/\p{Han}/) },
    has_latin: strings.count { |s| s.match?(/[A-Za-z]/) },
    has_cyrillic: strings.count { |s| s.match?(/\p{Cyrillic}/) },
    has_arabic: strings.count { |s| s.match?(/\p{Arabic}/) },
    has_ellipsis_ascii: strings.count { |s| s.include?("...") }
  }
end

def allowed_scripts_for(file)
  case file
  when /\Azh-/
    Set[:han, :latin]
  when /\Aja-/
    Set[:han, :latin]
  when /\Ako-/
    Set[:latin]
  when /\Aru-/
    Set[:cyrillic, :latin]
  when /\Aar-/
    Set[:arabic, :latin]
  else
    Set[:latin]
  end
end

def scripts_in(str)
  scripts = Set.new
  scripts << :han if str.match?(/\p{Han}/)
  scripts << :cyrillic if str.match?(/\p{Cyrillic}/)
  scripts << :arabic if str.match?(/\p{Arabic}/)
  scripts << :latin if str.match?(/[A-Za-z]/)
  scripts
end

files = Dir["*.i18n.yaml"].sort
base_file = "zh-CN.i18n.yaml"
base = flatten(YAML.load_file(base_file))

mode = ARGV[0] || "summary"
top_n = (ENV["TOP"] || "12").to_i

if mode == "help"
  puts "Usage:"
  puts "  ruby i18n_audit.rb summary"
  puts "  ruby i18n_audit.rb untranslated [base_file]"
  puts "  ruby i18n_audit.rb unexpected-scripts"
  puts "  ruby i18n_audit.rb latin-words <file>"
  puts "  ruby i18n_audit.rb longest <file>"
  puts "  ruby i18n_audit.rb diff-base <file>"
  puts "  ruby i18n_audit.rb spaces <file>"
  puts "  ruby i18n_audit.rb aliases"
  puts "  ruby i18n_audit.rb hant-simplified [zh-Hant.i18n.yaml]"
  puts "  ruby i18n_audit.rb hant-suggest-convert [zh-Hant.i18n.yaml] [zh-CN.i18n.yaml]"
  puts ""
  puts "Env:"
  puts "  TOP=12   limit printed keys/rows"
  exit 0
end

if mode == "summary"
  puts "BASE=#{base_file} keys=#{base.size}"
  files.each do |f|
    flat = flatten(YAML.load_file(f))
    missing = base.keys - flat.keys
    extra = flat.keys - base.keys

    placeholder_mismatch = 0
    same_as_base = 0
    base.each do |k, bv|
      next unless flat.key?(k)
      placeholder_mismatch += 1 unless placeholders(bv) == placeholders(flat[k])
      same_as_base += 1 if flat[k] == bv
    end

    s = stat(flat)
    puts [
      f,
      "keys=#{s[:total]}",
      "missing=#{missing.size}",
      "extra=#{extra.size}",
      "placeholder_mismatch=#{placeholder_mismatch}",
      "same_as_#{base_file}=#{same_as_base}",
      "empty=#{s[:empty_strings]}",
      "lead_space=#{s[:leading_space]}",
      "trail_space=#{s[:trailing_space]}",
      "han=#{s[:has_han]}",
      "latin=#{s[:has_latin]}",
      "cyrillic=#{s[:has_cyrillic]}",
      "arabic=#{s[:has_arabic]}",
      "ascii_ellipsis=#{s[:has_ellipsis_ascii]}"
    ].join(" ")
  end
  exit 0
end

if mode == "longest"
  target = ARGV[1] || base_file
  flat = flatten(YAML.load_file(target))
  rows = flat.select { |_, v| v.is_a?(String) }.map { |k, v| [k, v.size, v] }
  rows.sort_by! { |(_, len, _)| -len }
  rows.take(top_n).each do |k, len, v|
    puts "#{target} #{len} #{k}=#{v.inspect}"
  end
  exit 0
end

if mode == "diff-base"
  target = ARGV[1] || "en-US.i18n.yaml"
  flat = flatten(YAML.load_file(target))
  same = base.keys.select { |k| flat.key?(k) && flat[k] == base[k] }
  puts "same_as_#{base_file} count=#{same.size}"
  same.take(top_n).each { |k| puts k }
  exit 0
end

if mode == "spaces"
  target = ARGV[1] || base_file
  flat = flatten(YAML.load_file(target))
  leading = []
  trailing = []
  flat.each do |k, v|
    next unless v.is_a?(String)
    leading << k if v.match?(/\A\s+/)
    trailing << k if v.match?(/\s+\z/)
  end
  puts "leading_space count=#{leading.size}"
  leading.take(top_n).each { |k| puts k }
  puts "trailing_space count=#{trailing.size}"
  trailing.take(top_n).each { |k| puts k }
  exit 0
end

if mode == "untranslated"
  base_override = ARGV[1]
  base_for_untranslated_file = base_override || base_file
  base_for_untranslated = flatten(YAML.load_file(base_for_untranslated_file))

  files.each do |f|
    next if f == base_for_untranslated_file
    flat = flatten(YAML.load_file(f))
    keys = []
    base_for_untranslated.each do |k, bv|
      next unless flat.key?(k)
      next unless bv.is_a?(String) && flat[k].is_a?(String)
      next if bv.start_with?("@:")
      next unless bv.match?(/\p{Han}/)
      keys << k if flat[k] == bv
    end
    next if keys.empty?
    puts "#{f} untranslated_from_#{base_for_untranslated_file} count=#{keys.size}"
    keys.take(top_n).each { |k| puts k }
  end
  exit 0
end

if mode == "untranslated-show"
  target = ARGV[1] || "zh-Hant.i18n.yaml"
  base_override = ARGV[2] || base_file
  base_for_untranslated_file = base_override
  base_for_untranslated = flatten(YAML.load_file(base_for_untranslated_file))
  flat = flatten(YAML.load_file(target))

  keys = []
  base_for_untranslated.each do |k, bv|
    next unless flat.key?(k)
    next unless bv.is_a?(String) && flat[k].is_a?(String)
    next if bv.start_with?("@:")
    next unless bv.match?(/\p{Han}/)
    keys << k if flat[k] == bv
  end

  puts "#{target} untranslated_from_#{base_for_untranslated_file} count=#{keys.size}"
  keys.take(top_n).each do |k|
    puts "#{k} #{flat[k].inspect}"
  end
  exit 0
end

if mode == "same-as"
  left_file = ARGV[1] || base_file
  right_file = ARGV[2] || "en-US.i18n.yaml"
  left = flatten(YAML.load_file(left_file))
  right = flatten(YAML.load_file(right_file))

  same = left.keys.select do |k|
    left[k].is_a?(String) && right[k].is_a?(String) && left[k] == right[k]
  end

  puts "#{left_file} same_as #{right_file} count=#{same.size}"
  same.take(top_n).each do |k|
    puts "#{k} #{left[k].inspect}"
  end
  exit 0
end

if mode == "unexpected-scripts"
  files.each do |f|
    flat = flatten(YAML.load_file(f))
    allowed = allowed_scripts_for(f)
    bad = []
    flat.each do |k, v|
      next unless v.is_a?(String)
      present = scripts_in(v)
      unexpected = present - allowed
      bad << k unless unexpected.empty?
    end
    next if bad.empty?
    puts "#{f} unexpected_scripts count=#{bad.size}"
    bad.take(top_n).each { |k| puts k }
  end
  exit 0
end

if mode == "latin-words"
  target = ARGV[1] || base_file
  flat = flatten(YAML.load_file(target))
  keys = flat.select { |_, v| v.is_a?(String) && !v.start_with?("@:") && v.match?(/[A-Za-z]{3,}/) }.keys
  puts "#{target} latin_words count=#{keys.size}"
  keys.take(top_n).each { |k| puts k }
  exit 0
end

if mode == "hant-simplified"
  target = ARGV[1] || "zh-Hant.i18n.yaml"
  flat = flatten(YAML.load_file(target))
  simplified = [
    "这", "那", "哪", "么", "个", "为", "与", "里", "号", "发", "后", "会", "网", "线",
    "输", "队", "强", "动", "设", "开", "关", "选", "项", "区", "东", "医", "显", "隐",
    "标", "签", "册", "联", "误", "连", "删", "听", "说", "读", "写"
  ].to_set

  hits = []
  flat.each do |k, v|
    next unless v.is_a?(String)
    next if v.start_with?("@:")
    chars = v.each_char.to_set
    next if (chars & simplified).empty?
    hits << [k, v]
  end

  puts "#{target} simplified_suspects count=#{hits.size}"
  hits.take(top_n).each { |k, v| puts "#{k}=#{v.inspect}" }
  exit 0
end

if mode == "hant-suggest-convert"
  target = ARGV[1] || "zh-Hant.i18n.yaml"
  source = ARGV[2] || "zh-CN.i18n.yaml"
  t = flatten(YAML.load_file(target))
  s = flatten(YAML.load_file(source))

  map = {
    "暂" => "暫",
    "该" => "該",
    "这" => "這",
    "那" => "那",
    "个" => "個",
    "么" => "麼",
    "为" => "為",
    "与" => "與",
    "没" => "沒",
    "里" => "裡",
    "号" => "號",
    "发" => "發",
    "后" => "後",
    "会" => "會",
    "网" => "網",
    "线" => "線",
    "输" => "輸",
    "设" => "設",
    "备" => "備",
    "开" => "開",
    "关" => "關",
    "选" => "選",
    "项" => "項",
    "动" => "動",
    "应" => "應",
    "请" => "請",
    "误" => "誤",
    "删" => "刪",
    "连" => "連",
    "东" => "東",
    "显" => "顯",
    "隐" => "隱",
    "标" => "標",
    "签" => "簽",
    "册" => "冊",
    "联" => "聯",
    "话" => "話",
    "电" => "電",
    "码" => "碼",
    "账" => "帳",
    "户" => "戶"
  }

  hits = []
  s.each do |k, sv|
    next unless t.key?(k)
    tv = t[k]
    next unless sv.is_a?(String) && tv.is_a?(String)
    next if sv.start_with?("@:") || tv.start_with?("@:")
    next unless sv == tv
    next unless sv.match?(/\p{Han}/)

    converted = sv.dup
    map.each { |from, to| converted.gsub!(from, to) }
    next if converted == sv
    hits << [k, sv, converted]
  end

  puts "#{target} equal_to_#{source} convertible count=#{hits.size}"
  hits.take(top_n).each do |k, before, after|
    puts "#{k} #{before.inspect} -> #{after.inspect}"
  end
  exit 0
end

if mode == "aliases"
  files.each do |f|
    flat = flatten(YAML.load_file(f))
    alias_keys = flat.select { |_, v| v.is_a?(String) && v.start_with?("@:") }
    missing = []
    alias_keys.each do |k, v|
      ref = v.delete_prefix("@:")
      missing << [k, ref] unless flat.key?(ref)
    end
    next if missing.empty?
    puts "#{f} missing_alias_targets count=#{missing.size}"
    missing.take(top_n).each { |k, ref| puts "#{k} -> #{ref}" }
  end
  exit 0
end

abort "unknown mode: #{mode.inspect}"

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

def allowed_scripts_for(locale)
  case locale
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

def load_locale(dir)
  merged = {}
  Dir.glob(File.join(dir, "*.i18n.yaml")).each do |f|
    ns = File.basename(f, ".i18n.yaml")
    data = YAML.load_file(f)
    if data
      # slang namespaces: the filename is the top level key
      # t.common.cancel means common.i18n.yaml has cancel: ...
      # So we flatten with ns prefix
      flatten(data, ns, merged)
    end
  end
  merged
end

# Root directory of i18n
I18N_ROOT = File.dirname(__FILE__)
locales = Dir.children(I18N_ROOT).select { |d| File.directory?(File.join(I18N_ROOT, d)) }.sort
base_locale = "zh-CN"
base = load_locale(File.join(I18N_ROOT, base_locale))

mode = ARGV[0] || "summary"
top_n = (ENV["TOP"] || "12").to_i

if mode == "help"
  puts "Usage (Run from assets/i18n/):"
  puts "  ruby i18n_audit.rb summary"
  puts "  ruby i18n_audit.rb untranslated [base_locale]"
  puts "  ruby i18n_audit.rb unexpected-scripts"
  puts "  ruby i18n_audit.rb longest <locale>"
  puts "  ruby i18n_audit.rb spaces <locale>"
  puts "  ruby i18n_audit.rb aliases"
  exit 0
end

if mode == "summary"
  puts "BASE=#{base_locale} keys=#{base.size}"
  locales.each do |loc|
    flat = load_locale(File.join(I18N_ROOT, loc))
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
      loc.ljust(10),
      "keys=#{s[:total].to_s.ljust(5)}",
      "missing=#{missing.size.to_s.ljust(4)}",
      "extra=#{extra.size.to_s.ljust(4)}",
      "placeholder_mismatch=#{placeholder_mismatch.to_s.ljust(3)}",
      "same_as_base=#{same_as_base.to_s.ljust(5)}",
      "empty=#{s[:empty_strings]}",
      "han=#{s[:has_han]}",
      "latin=#{s[:has_latin]}",
      "cyrillic=#{s[:has_cyrillic]}",
      "arabic=#{s[:has_arabic]}"
    ].join(" ")
  end
  exit 0
end

if mode == "longest"
  target = ARGV[1] || base_locale
  flat = load_locale(File.join(I18N_ROOT, target))
  rows = flat.select { |_, v| v.is_a?(String) }.map { |k, v| [k, v.size, v] }
  rows.sort_by! { |(_, len, _)| -len }
  rows.take(top_n).each do |k, len, v|
    puts "#{target} #{len} #{k}=#{v.inspect}"
  end
  exit 0
end

if mode == "spaces"
  target = ARGV[1] || base_locale
  flat = load_locale(File.join(I18N_ROOT, target))
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
  cur_base_locale = base_override || base_locale
  cur_base = load_locale(File.join(I18N_ROOT, cur_base_locale))

  locales.each do |loc|
    next if loc == cur_base_locale
    flat = load_locale(File.join(I18N_ROOT, loc))
    keys = []
    cur_base.each do |k, bv|
      next unless flat.key?(k)
      next unless bv.is_a?(String) && flat[k].is_a?(String)
      next if bv.start_with?("@:")
      next unless bv.match?(/\p{Han}/)
      keys << k if flat[k] == bv
    end
    next if keys.empty?
    puts "#{loc} untranslated_from_#{cur_base_locale} count=#{keys.size}"
    keys.take(top_n).each { |k| puts k }
  end
  exit 0
end

if mode == "unexpected-scripts"
  locales.each do |loc|
    flat = load_locale(File.join(I18N_ROOT, loc))
    allowed = allowed_scripts_for(loc)
    bad = []
    flat.each do |k, v|
      next unless v.is_a?(String)
      present = scripts_in(v)
      unexpected = present - allowed
      bad << k unless unexpected.empty?
    end
    next if bad.empty?
    puts "#{loc} unexpected_scripts count=#{bad.size}"
    bad.take(top_n).each { |k| puts k }
  end
  exit 0
end

if mode == "aliases"
  locales.each do |loc|
    flat = load_locale(File.join(I18N_ROOT, loc))
    alias_keys = flat.select { |_, v| v.is_a?(String) && v.start_with?("@:") }
    missing = []
    alias_keys.each do |k, v|
      ref = v.delete_prefix("@:")
      # slang links can be absolute (ns.key) or relative (key)
      # My split script uses absolute links @:ns.key
      missing << [k, ref] unless flat.key?(ref)
    end
    next if missing.empty?
    puts "#{loc} missing_alias_targets count=#{missing.size}"
    missing.take(top_n).each { |k, ref| puts "#{k} -> #{ref}" }
  end
  exit 0
end

abort "unknown mode: #{mode.inspect}"

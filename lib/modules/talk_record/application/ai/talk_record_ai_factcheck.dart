/// Text-level zero-tolerance fact checker for client-BYOK summaries (T14).
///
/// The citation gate in `talkRecordAiSummary` already proves that every
/// segment reference exists and that forbidden attributes (owner_user_id,
/// due_date) stay absent. This checker adds the missing text-level contract:
/// every person, amount and date surface the model emits in `overview`,
/// `decisions[].text` or `actions[].text` must be grounded in the transcript
/// texts it was actually given. A summary carrying an ungrounded surface is
/// reported through [TalkRecordAiFactViolation] entries and must not be
/// published; the publication path throws, and the coordinator maps that
/// onto the same blocked/failure semantics as the citation gate.
///
/// Deterministic and conservative by design, not a NER system:
/// * extraction prefers recall over precision — a false positive blocks one
///   draft, a fabricated fact never slips through — while stoplists keep
///   generic referents (团队/双方/负责人...) from collapsing normal text;
/// * speaker labels are legal because they come from real diarization
///   results: segment `speaker_label`/`speaker` values (including the
///   chunk-scoped `1:S1` form) are whitelisted. The V1 backend summarize
///   snapshot carries texts only, so an `S1` the model could not have seen
///   is still flagged;
/// * amounts compare by (value, currency) after folding full/half width and
///   中文数字 <-> 阿拉伯数字, so `五万元`, `5万元` and `50000元` are one fact
///   while `五元` inside `五万元`, or `300元` inside `3000元`, is not;
/// * dates compare by normalized calendar fields (year/month/day), weekday
///   term (modifier included: 本周五 is not 下周五) and relative-day class.
///   Relative terms (今天/后天/...) fold against the optional record
///   [timeBase]; the V1 snapshot carries no record timestamp, so without a
///   base only same-class co-occurrence counts;
/// * known blind spots (durations, discounts 折, currency conversion,
///   conjunction name lists, English date surfaces) are documented with the
///   task result and must be iterated with real-model samples once a
///   provider key is available.
library;

enum TalkRecordAiFactKind { person, amount, date }

/// One ungrounded fact surface found in a summary text field.
class TalkRecordAiFactViolation {
  const TalkRecordAiFactViolation({
    required this.kind,
    required this.field,
    required this.fragment,
    required this.evidence,
  });

  final TalkRecordAiFactKind kind;

  /// Summary path the fragment came from, e.g. `overview` or
  /// `decisions[0].text`.
  final String field;

  /// The matched fragment as it appears in the normalized summary text.
  final String fragment;

  /// Why the fragment has no basis, e.g. `no person basis in transcript`.
  final String evidence;

  String get code => 'fabricated_${kind.name}';
  @override
  String toString() => '$code($field:$fragment)';
}

/// Thrown by the summary publication gate when fact violations exist. The
/// blocking semantics are identical to the citation gate; this type only
/// carries the precise fabricated_person/amount/date diagnosis.
class TalkRecordAiFactViolationException implements Exception {
  const TalkRecordAiFactViolationException(this.violations);
  final List<TalkRecordAiFactViolation> violations;
  @override
  String toString() =>
      'TalkRecordAiFactViolationException(${violations.map((item) => item.code).toSet().join(',')})';
}

/// Pure validator: returns every person/amount/date surface in the summary
/// that has no basis in the given segments' texts. An empty list means the
/// summary text is fully grounded (or entity-free, which trivially passes).
List<TalkRecordAiFactViolation> talkRecordAiSummaryFactViolations(
  Map<String, Object?> summary,
  List<dynamic> segments, {
  DateTime? timeBase,
}) {
  final corpus = StringBuffer();
  final labels = <String>{};
  for (final raw in segments) {
    if (raw is! Map) continue;
    final text = raw['text'];
    if (text is String) {
      corpus
        ..write(_normalize(text))
        ..write('\n');
    }
    for (final key in const ['speaker_label', 'speaker']) {
      final value = raw[key];
      if (value is String) {
        final label = _normalize(value).toLowerCase();
        labels
          ..add(label)
          // Chunk-scoped labels (`1:S1`) make their local part legal too.
          ..add(label.split(':').last);
      }
    }
  }
  final corpusText = corpus.toString();
  final corpusLower = corpusText.toLowerCase();
  final basis = _DateBasis.extract(corpusText, timeBase);
  final inputAmounts = _extractAmounts(corpusText);

  final fields = <String, String?>{'overview': summary['overview'] as String?};
  void collect(String field, String listKey) {
    final items = summary[listKey];
    if (items is! List) return;
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      fields['$listKey[$index].text'] = item is Map
          ? item['text'] as String?
          : null;
    }
  }

  collect('decisions', 'decisions');
  collect('actions', 'actions');

  final violations = <TalkRecordAiFactViolation>[];
  for (final entry in fields.entries) {
    final raw = entry.value;
    if (raw is! String || raw.isEmpty) continue;
    final text = _normalize(raw);
    for (final person in _extractPersons(text)) {
      final key = person.toLowerCase();
      if (corpusLower.contains(key) || labels.contains(key)) continue;
      violations.add(
        TalkRecordAiFactViolation(
          kind: TalkRecordAiFactKind.person,
          field: entry.key,
          fragment: person,
          evidence: 'no person basis in transcript',
        ),
      );
    }
    for (final amount in _extractAmounts(text)) {
      final grounded = inputAmounts.any(
        (input) =>
            input.unit == amount.unit &&
            (input.value - amount.value).abs() <
                1e-6 * (amount.value.abs() > 1 ? amount.value.abs() : 1),
      );
      if (grounded) continue;
      violations.add(
        TalkRecordAiFactViolation(
          kind: TalkRecordAiFactKind.amount,
          field: entry.key,
          fragment: amount.fragment,
          evidence: 'no amount basis in transcript (${amount.unit})',
        ),
      );
    }
    for (final date in _extractDates(text)) {
      if (basis.grounds(date, timeBase)) continue;
      violations.add(
        TalkRecordAiFactViolation(
          kind: TalkRecordAiFactKind.date,
          field: entry.key,
          fragment: date.fragment,
          evidence: 'no date basis in transcript',
        ),
      );
    }
  }
  return violations;
}

// ---------------------------------------------------------------------------
// Normalization: full-width ASCII -> half-width, ideographic space, ￥ -> ¥.
// ---------------------------------------------------------------------------

String _normalize(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    if (rune >= 0xff01 && rune <= 0xff5e) {
      buffer.writeCharCode(rune - 0xfee0);
    } else if (rune == 0x3000) {
      buffer.writeCharCode(0x20);
    } else if (rune == 0xffe5) {
      buffer.writeCharCode(0xa5);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Chinese numerals: positional forms (二〇二六) and unit forms (五万/三千五).
// ---------------------------------------------------------------------------

const String _numeralClass = '零〇一二两三四五六七八九十百千万亿点';
const String _numeralDigitClass = '零〇一二两三四五六七八九';

int? _digitValue(String char) => switch (char) {
  '零' || '〇' => 0,
  '一' => 1,
  '二' || '两' => 2,
  '三' => 3,
  '四' => 4,
  '五' => 5,
  '六' => 6,
  '七' => 7,
  '八' => 8,
  '九' => 9,
  _ => null,
};

double? _unitValue(String char) => switch (char) {
  '十' => 10,
  '百' => 100,
  '千' => 1000,
  _ => null,
};

/// Parses simple Chinese numerals. Positional digit strings (二〇二六) are
/// concatenated; unit forms follow the standard 万/亿 hierarchy. Returns null
/// for anything unparsable or implausibly large.
double? _chineseNumeral(String raw) {
  if (raw.isEmpty || raw.length > 12) return null;
  var positional = true;
  for (final rune in raw.runes) {
    final char = String.fromCharCode(rune);
    if (_digitValue(char) == null && char != '〇') positional = false;
    if (_digitValue(char) == null &&
        _unitValue(char) == null &&
        char != '万' &&
        char != '亿' &&
        char != '点' &&
        char != '〇') {
      return null;
    }
  }
  if (positional) {
    var value = 0.0;
    for (final rune in raw.runes) {
      value = value * 10 + (_digitValue(String.fromCharCode(rune)) ?? 0);
    }
    return value <= 1e13 ? value : null;
  }
  var total = 0.0, section = 0.0, pending = -1.0, fraction = 0.0;
  var inFraction = false, fractionScale = 0.1;
  for (final rune in raw.runes) {
    final char = String.fromCharCode(rune);
    final digit = _digitValue(char);
    if (digit != null) {
      if (inFraction) {
        fraction += digit * fractionScale;
        fractionScale /= 10;
      } else {
        pending = digit.toDouble();
      }
      continue;
    }
    if (char == '点') {
      if (pending >= 0) {
        section += pending;
        pending = -1;
      }
      inFraction = true;
      continue;
    }
    final unit = _unitValue(char);
    if (unit != null) {
      section += (pending < 0 ? 1 : pending) * unit;
      pending = -1;
      continue;
    }
    if (char == '万' || char == '亿') {
      if (pending >= 0) section += pending;
      pending = -1;
      if (char == '万') {
        total += section * 1e4;
      } else {
        total = (total + section) * 1e8;
      }
      section = 0;
      continue;
    }
    return null;
  }
  final value = total + section + (pending >= 0 ? pending : 0) + fraction;
  return value >= 0 && value <= 1e13 ? value : null;
}

// ---------------------------------------------------------------------------
// Persons: candidates only in explicit agent contexts (speech verbs, quotes,
// conjunction pairs, Latin "X said"), then stoplist + grounding.
// ---------------------------------------------------------------------------

const String _surnames =
    '王李张刘陈杨黄赵吴周徐孙马朱胡郭何高林罗郑梁谢宋唐许韩冯邓曹彭曾肖田董潘袁蔡蒋余于杜叶程苏魏吕丁任沈姚卢姜崔钟谭陆汪范金石廖贾夏韦傅方白邹孟熊秦邱江尹薛闫段雷侯龙史陶黎贺顾毛郝龚邵万钱严覃武戴莫孔向汤欧阳司马上官诸葛东方尉迟公孙皇甫令狐慕容';

const String _speechVerbs =
    '说|表示|认为|指出|提到|提出|建议|确认|同意|强调|补充|询问|回答|要求|决定|负责|汇报|承诺|拒绝|提醒|宣布|反对|支持|介绍|总结';

final RegExp _personAfterBoundary = RegExp(
  '(?:^|[，。、；：！？\\s）)”」』])([一-龥]{2,4})(?=(?:$_speechVerbs))',
);

final RegExp _personSurname = RegExp(
  '([$_surnames][一-龥]{1,3})(?=(?:$_speechVerbs))',
);

final RegExp _personPair = RegExp(
  '([$_surnames][一-龥]{1,3})(?:和|与|跟)([$_surnames][一-龥]{1,3})(?=(?:$_speechVerbs))',
);

final RegExp _personQuotedVerb = RegExp(
  '[「『“\']([^「『」』“”\']{1,16})[」』”\'](?:的)?(?:$_speechVerbs)',
);

final RegExp _personQuotedAs = RegExp(
  '(?:叫|称为|称作|称呼|是)[「『“\']([^「『」』“”\']{1,16})[」』”\']',
);

final RegExp _personLatin = RegExp(
  '(?:^|[^A-Za-z0-9_])'
  '([A-Za-z][A-Za-z0-9_.\\-]{0,24}(?:[ ][A-Za-z][A-Za-z0-9_.\\-]{0,24}){0,2})'
  '[ ]?(?:said|says|noted|added|asked|proposed|confirmed|agreed|suggested|'
  'mentioned|$_speechVerbs)',
  caseSensitive: false,
);

/// Generic referents, roles, temporal/common words that would otherwise look
/// like agents before a speech verb. Chinese entries (length >= 2) also
/// block by prefix so 马上面谈/任何问题/高级工程师 stay quiet.
const Set<String> _personStoplist = {
  // Pronouns and groups.
  '我们', '你们', '他们', '她们', '它们', '咱们', '自己', '大家', '所有人', '全员',
  '全体', '各方', '双方', '甲方', '乙方', '我方', '贵方', '对方', '有人', '某人',
  '任何人', '每个人', '与会者', '参会人', '参会者', '成员',
  // Roles and organizations.
  '负责人', '工程师', '经理', '主管', '总监', '组长', '领导', '老板', '客户', '用户',
  '同事', '供应商', '厂商', '团队', '公司', '部门', '项目组', '官方', '平台', '系统',
  '客服', '运营', '产品', '财务', '法务', '行政', '人事', '顾问', '专家', '老师',
  '医生', '律师', '记者', '嘉宾', '主持人', '高管', '很多', '部分', '少数', '多数',
  // Temporal and discourse words that precede verbs.
  '今天', '明天', '后天', '昨天', '前天', '目前', '现在', '最终', '最后', '会上',
  '现场', '会议', '讨论', '结果', '方案', '计划', '项目', '预算', '数据', '资料',
  '文档', '材料', '错误', '问题', '需求', '目标', '任务', '流程', '规则', '标准',
  '版本', '接口', '测试', '上线', '发布', '回复', '反馈', '意见', '其他', '以下',
  '如下', '关于', '上述', '以上', '本次', '资金', '技术', '金额', '金融', '万一',
  '马上', '周期', '周报', '周末', '周一', '周二', '周三', '周四', '周五', '周六',
  '周日', '严格', '严肃', '高度', '高峰', '高级', '任何', '任职', '自我',
  // English generic agents (exact match only).
  'the', 'this', 'that', 'these', 'those', 'we', 'you', 'they', 'he', 'she',
  'it', 'team', 'company', 'system', 'platform', 'official', 'client',
  'customer', 'user', 'manager', 'engineer', 'leader', 'boss', 'side',
  'party', 'everyone', 'someone', 'anyone', 'nobody', 'glm', 'ai',
};

bool _personStopped(String candidate) {
  final lower = candidate.toLowerCase();
  if (_personStoplist.contains(lower)) return true;
  // Prefix rule for Chinese stopwords only (English names may legitimately
  // start with e.g. "the" in Theodore).
  if (RegExp(r'^[一-龥]+$').hasMatch(candidate)) {
    for (final word in _personStoplist) {
      if (word.length >= 2 && lower.startsWith(word)) return true;
    }
  }
  return false;
}

final RegExp _cjkOnly = RegExp(r'^[一-龥]+$');
final RegExp _latinOnly = RegExp(r'^[A-Za-z][A-Za-z0-9_.\- ]*$');

List<String> _extractPersons(String text) {
  final candidates = <String>[];
  final seen = <String>{};
  void add(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length < 2 ||
        trimmed.length > 26 ||
        (!_cjkOnly.hasMatch(trimmed) && !_latinOnly.hasMatch(trimmed))) {
      return;
    }
    if (_personStopped(trimmed)) return;
    if (seen.add(trimmed.toLowerCase())) candidates.add(trimmed);
  }

  for (final match in _personPair.allMatches(text)) {
    add(match.group(1)!);
    add(match.group(2)!);
  }
  for (final match in _personAfterBoundary.allMatches(text)) {
    add(match.group(1)!);
  }
  for (final match in _personSurname.allMatches(text)) {
    add(match.group(1)!);
  }
  for (final match in _personQuotedVerb.allMatches(text)) {
    add(match.group(1)!);
  }
  for (final match in _personQuotedAs.allMatches(text)) {
    add(match.group(1)!);
  }
  for (final match in _personLatin.allMatches(text)) {
    add(match.group(1)!);
  }
  return candidates;
}

// ---------------------------------------------------------------------------
// Amounts: (value, currency) facts. Bare 万/亿 count as implied CNY unless a
// classifier follows (五万人 is a count, 五万。 is money).
// ---------------------------------------------------------------------------

class _AmountFact {
  const _AmountFact(this.value, this.unit, this.fragment);
  final double value;

  /// CNY / USD / JPY / EUR / GBP / HKD / PERCENT.
  final String unit;
  final String fragment;
}

const String _currenciesWord =
    '万亿美元|万美金|万美元|亿美金|亿美元|万元|亿元|万亿|日元|美元|美金|欧元|英镑|港元|港币|'
    '人民币|元|圆|块|円';

final RegExp _amountArabic = RegExp(
  '(\\d+(?:\\.\\d+)?)\\s*($_currenciesWord|%)',
);

final RegExp _amountSymbol = RegExp('[¥\$]\\s*(\\d+(?:\\.\\d+)?)');

const String _classifierGuard =
    '(?![人次个条项台件张名页步份款种类年月日天小时分钟秒米克吨升位批组轮期届级倍折'
    '元圆块円美元日元欧元英镑港元港币人民币%])';

final RegExp _amountArabicBare = RegExp(
  '(\\d+(?:\\.\\d+)?)(万|亿)$_classifierGuard',
);

final RegExp _amountChinese = RegExp(
  '([$_numeralClass]{1,12})($_currenciesWord)',
);

final RegExp _amountChineseBare = RegExp(
  '([$_numeralClass]{1,12})(万|亿)$_classifierGuard',
);

final RegExp _percentChinese = RegExp('百分之([$_numeralClass]{1,12})');

final RegExp _percentPoint = RegExp(
  '(\\d+(?:\\.\\d+)?|[$_numeralClass]{1,8})个?百分点',
);

final RegExp _tenthChinese = RegExp('([$_numeralDigitClass]{1,3})成(?![为就长立])');

_AmountFact? _amountFromUnit(double value, String unit, String fragment) {
  switch (unit) {
    case '%':
      return _AmountFact(value, 'PERCENT', fragment);
    case '万亿美元':
      return _AmountFact(value * 1e12, 'USD', fragment);
    case '万亿元':
    case '万亿':
      return _AmountFact(value * 1e12, 'CNY', fragment);
    case '万美金':
    case '万美元':
      return _AmountFact(value * 1e4, 'USD', fragment);
    case '亿美金':
    case '亿美元':
      return _AmountFact(value * 1e8, 'USD', fragment);
    case '万元':
      return _AmountFact(value * 1e4, 'CNY', fragment);
    case '亿元':
      return _AmountFact(value * 1e8, 'CNY', fragment);
    case '美元':
    case '美金':
      return _AmountFact(value, 'USD', fragment);
    case '日元':
    case '円':
      return _AmountFact(value, 'JPY', fragment);
    case '欧元':
      return _AmountFact(value, 'EUR', fragment);
    case '英镑':
      return _AmountFact(value, 'GBP', fragment);
    case '港元':
    case '港币':
      return _AmountFact(value, 'HKD', fragment);
    case '万':
      return _AmountFact(value * 1e4, 'CNY', fragment);
    case '亿':
      return _AmountFact(value * 1e8, 'CNY', fragment);
    case '人民币':
    case '元':
    case '圆':
    case '块':
      return _AmountFact(value, 'CNY', fragment);
  }
  return null;
}

List<_AmountFact> _extractAmounts(String text) {
  final facts = <_AmountFact>[];
  final seen = <String>{};
  final consumed = <List<int>>[];
  bool overlaps(int start, int end) =>
      consumed.any((span) => start < span[1] && span[0] < end);
  void emit(_AmountFact? fact, int start, int end) {
    if (fact == null || overlaps(start, end)) return;
    consumed.add([start, end]);
    if (seen.add('${fact.unit}:${fact.value}')) facts.add(fact);
  }

  for (final match in _amountArabic.allMatches(text)) {
    emit(
      _amountFromUnit(
        double.parse(match.group(1)!),
        match.group(2)!,
        match[0]!,
      ),
      match.start,
      match.end,
    );
  }
  for (final match in _amountSymbol.allMatches(text)) {
    final value = double.parse(match.group(1)!);
    final currency = match[0]!.startsWith('\$') ? 'USD' : 'CNY';
    emit(_AmountFact(value, currency, match[0]!), match.start, match.end);
  }
  for (final match in _amountArabicBare.allMatches(text)) {
    emit(
      _amountFromUnit(
        double.parse(match.group(1)!),
        match.group(2)!,
        match[0]!,
      ),
      match.start,
      match.end,
    );
  }
  for (final match in _percentChinese.allMatches(text)) {
    final value = _chineseNumeral(match.group(1)!);
    emit(
      value == null
          ? null
          : _AmountFact(value, 'PERCENT', '百分之${match.group(1)}'),
      match.start,
      match.end,
    );
  }
  for (final match in _percentPoint.allMatches(text)) {
    final raw = match.group(1)!;
    final value = RegExp(r'^\d').hasMatch(raw)
        ? double.parse(raw)
        : _chineseNumeral(raw);
    emit(
      value == null ? null : _AmountFact(value, 'PERCENT', match[0]!),
      match.start,
      match.end,
    );
  }
  for (final match in _tenthChinese.allMatches(text)) {
    final value = _chineseNumeral(match.group(1)!);
    emit(
      value == null ? null : _AmountFact(value * 10, 'PERCENT', match[0]!),
      match.start,
      match.end,
    );
  }
  for (final match in _amountChinese.allMatches(text)) {
    final value = _chineseNumeral(match.group(1)!);
    emit(
      value == null ? null : _amountFromUnit(value, match.group(2)!, match[0]!),
      match.start,
      match.end,
    );
  }
  for (final match in _amountChineseBare.allMatches(text)) {
    final value = _chineseNumeral(match.group(1)!);
    emit(
      value == null ? null : _amountFromUnit(value, match.group(2)!, match[0]!),
      match.start,
      match.end,
    );
  }
  return facts;
}

// ---------------------------------------------------------------------------
// Dates: absolute (y/m/d in any numeral script), weekday terms (modifier
// included), relative day classes (folded against an optional time base).
// ---------------------------------------------------------------------------

class _DateFact {
  const _DateFact({
    this.year,
    this.month,
    this.day,
    this.weekdayKey,
    this.offset,
    required this.fragment,
  });

  final int? year;
  final int? month;
  final int? day;

  /// `modifier|index` for 周/星期/礼拜 terms; 7 encodes 末.
  final String? weekdayKey;

  /// 0 today, +1 tomorrow ... -1 yesterday.
  final int? offset;
  final String fragment;
}

class _AbsoluteDate {
  const _AbsoluteDate(this.year, this.month, this.day);
  final int? year;
  final int? month;
  final int? day;
}

class _DateBasis {
  const _DateBasis(this.absolutes, this.weekdayKeys, this.offsets);
  final List<_AbsoluteDate> absolutes;
  final Set<String> weekdayKeys;
  final Set<int> offsets;

  static _DateBasis extract(String text, DateTime? timeBase) {
    final absolutes = <_AbsoluteDate>[];
    final weekdayKeys = <String>{};
    final offsets = <int>{};
    for (final fact in _extractDates(text)) {
      if (fact.weekdayKey != null) {
        weekdayKeys.add(fact.weekdayKey!);
      } else if (fact.offset != null) {
        offsets.add(fact.offset!);
        if (timeBase != null) {
          final folded = _fold(timeBase, fact.offset!);
          absolutes.add(_AbsoluteDate(folded.year, folded.month, folded.day));
        }
      } else {
        absolutes.add(_AbsoluteDate(fact.year, fact.month, fact.day));
      }
    }
    return _DateBasis(absolutes, weekdayKeys, offsets);
  }

  bool grounds(_DateFact fact, DateTime? timeBase) {
    if (fact.weekdayKey != null) {
      return weekdayKeys.contains(fact.weekdayKey);
    }
    if (fact.offset != null) {
      if (offsets.contains(fact.offset)) return true;
      if (timeBase != null) {
        final target = _fold(timeBase, fact.offset!);
        return absolutes.any(
          (input) =>
              input.year == target.year &&
              input.month == target.month &&
              input.day == target.day,
        );
      }
      return false;
    }
    for (final input in absolutes) {
      if (fact.year != null && input.year != fact.year) continue;
      if (fact.month != null && input.month != fact.month) continue;
      if (fact.day != null && input.day != fact.day) continue;
      if (fact.year != null && input.year == null) continue;
      if (fact.month != null && input.month == null) continue;
      if (fact.day != null && input.day == null) continue;
      return true;
    }
    return false;
  }
}

DateTime _fold(DateTime base, int offset) =>
    DateTime(base.year, base.month, base.day + offset);

final RegExp _dateArabic = RegExp(
  '(\\d{4})年\\s?(\\d{1,2})月\\s?(\\d{1,2})[日号]?'
  '|(\\d{4})[./-](\\d{1,2})[./-](\\d{1,2})'
  '|(\\d{1,2})月(\\d{1,2})[日号]'
  '|(\\d{4})年\\s?(\\d{1,2})月'
  '|(\\d{4})年',
);

final RegExp _dateChinese = RegExp(
  '([$_numeralClass]{2,10})年([$_numeralClass]{1,6})月([$_numeralClass]{1,6})[日号]?'
  '|([$_numeralClass]{2,10})年([$_numeralClass]{1,6})月'
  '|([$_numeralClass]{1,4})月([$_numeralClass]{1,4})[日号]'
  '|([$_numeralClass]{2,8})年',
);

final RegExp _weekday = RegExp('(下下|下|这|本|上)?(?:周|星期|礼拜)([一二三四五六日天末])');

final RegExp _relativeDay = RegExp(
  '大后天|大前天|今天|今日|当天|今晚|明天|明日|明晚|后天|后日|昨天|昨日|前天',
);

const Map<String, int> _relativeOffsets = {
  '今天': 0,
  '今日': 0,
  '当天': 0,
  '今晚': 0,
  '明天': 1,
  '明日': 1,
  '明晚': 1,
  '后天': 2,
  '后日': 2,
  '大后天': 3,
  '昨天': -1,
  '昨日': -1,
  '前天': -2,
  '大前天': -3,
};

bool _validYear(int year) => year >= 1500 && year <= 3000;
bool _validMonth(int month) => month >= 1 && month <= 12;
bool _validDay(int day) => day >= 1 && day <= 31;

List<_DateFact> _extractDates(String text) {
  final facts = <_DateFact>[];
  final seen = <String>{};
  void emit(_DateFact? fact) {
    if (fact == null) return;
    if (!seen.add(
      '${fact.year}/${fact.month}/${fact.day}'
      '/${fact.weekdayKey}/${fact.offset}',
    )) {
      return;
    }
    facts.add(fact);
  }

  for (final match in _dateArabic.allMatches(text)) {
    final groups = List<String?>.generate(12, match.group);
    final y = _parseInt(groups[1] ?? groups[4] ?? groups[9] ?? groups[11]);
    final m = _parseInt(groups[2] ?? groups[5] ?? groups[7] ?? groups[10]);
    final d = _parseInt(groups[3] ?? groups[6] ?? groups[8]);
    if (y != null && !_validYear(y)) continue;
    if (m != null && !_validMonth(m)) continue;
    if (d != null && !_validDay(d)) continue;
    emit(_DateFact(year: y, month: m, day: d, fragment: match[0]!));
  }
  for (final match in _dateChinese.allMatches(text)) {
    // Alternation groups: 1-3 (y,m,d), 4-5 (y,m), 6-7 (m,d), 8 (y).
    final groups = List<String?>.generate(9, match.group);
    final y = _chineseNumeral(groups[1] ?? groups[4] ?? groups[8] ?? '');
    final m = _chineseNumeral(groups[2] ?? groups[5] ?? groups[6] ?? '');
    final d = _chineseNumeral(groups[3] ?? groups[7] ?? '');
    final yInt = y?.round();
    final mInt = m?.round();
    final dInt = d?.round();
    if (yInt != null && !_validYear(yInt)) continue;
    if (mInt != null && !_validMonth(mInt)) continue;
    if (dInt != null && !_validDay(dInt)) continue;
    emit(_DateFact(year: yInt, month: mInt, day: dInt, fragment: match[0]!));
  }
  for (final match in _weekday.allMatches(text)) {
    final modifier = match.group(1) ?? '';
    final day = switch (match.group(2)) {
      '一' => 1,
      '二' => 2,
      '三' => 3,
      '四' => 4,
      '五' => 5,
      '六' => 6,
      '日' || '天' => 0,
      '末' => 7,
      _ => -1,
    };
    if (day < 0) continue;
    emit(_DateFact(weekdayKey: '$modifier|$day', fragment: match[0]!));
  }
  for (final match in _relativeDay.allMatches(text)) {
    final offset = _relativeOffsets[match.group(0)]!;
    emit(_DateFact(offset: offset, fragment: match[0]!));
  }
  return facts;
}

int? _parseInt(String? raw) {
  if (raw == null) return null;
  return int.tryParse(raw);
}

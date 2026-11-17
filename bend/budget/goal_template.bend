# The parser for budget templates written in category notes, such as
# `#template $50 up to 200` or `#template-2 schedule Rent [increase 5%]`: a
# port of packages/loot-core/src/server/budget/goal-template.pegjs.
#
# The TypeScript compiles that grammar with Peggy. Here each rule is a def
# that reads the head of a text and answers its value and the text after it,
# with Peggy's semantics: a choice takes its first alternative that matches
# and is not revisited when what follows fails. `GoalTemplate.parse` answers
# the template as the JSON value the Peggy actions build, so its text equals
# `JSON.stringify` of the TS result; None where Peggy throws.
import Base
import ../lib/core.bend as C
import ../lib/num.bend as N
import ../lib/text.bend as T
import ../json/json.bend as J
import ../shared/util.bend as F
import ../shared/arithmetic.bend as A

# A rule's value and the text after it.
type Tpl.R is Data:
  R{value: J.Json, rest: String}

# Matched text and the text after it.
type Tpl.Span is Data:
  Span{text: String, rest: String}

def Tpl.then(m: Maybe<&2, Tpl.R>, f: J.Json -> String -> Maybe<&2, Tpl.R>) -> Maybe<&2, Tpl.R>:
  match m:
    case None{}:
      None{}
    case Some{R{v, rest}}:
      f(v, rest)

def Tpl.span_then(m: Maybe<&2, Tpl.Span>, f: String -> String -> Maybe<&2, Tpl.R>) -> Maybe<&2, Tpl.R>:
  match m:
    case None{}:
      None{}
    case Some{Span{text, rest}}:
      f(text, rest)

def Tpl.rest_then(m: Maybe<&2, String>, f: String -> Maybe<&2, Tpl.R>) -> Maybe<&2, Tpl.R>:
  match m:
    case None{}:
      None{}
    case Some{rest}:
      f(rest)

# An optional rule: its value, or `null` and the text untouched.
def Tpl.opt(m: Maybe<&2, Tpl.R>, s: String) -> Tpl.R:
  match m:
    case None{}:
      R{J.JNull{}, s}
    case Some{r}:
      r

# The first alternative that matched.
def Tpl.or(a: Maybe<&2, Tpl.R>, b: Maybe<&2, Tpl.R>) -> Maybe<&2, Tpl.R>:
  match a:
    case None{}:
      b
    case Some{r}:
      Some{r}

# Tokens
# ------

# `_`: spaces and tabs.
def Tpl.ws(s: String) -> String:
  match s:
    case SCon{' ', t}:
      Tpl.ws(t)
    case SCon{'\t', t}:
      Tpl.ws(t)
    case other:
      other

# A literal, compared without case: the text after it. `w` is in lower case.
def Tpl.word(+s: String, +w: String) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, String.starts_with(String.to_lower(String.take(s, String.length(w))), w),
    Some{String.drop(s, String.length(w))}, None{})

# A literal, compared exactly.
def Tpl.exact(+s: String, +w: String) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, String.starts_with(s, w), Some{String.drop(s, String.length(w))}, None{})

# Literals without case, with `_` between them.
def Tpl.words(ws: List<&2, String>, s: String) -> Maybe<&2, String>:
  match ws:
    case Nil{}:
      Some{s}
    case Con{w, Nil{}}:
      Tpl.word(s, w)
    case Con{w, rest}:
      Maybe.bind(&2, String, String, Tpl.word(s, w), after => Tpl.words(rest, Tpl.ws(after)))

def Tpl.is_digit(+x: U32) -> Bool:
  Bool.and((x >= 48 : U32), (x <= 57 : U32))

def Tpl.digits.put(c: Char, r: Tpl.Span) -> Tpl.Span:
  match r:
    case Span{text, rest}:
      Span{SCon{c, text}, rest}

# At most `max` digits at the head of s.
def Tpl.digits(max: Nat, s: String) -> Tpl.Span:
  match max s:
    case 0n other:
      Span{SNil{}, other}
    case 1n+p SNil{}:
      Span{SNil{}, SNil{}}
    case 1n+ +p SCon{Chr{+x}, +t}:
      C.If(Tpl.Span, Tpl.is_digit(x),
        u => Tpl.digits.put(Chr{x}, Tpl.digits(p, t)),
        u => Span{SNil{}, SCon{Chr{x}, t}})

def Tpl.fixed.check(n: Nat, r: Tpl.Span) -> Maybe<&2, Tpl.Span>:
  match r:
    case Span{+text, rest}:
      Bool.pick(Maybe<&2, Tpl.Span>, Nat.is_eq(String.length(text), n), Some{Span{text, rest}}, None{})

# Exactly n digits.
def Tpl.fixed(+n: Nat, s: String) -> Maybe<&2, Tpl.Span>:
  Tpl.fixed.check(n, Tpl.digits(n, s))

def Tpl.nonempty(r: Tpl.Span) -> Maybe<&2, Tpl.Span>:
  match r:
    case Span{SNil{}, rest}:
      None{}
    case Span{text, rest}:
      Some{Span{text, rest}}

# `number`: one or more digits.
def Tpl.number(s: String) -> Maybe<&2, Tpl.Span>:
  Tpl.nonempty(Tpl.digits(64n, s))

# `positive`: digits not starting with 0.
def Tpl.positive(s: String) -> Maybe<&2, Tpl.Span>:
  match s:
    case SCon{'0', t}:
      None{}
    case other:
      Tpl.number(other)

def Tpl.frac.join(whole: String, r: Tpl.Span) -> Tpl.Span:
  match r:
    case Span{text, rest}:
      Span{whole ++ "." ++ text, rest}

# After the whole digits: an optional point and at most `max` digits.
def Tpl.frac(whole: String, rest: String, max: Nat) -> Tpl.Span:
  match rest:
    case SCon{'.', t}:
      Tpl.frac.join(whole, Tpl.digits(max, t))
    case other:
      Span{whole, other}

def Tpl.decimal.whole(m: Maybe<&2, Tpl.Span>, max: Nat) -> Maybe<&2, Tpl.Span>:
  match m:
    case None{}:
      None{}
    case Some{Span{text, rest}}:
      Some{Tpl.frac(text, rest, max)}

# `d+ ('.' d{0,max})?`
def Tpl.decimal(s: String, max: Nat) -> Maybe<&2, Tpl.Span>:
  Tpl.decimal.whole(Tpl.number(s), max)

def Tpl.minus(r: Maybe<&2, Tpl.Span>) -> Maybe<&2, Tpl.Span>:
  match r:
    case None{}:
      None{}
    case Some{Span{text, rest}}:
      Some{Span{SCon{'-', text}, rest}}

# `'-'? d+ ('.' (d d?)?)?`
def Tpl.signed(s: String) -> Maybe<&2, Tpl.Span>:
  match s:
    case SCon{'-', t}:
      Tpl.minus(Tpl.decimal(t, 2n))
    case other:
      Tpl.decimal(other, 2n)

# A JS number from its text, `+text`, as a JSON value.
def Tpl.num(text: String) -> J.Json:
  J.JDec{N.Num.show(Maybe.default(&2, N.Num, F.Util.parse_float(text), N.Num.zero()))}

def Tpl.num_r(m: Maybe<&2, Tpl.Span>) -> Maybe<&2, Tpl.R>:
  match m:
    case None{}:
      None{}
    case Some{Span{text, rest}}:
      Some{R{Tpl.num(text), rest}}

def Tpl.str_r(m: Maybe<&2, Tpl.Span>) -> Maybe<&2, Tpl.R>:
  match m:
    case None{}:
      None{}
    case Some{Span{text, rest}}:
      Some{R{J.JStr{text}, rest}}

# `currencySymbol? _?`
def Tpl.currency(s: String) -> String:
  match s:
    case SCon{Chr{+x}, +t}:
      Tpl.ws(Bool.pick(String, A.Arith.is_currency(x), t, SCon{Chr{x}, t}))
    case other:
      other

# `amount`
def Tpl.amount(s: String) -> Maybe<&2, Tpl.R>:
  Tpl.num_r(Tpl.signed(Tpl.currency(s)))

# `unsignedAmount`
def Tpl.unsigned_amount(s: String) -> Maybe<&2, Tpl.R>:
  Tpl.num_r(Tpl.decimal(Tpl.currency(s), 2n))

def Tpl.percent.sign(sp: Tpl.Span) -> Maybe<&2, Tpl.Span>:
  match sp:
    case Span{text, rest}:
      Maybe.map(&2, String, Tpl.Span, after => Span{text, after}, Tpl.exact(Tpl.ws(rest), "%"))

# `percent`: `d+ ('.' d*)? _? '%'`, as its text.
def Tpl.percent(s: String) -> Maybe<&2, Tpl.Span>:
  Maybe.bind(&2, Tpl.Span, Tpl.Span, Tpl.decimal(s, 64n), sp => Tpl.percent.sign(sp))

def Tpl.join(a: String, sep: String, m: Maybe<&2, Tpl.Span>) -> Maybe<&2, Tpl.Span>:
  match m:
    case None{}:
      None{}
    case Some{Span{text, rest}}:
      Some{Span{a ++ sep ++ text, rest}}

def Tpl.dash(m: Maybe<&2, Tpl.Span>) -> Maybe<&2, Tpl.Span>:
  match m:
    case Some{Span{text, SCon{'-', t}}}:
      Tpl.join(text, "-", Tpl.fixed(2n, t))
    case other:
      None{}

# `month`: `dddd-dd`
def Tpl.month(s: String) -> Maybe<&2, Tpl.Span>:
  Tpl.dash(Tpl.fixed(4n, s))

# `date`: `dddd-dd-dd`
def Tpl.date(s: String) -> Maybe<&2, Tpl.Span>:
  Tpl.dash(Tpl.month(s))

def Tpl.member(key: String, value: J.Json) -> J.Json.Member:
  J.Member{key, value}

# Rules
# -----

# `hold`: true, or null when absent.
def Tpl.hold(+s: String) -> Tpl.R:
  Tpl.opt(Maybe.map(&2, String, Tpl.R, rest => R{J.JBool{True{}}, rest}, Tpl.word(s, "hold")), s)

def Tpl.limit.make(amount: J.Json, period: String, start: J.Json, hold: Tpl.R) -> Maybe<&2, Tpl.R>:
  match hold:
    case R{h, rest}:
      Some{R{J.Json.object([Tpl.member("amount", amount), Tpl.member("hold", h),
        Tpl.member("period", J.JStr{period}), Tpl.member("start", start)]), rest}}

# After `up to amount _`: `'per week starting' _ date _? hold?`
def Tpl.limit.weekly(amount: J.Json, s: String) -> Maybe<&2, Tpl.R>:
  Tpl.rest_then(Tpl.word(s, "per week starting"), after =>
    Tpl.span_then(Tpl.date(Tpl.ws(after)), start => rest =>
      Tpl.limit.make(amount, "weekly", J.JStr{start}, Tpl.hold(Tpl.ws(rest)))))

# After `up to amount _`: `'per day' _? hold?`
def Tpl.limit.daily(amount: J.Json, s: String) -> Maybe<&2, Tpl.R>:
  Tpl.rest_then(Tpl.word(s, "per day"), after =>
    Tpl.limit.make(amount, "daily", J.JNull{}, Tpl.hold(Tpl.ws(after))))

# `limit`: `_? 'up' _ 'to' _ amount` and then a weekly, daily or monthly tail.
def Tpl.limit(s: String) -> Maybe<&2, Tpl.R>:
  Tpl.rest_then(Tpl.words(["up", "to"], Tpl.ws(s)), after =>
    Tpl.then(Tpl.amount(Tpl.ws(after)), +amount => +rest =>
      Tpl.or(Tpl.limit.weekly(amount, Tpl.ws(rest)),
        Tpl.or(Tpl.limit.daily(amount, Tpl.ws(rest)),
          Tpl.limit.make(amount, "monthly", J.JNull{}, Tpl.hold(Tpl.ws(rest)))))))

# `limit?`
def Tpl.limit_opt(+s: String) -> Tpl.R:
  Tpl.opt(Tpl.limit(s), s)

# The members a modifier adds: `adjustment` and `adjustmentType`.
type Tpl.Mod is Data:
  Mod{members: List<&2, J.Json.Member>, rest: String}

def Tpl.modifier.kind(number: String, +rest: String, percent: Maybe<&2, String>) -> Tpl.Mod:
  match percent:
    case None{}:
      Mod{[Tpl.member("adjustment", Tpl.num(number)), Tpl.member("adjustmentType", J.JStr{"fixed"})], rest}
    case Some{after}:
      Mod{[Tpl.member("adjustment", Tpl.num(number)), Tpl.member("adjustmentType", J.JStr{"percent"})], after}

# `percentOrNumber`, with the sign the operator gives it.
def Tpl.modifier.value(sign: String, sp: Tpl.Span) -> Tpl.Mod:
  match sp:
    case Span{text, +rest}:
      Tpl.modifier.kind(sign ++ text, rest, Tpl.exact(Tpl.ws(rest), "%"))

def Tpl.modifier.close(m: Tpl.Mod) -> Maybe<&2, Tpl.Mod>:
  match m:
    case Mod{members, SCon{']', t}}:
      Some{Mod{members, t}}
    case other:
      None{}

def Tpl.modifier.op(sign: String, after: Maybe<&2, String>) -> Maybe<&2, Tpl.Mod>:
  match after:
    case None{}:
      None{}
    case Some{rest}:
      Maybe.bind(&2, Tpl.Span, Tpl.Mod, Tpl.decimal(Tpl.ws(rest), 64n), sp =>
        Tpl.modifier.close(Tpl.modifier.value(sign, sp)))

def Tpl.modifier.first(a: Maybe<&2, Tpl.Mod>, b: Maybe<&2, Tpl.Mod>) -> Maybe<&2, Tpl.Mod>:
  match a:
    case None{}:
      b
    case Some{m}:
      Some{m}

def Tpl.modifiers.open(s: String) -> Maybe<&2, Tpl.Mod>:
  match s:
    case SCon{'[', +t}:
      Tpl.modifier.first(Tpl.modifier.op("", Tpl.word(t, "increase")),
        Tpl.modifier.op("-", Tpl.word(t, "decrease")))
    case other:
      None{}

def Tpl.modifiers.or(m: Maybe<&2, Tpl.Mod>, s: String) -> Tpl.Mod:
  match m:
    case None{}:
      Mod{Nil{}, s}
    case Some{found}:
      found

# `modifiers?`: `_ '[' ('increase' / 'decrease') _ percentOrNumber ']'`. When
# absent there are no members: the TS leaves both keys undefined.
def Tpl.modifiers(+s: String) -> Tpl.Mod:
  Tpl.modifiers.or(Tpl.modifiers.open(Tpl.ws(s)), s)

# An object ending with a modifier's members.
def Tpl.with_mod(members: List<&2, J.Json.Member>, m: Tpl.Mod) -> Maybe<&2, Tpl.R>:
  match m:
    case Mod{extra, rest}:
      Some{R{J.Json.object(List.append(&2, J.Json.Member, members, extra)), rest}}

# An object whose `limit` member comes from `limit?`; `before` are the
# members ahead of it and `after` those behind.
def Tpl.with_limit(
  before: List<&2, J.Json.Member>, after: List<&2, J.Json.Member>, limit: Tpl.R
) -> Maybe<&2, Tpl.R>:
  match limit:
    case R{value, rest}:
      Some{R{J.Json.object(List.append(&2, J.Json.Member, before,
        Con{Tpl.member("limit", value), after})), rest}}

# `priority` and `directive: 'template'`
def Tpl.tail(priority: J.Json) -> List<&2, J.Json.Member>:
  [Tpl.member("priority", priority), Tpl.member("directive", J.JStr{"template"})]

# `name`: the characters up to a tab or a line end.
def Tpl.name(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{'\r', t}:
      SNil{}
    case SCon{'\n', t}:
      SNil{}
    case SCon{'\t', t}:
      SNil{}
    case SCon{h, t}:
      SCon{h, Tpl.name(t)}

# 1: `percentOf name`
def Tpl.percentage.name(percent: String, previous: Bool, +s: String, priority: J.Json) -> Maybe<&2, Tpl.R>:
  +name = Tpl.name(s)
  Bool.pick(Maybe<&2, Tpl.R>, String.is_empty(name), None{},
    Some{R{J.Json.object(List.append(&2, J.Json.Member,
      [Tpl.member("type", J.JStr{"percentage"}), Tpl.member("percent", Tpl.num(percent)),
       Tpl.member("previous", J.JBool{previous}), Tpl.member("category", J.JStr{name})],
      Tpl.tail(priority))), String.drop(s, String.length(name))}})

def Tpl.percentage.of(percent: String, +after: String, prev: Maybe<&2, String>, priority: J.Json) -> Maybe<&2, Tpl.R>:
  match prev:
    case None{}:
      Tpl.percentage.name(percent, False{}, after, priority)
    case Some{rest}:
      Tpl.percentage.name(percent, True{}, Tpl.ws(rest), priority)

# `percentOf name`, where `percentOf` is `percent _ 'of' _ ('previous' _)?`.
# Once `previous` is read it is not given back to the name.
def Tpl.percentage(s: String, +priority: J.Json) -> Maybe<&2, Tpl.R>:
  Tpl.span_then(Tpl.percent(s), percent => rest =>
    Tpl.rest_then(Tpl.word(Tpl.ws(rest), "of"), +after =>
      Tpl.percentage.of(percent, Tpl.ws(after), Tpl.word(Tpl.ws(after), "previous"), priority)))

def Tpl.period(name: String, count: J.Json, rest: String) -> Maybe<&2, Tpl.R>:
  Some{R{J.Json.object([Tpl.member("period", J.JStr{name}), Tpl.member("amount", count)]), rest}}

# `positive _ unit`, with the unit's own trailing `_` when `pad` is set.
def Tpl.period.counted(+s: String, unit: String, name: String, pad: Bool) -> Maybe<&2, Tpl.R>:
  Tpl.span_then(Tpl.positive(s), n => rest =>
    Tpl.rest_then(Tpl.word(Tpl.ws(rest), unit), +after =>
      Tpl.period(name, Tpl.num(n), Bool.pick(String, pad, Tpl.ws(after), after))))

# `periodCount`
def Tpl.period_count(+s: String) -> Maybe<&2, Tpl.R>:
  Tpl.or(Tpl.rest_then(Tpl.word(s, "day"), after => Tpl.period("day", J.Json.nat(1n), after)),
    Tpl.or(Tpl.period.counted(s, "days", "day", True{}),
      Tpl.or(Tpl.rest_then(Tpl.word(s, "week"), after => Tpl.period("week", J.Json.nat(1n), Tpl.ws(after))),
        Tpl.or(Tpl.period.counted(s, "weeks", "week", False{}),
          Tpl.or(Tpl.period.counted(s, "months", "month", True{}),
            Tpl.or(Tpl.rest_then(Tpl.word(s, "year"), after => Tpl.period("year", J.Json.nat(1n), Tpl.ws(after))),
              Tpl.period.counted(s, "years", "year", True{})))))))

# 2: `amount _ 'repeat' _ 'every' _ periodCount _ 'starting' _ date limit?`
def Tpl.periodic(s: String, +priority: J.Json) -> Maybe<&2, Tpl.R>:
  Tpl.then(Tpl.amount(s), +amount => rest =>
    Tpl.rest_then(Tpl.words(["repeat", "every"], Tpl.ws(rest)), after =>
      Tpl.then(Tpl.period_count(Tpl.ws(after)), +period => rest2 =>
        Tpl.rest_then(Tpl.word(Tpl.ws(rest2), "starting"), after2 =>
          Tpl.span_then(Tpl.date(Tpl.ws(after2)), +starting => rest3 =>
            Tpl.with_limit(
              [Tpl.member("type", J.JStr{"periodic"}), Tpl.member("amount", amount),
               Tpl.member("period", period), Tpl.member("starting", J.JStr{starting})],
              Tpl.tail(priority), Tpl.limit_opt(rest3)))))))

def Tpl.repeat.unit(sp: Tpl.Span, unit: String, annual: Bool) -> Maybe<&2, Tpl.Mod>:
  match sp:
    case Span{n, rest}:
      Maybe.map(&2, String, Tpl.Mod,
        after => Mod{[Tpl.member("annual", J.JBool{annual}), Tpl.member("repeat", Tpl.num(n))], after},
        Tpl.word(Tpl.ws(rest), unit))

def Tpl.repeat.counted(s: String, unit: String, annual: Bool) -> Maybe<&2, Tpl.Mod>:
  Maybe.bind(&2, Tpl.Span, Tpl.Mod, Tpl.positive(s), sp => Tpl.repeat.unit(sp, unit, annual))

def Tpl.repeat.one(s: String, unit: String, annual: Bool) -> Maybe<&2, Tpl.Mod>:
  Maybe.map(&2, String, Tpl.Mod, after => Mod{[Tpl.member("annual", J.JBool{annual})], after},
    Tpl.word(s, unit))

# `repeat`: `'month' / positive _ 'months' / 'year' / positive _ 'years'`,
# as the members it adds.
def Tpl.repeat(+s: String) -> Maybe<&2, Tpl.Mod>:
  Tpl.modifier.first(Tpl.repeat.one(s, "month", False{}),
    Tpl.modifier.first(Tpl.repeat.counted(s, "months", False{}),
      Tpl.modifier.first(Tpl.repeat.one(s, "year", True{}), Tpl.repeat.counted(s, "years", True{}))))

# `(_ 'repeat' _ 'every' _ repeat)?`
def Tpl.repeat_opt(+s: String) -> Tpl.Mod:
  Tpl.modifiers.or(
    Maybe.bind(&2, String, Tpl.Mod, Tpl.words(["repeat", "every"], Tpl.ws(s)), after => Tpl.repeat(Tpl.ws(after))),
    s)

# `spendFrom?`: `_ 'spend' _ 'from' _ month`
def Tpl.spend_from(+s: String) -> Tpl.R:
  Tpl.opt(Tpl.rest_then(Tpl.words(["spend", "from"], Tpl.ws(s)), after => Tpl.str_r(Tpl.month(Tpl.ws(after)))), s)

def Tpl.by.type(from: J.Json) -> J.Json:
  match from:
    case J.JNull{}:
      J.JStr{"by"}
    case other:
      J.JStr{"spend"}

def Tpl.by.make(amount: J.Json, month: String, +from: J.Json, repeat: Tpl.Mod, priority: J.Json) -> Maybe<&2, Tpl.R>:
  match repeat:
    case Mod{members, rest}:
      Some{R{J.Json.object(List.concat(&2, J.Json.Member, [
        [Tpl.member("type", Tpl.by.type(from)), Tpl.member("amount", amount), Tpl.member("month", J.JStr{month})],
        members, [Tpl.member("from", from)], Tpl.tail(priority)])), rest}}

def Tpl.by.from(amount: J.Json, month: String, from: Tpl.R, priority: J.Json) -> Maybe<&2, Tpl.R>:
  match from:
    case R{value, rest}:
      Tpl.by.make(amount, month, value, Tpl.repeat_opt(rest), priority)

# 3: `unsignedAmount _ 'by' _ month spendFrom? (_ 'repeat' _ 'every' _ repeat)?`
def Tpl.by(s: String, +priority: J.Json) -> Maybe<&2, Tpl.R>:
  Tpl.then(Tpl.unsigned_amount(s), +amount => rest =>
    Tpl.rest_then(Tpl.word(Tpl.ws(rest), "by"), after =>
      Tpl.span_then(Tpl.month(Tpl.ws(after)), month => rest2 =>
        Tpl.by.from(amount, month, Tpl.spend_from(rest2), priority))))

# 4: `amount limit?`
def Tpl.simple(s: String, +priority: J.Json) -> Maybe<&2, Tpl.R>:
  Tpl.then(Tpl.amount(s), monthly => rest =>
    Tpl.with_limit([Tpl.member("type", J.JStr{"simple"}), Tpl.member("monthly", monthly)],
      Tpl.tail(priority), Tpl.limit_opt(rest)))

# 5: `limit`
def Tpl.limit_only(s: String, +priority: J.Json) -> Maybe<&2, Tpl.R>:
  Tpl.then(Tpl.limit(s), limit => rest =>
    Some{R{J.Json.object(List.append(&2, J.Json.Member,
      [Tpl.member("type", J.JStr{"simple"}), Tpl.member("monthly", J.JNull{}), Tpl.member("limit", limit)],
      Tpl.tail(priority))), rest}})

# Whether `'[' ('increase' / 'decrease')` is at the head of s.
def Tpl.at_modifier(s: String) -> Bool:
  match s:
    case SCon{'[', +t}:
      Bool.or(Maybe.is_some(&2, String, Tpl.word(t, "increase")),
        Maybe.is_some(&2, String, Tpl.word(t, "decrease")))
    case other:
      False{}

# The rest of a schedule name: any character but a line end, stopping where
# `_ '[' ('increase' / 'decrease')` begins.
def Tpl.schedule_name.more(s: String) -> Tpl.Span:
  match s:
    case SNil{}:
      Span{SNil{}, SNil{}}
    case SCon{'\r', t}:
      Span{SNil{}, SCon{'\r', t}}
    case SCon{'\n', t}:
      Span{SNil{}, SCon{'\n', t}}
    case SCon{+h, +t}:
      C.If(Tpl.Span, Tpl.at_modifier(Tpl.ws(SCon{h, t})),
        u => Span{SNil{}, SCon{h, t}},
        u => Tpl.digits.put(h, Tpl.schedule_name.more(t)))

# `rawScheduleName`: a first character that is not whitespace and does not
# open a modifier, then the rest of the name.
def Tpl.schedule_name(s: String) -> Maybe<&2, Tpl.Span>:
  match s:
    case SNil{}:
      None{}
    case SCon{' ', t}:
      None{}
    case SCon{'\t', t}:
      None{}
    case SCon{'\r', t}:
      None{}
    case SCon{'\n', t}:
      None{}
    case SCon{+h, +t}:
      C.If(Maybe<&2, Tpl.Span>, Tpl.at_modifier(SCon{h, t}),
        u => None{},
        u => Some{Tpl.digits.put(h, Tpl.schedule_name.more(t))})

# `full?`: `'full' _`, true or null.
def Tpl.full(+s: String) -> Tpl.R:
  Tpl.opt(Maybe.map(&2, String, Tpl.R, rest => R{J.JBool{True{}}, Tpl.ws(rest)}, Tpl.word(s, "full")), s)

def Tpl.schedule.named(full: Tpl.R, +priority: J.Json) -> Maybe<&2, Tpl.R>:
  match full:
    case R{+value, rest}:
      Tpl.span_then(Tpl.schedule_name(rest), name => after =>
        Tpl.with_mod(List.append(&2, J.Json.Member,
          Con{Tpl.member("type", J.JStr{"schedule"}), Con{Tpl.member("name", J.JStr{String.trim(name)}),
            Tpl.tail(priority)}},
          [Tpl.member("full", value)]), Tpl.modifiers(after)))

# 6: `'schedule' _ full? rawScheduleName modifiers?`
def Tpl.schedule(s: String, +priority: J.Json) -> Maybe<&2, Tpl.R>:
  Tpl.rest_then(Tpl.word(s, "schedule"), after => Tpl.schedule.named(Tpl.full(Tpl.ws(after)), priority))

# `+weight || 1`
def Tpl.weight(m: Maybe<&2, Tpl.Span>, +s: String) -> Tpl.R:
  match m:
    case None{}:
      R{J.Json.nat(1n), s}
    case Some{Span{n, rest}}:
      R{Tpl.num(n), rest}

def Tpl.remainder.make(weight: Tpl.R) -> Maybe<&2, Tpl.R>:
  match weight:
    case R{value, rest}:
      Tpl.with_limit([Tpl.member("type", J.JStr{"remainder"}), Tpl.member("priority", J.JNull{}),
        Tpl.member("directive", J.JStr{"template"}), Tpl.member("weight", value)], Nil{}, Tpl.limit_opt(rest))

# 7: `'remainder' _? positive? limit?`
def Tpl.remainder(s: String) -> Maybe<&2, Tpl.R>:
  Tpl.rest_then(Tpl.word(s, "remainder"), +after =>
    Tpl.remainder.make(Tpl.weight(Tpl.positive(Tpl.ws(after)), Tpl.ws(after))))

def Tpl.weekday.try(+s: String, days: List<&2, String>) -> Maybe<&2, Tpl.R>:
  match days:
    case Nil{}:
      None{}
    case Con{+day, rest}:
      Tpl.or(Maybe.map(&2, String, Tpl.R, after => R{J.JStr{day}, after}, Tpl.word(s, day)),
        Tpl.weekday.try(s, rest))

# `weekday`, in lower case.
def Tpl.weekday(s: String) -> Maybe<&2, Tpl.R>:
  Tpl.weekday.try(s, ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"])

# `'weeks' / 'week'`
def Tpl.weeks(+s: String) -> Maybe<&2, String>:
  Maybe.or(&2, String, Tpl.word(s, "weeks"), Tpl.word(s, "week"))

# 8: `'average' _ positive _ ('weeks' / 'week') _ 'on' _ weekday modifiers?`
def Tpl.weekly_average(s: String, +priority: J.Json) -> Maybe<&2, Tpl.R>:
  Tpl.rest_then(Tpl.word(s, "average"), after =>
    Tpl.span_then(Tpl.positive(Tpl.ws(after)), +n => rest =>
      Tpl.rest_then(Tpl.weeks(Tpl.ws(rest)), after2 =>
        Tpl.rest_then(Tpl.word(Tpl.ws(after2), "on"), after3 =>
          Tpl.then(Tpl.weekday(Tpl.ws(after3)), weekday => rest2 =>
            Tpl.with_mod(
              Con{Tpl.member("type", J.JStr{"weeklyAverage"}), Con{Tpl.member("numWeeks", Tpl.num(n)),
                Con{Tpl.member("weekday", weekday), Tpl.tail(priority)}}},
              Tpl.modifiers(rest2)))))))

# `'months'?`
def Tpl.months_opt(+s: String) -> String:
  Maybe.default(&2, String, Tpl.word(s, "months"), s)

# 9: `'average' _ positive _ 'months'? modifiers?`
def Tpl.average(s: String, +priority: J.Json) -> Maybe<&2, Tpl.R>:
  Tpl.rest_then(Tpl.word(s, "average"), after =>
    Tpl.span_then(Tpl.positive(Tpl.ws(after)), n => rest =>
      Tpl.with_mod(
        Con{Tpl.member("type", J.JStr{"average"}), Con{Tpl.member("numMonths", Tpl.num(n)), Tpl.tail(priority)}},
        Tpl.modifiers(Tpl.months_opt(Tpl.ws(rest))))))

# 10: `'copy from' _ positive _ 'months ago' limit?`
def Tpl.copy(s: String, +priority: J.Json) -> Maybe<&2, Tpl.R>:
  Tpl.rest_then(Tpl.word(s, "copy from"), after =>
    Tpl.span_then(Tpl.positive(Tpl.ws(after)), +n => rest =>
      Tpl.rest_then(Tpl.word(Tpl.ws(rest), "months ago"), after2 =>
        Tpl.with_limit(
          Con{Tpl.member("type", J.JStr{"copy"}), List.append(&2, J.Json.Member, Tpl.tail(priority),
            [Tpl.member("lookBack", Tpl.num(n))])},
          Nil{}, Tpl.limit_opt(after2)))))

# The alternatives that follow `template _`, in the grammar's order.
def Tpl.after_template(+s: String, +priority: J.Json) -> Maybe<&2, Tpl.R>:
  Tpl.or(Tpl.percentage(s, priority),
    Tpl.or(Tpl.periodic(s, priority),
      Tpl.or(Tpl.by(s, priority),
        Tpl.or(Tpl.simple(s, priority),
          Tpl.or(Tpl.limit_only(s, priority),
            Tpl.or(Tpl.schedule(s, priority),
              Tpl.or(Tpl.remainder(s),
                Tpl.or(Tpl.weekly_average(s, priority),
                  Tpl.or(Tpl.average(s, priority), Tpl.copy(s, priority))))))))))

def Tpl.priority.or(m: Maybe<&2, Tpl.R>, s: String) -> Tpl.R:
  match m:
    case None{}:
      R{J.Json.nat(0n), s}
    case Some{r}:
      r

# `priority?`: `'-' number`, as `+priority`; 0 when absent.
def Tpl.priority(s: String) -> Tpl.R:
  match s:
    case SCon{'-', +t}:
      Tpl.priority.or(Tpl.num_r(Tpl.number(t)), SCon{'-', t})
    case other:
      R{J.Json.nat(0n), other}

def Tpl.template.with(p: Tpl.R) -> Maybe<&2, Tpl.R>:
  match p:
    case R{priority, rest}:
      Tpl.after_template(Tpl.ws(rest), priority)

# `'#template' priority? _` and one of the template forms.
def Tpl.template(s: String) -> Maybe<&2, Tpl.R>:
  Tpl.rest_then(Tpl.exact(s, "#template"), after => Tpl.template.with(Tpl.priority(after)))

# 11: `'#goal' amount`
def Tpl.goal(s: String) -> Maybe<&2, Tpl.R>:
  Tpl.rest_then(Tpl.word(s, "#goal"), after =>
    Tpl.then(Tpl.amount(after), amount => rest =>
      Some{R{J.Json.object([Tpl.member("type", J.JStr{"goal"}), Tpl.member("amount", amount),
        Tpl.member("priority", J.JNull{}), Tpl.member("directive", J.JStr{"goal"})]), rest}}))

# The whole input must be consumed.
def Tpl.whole(m: Maybe<&2, Tpl.R>) -> Maybe<&2, J.Json>:
  match m:
    case Some{R{value, SNil{}}}:
      Some{value}
    case other:
      None{}

# Parses one template line. None where the Peggy parser throws a syntax
# error.
def GoalTemplate.parse(+line: String) -> Maybe<&2, J.Json>:
  Tpl.whole(Tpl.or(Tpl.template(line), Tpl.goal(line)))

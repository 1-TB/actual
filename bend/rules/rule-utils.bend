# Helpers for rules: a port of
# packages/loot-core/src/server/rules/rule-utils.ts.
#
# Deviations:
# - `assert` answers a `Result` where the TS throws a `RuleError`.
# - `migrateIds` answers the patched rule where the TS mutates it, and takes
#   the id mappings as a list where the TS takes a `Map`.
# - `iterateIds` takes a callback that may stop a rule early. Here
#   `RuleUtils.iterate_ids` answers, per rule, the ids the callback would be
#   given, in order; the caller walks each list and stops where the callback
#   would have answered true.
# - `rankRules`: ids are compared by code point (JS compares UTF-16 units),
#   and only when both are strings. When some rules of equal score have no id
#   the JS comparator is inconsistent and its order depends on the engine's
#   sort; here the sort is a stable insertion sort.
# - `parseDateString` checks the text the way date-fns `parseISO` does, with
#   all its ISO 8601 shapes; the only difference is at the two ends of the JS
#   date range, where years below -271820 or above 275759 are all invalid here.
# - `parseRecurDate` is not ported (it needs the rschedule library).
import Base
import ../lib/core.bend as C
import ../lib/date.bend as D
import ../lib/num.bend as N
import ./value.bend as V
import ./types.bend as Y

def RuleUtils.assert(test: Bool, kind: String, msg: String) -> Result<&2, &2, Y.RuleError, Unit>:
  match test:
    case True{}:
      Done{Unit{}}
    case False{}:
      Fail{Y.RuleError{kind, msg}}

# ---------------------------------------------------------------------------
# date-fns `isValid(parseISO(s))`

type RuleUtils.Lead is Data:
  Lead{neg: Bool, value: Nat, rest: String}

type RuleUtils.Cut is Data:
  Cut{before: String, after: String}

type RuleUtils.TimeUnit is Data:
  TimeUnit{int: Nat, whole: Bool, rest: String}

def RuleUtils.digits(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{h, t}:
      Bool.and(Char.is_digit(h), RuleUtils.digits(t))

# The number that exactly n digits at the start of s write, and what follows.
def RuleUtils.lead(+s: String, +n: Nat) -> Maybe<&2, RuleUtils.Lead>:
  +head = String.take(s, n)
  C.If(Maybe<&2, RuleUtils.Lead>, Bool.and(Nat.is_eq(String.length(head), n), RuleUtils.digits(head)),
    u => Some{Lead{False{}, Maybe.default(&2, Nat, Nat.read(head), 0n), String.drop(s, n)}},
    u => None{})

def RuleUtils.iso.century(m: Maybe<&2, RuleUtils.Lead>) -> Maybe<&2, RuleUtils.Lead>:
  match m:
    case None{}:
      None{}
    case Some{Lead{neg, value, rest}}:
      Bool.pick(Maybe<&2, RuleUtils.Lead>, String.is_empty(rest), Some{Lead{neg, (value * 100n : Nat), ""}}, None{})

def RuleUtils.iso.year.pick(full: Maybe<&2, RuleUtils.Lead>, s: String, short: Nat) -> Maybe<&2, RuleUtils.Lead>:
  match full:
    case Some{y}:
      Some{y}
    case None{}:
      RuleUtils.iso.century(RuleUtils.lead(s, short))

def RuleUtils.iso.negate(m: Maybe<&2, RuleUtils.Lead>) -> Maybe<&2, RuleUtils.Lead>:
  match m:
    case None{}:
      None{}
    case Some{Lead{neg, value, rest}}:
      Some{Lead{True{}, value, rest}}

# ^(?:(\d{4}|[+-]\d{6})|(\d{2}|[+-]\d{4})$)
def RuleUtils.iso.year(+s: String) -> Maybe<&2, RuleUtils.Lead>:
  match s:
    case SCon{'+', +t}:
      RuleUtils.iso.year.pick(RuleUtils.lead(t, 6n), t, 4n)
    case SCon{'-', +t}:
      RuleUtils.iso.negate(RuleUtils.iso.year.pick(RuleUtils.lead(t, 6n), t, 4n))
    case other:
      RuleUtils.iso.year.pick(RuleUtils.lead(s, 4n), s, 2n)

def RuleUtils.iso.two(a: Char, b: Char) -> Maybe<&2, Nat>:
  Nat.read(SCon{a, SCon{b, SNil{}}})

def RuleUtils.iso.within(m: Maybe<&2, Nat>, lo: Nat, hi: Nat) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{+n}:
      Bool.and(Nat.is_ge(n, lo), Nat.is_le(n, hi))

def RuleUtils.iso.month_day(m: Maybe<&2, Nat>, d: Maybe<&2, Nat>, leap: Bool) -> Bool:
  match m d:
    case Some{+mo} Some{+da}:
      Bool.and(Bool.and(Nat.is_ge(mo, 1n), Nat.is_le(mo, 12n)),
        Bool.and(Nat.is_ge(da, 1n),
          Nat.is_le(da, D.Date.days_in_month(Bool.pick(Nat, leap, 2000n, 2001n), C.Nat.hi(1n, C.Nat.lo(mo, 12n))))))
    case _ _:
      False{}

# ^(?:(\d{3})|(\d{2})(?:-?(\d{2}))?|W(\d{2})(?:-?(\d{1}))?|)$ and the
# validation of what it captured.
def RuleUtils.iso.date(r: String, leap: Bool) -> Bool:
  match r:
    case SNil{}:
      True{}
    case SCon{'W', SCon{a, SCon{b, SNil{}}}}:
      RuleUtils.iso.within(RuleUtils.iso.two(a, b), 1n, 53n)
    case SCon{'W', SCon{a, SCon{b, SCon{d, SNil{}}}}}:
      Bool.and(RuleUtils.iso.within(RuleUtils.iso.two(a, b), 1n, 53n), RuleUtils.iso.within(RuleUtils.iso.two('0', d), 1n, 7n))
    case SCon{'W', SCon{a, SCon{b, SCon{'-', SCon{d, SNil{}}}}}}:
      Bool.and(RuleUtils.iso.within(RuleUtils.iso.two(a, b), 1n, 53n), RuleUtils.iso.within(RuleUtils.iso.two('0', d), 1n, 7n))
    case SCon{a, SCon{b, SNil{}}}:
      RuleUtils.iso.within(RuleUtils.iso.two(a, b), 1n, 12n)
    case SCon{a, SCon{b, SCon{c, SNil{}}}}:
      RuleUtils.iso.within(Nat.read(SCon{a, SCon{b, SCon{c, SNil{}}}}), 1n, Bool.pick(Nat, leap, 366n, 365n))
    case SCon{a, SCon{b, SCon{'-', SCon{c, SCon{d, SNil{}}}}}}:
      RuleUtils.iso.month_day(RuleUtils.iso.two(a, b), RuleUtils.iso.two(c, d), leap)
    case SCon{a, SCon{b, SCon{c, SCon{d, SNil{}}}}}:
      RuleUtils.iso.month_day(RuleUtils.iso.two(a, b), RuleUtils.iso.two(c, d), leap)
    case other:
      False{}

def RuleUtils.iso.minus(s: String) -> String:
  match s:
    case SCon{'-', t}:
      t
    case other:
      other

# A year and what follows it make a date the JS Date type can hold.
def RuleUtils.iso.dated(y: Maybe<&2, RuleUtils.Lead>) -> Bool:
  match y:
    case None{}:
      False{}
    case Some{Lead{neg, +value, rest}}:
      Bool.and(Nat.is_le(value, Bool.pick(Nat, neg, 271820n, 275759n)),
        RuleUtils.iso.date(RuleUtils.iso.minus(rest), D.Date.is_leap(value)))

def RuleUtils.iso.frac(s: String, +int: Nat, +whole: Bool) -> RuleUtils.TimeUnit:
  match s:
    case SNil{}:
      TimeUnit{int, whole, SNil{}}
    case SCon{Chr{+x}, +t}:
      C.If(RuleUtils.TimeUnit, Char.is_digit(Chr{x}),
        u => RuleUtils.iso.frac(t, int, Bool.and(whole, U32.is_eq(x, 48))),
        u => TimeUnit{int, whole, SCon{Chr{x}, t}})

def RuleUtils.iso.unit.at(n: Maybe<&2, Nat>, t: String) -> Maybe<&2, RuleUtils.TimeUnit>:
  match n t:
    case None{} _:
      None{}
    case Some{v} SCon{'.', u}:
      Some{RuleUtils.iso.frac(u, v, True{})}
    case Some{v} SCon{',', u}:
      Some{RuleUtils.iso.frac(u, v, True{})}
    case Some{v} other:
      Some{TimeUnit{v, True{}, other}}

# \d{2}(?:[.,]\d*)?
def RuleUtils.iso.unit(s: String) -> Maybe<&2, RuleUtils.TimeUnit>:
  match s:
    case SCon{a, SCon{b, t}}:
      RuleUtils.iso.unit.at(RuleUtils.iso.two(a, b), t)
    case other:
      None{}

def RuleUtils.iso.colon(s: String) -> String:
  match s:
    case SCon{':', t}:
      t
    case other:
      other

def RuleUtils.iso.clock(+h: Nat, hw: Bool, +m: Nat, mw: Bool, +s: Nat, sw: Bool) -> Bool:
  Bool.pick(Bool, Bool.and(Nat.is_eq(h, 24n), hw),
    Bool.and(Bool.and(Nat.is_eq(m, 0n), mw), Bool.and(Nat.is_eq(s, 0n), sw)),
    Bool.and(Nat.is_lt(s, 60n), Bool.and(Nat.is_lt(m, 60n), Nat.is_lt(h, 25n))))

def RuleUtils.iso.time.third(h: Nat, hw: Bool, m: Nat, mw: Bool, u: Maybe<&2, RuleUtils.TimeUnit>) -> Bool:
  match u:
    case None{}:
      False{}
    case Some{TimeUnit{s, sw, rest}}:
      Bool.and(String.is_empty(rest), RuleUtils.iso.clock(h, hw, m, mw, s, sw))

def RuleUtils.iso.time.second(+h: Nat, +hw: Bool, u: Maybe<&2, RuleUtils.TimeUnit>) -> Bool:
  match u:
    case None{}:
      False{}
    case Some{TimeUnit{+m, +mw, +rest}}:
      C.If(Bool, String.is_empty(rest),
        u => RuleUtils.iso.clock(h, hw, m, mw, 0n, True{}),
        u => RuleUtils.iso.time.third(h, hw, m, mw, RuleUtils.iso.unit(RuleUtils.iso.colon(rest))))

def RuleUtils.iso.time.first(u: Maybe<&2, RuleUtils.TimeUnit>) -> Bool:
  match u:
    case None{}:
      False{}
    case Some{TimeUnit{+h, +hw, +rest}}:
      C.If(Bool, String.is_empty(rest),
        u => RuleUtils.iso.clock(h, hw, 0n, True{}, 0n, True{}),
        u => RuleUtils.iso.time.second(h, hw, RuleUtils.iso.unit(RuleUtils.iso.colon(rest))))

# The time matches the three-unit pattern and `validateTime` accepts it.
def RuleUtils.iso.time(s: String) -> Bool:
  RuleUtils.iso.time.first(RuleUtils.iso.unit(s))

def RuleUtils.iso.zone.minutes(+s: String) -> Bool:
  Bool.or(Bool.not(Bool.and(Nat.is_eq(String.length(s), 2n), RuleUtils.digits(s))),
    Nat.is_le(Maybe.default(&2, Nat, Nat.read(s), 0n), 59n))

def RuleUtils.iso.zone.hours(+s: String) -> Bool:
  +hours = String.take(s, 2n)
  Bool.or(Bool.not(Bool.and(Nat.is_eq(String.length(hours), 2n), RuleUtils.digits(hours))),
    RuleUtils.iso.zone.minutes(RuleUtils.iso.colon(String.drop(s, 2n))))

# `parseTimezone`: only ^([+-])(\d{2})(?::?(\d{2}))?$ with minutes above 59 is
# refused; anything that does not match counts as no offset.
def RuleUtils.iso.zone(s: String) -> Bool:
  match s:
    case SCon{'+', t}:
      RuleUtils.iso.zone.hours(t)
    case SCon{'-', t}:
      RuleUtils.iso.zone.hours(t)
    case other:
      True{}

# Which characters end the first part of a text: 0 is [T ], 1 is [Zz ],
# 2 is [Z+-], 3 is a line terminator, 4 is a colon.
def RuleUtils.iso.is_delim(mode: U32, +x: U32) -> Bool:
  match mode:
    case 0:
      Bool.or(U32.is_eq(x, 84), U32.is_eq(x, 32))
    case 1:
      Bool.or(U32.is_eq(x, 90), Bool.or(U32.is_eq(x, 122), U32.is_eq(x, 32)))
    case 2:
      Bool.or(U32.is_eq(x, 90), Bool.or(U32.is_eq(x, 43), U32.is_eq(x, 45)))
    case 3:
      Bool.or(U32.is_eq(x, 10), Bool.or(U32.is_eq(x, 13), Bool.or(U32.is_eq(x, 8232), U32.is_eq(x, 8233))))
    case other:
      U32.is_eq(x, 58)

def RuleUtils.iso.cut.push(c: Char, r: RuleUtils.Cut) -> RuleUtils.Cut:
  match r:
    case Cut{before, after}:
      Cut{SCon{c, before}, after}

# The text before the first delimiter, and the text from that delimiter on.
def RuleUtils.iso.cut(s: String, +mode: U32) -> RuleUtils.Cut:
  match s:
    case SNil{}:
      Cut{SNil{}, SNil{}}
    case SCon{Chr{+x}, +t}:
      C.If(RuleUtils.Cut, RuleUtils.iso.is_delim(mode, x),
        u => Cut{SNil{}, SCon{Chr{x}, t}},
        u => RuleUtils.iso.cut.push(Chr{x}, RuleUtils.iso.cut(t, mode)))

def RuleUtils.Cut.before(c: RuleUtils.Cut) -> String:
  match c:
    case Cut{before, after}:
      before

def RuleUtils.Cut.after(c: RuleUtils.Cut) -> String:
  match c:
    case Cut{before, after}:
      after

def RuleUtils.iso.has(s: String, mode: U32) -> Bool:
  Bool.not(String.is_empty(RuleUtils.Cut.after(RuleUtils.iso.cut(s, mode))))

# The part after the date: a time, then from the first of [Z+-] a zone.
def RuleUtils.iso.timed(+ts: String) -> Bool:
  +c = RuleUtils.iso.cut(ts, 2)
  +time = RuleUtils.Cut.before(c)
  +zone = RuleUtils.Cut.after(c)
  Bool.and(Bool.not(RuleUtils.iso.has(ts, 3)),
    Bool.and(Bool.or(String.is_empty(time), RuleUtils.iso.time(time)),
      Bool.or(String.is_empty(zone), RuleUtils.iso.zone(zone))))

# date-fns `isValid(parseISO(s))`.
def RuleUtils.iso.valid(+s: String) -> Bool:
  +c = RuleUtils.iso.cut(s, 0)
  +first = RuleUtils.Cut.before(c)
  +rest = String.drop(RuleUtils.Cut.after(c), 1n)
  +zoned = RuleUtils.iso.has(first, 1)
  +z = RuleUtils.iso.cut(s, 1)
  +date = Bool.pick(String, zoned, RuleUtils.Cut.before(z), first)
  +ts = Bool.pick(String, zoned, RuleUtils.Cut.after(z), rest)
  Bool.and(Bool.not(RuleUtils.iso.has(rest, 0)),
    Bool.and(Bool.not(RuleUtils.iso.has(first, 4)),
      Bool.and(Bool.not(String.is_empty(date)),
        Bool.and(RuleUtils.iso.dated(RuleUtils.iso.year(date)),
          Bool.or(String.is_empty(ts), RuleUtils.iso.timed(ts))))))

# JS `s.length`: UTF-16 code units.
def RuleUtils.utf16_length(s: String) -> Nat:
  match s:
    case SNil{}:
      0n
    case SCon{Chr{x}, t}:
      (1n + U32.to_nat(Bool.to_u32((x >= 65536 : U32))) + RuleUtils.utf16_length(t) : Nat)

def RuleUtils.parse_date_string.of(+s: String, len: Nat) -> Maybe<&2, Y.Parsed>:
  match len:
    case 10n:
      Bool.pick(Maybe<&2, Y.Parsed>, RuleUtils.iso.valid(s), Some{Y.PDate{"date", s}}, None{})
    case 7n:
      Bool.pick(Maybe<&2, Y.Parsed>, RuleUtils.iso.valid(s ++ "-01"), Some{Y.PDate{"month", s}}, None{})
    case 4n:
      Bool.pick(Maybe<&2, Y.Parsed>, RuleUtils.iso.valid(s ++ "-01-01"), Some{Y.PDate{"year", s}}, None{})
    case other:
      None{}

# `parseDateString`: a day (YYYY-MM-DD), a month (YYYY-MM) or a year (YYYY).
def RuleUtils.parse_date_string(v: V.Value) -> Maybe<&2, Y.Parsed>:
  match v:
    case V.VStr{+s}:
      RuleUtils.parse_date_string.of(s, RuleUtils.utf16_length(s))
    case other:
      None{}

def RuleUtils.parse_between_amount.of(num1: V.Value, num2: V.Value) -> Maybe<&2, Y.Parsed>:
  match num1 num2:
    case V.VNum{a} V.VNum{b}:
      Some{Y.PBetween{a, b}}
    case _ _:
      None{}

# `parseBetweenAmount`: `{ num1, num2 }` with two numbers.
def RuleUtils.parse_between_amount(+between: V.Value) -> Maybe<&2, Y.Parsed>:
  RuleUtils.parse_between_amount.of(V.Txn.get(V.Value.fields(between), "num1"),
    V.Txn.get(V.Value.fields(between), "num2"))

# ---------------------------------------------------------------------------
# Ranking

# OP_SCORES[op]
def RuleUtils.op_score(op: String) -> Maybe<&2, Nat>:
  match op:
    case "is":
      Some{10n}
    case "isNot":
      Some{10n}
    case "oneOf":
      Some{9n}
    case "notOneOf":
      Some{9n}
    case "isapprox":
      Some{5n}
    case "isbetween":
      Some{5n}
    case "gt":
      Some{1n}
    case "gte":
      Some{1n}
    case "lt":
      Some{1n}
    case "lte":
      Some{1n}
    case "contains":
      Some{0n}
    case "doesNotContain":
      Some{0n}
    case "matches":
      Some{0n}
    case "hasTags":
      Some{0n}
    case "hasAnyTag":
      Some{0n}
    case "onBudget":
      Some{0n}
    case "offBudget":
      Some{0n}
    case other:
      None{}

def RuleUtils.score.add(score: Nat, s: Maybe<&2, Nat>) -> Nat:
  match s:
    case None{}:
      0n
    case Some{n}:
      (score + n : Nat)

# The reduce of `computeScore`: an unknown operation sets the score back to 0.
def RuleUtils.score.go(conds: List<&2, Y.Condition>, score: Nat) -> Nat:
  match conds:
    case Nil{}:
      score
    case Con{Y.Cond{op, field, value, raw, unparsed, options, kind}, rest}:
      RuleUtils.score.go(rest, RuleUtils.score.add(score, RuleUtils.op_score(op)))

def RuleUtils.score.exact_op(op: String) -> Bool:
  match op:
    case "is":
      True{}
    case "isNot":
      True{}
    case "isapprox":
      True{}
    case "oneOf":
      True{}
    case "notOneOf":
      True{}
    case other:
      False{}

def RuleUtils.score.exact(conds: List<&2, Y.Condition>) -> Bool:
  match conds:
    case Nil{}:
      True{}
    case Con{Y.Cond{op, field, value, raw, unparsed, options, kind}, rest}:
      Bool.and(RuleUtils.score.exact_op(op), RuleUtils.score.exact(rest))

# `computeScore`
def RuleUtils.compute_score(rule: Y.Rule) -> Nat:
  match rule:
    case Y.Rule{id, stage, conditions_op, +conditions, actions}:
      (RuleUtils.score.go(conditions, 0n) * Bool.pick(Nat, RuleUtils.score.exact(conditions), 2n, 1n) : Nat)

type RuleUtils.Scored is Data:
  Scored{score: Nat, id: V.Value, rule: Y.Rule}

def RuleUtils.rule_id(rule: Y.Rule) -> V.Value:
  match rule:
    case Y.Rule{id, stage, conditions_op, conditions, actions}:
      id

def RuleUtils.rule_stage(rule: Y.Rule) -> V.Value:
  match rule:
    case Y.Rule{id, stage, conditions_op, conditions, actions}:
      stage

def RuleUtils.scored(rules: List<&2, Y.Rule>) -> List<&2, RuleUtils.Scored>:
  match rules:
    case Nil{}:
      Nil{}
    case Con{+r, t}:
      Con{Scored{RuleUtils.compute_score(r), RuleUtils.rule_id(r), r}, RuleUtils.scored(t)}

def RuleUtils.id_cmp(a: V.Value, b: V.Value) -> Cmp:
  match a b:
    case V.VStr{x} V.VStr{y}:
      String.order(x, y)
    case _ _:
      EQ{}

def RuleUtils.cmp.tie(c: Cmp, a: V.Value, b: V.Value) -> Cmp:
  match c:
    case EQ{}:
      RuleUtils.id_cmp(a, b)
    case other:
      other

# The comparator of `_rankRules`: by score, then by id.
def RuleUtils.cmp(a: RuleUtils.Scored, b: RuleUtils.Scored) -> Cmp:
  match a b:
    case Scored{s1, id1, r1} Scored{s2, id2, r2}:
      RuleUtils.cmp.tie(Nat.cmp(s1, s2), id1, id2)

# Puts x before the first element that is not below it.
def RuleUtils.insert(sorted: List<&2, RuleUtils.Scored>, +x: RuleUtils.Scored) -> List<&2, RuleUtils.Scored>:
  match sorted:
    case Nil{}:
      [x]
    case Con{+y, +rest}:
      C.If(List<&2, RuleUtils.Scored>, Cmp.is_lt(RuleUtils.cmp(y, x)),
        u => Con{y, RuleUtils.insert(rest, x)},
        u => Con{x, Con{y, rest}})

def RuleUtils.sort(xs: List<&2, RuleUtils.Scored>) -> List<&2, RuleUtils.Scored>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      RuleUtils.insert(RuleUtils.sort(t), h)

def RuleUtils.unscored(xs: List<&2, RuleUtils.Scored>) -> List<&2, Y.Rule>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Scored{score, id, rule}, t}:
      Con{rule, RuleUtils.unscored(t)}

# `_rankRules`
def RuleUtils.rank(rules: List<&2, Y.Rule>) -> List<&2, Y.Rule>:
  RuleUtils.unscored(RuleUtils.sort(RuleUtils.scored(rules)))

# 0 for a 'pre' rule, 2 for a 'post' rule, 1 for any other.
def RuleUtils.stage_index(stage: V.Value) -> Nat:
  match stage:
    case V.VStr{"pre"}:
      0n
    case V.VStr{"post"}:
      2n
    case other:
      1n

def RuleUtils.in_stage(rules: List<&2, Y.Rule>, +index: Nat) -> List<&2, Y.Rule>:
  match rules:
    case Nil{}:
      Nil{}
    case Con{+r, +t}:
      C.If(List<&2, Y.Rule>, Nat.is_eq(RuleUtils.stage_index(RuleUtils.rule_stage(r)), index),
        u => Con{r, RuleUtils.in_stage(t, index)},
        u => RuleUtils.in_stage(t, index))

# `rankRules`: 'pre' rules, then the rest, then 'post' rules, each ranked.
def RuleUtils.rank_rules(+rules: List<&2, Y.Rule>) -> List<&2, Y.Rule>:
  List.append(&2, Y.Rule, RuleUtils.rank(RuleUtils.in_stage(rules, 0n)),
    List.append(&2, Y.Rule, RuleUtils.rank(RuleUtils.in_stage(rules, 1n)), RuleUtils.rank(RuleUtils.in_stage(rules, 2n))))

# ---------------------------------------------------------------------------
# Ids

type RuleUtils.Mapping is Data:
  Mapping{from: String, to: String}

def RuleUtils.lookup(mappings: List<&2, RuleUtils.Mapping>, +key: String) -> V.Value:
  match mappings:
    case Nil{}:
      V.VMissing{}
    case Con{Mapping{from, to}, rest}:
      C.If(V.Value, String.eq(from, key), u => V.VStr{to}, u => RuleUtils.lookup(rest, key))

# mappings.get(v) || v
def RuleUtils.mapped(mappings: List<&2, RuleUtils.Mapping>, v: V.Value) -> V.Value:
  match v:
    case V.VStr{+s}:
      V.Value.or(RuleUtils.lookup(mappings, s), V.VStr{s})
    case other:
      other

def RuleUtils.add_unique(xs: List<&2, V.Value>, +x: V.Value) -> List<&2, V.Value>:
  match xs:
    case Nil{}:
      [x]
    case Con{+h, +t}:
      C.If(List<&2, V.Value>, V.Value.eq(h, x), u => Con{h, t}, u => Con{h, RuleUtils.add_unique(t, x)})

# [...new Set(values.map(v => mappings.get(v) || v))]
def RuleUtils.mapped_set(values: List<&2, V.Value>, +mappings: List<&2, RuleUtils.Mapping>, acc: List<&2, V.Value>) -> List<&2, V.Value>:
  match values:
    case Nil{}:
      acc
    case Con{h, t}:
      RuleUtils.mapped_set(t, mappings, RuleUtils.add_unique(acc, RuleUtils.mapped(mappings, h)))

def RuleUtils.migrate.cond.id(+c: Y.Condition, +mappings: List<&2, RuleUtils.Mapping>) -> Y.Condition:
  match c:
    case Y.Cond{"is", field, value, +raw, unparsed, options, kind}:
      +v = RuleUtils.mapped(mappings, raw)
      Y.Cond{"is", field, Y.PValue{v}, raw, v, options, kind}
    case Y.Cond{"isNot", field, value, +raw, unparsed, options, kind}:
      +v = RuleUtils.mapped(mappings, raw)
      Y.Cond{"isNot", field, Y.PValue{v}, raw, v, options, kind}
    case Y.Cond{"oneOf", field, value, +raw, unparsed, options, kind}:
      +v = V.Value.array(RuleUtils.mapped_set(V.Value.items(raw), mappings, Nil{}))
      Y.Cond{"oneOf", field, Y.PValue{v}, raw, v, options, kind}
    case Y.Cond{"notOneOf", field, value, +raw, unparsed, options, kind}:
      +v = V.Value.array(RuleUtils.mapped_set(V.Value.items(raw), mappings, Nil{}))
      Y.Cond{"notOneOf", field, Y.PValue{v}, raw, v, options, kind}
    case other:
      c

def RuleUtils.cond_kind(c: Y.Condition) -> String:
  match c:
    case Y.Cond{op, field, value, raw, unparsed, options, kind}:
      kind

def RuleUtils.migrate.conds(conds: List<&2, Y.Condition>, +mappings: List<&2, RuleUtils.Mapping>) -> List<&2, Y.Condition>:
  match conds:
    case Nil{}:
      Nil{}
    case Con{+c, t}:
      Con{Bool.pick(Y.Condition, String.eq(RuleUtils.cond_kind(c), "id"), RuleUtils.migrate.cond.id(c, mappings), c),
        RuleUtils.migrate.conds(t, mappings)}

def RuleUtils.migrate.action(+a: Y.Action, mappings: List<&2, RuleUtils.Mapping>) -> Y.Action:
  match a:
    case Y.Act{"set", field, value, +raw, options, V.VStr{"id"}}:
      Y.Act{"set", field, RuleUtils.mapped(mappings, raw), raw, options, V.VStr{"id"}}
    case other:
      a

def RuleUtils.migrate.actions(actions: List<&2, Y.Action>, +mappings: List<&2, RuleUtils.Mapping>) -> List<&2, Y.Action>:
  match actions:
    case Nil{}:
      Nil{}
    case Con{a, t}:
      Con{RuleUtils.migrate.action(a, mappings), RuleUtils.migrate.actions(t, mappings)}

# `migrateIds`: the rule with ids that were merged into other ids replaced.
# The replacement is always computed from `raw`, the id as first written, so
# that applying a later mapping (or an undone one) starts from the original.
def RuleUtils.migrate_ids(rule: Y.Rule, +mappings: List<&2, RuleUtils.Mapping>) -> Y.Rule:
  match rule:
    case Y.Rule{id, stage, conditions_op, conditions, actions}:
      Y.Rule{id, stage, conditions_op, RuleUtils.migrate.conds(conditions, mappings),
        RuleUtils.migrate.actions(actions, mappings)}

type RuleUtils.Visit is Data:
  Visit{rule: Y.Rule, ids: List<&2, V.Value>}

def RuleUtils.ids.cond.op(op: String, +v: V.Value) -> List<&2, V.Value>:
  match op:
    case "is":
      [v]
    case "isNot":
      [v]
    case "oneOf":
      V.Value.items(v)
    case "notOneOf":
      V.Value.items(v)
    case other:
      Nil{}

def RuleUtils.ids.cond(c: Y.Condition, name: String) -> List<&2, V.Value>:
  match c:
    case Y.Cond{op, field, Y.PValue{v}, raw, unparsed, options, "id"}:
      Bool.pick(List<&2, V.Value>, String.eq(field, name), RuleUtils.ids.cond.op(op, v), Nil{})
    case other:
      Nil{}

def RuleUtils.ids.conds(conds: List<&2, Y.Condition>, +name: String) -> List<&2, V.Value>:
  match conds:
    case Nil{}:
      Nil{}
    case Con{c, t}:
      List.append(&2, V.Value, RuleUtils.ids.cond(c, name), RuleUtils.ids.conds(t, name))

def RuleUtils.ids.actions(actions: List<&2, Y.Action>, +name: String) -> List<&2, V.Value>:
  match actions:
    case Nil{}:
      Nil{}
    case Con{Y.Act{"set", V.VStr{field}, +value, raw, options, V.VStr{"id"}}, +t}:
      C.If(List<&2, V.Value>, String.eq(field, name),
        u => Con{value, RuleUtils.ids.actions(t, name)},
        u => RuleUtils.ids.actions(t, name))
    case Con{other, t}:
      RuleUtils.ids.actions(t, name)

# The ids of `fieldName` a rule refers to, in the order `iterateIds` hands
# them to its callback: those of its conditions, then those of its actions.
def RuleUtils.rule_ids(rule: Y.Rule, +name: String) -> List<&2, V.Value>:
  match rule:
    case Y.Rule{id, stage, conditions_op, conditions, actions}:
      List.append(&2, V.Value, RuleUtils.ids.conds(conditions, name), RuleUtils.ids.actions(actions, name))

# `iterateIds`: for each rule, the ids its callback would be called with.
def RuleUtils.iterate_ids(rules: List<&2, Y.Rule>, +name: String) -> List<&2, RuleUtils.Visit>:
  match rules:
    case Nil{}:
      Nil{}
    case Con{+r, t}:
      Con{Visit{r, RuleUtils.rule_ids(r, name)}, RuleUtils.iterate_ids(t, name)}

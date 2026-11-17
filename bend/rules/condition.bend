# Rule conditions: a port of
# packages/loot-core/src/server/rules/condition.ts. The class `Condition` is
# the datatype `Condition` of types.bend; `new Condition(...)` is
# `Condition.new` and the methods are `Condition.eval`, `Condition.get_value`
# and `Condition.serialize`.
#
# Deviations:
# - The constructor throws a `RuleError`; `Condition.new` answers
#   `Fail{RuleError{kind, message}}` with the same type and message.
# - Recurring dates (a value with a `frequency`, parsed by `parseRecurDate`
#   and evaluated by the rschedule library) are not ported: `Condition.new`
#   answers `Fail{RuleError{"unsupported", ...}}` for them, so the `recur`
#   branches of `eval` never arise.
# - `matches` uses rules/regex.bend; a pattern it does not support
#   (backreferences, lookbehind) answers False, as an invalid one does.
# - Strings are lowered with `Value.lower` and compared by code point; see
#   rules/value.bend for where that differs from JS. A date field holding
#   something other than a string never satisfies a date condition, and a
#   string member of a `oneOf` list that is not a string is left as it is
#   (the TS throws a TypeError for it).
import Base
import ../lib/core.bend as C
import ../lib/int.bend as I
import ../lib/num.bend as N
import ../lib/text.bend as T
import ../shared/months.bend as M
import ../shared/tags.bend as G
import ./value.bend as V
import ./types.bend as Y
import ./rules.bend as R
import ./rule-utils.bend as U
import ./regex.bend as X

# ---------------------------------------------------------------------------
# CONDITION_TYPES[type].parse

def Condition.fail(kind: String, msg: String) -> Result<&2, &2, Y.RuleError, Y.Parsed>:
  Fail{Y.RuleError{kind, msg}}

def Condition.exact_date_op(op: String) -> Bool:
  match op:
    case "gt":
      True{}
    case "gte":
      True{}
    case "lt":
      True{}
    case "lte":
      True{}
    case other:
      False{}

def Condition.parse.date.check(p: Y.Parsed, +op: String, field: String) -> Result<&2, &2, Y.RuleError, Y.Parsed>:
  match p:
    case Y.PDate{+kind, date}:
      Bool.pick(Result<&2, &2, Y.RuleError, Y.Parsed>,
        Bool.or(String.eq(kind, "date"), Bool.not(Bool.or(String.eq(op, "isapprox"), Condition.exact_date_op(op)))),
        Done{Y.PDate{kind, date}},
        Condition.fail("date-format", "Invalid date value for \"" ++ op ++ "\" (field: " ++ field ++ ")"))
    case other:
      Done{other}

def Condition.parse.date.of(p: Maybe<&2, Y.Parsed>, recur: Bool, op: String, +field: String) ->
  Result<&2, &2, Y.RuleError, Y.Parsed>:
  match p recur:
    case Some{d} _:
      Condition.parse.date.check(d, op, field)
    case None{} True{}:
      Condition.fail("unsupported", "Recurring date conditions are not supported (field: " ++ field ++ ")")
    case None{} False{}:
      Condition.fail("date-format", "Invalid date format (field: " ++ field ++ ")")

def Condition.parse.date(op: String, +value: V.Value, field: String) -> Result<&2, &2, Y.RuleError, Y.Parsed>:
  Condition.parse.date.of(U.RuleUtils.parse_date_string(value),
    Bool.and(Bool.not(V.Value.is_string(value)),
      Bool.not(V.Value.is_nullish(V.Txn.get(V.Value.fields(value), "frequency")))),
    op, field)

def Condition.list_op(op: String) -> Bool:
  match op:
    case "oneOf":
      True{}
    case "notOneOf":
      True{}
    case other:
      False{}

def Condition.parse.id(+op: String, +value: V.Value, field: String) -> Result<&2, &2, Y.RuleError, Y.Parsed>:
  Bool.pick(Result<&2, &2, Y.RuleError, Y.Parsed>,
    Bool.or(Bool.not(Bool.or(Condition.list_op(op), String.eq(op, "and"))), V.Value.is_array(value)),
    Done{Y.PValue{value}},
    Condition.fail("no-empty-array", "oneOf must have an array value (field: " ++ field ++ ")"))

# value.filter(Boolean).map(val => val.toLowerCase())
def Condition.lower_all(items: List<&2, V.Value>) -> List<&2, V.Value>:
  match items:
    case Nil{}:
      Nil{}
    case Con{V.VStr{+s}, t}:
      List.append(&2, V.Value, Bool.pick(List<&2, V.Value>, String.is_empty(s), Nil{}, [V.VStr{V.Value.lower(s)}]),
        Condition.lower_all(t))
    case Con{+other, t}:
      List.append(&2, V.Value, Bool.pick(List<&2, V.Value>, V.Value.truthy(other), [other], Nil{}), Condition.lower_all(t))

def Condition.nonempty_op(op: String) -> Bool:
  match op:
    case "contains":
      True{}
    case "matches":
      True{}
    case "doesNotContain":
      True{}
    case "hasTags":
      True{}
    case "hasAnyTag":
      True{}
    case other:
      False{}

def Condition.tag_op(op: String) -> Bool:
  match op:
    case "hasTags":
      True{}
    case "hasAnyTag":
      True{}
    case other:
      False{}

def Condition.parse.string.text(+op: String, +s: String, field: String) -> Result<&2, &2, Y.RuleError, Y.Parsed>:
  C.If(Result<&2, &2, Y.RuleError, Y.Parsed>, Bool.and(Condition.nonempty_op(op), String.is_empty(s)),
    u => Condition.fail("no-empty-string", op ++ " must have non-empty string (field: " ++ field ++ ")"),
    u => Done{Y.PValue{V.VStr{Bool.pick(String, Condition.tag_op(op), s, V.Value.lower(s))}}})

def Condition.parse.string.of(op: String, value: V.Value, field: String) -> Result<&2, &2, Y.RuleError, Y.Parsed>:
  match value:
    case V.VStr{s}:
      Condition.parse.string.text(op, s, field)
    case other:
      Condition.fail("not-string", "Invalid string value (field: " ++ field ++ ")")

def Condition.parse.string(+op: String, +value: V.Value, +field: String) -> Result<&2, &2, Y.RuleError, Y.Parsed>:
  C.If(Result<&2, &2, Y.RuleError, Y.Parsed>, Condition.list_op(op),
    u => Bool.pick(Result<&2, &2, Y.RuleError, Y.Parsed>, V.Value.is_array(value),
      Done{Y.PValue{V.Value.array(Condition.lower_all(V.Value.items(value)))}},
      Condition.fail("no-empty-array",
        "oneOf must have an array value (field: " ++ field ++ "): " ++ V.Value.show(value))),
    u => Condition.parse.string.of(op, value, field))

def Condition.parse.number.check(p: Maybe<&2, Y.Parsed>, +op: String, +value: V.Value, +field: String) ->
  Result<&2, &2, Y.RuleError, Y.Parsed>:
  match p:
    case None{}:
      Condition.fail("not-number",
        "Value must be a number or between amount: " ++ V.Value.show(value) ++ " (field: " ++ field ++ ")")
    case Some{Y.PBetween{a, b}}:
      Bool.pick(Result<&2, &2, Y.RuleError, Y.Parsed>, String.eq(op, "isbetween"), Done{Y.PBetween{a, b}},
        Condition.fail("number-format", "Invalid number value for \"" ++ op ++ "\" (field: " ++ field ++ ")"))
    case Some{other}:
      Bool.pick(Result<&2, &2, Y.RuleError, Y.Parsed>, String.eq(op, "isbetween"),
        Condition.fail("number-format", "Invalid between value for \"" ++ op ++ "\" (field: " ++ field ++ ")"),
        Done{other})

def Condition.parse.number.of(+value: V.Value) -> Maybe<&2, Y.Parsed>:
  match value:
    case V.VNum{n}:
      Some{Y.PLiteral{n}}
    case other:
      U.RuleUtils.parse_between_amount(value)

def Condition.parse.boolean(+value: V.Value, field: String) -> Result<&2, &2, Y.RuleError, Y.Parsed>:
  match value:
    case V.VBool{b}:
      Done{Y.PValue{V.VBool{b}}}
    case other:
      Condition.fail("not-boolean", "Value must be a boolean: " ++ V.Value.to_string(value) ++ " (field: " ++ field ++ ")")

def Condition.parse(kind: String, op: String, +value: V.Value, field: String) -> Result<&2, &2, Y.RuleError, Y.Parsed>:
  match kind:
    case "date":
      Condition.parse.date(op, value, field)
    case "id":
      Condition.parse.id(op, value, field)
    case "string":
      Condition.parse.string(op, value, field)
    case "number":
      Condition.parse.number.check(Condition.parse.number.of(value), op, value, field)
    case "boolean":
      Condition.parse.boolean(value, field)
    case other:
      Done{Y.PValue{value}}

# ---------------------------------------------------------------------------
# new Condition(op, field, value, options)

def Condition.new.typed(kind: Maybe<&2, String>, +op: String, +field: String, +value: V.Value, options: V.Value) ->
  Result<&2, &2, Y.RuleError, Y.Condition>:
  match kind:
    case None{}:
      Fail{Y.RuleError{"internal", "Invalid condition field: " ++ field}}
    case Some{+k}:
      do Result<&2, &2, Y.RuleError, Y.Condition>:
        a : Unit <- U.RuleUtils.assert(Bool.not(String.eq(k, "saved")), "internal",
          "Invalid condition type: " ++ k ++ " (field: " ++ field ++ ")")
        b : Unit <- U.RuleUtils.assert(R.Rules.is_valid_op(field, op), "internal",
          "Invalid condition operator: " ++ op ++ " (type: " ++ k ++ ", field: " ++ field ++ ")")
        c : Unit <- U.RuleUtils.assert(Bool.or(R.Rules.type_nullable(k), Bool.not(V.Value.is_nullish(value))), "no-null",
          "Field cannot be empty: " ++ field)
        p : Y.Parsed <- Condition.parse(k, op, value, field)
        return Y.Cond{op, field, p, value, value, options, k}

# It is important to validate rules: a faulty one might mess up the user's
# transactions.
def Condition.new(op: String, +field: String, value: V.Value, options: V.Value) ->
  Result<&2, &2, Y.RuleError, Y.Condition>:
  Condition.new.typed(R.Rules.field_type(field), op, field, value, options)

# ---------------------------------------------------------------------------
# eval

# The field as `eval` reads it: a missing or null string is "", and a string
# is lowered.
def Condition.field_value(string: Bool, v: V.Value) -> V.Value:
  match string v:
    case _ V.VStr{s}:
      V.VStr{V.Value.lower(s)}
    case True{} V.VNull{}:
      V.VStr{""}
    case True{} V.VMissing{}:
      V.VStr{""}
    case _ other:
      other

def Condition.option(options: V.Value, name: String) -> Bool:
  V.Value.truthy(V.Txn.get(V.Value.fields(options), name))

def Condition.flow.out(n: Maybe<&2, N.Num>) -> Maybe<&2, V.Value>:
  match n:
    case None{}:
      None{}
    case Some{+x}:
      Bool.pick(Maybe<&2, V.Value>, Bool.and(Bool.not(N.Num.is_neg(x)), Bool.not(N.Num.is_zero(x))),
        None{}, Some{V.VNum{N.Num.neg(x)}})

def Condition.flow.in(n: Maybe<&2, N.Num>, fv: V.Value) -> Maybe<&2, V.Value>:
  match n:
    case None{}:
      Some{fv}
    case Some{x}:
      Bool.pick(Maybe<&2, V.Value>, N.Num.is_neg(x), None{}, Some{fv})

# The `outflow` and `inflow` options of a number condition: None when the
# amount has the wrong sign, else the amount to compare (negated for outflow).
def Condition.flow(+fv: V.Value, +options: V.Value) -> Maybe<&2, V.Value>:
  C.If(Maybe<&2, V.Value>, Condition.option(options, "outflow"),
    u => Condition.flow.out(V.Value.to_number(fv)),
    u => C.If(Maybe<&2, V.Value>, Condition.option(options, "inflow"),
      u => Condition.flow.in(V.Value.to_number(fv), fv),
      u => Some{fv}))

def Condition.num_cmp(a: Maybe<&2, N.Num>, b: N.Num) -> Maybe<&2, Cmp>:
  match a:
    case None{}:
      None{}
    case Some{x}:
      Some{N.Num.cmp(x, b)}

def Condition.cmp_is(c: Maybe<&2, Cmp>, lt: Bool, eq: Bool, gt: Bool) -> Bool:
  match c:
    case None{}:
      False{}
    case Some{LT{}}:
      lt
    case Some{EQ{}}:
      eq
    case Some{GT{}}:
      gt

def Condition.plus(a: N.Num, b: N.Num) -> N.Num:
  Maybe.default(&2, N.Num, N.Num.add(a, b), N.Num.zero())

# low <= Number(fv) <= high
def Condition.within(+fv: V.Value, low: N.Num, high: N.Num) -> Bool:
  Bool.and(Condition.cmp_is(Condition.num_cmp(V.Value.to_number(fv), low), False{}, True{}, True{}),
    Condition.cmp_is(Condition.num_cmp(V.Value.to_number(fv), high), True{}, True{}, False{}))

def Condition.maybe_eq(m: Maybe<&2, String>, s: String) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{x}:
      String.eq(x, s)

def Condition.str_between(+s: String, low: Maybe<&2, String>, high: Maybe<&2, String>) -> Bool:
  match low high:
    case Some{l} Some{h}:
      Bool.and(String.is_ge(s, l), String.is_le(s, h))
    case _ _:
      False{}

def Condition.is.date(approx: Bool, +s: String, kind: String, +date: String) -> Bool:
  match approx kind:
    case True{} _:
      Condition.str_between(s, M.Months.sub_days(date, I.Int.from_nat(2n)), M.Months.add_days(date, I.Int.from_nat(2n)))
    case False{} "date":
      String.eq(s, date)
    case False{} "month":
      Condition.maybe_eq(M.Months.month_from_date(s), date)
    case False{} "year":
      Condition.maybe_eq(M.Months.year_from_date(s), date)
    case False{} other:
      False{}

def Condition.is.dated(fv: V.Value, approx: Bool, kind: String, date: String) -> Bool:
  match fv:
    case V.VStr{s}:
      Condition.is.date(approx, s, kind, date)
    case other:
      False{}

def Condition.is(approx: Bool, +fv: V.Value, value: Y.Parsed) -> Bool:
  match value:
    case Y.PDate{kind, date}:
      Condition.is.dated(fv, approx, kind, date)
    case Y.PLiteral{+n}:
      Bool.pick(Bool, approx,
        Condition.within(fv, Maybe.default(&2, N.Num, N.Num.sub(n, R.Rules.approx_threshold(n)), N.Num.zero()),
          Condition.plus(n, R.Rules.approx_threshold(n))),
        V.Value.strict_eq(fv, V.VNum{n}))
    case Y.PBetween{a, b}:
      False{}
    case Y.PValue{v}:
      V.Value.strict_eq(fv, v)

def Condition.boundary(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+x}, t}:
      Bool.or(U32.is_eq(x, 35), T.Text.is_js_space(x))

# (?<!#)tag([\s#]|$) somewhere in s; prev is the character before s.
def Condition.has_tag(s: String, +tag: String, prev: U32) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+x}, +t}:
      C.If(Bool, Bool.and(U32.is_ne(prev, 35), Bool.and(String.starts_with(SCon{Chr{x}, t}, tag),
          Condition.boundary(String.drop(SCon{Chr{x}, t}, String.length(tag))))),
        u => True{},
        u => Condition.has_tag(t, tag, x))

def Condition.tags(tags: List<&2, String>, +text: String, +all: Bool) -> Bool:
  match tags:
    case Nil{}:
      all
    case Con{tag, rest}:
      C.If(Bool, V.Value.bool_eq(Condition.has_tag(text, V.Value.lower(tag), 0), all),
        u => Condition.tags(rest, text, all),
        u => Bool.not(all))

def Condition.order.date(fv: V.Value, +date: String, before: Bool, after: Bool, same: Bool) -> Bool:
  match fv:
    case V.VStr{+s}:
      Bool.or(Bool.and(same, String.eq(s, date)),
        Bool.or(Bool.and(after, M.Months.is_after(s, date)), Bool.and(before, M.Months.is_before(s, date))))
    case other:
      False{}

# fv < value, fv <= value and so on: `lt` and `gt` say which sides count and
# `eq` whether equality does.
def Condition.order(+fv: V.Value, value: Y.Parsed, +lt: Bool, +eq: Bool, +gt: Bool) -> Bool:
  match value:
    case Y.PDate{kind, date}:
      Condition.order.date(fv, date, lt, gt, eq)
    case Y.PLiteral{n}:
      Condition.cmp_is(Condition.num_cmp(V.Value.to_number(fv), n), lt, eq, gt)
    case other:
      False{}

def Condition.between(+fv: V.Value, value: Y.Parsed) -> Bool:
  match value:
    case Y.PBetween{+a, +b}:
      Bool.pick(Bool, Cmp.is_lt(N.Num.cmp(a, b)), Condition.within(fv, a, b), Condition.within(fv, b, a))
    case other:
      False{}

def Condition.plain(value: Y.Parsed) -> V.Value:
  match value:
    case Y.PValue{v}:
      v
    case other:
      V.VMissing{}

# new RegExp(value).source: undefined is the empty pattern.
def Condition.pattern(v: V.Value) -> String:
  match v:
    case V.VMissing{}:
      ""
    case other:
      V.Value.to_string(other)

def Condition.budget(+account: V.Value, want: Nat) -> Bool:
  Bool.and(V.Value.truthy(account),
    V.Value.strict_eq(V.Txn.get(V.Value.fields(account), "offbudget"), V.Value.nat(want)))

def Condition.eval.op(op: String, +fv: V.Value, +value: Y.Parsed, +object: List<&2, V.Field>, +null: Bool, +text: String) -> Bool:
  match op:
    case "is":
      Condition.is(False{}, fv, value)
    case "isapprox":
      Condition.is(True{}, fv, value)
    case "isNot":
      Bool.not(V.Value.strict_eq(fv, Condition.plain(value)))
    case "isbetween":
      Condition.between(fv, value)
    case "contains":
      Bool.and(Bool.not(null), String.contains(text, V.Value.to_string(Condition.plain(value))))
    case "doesNotContain":
      Bool.and(Bool.not(null), Bool.not(String.contains(text, V.Value.to_string(Condition.plain(value)))))
    case "oneOf":
      Bool.and(Bool.not(null), V.Value.includes(Condition.plain(value), fv))
    case "notOneOf":
      Bool.and(Bool.not(null), Bool.not(V.Value.includes(Condition.plain(value), fv)))
    case "hasTags":
      Bool.and(Bool.not(null),
        Condition.tags(G.Tags.extract_for_filter(V.Value.to_string(Condition.plain(value))), text, True{}))
    case "hasAnyTag":
      Bool.and(Bool.not(null),
        Condition.tags(G.Tags.extract_for_filter(V.Value.to_string(Condition.plain(value))), text, False{}))
    case "gt":
      Bool.and(Bool.not(null), Condition.order(fv, value, False{}, False{}, True{}))
    case "gte":
      Bool.and(Bool.not(null), Condition.order(fv, value, False{}, True{}, True{}))
    case "lt":
      Bool.and(Bool.not(null), Condition.order(fv, value, True{}, False{}, False{}))
    case "lte":
      Bool.and(Bool.not(null), Condition.order(fv, value, True{}, True{}, False{}))
    case "matches":
      Bool.and(Bool.not(null), X.Regex.test(Condition.pattern(Condition.plain(value)), text))
    case "onBudget":
      Condition.budget(V.Txn.get(object, "_account"), 0n)
    case "offBudget":
      Condition.budget(V.Txn.get(object, "_account"), 1n)
    case other:
      False{}

def Condition.eval.flowed(fv: Maybe<&2, V.Value>, op: String, value: Y.Parsed, object: List<&2, V.Field>) -> Bool:
  match fv:
    case None{}:
      False{}
    case Some{+v}:
      Condition.eval.op(op, v, value, object, V.Value.is_null(v), V.Value.to_string(v))

def Condition.eval.field(+fv: V.Value, op: String, value: Y.Parsed, +options: V.Value, number: Bool,
  object: List<&2, V.Field>) -> Bool:
  match fv:
    case V.VMissing{}:
      False{}
    case other:
      Condition.eval.flowed(
        Bool.pick(Maybe<&2, V.Value>, Bool.and(number, V.Value.truthy(options)), Condition.flow(fv, options), Some{fv}),
        op, value, object)

# Whether a transaction satisfies the condition.
def Condition.eval(c: Y.Condition, +object: List<&2, V.Field>) -> Bool:
  match c:
    case Y.Cond{op, field, value, raw, unparsed, +options, +kind}:
      Condition.eval.field(Condition.field_value(String.eq(kind, "string"), V.Txn.get(object, field)),
        op, value, options, String.eq(kind, "number"), object)

# `getValue()`: the parsed value as the JS object it is.
def Condition.get_value(c: Y.Condition) -> V.Value:
  match c:
    case Y.Cond{op, field, value, raw, unparsed, options, kind}:
      Y.Parsed.to_value(value)

# `serialize()`
def Condition.serialize(c: Y.Condition) -> List<&2, V.Field>:
  match c:
    case Y.Cond{op, field, value, raw, unparsed, +options, kind}:
      List.append(&2, V.Field, [V.Field{"op", V.VStr{op}}, V.Field{"field", V.VStr{field}}, V.Field{"value", unparsed},
        V.Field{"type", V.VStr{kind}}],
        Bool.pick(List<&2, V.Field>, V.Value.truthy(options), [V.Field{"options", options}], Nil{}))

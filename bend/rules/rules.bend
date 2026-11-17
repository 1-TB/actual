# Field and operator metadata for rules, and the helpers the rule editor
# uses: a port of packages/loot-core/src/shared/rules.ts.
#
# Deviations:
# - `parse`, `unparse` and `makeValue` take and return an item as a list of
#   fields (rules/value.bend) where the TS spreads a JS object.
# - `unparse` of a fixed-percent split calls `parseFloat`; where that gives
#   NaN the value here is `VNull` (what `JSON.stringify(NaN)` writes).
# - `Rules.approx_threshold` works on exact rationals. For integers it equals
#   `Math.round(Math.abs(n) * 0.075)`; it answers 0 if the product overflows
#   lib/num.bend (beyond about 2^46).
import Base
import ../lib/core.bend as C
import ../lib/int.bend as I
import ../lib/num.bend as N
import ../shared/util.bend as U
import ./value.bend as V

def Rules.has(xs: List<&2, String>, +x: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{h, t}:
      Bool.or(String.eq(h, x), Rules.has(t, x))

# TYPE_INFO[type].ops
def Rules.type_ops(kind: String) -> List<&2, String>:
  match kind:
    case "date":
      ["is", "isapprox", "gt", "gte", "lt", "lte"]
    case "id":
      ["is", "contains", "matches", "oneOf", "isNot", "doesNotContain", "notOneOf", "onBudget", "offBudget"]
    case "string":
      ["is", "contains", "matches", "oneOf", "isNot", "doesNotContain", "notOneOf", "hasTags", "hasAnyTag"]
    case "number":
      ["is", "isapprox", "isbetween", "gt", "gte", "lt", "lte"]
    case "boolean":
      ["is"]
    case other:
      []

# TYPE_INFO[type].nullable
def Rules.type_nullable(kind: String) -> Bool:
  match kind:
    case "id":
      True{}
    case "string":
      True{}
    case other:
      False{}

# The keys of FIELD_INFO, in order.
def Rules.fields() -> List<&2, String>:
  ["imported_payee", "payee", "payee_name", "date", "notes", "amount", "category", "category_group",
    "account", "cleared", "reconciled", "saved", "transfer", "parent"]

# FIELD_TYPES.get(field)
def Rules.field_type(field: String) -> Maybe<&2, String>:
  match field:
    case "imported_payee":
      Some{"string"}
    case "payee":
      Some{"id"}
    case "payee_name":
      Some{"string"}
    case "date":
      Some{"date"}
    case "notes":
      Some{"string"}
    case "amount":
      Some{"number"}
    case "category":
      Some{"id"}
    case "category_group":
      Some{"id"}
    case "account":
      Some{"id"}
    case "cleared":
      Some{"boolean"}
    case "reconciled":
      Some{"boolean"}
    case "saved":
      Some{"saved"}
    case "transfer":
      Some{"boolean"}
    case "parent":
      Some{"boolean"}
    case other:
      None{}

# FIELD_INFO[field].disallowedOps
def Rules.disallowed_ops(field: String) -> List<&2, String>:
  match field:
    case "imported_payee":
      ["hasTags", "hasAnyTag"]
    case "payee":
      ["onBudget", "offBudget"]
    case "notes":
      ["oneOf", "notOneOf"]
    case "category":
      ["onBudget", "offBudget"]
    case "category_group":
      ["onBudget", "offBudget"]
    case other:
      []

# FIELD_INFO[field].internalOps
def Rules.internal_ops(field: String) -> List<&2, String>:
  match field:
    case "category":
      ["and"]
    case "category_group":
      ["and"]
    case other:
      []

def Rules.is_valid_op.of(kind: Maybe<&2, String>, +field: String, +op: String) -> Bool:
  match kind:
    case None{}:
      False{}
    case Some{t}:
      Bool.and(Bool.not(Rules.has(Rules.disallowed_ops(field), op)),
        Bool.or(Rules.has(Rules.type_ops(t), op), Rules.has(Rules.internal_ops(field), op)))

def Rules.is_valid_op(+field: String, op: String) -> Bool:
  Rules.is_valid_op.of(Rules.field_type(field), field, op)

def Rules.without(xs: List<&2, String>, +drop: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+h, +t}:
      C.If(List<&2, String>, Rules.has(drop, h), u => Rules.without(t, drop), u => Con{h, Rules.without(t, drop)})

def Rules.get_valid_ops.of(kind: Maybe<&2, String>, field: String) -> List<&2, String>:
  match kind:
    case None{}:
      []
    case Some{t}:
      Rules.without(Rules.type_ops(t), Rules.disallowed_ops(field))

def Rules.get_valid_ops(+field: String) -> List<&2, String>:
  Rules.get_valid_ops.of(Rules.field_type(field), field)

# `{ field, options? }` as an object.
def Rules.deserialize_field(field: String) -> List<&2, V.Field>:
  match field:
    case "amount-inflow":
      [V.Field{"field", V.VStr{"amount"}}, V.Field{"options", V.Value.object([V.Field{"inflow", V.VBool{True{}}}])}]
    case "amount-outflow":
      [V.Field{"field", V.VStr{"amount"}}, V.Field{"options", V.Value.object([V.Field{"outflow", V.VBool{True{}}}])}]
    case other:
      [V.Field{"field", V.VStr{other}}]

def Rules.get_field_error(kind: String) -> String:
  match kind:
    case "date-format":
      "Invalid date format"
    case "no-null":
      "Value cannot be empty"
    case "no-empty-array":
      "Value cannot be empty"
    case "no-empty-string":
      "Value cannot be empty"
    case "not-string":
      "Value must be a string"
    case "not-boolean":
      "Value must be a boolean"
    case "not-number":
      "Value must be a number"
    case "invalid-field":
      "Please choose a valid field for this type of rule"
    case "invalid-template":
      "Invalid handlebars template"
    case other:
      "Internal error, sorry! Please get in touch https://actualbudget.org/contact/ for support"

# The two numbers, smaller first.
def Rules.sort_numbers(+num1: N.Num, +num2: N.Num) -> N.Num & N.Num:
  Bool.pick(N.Num & N.Num, Cmp.is_lt(N.Num.cmp(num1, num2)), (num1, num2), (num2, num1))

def Rules.is_op(item: List<&2, V.Field>, op: String) -> Bool:
  V.Value.strict_eq(V.Txn.get(item, "op"), V.VStr{op})

def Rules.type_is(item: List<&2, V.Field>, kind: String) -> Bool:
  V.Value.strict_eq(V.Txn.get(item, "type"), V.VStr{kind})

def Rules.method_is(item: List<&2, V.Field>, method: String) -> Bool:
  V.Value.strict_eq(V.Txn.get(V.Value.fields(V.Txn.get(item, "options")), "method"), V.VStr{method})

def Rules.parse.typed(+item: List<&2, V.Field>, kind: V.Value) -> List<&2, V.Field>:
  match kind:
    case V.VStr{"number"}:
      item
    case V.VStr{"string"}:
      V.Txn.set(item, "value", V.Value.or_else(V.Txn.get(item, "value"), V.VStr{""}))
    case V.VStr{"boolean"}:
      V.Txn.set(item, "value", V.Txn.get(item, "value"))
    case other:
      V.Txn.set(item, "error", V.VNull{})

def Rules.parse(+item: List<&2, V.Field>) -> List<&2, V.Field>:
  C.If(List<&2, V.Field>, Rules.is_op(item, "set-split-amount"),
    u => item,
    u => Rules.parse.typed(item, V.Txn.get(item, "type")))

def Rules.parse_float(m: Maybe<&2, N.Num>) -> V.Value:
  match m:
    case None{}:
      V.VNull{}
    case Some{n}:
      V.VNum{n}

def Rules.unparse.typed(+item: List<&2, V.Field>, kind: V.Value) -> List<&2, V.Field>:
  match kind:
    case V.VStr{"string"}:
      V.Txn.set(item, "value", V.Value.or_else(V.Txn.get(item, "value"), V.VStr{""}))
    case V.VStr{"boolean"}:
      V.Txn.set(item, "value", V.Value.or_else(V.Txn.get(item, "value"), V.VBool{False{}}))
    case other:
      item

def Rules.unparse.percent(+item: List<&2, V.Field>, +value: V.Value) -> List<&2, V.Field>:
  C.If(List<&2, V.Field>, V.Value.truthy(value),
    u => V.Txn.set(item, "value", Rules.parse_float(U.Util.parse_float(V.Value.to_string(value)))),
    u => V.Txn.set(item, "value", value))

def Rules.unparse.rest(+item: List<&2, V.Field>) -> List<&2, V.Field>:
  C.If(List<&2, V.Field>, Rules.is_op(item, "set-split-amount"),
    u => C.If(List<&2, V.Field>, Rules.method_is(item, "fixed-percent"),
      u => Rules.unparse.percent(item, V.Txn.get(item, "value")),
      u => item),
    u => Rules.unparse.typed(item, V.Txn.get(item, "type")))

def Rules.unparse(item: List<&2, V.Field>) -> List<&2, V.Field>:
  Rules.unparse.rest(V.Txn.del(V.Txn.del(item, "error"), "inputKey"))

def Rules.make_value(+value: V.Value, +cond: List<&2, V.Field>) -> List<&2, V.Field>:
  +multi = Rules.is_op(cond, "oneOf") || Rules.is_op(cond, "notOneOf")
  +zero = Rules.type_is(cond, "number") && V.Value.is_nullish(value)
  V.Txn.set(V.Txn.set(cond, "error", V.VNull{}), "value",
    Bool.pick(V.Value, multi, V.Value.or(value, V.Value.array([])),
      Bool.pick(V.Value, zero, V.Value.nat(0n), value)))

# Math.round(Math.abs(number) * 0.075)
def Rules.approx_threshold(number: N.Num) -> N.Num:
  match number:
    case N.Num{neg, num, den}:
      N.Num.from_int(Maybe.default(&2, I.Int,
        Maybe.bind(&2, N.Num, I.Int, N.Num.mul(N.Num{False{}, num, den}, N.Num{False{}, 3n, 40n}),
          p => N.Num.round(p, 0n)),
        I.Int.zero()))

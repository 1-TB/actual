# Rule actions: a port of packages/loot-core/src/server/rules/action.ts. The
# class `Action` is the datatype `Action` of types.bend; `new Action(...)` is
# `Action.new` and the methods are `Action.exec` and `Action.serialize`.
#
# Deviations:
# - The constructor throws a `RuleError`; `Action.new` answers
#   `Fail{RuleError{kind, message}}` with the same type and message.
# - Handlebars templates (`options.template`) and formulas (`options.formula`
#   on a `set`, or the `formula` method of `set-split-amount`) are not ported:
#   they need the Handlebars and HyperFormula libraries. `Action.new` answers
#   `Fail{RuleError{"unsupported", ...}}` for such an action, after the checks
#   the TS makes, so `exec` never meets one. `executeFormulaSync` and
#   `extractVariablesFromAST` are not ported either.
# - `exec` mutates its object; `Action.exec` answers the changed transaction,
#   or `Fail` with the message of the TypeError the JS throws when a
#   `set-split-amount` action has no options.
# - `prepend-notes` and `append-notes` use JS `+`: here two numbers, booleans
#   or nulls are added and anything else is joined as text; a sum with
#   `undefined` (NaN in JS) is `VNull`.
import Base
import ../lib/core.bend as C
import ../lib/num.bend as N
import ./value.bend as V
import ./types.bend as Y
import ./rules.bend as R
import ./rule-utils.bend as U

# ACTION_OPS.includes(op)
def Action.is_op(op: String) -> Bool:
  match op:
    case "set":
      True{}
    case "set-split-amount":
      True{}
    case "link-schedule":
      True{}
    case "prepend-notes":
      True{}
    case "append-notes":
      True{}
    case "delete-transaction":
      True{}
    case other:
      False{}

def Action.field_type(field: V.Value) -> Maybe<&2, String>:
  match field:
    case V.VStr{s}:
      R.Rules.field_type(s)
    case other:
      None{}

def Action.option(options: V.Value, name: String) -> V.Value:
  V.Txn.get(V.Value.fields(options), name)

def Action.unsupported(msg: String) -> Result<&2, &2, Y.RuleError, Unit>:
  Fail{Y.RuleError{"unsupported", msg}}

# What this port cannot run.
def Action.supported(op: String, +options: V.Value) -> Result<&2, &2, Y.RuleError, Unit>:
  match op:
    case "set":
      C.If(Result<&2, &2, Y.RuleError, Unit>, V.Value.truthy(Action.option(options, "template")),
        u => Action.unsupported("Handlebars templates are not supported"),
        u => Bool.pick(Result<&2, &2, Y.RuleError, Unit>, V.Value.truthy(Action.option(options, "formula")),
          Action.unsupported("Formula actions are not supported"), Done{Unit{}}))
    case "set-split-amount":
      Bool.pick(Result<&2, &2, Y.RuleError, Unit>, V.Value.strict_eq(Action.option(options, "method"), V.VStr{"formula"}),
        Action.unsupported("Formula actions are not supported"), Done{Unit{}})
    case other:
      Done{Unit{}}

def Action.new.set(kind: Maybe<&2, String>, +field: V.Value, +value: V.Value, +options: V.Value) ->
  Result<&2, &2, Y.RuleError, Y.Action>:
  match kind:
    case None{}:
      Fail{Y.RuleError{"internal", "Invalid field for action: " ++ V.Value.to_string(field)}}
    case Some{k}:
      do Result<&2, &2, Y.RuleError, Y.Action>:
        a : Unit <- U.RuleUtils.assert(
          Bool.or(Bool.not(V.Value.strict_eq(field, V.VStr{"account"})), V.Value.truthy(value)),
          "no-null", "Field cannot be empty: account")
        b : Unit <- Action.supported("set", options)
        return Y.Act{"set", field, value, value, options, V.VStr{k}}

# The field and type an operation other than `set` has.
def Action.new.other(+op: String, +field: V.Value, +value: V.Value, +options: V.Value, f: V.Value, k: V.Value) ->
  Result<&2, &2, Y.RuleError, Y.Action>:
  do Result<&2, &2, Y.RuleError, Y.Action>:
    a : Unit <- U.RuleUtils.assert(
      Bool.or(Bool.not(V.Value.strict_eq(field, V.VStr{"account"})), V.Value.truthy(value)),
      "no-null", "Field cannot be empty: account")
    b : Unit <- Action.supported(op, options)
    return Y.Act{op, f, value, value, options, k}

def Action.new(+op: String, +field: V.Value, value: V.Value, options: V.Value) -> Result<&2, &2, Y.RuleError, Y.Action>:
  match op:
    case "set":
      Action.new.set(Action.field_type(field), field, value, options)
    case "set-split-amount":
      Action.new.other(op, field, value, options, V.VNull{}, V.VStr{"number"})
    case "link-schedule":
      Action.new.other(op, field, value, options, V.VNull{}, V.VStr{"id"})
    case "prepend-notes":
      Action.new.other(op, field, value, options, V.VStr{"notes"}, V.VStr{"id"})
    case "append-notes":
      Action.new.other(op, field, value, options, V.VStr{"notes"}, V.VStr{"id"})
    case "delete-transaction":
      Action.new.other(op, field, value, options, V.VMissing{}, V.VMissing{})
    case other:
      Fail{Y.RuleError{"internal", "Invalid action operation: " ++ op}}

# ---------------------------------------------------------------------------
# exec

def Action.numeric(v: V.Value) -> Bool:
  match v:
    case V.VNum{n}:
      True{}
    case V.VBool{b}:
      True{}
    case V.VNull{}:
      True{}
    case V.VMissing{}:
      True{}
    case other:
      False{}

def Action.sum(a: Maybe<&2, N.Num>, b: Maybe<&2, N.Num>) -> V.Value:
  match a b:
    case Some{x} Some{y}:
      V.VNum{Maybe.default(&2, N.Num, N.Num.add(x, y), N.Num.zero())}
    case _ _:
      V.VNull{}

# JS `a + b`.
def Action.add(+a: V.Value, +b: V.Value) -> V.Value:
  C.If(V.Value, Bool.and(Action.numeric(a), Action.numeric(b)),
    u => Action.sum(V.Value.to_number(a), V.Value.to_number(b)),
    u => V.VStr{V.Value.to_string(a) ++ V.Value.to_string(b)})

def Action.exec.set(field: V.Value, +object: List<&2, V.Field>, value: V.Value) -> List<&2, V.Field>:
  match field:
    case V.VStr{"payee_name"}:
      V.Txn.set(V.Txn.set(object, "payee_name", value), "payee", V.VStr{"new"})
    case other:
      V.Txn.set(object, V.Value.to_string(other), value)

def Action.exec.split(+options: V.Value, +object: List<&2, V.Field>, value: V.Value) ->
  Result<&2, &2, String, List<&2, V.Field>>:
  match options:
    case V.VMissing{}:
      Fail{"Cannot read properties of undefined (reading 'method')"}
    case V.VNull{}:
      Fail{"Cannot read properties of null (reading 'method')"}
    case other:
      Done{Bool.pick(List<&2, V.Field>, V.Value.strict_eq(Action.option(options, "method"), V.VStr{"fixed-amount"}),
        V.Txn.set(object, "amount", value), object)}

def Action.exec.notes(+object: List<&2, V.Field>, +value: V.Value, prepend: Bool) -> List<&2, V.Field>:
  +notes = V.Txn.get(object, "notes")
  V.Txn.set(object, "notes",
    Bool.pick(V.Value, V.Value.truthy(notes),
      Bool.pick(V.Value, prepend, Action.add(value, notes), Action.add(notes, value)), value))

# The transaction after the action.
def Action.exec(action: Y.Action, object: List<&2, V.Field>) -> Result<&2, &2, String, List<&2, V.Field>>:
  match action:
    case Y.Act{"set", field, value, raw, options, kind}:
      Done{Action.exec.set(field, object, value)}
    case Y.Act{"set-split-amount", field, value, raw, options, kind}:
      Action.exec.split(options, object, value)
    case Y.Act{"link-schedule", field, value, raw, options, kind}:
      Done{V.Txn.set(object, "schedule", value)}
    case Y.Act{"prepend-notes", field, value, raw, options, kind}:
      Done{Action.exec.notes(object, value, True{})}
    case Y.Act{"append-notes", field, value, raw, options, kind}:
      Done{Action.exec.notes(object, value, False{})}
    case Y.Act{"delete-transaction", field, value, raw, options, kind}:
      Done{V.Txn.set(object, "tombstone", V.Value.nat(1n))}
    case other:
      Done{object}

# `serialize()`
def Action.serialize(action: Y.Action) -> List<&2, V.Field>:
  match action:
    case Y.Act{op, field, value, raw, +options, kind}:
      List.append(&2, V.Field, [V.Field{"op", V.VStr{op}}, V.Field{"field", field}, V.Field{"value", value},
        V.Field{"type", kind}],
        Bool.pick(List<&2, V.Field>, V.Value.truthy(options), [V.Field{"options", options}], Nil{}))

def Action.op(action: Y.Action) -> String:
  match action:
    case Y.Act{op, field, value, raw, options, kind}:
      op

def Action.value(action: Y.Action) -> V.Value:
  match action:
    case Y.Act{op, field, value, raw, options, kind}:
      value

def Action.options(action: Y.Action) -> V.Value:
  match action:
    case Y.Act{op, field, value, raw, options, kind}:
      options

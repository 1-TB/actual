# Rules: a port of packages/loot-core/src/server/rules/rule.ts. The class
# `Rule` is the datatype `Rule` of types.bend; `new Rule({...})` is
# `Rule.new` and the methods are `Rule.eval_conditions`, `Rule.exec_actions`,
# `Rule.exec`, `Rule.apply`, `Rule.get_id` and `Rule.serialize`. The exported
# function `execActions` is `Rule.exec_action_list`.
#
# Deviations:
# - `Rule.new` takes the rule as an object (a list of fields with `id`,
#   `stage`, `conditionsOp`, `conditions`, `actions`) and answers `Fail` with
#   the first `RuleError` a condition or action raises.
# - Running actions answers a `Result`: `Fail` carries the message of the
#   TypeError the JS throws (a `set-split-amount` action without options, or
#   split actions whose `splitIndex` skips a number).
# - Splitting a transaction creates parts with random ids (`uuidv4()`); here
#   the ids are an argument: the k-th part created gets `ids[k]` ("" when the
#   list is too short). The first part created is the placeholder for
#   "apply to all" actions and is dropped from the result, as in the TS.
# - A `splitIndex` that is not a natural number counts as 0.
# - The changes of `execActions` are the fields whose value differs by
#   structure, where the TS compares arrays and objects by identity.
# - Amounts are exact rationals. `Math.round(remainder * (percent / 100))` is
#   a float product in JS, which at an exact half can fall on either side
#   (0.57 * 150 is 85.49999999999999). `Rule.float_off` reproduces that for a
#   whole-number percent below 4096 and a remainder below 2^28; outside that,
#   and for a fractional percent such as 33.3, the product is rounded exactly,
#   which can differ from JS by one at an exact half. A percent that is not a
#   number gives NaN in JS and `VNull` here.
import Base
import ../lib/core.bend as C
import ../lib/int.bend as I
import ../lib/num.bend as N
import ./value.bend as V
import ./types.bend as Y
import ./condition.bend as K
import ./action.bend as A
import ./transactions.bend as S

# ---------------------------------------------------------------------------
# execActions

# options?.splitIndex
def Rule.split_index(action: Y.Action) -> V.Value:
  A.Action.option(A.Action.options(action), "splitIndex")

def Rule.nat(v: V.Value) -> Nat:
  match v:
    case V.VNum{N.Num{False{}, n, 1n}}:
      n
    case other:
      0n

# options?.splitIndex ?? 0, as a natural.
def Rule.index(action: Y.Action) -> Nat:
  Rule.nat(Rule.split_index(action))

# The position of an action's part in the flat list: splitIndex + 1.
def Rule.part(action: Y.Action) -> Nat:
  1n+Rule.index(action)

def Rule.exec_step(r: Result<&2, &2, String, List<&2, V.Field>>, action: Y.Action) ->
  Result<&2, &2, String, List<&2, V.Field>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{object}:
      A.Action.exec(action, object)

# `execNonSplitActions`
def Rule.exec_all(actions: List<&2, Y.Action>, r: Result<&2, &2, String, List<&2, V.Field>>) ->
  Result<&2, &2, String, List<&2, V.Field>>:
  match actions:
    case Nil{}:
      r
    case Con{a, t}:
      Rule.exec_all(t, Rule.exec_step(r, a))

# `getSplitRemainder`: how much of the parent's amount the parts leave over.
def Rule.remainder(transactions: List<&2, List<&2, V.Field>>) -> N.Num:
  V.Value.num(V.Txn.get(V.Value.fields(V.Txn.get(S.Trans.recalculate_split(S.Trans.group(transactions)), "error")),
    "difference"))

# Keeps the parent's data on a part, apart from the fields split actions set.
def Rule.with_parent(child: List<&2, V.Field>, +t: List<&2, V.Field>) -> List<&2, V.Field>:
  +a = V.Txn.set(child, "parent_amount", V.Txn.get(t, "amount"))
  +b = V.Txn.set(a, "parent_notes", V.Value.or_else(V.Txn.get(t, "notes"), V.VStr{""}))
  +c = V.Txn.set(b, "parent_imported_payee", V.Value.or_else(V.Txn.get(t, "imported_payee"), V.VStr{""}))
  +d = V.Txn.set(c, "parent_payee", V.Value.or_else(V.Txn.get(t, "payee"), V.VStr{""}))
  +e = V.Txn.set(d, "parent_account", V.Value.or_else(V.Txn.get(t, "account"), V.VStr{""}))
  V.Txn.set(V.Txn.set(e, "balance", V.Txn.get(t, "balance")), "_balanceOfPrefetched", V.Txn.get(t, "_balanceOfPrefetched"))

def Rule.put(r: Result<&2, &2, String, List<&2, V.Field>>, nt: List<&2, List<&2, V.Field>>, idx: Nat) ->
  Result<&2, &2, String, List<&2, List<&2, V.Field>>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{child}:
      Done{List.set(&2, List<&2, V.Field>, nt, idx, child)}

def Rule.split.apply(child: Maybe<&2, List<&2, V.Field>>, nt: List<&2, List<&2, V.Field>>, idx: Nat,
  action: Y.Action, t: List<&2, V.Field>) -> Result<&2, &2, String, List<&2, List<&2, V.Field>>>:
  match child:
    case None{}:
      Fail{"Cannot set properties of undefined (setting 'parent_amount')"}
    case Some{c}:
      Rule.put(A.Action.exec(action, Rule.with_parent(c, t)), nt, idx)

def Rule.id_at(ids: List<&2, String>, n: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, ids, n), "")

# One round of the loop of `execSplitActions`: adds a part when the action's
# part does not exist yet, then runs the action on its part.
def Rule.split.step(+action: Y.Action, +nt: List<&2, List<&2, V.Field>>, +t: List<&2, V.Field>, ids: List<&2, String>) ->
  Result<&2, &2, String, List<&2, List<&2, V.Field>>>:
  +idx = Rule.part(action)
  +len = List.length(&2, List<&2, V.Field>, nt)
  +grown = Bool.pick(List<&2, List<&2, V.Field>>, Nat.is_ge(idx, len),
    S.Trans.add_split_transaction(nt, V.Txn.get(t, "id"), Rule.id_at(ids, Nat.sub(len, 1n))), nt)
  Rule.split.apply(List.get(&2, List<&2, V.Field>, grown, idx), grown, idx, action, t)

def Rule.split.loop(actions: List<&2, Y.Action>, r: Result<&2, &2, String, List<&2, List<&2, V.Field>>>,
  +t: List<&2, V.Field>, +ids: List<&2, String>) -> Result<&2, &2, String, List<&2, List<&2, V.Field>>>:
  match actions r:
    case Nil{} r:
      r
    case Con{a, rest} Fail{e}:
      Fail{e}
    case Con{a, rest} Done{nt}:
      Rule.split.loop(rest, Rule.split.step(a, nt, t, ids), t, ids)

def Rule.method_is(action: Y.Action, method: String) -> Bool:
  match action:
    case Y.Act{"set-split-amount", field, value, raw, options, kind}:
      V.Value.strict_eq(A.Action.option(options, "method"), V.VStr{method})
    case other:
      False{}

def Rule.set_amount.of(child: Maybe<&2, List<&2, V.Field>>, +nt: List<&2, List<&2, V.Field>>, idx: Nat, amount: V.Value) ->
  List<&2, List<&2, V.Field>>:
  match child:
    case None{}:
      nt
    case Some{c}:
      List.set(&2, List<&2, V.Field>, nt, idx, V.Txn.set(c, "amount", amount))

# newTransactions[idx].amount = amount
def Rule.set_amount(+nt: List<&2, List<&2, V.Field>>, +idx: Nat, amount: V.Value) -> List<&2, List<&2, V.Field>>:
  Rule.set_amount.of(List.get(&2, List<&2, V.Field>, nt, idx), nt, idx, amount)

def Rule.rounded(m: Maybe<&2, N.Num>) -> V.Value:
  match m:
    case None{}:
      V.VNull{}
    case Some{x}:
      V.Value.int(Maybe.default(&2, I.Int, N.Num.round(x, 0n), I.Int.zero()))

# floor(log2 n) for n >= 1.
def Rule.log2(fuel: Nat, +n: Nat) -> Nat:
  match fuel:
    case 0n:
      0n
    case 1n+g:
      C.If(Nat, Nat.is_lt(n, 2n), u => 0n, u => 1n+Rule.log2(g, Nat.div(n, 2n)))

def Rule.pow2(n: Nat) -> Nat:
  match n:
    case 0n:
      1n
    case 1n+m:
      (2n * Rule.pow2(m) : Nat)

# What is left of a division after some bits of the quotient were taken:
# rem / den of a unit in the last place, and whether the last bit was 1.
type Rule.Quot is Data:
  Quot{rem: Nat, den: Nat, odd: Bool}

# n more bits of rem / den.
def Rule.bits(n: Nat, +rem: Nat, +den: Nat, odd: Bool) -> Rule.Quot:
  match n:
    case 0n:
      Quot{rem, den, odd}
    case 1n+m:
      Rule.bits(m, Nat.sub((rem * 2n : Nat), Bool.pick(Nat, Nat.is_ge((rem * 2n : Nat), den), den, 0n)), den,
        Nat.is_ge((rem * 2n : Nat), den))

# The smallest n with v * 2^n >= 100.
def Rule.shift_up(fuel: Nat, +v: Nat) -> Nat:
  match fuel:
    case 0n:
      0n
    case 1n+g:
      C.If(Nat, Nat.is_ge(v, 100n), u => 0n, u => 1n+Rule.shift_up(g, (v * 2n : Nat)))

# Whether the double product r * (v / 100) lands on the far side of the tie
# it should hit. `eo` is 64 plus the exponent of v / 100, `to` 64 plus that
# of the exact product; q is what rounding v / 100 to 53 bits left over.
def Rule.float_off.at(q: Rule.Quot, +r: Nat, +eo: Nat, +to: Nat, neg: Bool) -> Bool:
  match q:
    case Quot{+rem, +den, odd}:
      +twice = (rem * 2n : Nat)
      +up = Bool.or(Nat.is_gt(twice, den), Bool.and(Nat.is_eq(twice, den), odd))
      +miss = (r * Bool.pick(Nat, up, Nat.sub(den, rem), rem) : Nat)
      +far = Bool.pick(Bool, Nat.is_ge(1n+eo, to),
        Nat.is_gt((miss * Rule.pow2(C.Nat.lo(Nat.sub(1n+eo, to), 6n)) : Nat), den),
        Nat.is_gt(miss, (den * Rule.pow2(C.Nat.lo(Nat.sub(to, 1n+eo), 30n)) : Nat)))
      Bool.and(far, Bool.pick(Bool, neg, up, Bool.not(up)))

# JS computes `remaining * (value / 100)` in doubles. When the exact product
# is halfway between two integers the double can fall just short of it or
# just past it, and `Math.round` then differs from exact rounding by one.
# This says whether it does, for |remaining| = r below 2^28 and an integer
# |value| = v below 4096; `neg` is the sign of the product.
def Rule.float_off.tie(+r: Nat, +v: Nat, +neg: Bool) -> Bool:
  +up = Rule.shift_up(8n, v)
  +e = Rule.log2(48n, Nat.div(v, 100n))
  +to = (63n + Rule.log2(48n, Nat.div((r * v : Nat), 50n)) : Nat)
  C.If(Bool, Nat.is_eq(Nat.mod((r * v : Nat), 100n), 50n),
    u => C.If(Bool, Nat.is_ge(v, 100n),
      u => Rule.float_off.at(
        Rule.bits(52n, Nat.sub(v, (100n * Rule.pow2(e) : Nat)), (100n * Rule.pow2(e) : Nat), True{}),
        r, (64n + e : Nat), to, neg),
      u => Rule.float_off.at(Rule.bits(52n, Nat.sub((v * Rule.pow2(up) : Nat), 100n), 100n, True{}),
        r, Nat.sub(64n, up), to, neg)),
    u => False{})

def Rule.float_off(+r: Nat, +v: Nat, +neg: Bool) -> Bool:
  C.If(Bool, Bool.and(Bool.and(Nat.is_gt(v, 0n), Nat.is_lt(v, 4096n)), Nat.is_lt(r, 268435456n)),
    u => Rule.float_off.tie(r, v, neg),
    u => False{})

def Rule.percent.fix(exact: V.Value, off: Bool) -> V.Value:
  match exact off:
    case V.VNum{n} True{}:
      V.VNum{Maybe.default(&2, N.Num, N.Num.sub(n, N.Num.from_nat(1n)), N.Num.zero())}
    case other _:
      other

def Rule.percent.off(remaining: N.Num, v: N.Num) -> Bool:
  match remaining v:
    case N.Num{s, r, 1n} N.Num{t, p, 1n}:
      Rule.float_off(r, p, Bool.xor(s, t))
    case _ _:
      False{}

# Math.round(remaining * (value / 100))
def Rule.percent(+remaining: N.Num, value: Maybe<&2, N.Num>) -> V.Value:
  match value:
    case None{}:
      V.VNull{}
    case Some{+v}:
      Rule.percent.fix(
        Rule.rounded(Maybe.bind(&2, N.Num, N.Num, N.Num.mul(remaining, v), p => N.Num.div(p, N.Num.from_nat(100n)))),
        Rule.percent.off(remaining, v))

# Gives each fixed-percent part its share of what the fixed amounts left.
def Rule.percents(actions: List<&2, Y.Action>, +nt: List<&2, List<&2, V.Field>>, +remaining: N.Num) ->
  List<&2, List<&2, V.Field>>:
  match actions:
    case Nil{}:
      nt
    case Con{+a, t}:
      Rule.percents(t,
        Bool.pick(List<&2, List<&2, V.Field>>, Rule.method_is(a, "fixed-percent"),
          Rule.set_amount(nt, Rule.part(a), Rule.percent(remaining, V.Value.to_number(A.Action.value(a)))), nt),
        remaining)

def Rule.count(actions: List<&2, Y.Action>, +method: String) -> Nat:
  match actions:
    case Nil{}:
      0n
    case Con{a, t}:
      (U32.to_nat(Bool.to_u32(Rule.method_is(a, method))) + Rule.count(t, method) : Nat)

# Gives each remainder part the same amount; answers the list and, through
# `last`, follows the highest part index.
def Rule.remainders(actions: List<&2, Y.Action>, +nt: List<&2, List<&2, V.Field>>, +amount: V.Value) ->
  List<&2, List<&2, V.Field>>:
  match actions:
    case Nil{}:
      nt
    case Con{+a, t}:
      Rule.remainders(t,
        Bool.pick(List<&2, List<&2, V.Field>>, Rule.method_is(a, "remainder"), Rule.set_amount(nt, Rule.part(a), amount), nt),
        amount)

def Rule.last_remainder(actions: List<&2, Y.Action>, +last: Nat) -> Nat:
  match actions:
    case Nil{}:
      last
    case Con{+a, t}:
      Rule.last_remainder(t, Bool.pick(Nat, Rule.method_is(a, "remainder"), C.Nat.hi(last, Rule.part(a)), last))

def Rule.plus(a: N.Num, b: N.Num) -> N.Num:
  Maybe.default(&2, N.Num, N.Num.add(a, b), N.Num.zero())

# The last remainder part takes what rounding left over.
def Rule.adjust(+nt: List<&2, List<&2, V.Field>>, +last: Nat) -> List<&2, List<&2, V.Field>>:
  Rule.set_amount(nt, last,
    V.VNum{Rule.plus(
      V.Value.num(V.Txn.get(Maybe.default(&2, List<&2, V.Field>, List.get(&2, List<&2, V.Field>, nt, last), Nil{}), "amount")),
      Rule.remainder(nt))})

def Rule.spread(+actions: List<&2, Y.Action>, +nt: List<&2, List<&2, V.Field>>, +count: Nat) -> List<&2, List<&2, V.Field>>:
  C.If(List<&2, List<&2, V.Field>>, Nat.is_eq(count, 0n),
    u => nt,
    u => Rule.adjust(
      Rule.remainders(actions, nt, Rule.rounded(N.Num.div(Rule.remainder(nt), N.Num.from_nat(count)))),
      Rule.last_remainder(actions, 0n)))

# newTransactions.splice(1, 1)
def Rule.drop_second(nt: List<&2, List<&2, V.Field>>) -> List<&2, List<&2, V.Field>>:
  match nt:
    case Con{a, Con{b, rest}}:
      Con{a, rest}
    case other:
      other

def Rule.split.finish(r: Result<&2, &2, String, List<&2, List<&2, V.Field>>>, +actions: List<&2, Y.Action>) ->
  Result<&2, &2, String, List<&2, V.Field>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{+nt}:
      Done{S.Trans.recalculate_split(S.Trans.group(Rule.drop_second(
        Rule.spread(actions, Rule.percents(actions, nt, Rule.remainder(nt)), Rule.count(actions, "remainder")))))}

# `execSplitActions`
def Rule.exec_split(+actions: List<&2, Y.Action>, +t: List<&2, V.Field>, +ids: List<&2, String>) ->
  Result<&2, &2, String, List<&2, V.Field>>:
  Rule.split.finish(
    Rule.split.loop(actions,
      Done{S.Trans.split_transaction(S.Trans.ungroup(t), V.Txn.get(t, "id"), Rule.id_at(ids, 0n))}, t, ids),
    actions)

# The actions whose `splitIndex` is truthy (`split`) or not.
def Rule.pick_actions(actions: List<&2, Y.Action>, +split: Bool) -> List<&2, Y.Action>:
  match actions:
    case Nil{}:
      Nil{}
    case Con{+a, +t}:
      C.If(List<&2, Y.Action>, V.Value.bool_eq(V.Value.truthy(Rule.split_index(a)), split),
        u => Con{a, Rule.pick_actions(t, split)},
        u => Rule.pick_actions(t, split))

def Rule.max_index(actions: List<&2, Y.Action>, acc: Nat) -> Nat:
  match actions:
    case Nil{}:
      acc
    case Con{a, t}:
      Rule.max_index(t, C.Nat.hi(acc, Rule.index(a)))

def Rule.exec_action_list.rest(r: Result<&2, &2, String, List<&2, V.Field>>, splits: Bool,
  children: List<&2, Y.Action>, ids: List<&2, String>) -> Result<&2, &2, String, List<&2, V.Field>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{+t}:
      # Rules with splits can't be applied to child transactions.
      C.If(Result<&2, &2, String, List<&2, V.Field>>, Bool.and(splits, Bool.not(V.Value.truthy(V.Txn.get(t, "is_child")))),
        u => Rule.exec_split(children, t, ids),
        u => Done{t})

# `execActions(actions, transaction)`: the transaction after the actions,
# split into parts when some action has a `splitIndex`.
def Rule.exec_action_list(+actions: List<&2, Y.Action>, transaction: List<&2, V.Field>, ids: List<&2, String>) ->
  Result<&2, &2, String, List<&2, V.Field>>:
  Rule.exec_action_list.rest(Rule.exec_all(Rule.pick_actions(actions, False{}), Done{transaction}),
    Nat.is_gt(Rule.max_index(actions, 0n), 0n), Rule.pick_actions(actions, True{}), ids)

# ---------------------------------------------------------------------------
# new Rule({ id, stage, conditionsOp, conditions, actions })

def Rule.get(spec: V.Value, key: String) -> V.Value:
  V.Txn.get(V.Value.fields(spec), key)

def Rule.new.conds(specs: List<&2, V.Value>) -> Result<&2, &2, Y.RuleError, List<&2, Y.Condition>>:
  match specs:
    case Nil{}:
      Done{Nil{}}
    case Con{+c, t}:
      do Result<&2, &2, Y.RuleError, List<&2, Y.Condition>>:
        x : Y.Condition <- K.Condition.new(V.Value.to_string(Rule.get(c, "op")), V.Value.to_string(Rule.get(c, "field")),
          Rule.get(c, "value"), Rule.get(c, "options"))
        xs : List<&2, Y.Condition> <- Rule.new.conds(t)
        return Con{x, xs}

def Rule.new.actions(specs: List<&2, V.Value>) -> Result<&2, &2, Y.RuleError, List<&2, Y.Action>>:
  match specs:
    case Nil{}:
      Done{Nil{}}
    case Con{+a, t}:
      do Result<&2, &2, Y.RuleError, List<&2, Y.Action>>:
        x : Y.Action <- A.Action.new(V.Value.to_string(Rule.get(a, "op")), Rule.get(a, "field"), Rule.get(a, "value"),
          Rule.get(a, "options"))
        xs : List<&2, Y.Action> <- Rule.new.actions(t)
        return Con{x, xs}

def Rule.new(+spec: List<&2, V.Field>) -> Result<&2, &2, Y.RuleError, Y.Rule>:
  do Result<&2, &2, Y.RuleError, Y.Rule>:
    conditions : List<&2, Y.Condition> <- Rule.new.conds(V.Value.items(V.Txn.get(spec, "conditions")))
    actions : List<&2, Y.Action> <- Rule.new.actions(V.Value.items(V.Txn.get(spec, "actions")))
    return Y.Rule{V.Txn.get(spec, "id"), V.Value.or_else(V.Txn.get(spec, "stage"), V.VNull{}),
      V.Txn.get(spec, "conditionsOp"), conditions, actions}

# ---------------------------------------------------------------------------
# Methods

def Rule.some(conds: List<&2, Y.Condition>, +object: List<&2, V.Field>) -> Bool:
  match conds:
    case Nil{}:
      False{}
    case Con{c, +t}:
      C.If(Bool, K.Condition.eval(c, object), u => True{}, u => Rule.some(t, object))

def Rule.every(conds: List<&2, Y.Condition>, +object: List<&2, V.Field>) -> Bool:
  match conds:
    case Nil{}:
      True{}
    case Con{c, +t}:
      C.If(Bool, K.Condition.eval(c, object), u => Rule.every(t, object), u => False{})

def Rule.eval_conditions.of(conds: List<&2, Y.Condition>, any: Bool, object: List<&2, V.Field>) -> Bool:
  match conds any:
    case Nil{} _:
      False{}
    case cs True{}:
      Rule.some(cs, object)
    case cs False{}:
      Rule.every(cs, object)

# Whether the transaction satisfies the conditions: all of them, or with
# `conditionsOp` 'or' one of them. A rule without conditions matches nothing.
def Rule.eval_conditions(rule: Y.Rule, object: List<&2, V.Field>) -> Bool:
  match rule:
    case Y.Rule{id, stage, conditions_op, conditions, actions}:
      Rule.eval_conditions.of(conditions, V.Value.strict_eq(conditions_op, V.VStr{"or"}), object)

# The fields of `result` that differ from those of `object`.
def Rule.changes(result: List<&2, V.Field>, +object: List<&2, V.Field>) -> List<&2, V.Field>:
  match result:
    case Nil{}:
      Nil{}
    case Con{V.Field{+k, +v}, +t}:
      C.If(List<&2, V.Field>, V.Value.eq(v, V.Txn.get(object, k)),
        u => Rule.changes(t, object),
        u => Con{V.Field{k, v}, Rule.changes(t, object)})

def Rule.changed(r: Result<&2, &2, String, List<&2, V.Field>>, object: List<&2, V.Field>) ->
  Result<&2, &2, String, List<&2, V.Field>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{result}:
      Done{Rule.changes(result, object)}

# `execActions(object)`: what the actions change.
def Rule.exec_actions(rule: Y.Rule, +object: List<&2, V.Field>, ids: List<&2, String>) ->
  Result<&2, &2, String, List<&2, V.Field>>:
  match rule:
    case Y.Rule{id, stage, conditions_op, conditions, actions}:
      Rule.changed(Rule.exec_action_list(actions, object, ids), object)

def Rule.some_changes(r: Result<&2, &2, String, List<&2, V.Field>>) -> Result<&2, &2, String, Maybe<&2, List<&2, V.Field>>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{changes}:
      Done{Some{changes}}

# `exec(object)`: the changes when the conditions hold, else None (JS null).
def Rule.exec(+rule: Y.Rule, +object: List<&2, V.Field>, ids: List<&2, String>) ->
  Result<&2, &2, String, Maybe<&2, List<&2, V.Field>>>:
  C.If(Result<&2, &2, String, Maybe<&2, List<&2, V.Field>>>, Rule.eval_conditions(rule, object),
    u => Rule.some_changes(Rule.exec_actions(rule, object, ids)),
    u => Done{None{}})

def Rule.applied(r: Result<&2, &2, String, Maybe<&2, List<&2, V.Field>>>, object: List<&2, V.Field>) ->
  Result<&2, &2, String, List<&2, V.Field>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{None{}}:
      Done{object}
    case Done{Some{changes}}:
      Done{V.Txn.assign(object, changes)}

# `apply(object)`: like `exec`, with the changes applied to the transaction.
def Rule.apply(rule: Y.Rule, +object: List<&2, V.Field>, ids: List<&2, String>) ->
  Result<&2, &2, String, List<&2, V.Field>>:
  Rule.applied(Rule.exec(rule, object, ids), object)

def Rule.get_id(rule: Y.Rule) -> V.Value:
  match rule:
    case Y.Rule{id, stage, conditions_op, conditions, actions}:
      id

def Rule.serialize.conds(conds: List<&2, Y.Condition>) -> List<&2, V.Value>:
  match conds:
    case Nil{}:
      Nil{}
    case Con{c, t}:
      Con{V.Value.object(K.Condition.serialize(c)), Rule.serialize.conds(t)}

def Rule.serialize.actions(actions: List<&2, Y.Action>) -> List<&2, V.Value>:
  match actions:
    case Nil{}:
      Nil{}
    case Con{a, t}:
      Con{V.Value.object(A.Action.serialize(a)), Rule.serialize.actions(t)}

# `serialize()`
def Rule.serialize(rule: Y.Rule) -> List<&2, V.Field>:
  match rule:
    case Y.Rule{id, stage, conditions_op, conditions, actions}:
      [V.Field{"id", id}, V.Field{"stage", stage}, V.Field{"conditionsOp", conditions_op},
        V.Field{"conditions", V.Value.array(Rule.serialize.conds(conditions))},
        V.Field{"actions", V.Value.array(Rule.serialize.actions(actions))}]

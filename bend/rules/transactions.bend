# Split transactions, as far as rules need them: a port of `makeChild`,
# `recalculateSplit`, `groupTransaction`, `ungroupTransaction(s)`,
# `splitTransaction` and `addSplitTransaction` from
# packages/loot-core/src/shared/transactions.ts. The rest of that module is
# not ported here.
#
# Deviations:
# - `makeChild` draws a random id with `uuidv4()`; here the id is an argument.
# - `splitTransaction` and `addSplitTransaction` answer only the `data` list
#   (not `diff` or `newTransaction`), take no `createSubtransactions`, and
#   expect the transaction to edit to be the first of the list, which is how
#   rule.ts calls them; with any other list they answer it unchanged, where
#   the TS searches the list (and throws for an unknown id).
# - Amounts are exact rationals; a sum that overflows lib/num.bend counts as 0.
import Base
import ../lib/core.bend as C
import ../lib/num.bend as N
import ./value.bend as V

def Trans.truthy(t: List<&2, V.Field>, key: String) -> Bool:
  V.Value.truthy(V.Txn.get(t, key))

# `x != null ? x : null`
def Trans.or_null(v: V.Value) -> V.Value:
  V.Value.or_else(v, V.VNull{})

def Trans.objects(ts: List<&2, List<&2, V.Field>>) -> List<&2, V.Value>:
  match ts:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{V.Value.object(h), Trans.objects(t)}

def Trans.lists(vs: List<&2, V.Value>) -> List<&2, List<&2, V.Field>>:
  match vs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{V.Value.fields(h), Trans.lists(t)}

# trans.subtransactions || []
def Trans.subs(trans: List<&2, V.Field>) -> List<&2, List<&2, V.Field>>:
  Trans.lists(V.Value.items(V.Txn.get(trans, "subtransactions")))

def Trans.copy(keys: List<&2, String>, +from: List<&2, V.Field>, child: List<&2, V.Field>) -> List<&2, V.Field>:
  match keys:
    case Nil{}:
      child
    case Con{+k, rest}:
      Trans.copy(rest, from, V.Txn.set(child, k, Trans.or_null(V.Txn.get(from, k))))

# `makeChild(parent, data)` with the id a new child gets.
def Trans.make_child(+parent: List<&2, V.Field>, +data: List<&2, V.Field>, id: String) -> List<&2, V.Field>:
  +prefix = Bool.pick(String, V.Value.strict_eq(V.Txn.get(parent, "id"), V.VStr{"temp"}), "temp", "")
  +a = V.Txn.assign([V.Field{"amount", V.Value.nat(0n)}], data)
  +b = V.Txn.set(a, "category", V.Txn.get(Bool.pick(List<&2, V.Field>, V.Txn.has(data, "category"), data, parent), "category"))
  +c = V.Txn.set(b, "payee", V.Txn.get(Bool.pick(List<&2, V.Field>, V.Txn.has(data, "payee"), data, parent), "payee"))
  +d = V.Txn.set(c, "id", Bool.pick(V.Value, V.Txn.has(data, "id"), V.Txn.get(data, "id"), V.VStr{prefix ++ id}))
  +e = V.Txn.set(V.Txn.set(d, "account", V.Txn.get(parent, "account")), "date", V.Txn.get(parent, "date"))
  +f = Trans.copy(["cleared", "reconciled", "starting_balance_flag"], parent, e)
  +g = V.Txn.set(f, "sort_order",
    Bool.pick(V.Value, V.Txn.has(data, "sort_order"), V.Txn.get(data, "sort_order"), Trans.or_null(V.Txn.get(parent, "sort_order"))))
  V.Txn.set(V.Txn.set(V.Txn.set(g, "is_child", V.VBool{True{}}), "parent_id", V.Txn.get(parent, "id")), "error", V.VNull{})

def Trans.plus(a: N.Num, b: N.Num) -> N.Num:
  Maybe.default(&2, N.Num, N.Num.add(a, b), N.Num.zero())

def Trans.minus(a: N.Num, b: N.Num) -> N.Num:
  Maybe.default(&2, N.Num, N.Num.sub(a, b), N.Num.zero())

def Trans.total(subs: List<&2, List<&2, V.Field>>, acc: N.Num) -> N.Num:
  match subs:
    case Nil{}:
      acc
    case Con{h, t}:
      Trans.total(t, Trans.plus(acc, V.Value.num(V.Txn.get(h, "amount"))))

# `SplitTransactionError(total, parent)`
def Trans.split_error(total: N.Num, parent: List<&2, V.Field>) -> V.Value:
  V.Value.object([V.Field{"type", V.VStr{"SplitTransactionError"}}, V.Field{"version", V.Value.nat(1n)},
    V.Field{"difference", V.VNum{Trans.minus(V.Value.num(V.Txn.get(parent, "amount")), total)}}])

# `recalculateSplit`: the error says by how much the parts miss the parent.
def Trans.recalculate_split(+trans: List<&2, V.Field>) -> List<&2, V.Field>:
  +total = Trans.total(Trans.subs(trans), N.Num.zero())
  V.Txn.set(V.Txn.del(trans, "error"), "error",
    Bool.pick(V.Value, N.Num.is_eq(total, V.Value.num(V.Txn.get(trans, "amount"))), V.VNull{}, Trans.split_error(total, trans)))

# `groupTransaction`: the first of the list with the others as its parts.
def Trans.group(split: List<&2, List<&2, V.Field>>) -> List<&2, V.Field>:
  match split:
    case Nil{}:
      [V.Field{"subtransactions", V.Value.array(Nil{})}]
    case Con{h, t}:
      V.Txn.set(h, "subtransactions", V.Value.array(Trans.objects(t)))

# `ungroupTransaction`: the transaction, then its parts.
def Trans.ungroup(+trans: List<&2, V.Field>) -> List<&2, List<&2, V.Field>>:
  Con{V.Txn.del(trans, "subtransactions"), Trans.subs(trans)}

# The parts that follow a parent in a flat list, and what comes after them.
def Trans.children(rest: List<&2, List<&2, V.Field>>) -> List<&2, List<&2, V.Field>>:
  match rest:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      C.If(List<&2, List<&2, V.Field>>, Trans.truthy(h, "is_child"), u => Con{h, Trans.children(t)}, u => Nil{})

def Trans.after_children(rest: List<&2, List<&2, V.Field>>) -> List<&2, List<&2, V.Field>>:
  match rest:
    case Nil{}:
      Nil{}
    case Con{+h, +t}:
      C.If(List<&2, List<&2, V.Field>>, Trans.truthy(h, "is_child"), u => Trans.after_children(t), u => Con{h, t})

# The callback of `splitTransaction`.
def Trans.split.one(+trans: List<&2, V.Field>, id: String) -> List<&2, V.Field>:
  +child = Trans.make_child(trans, Nil{}, id)
  +sub = V.Txn.set(child, "sort_order", V.Value.or(V.Txn.get(child, "sort_order"), V.Value.minus(1n)))
  +zero = N.Num.is_zero(V.Value.num(V.Txn.get(trans, "amount")))
  +a = V.Txn.set(V.Txn.set(V.Txn.del(trans, "error"), "is_parent", V.VBool{True{}}), "payee", V.VNull{})
  +b = V.Txn.set(a, "error", Bool.pick(V.Value, zero, V.VNull{}, Trans.split_error(N.Num.zero(), trans)))
  V.Txn.set(b, "subtransactions", V.Value.array([V.Value.object(sub)]))

def Trans.last_sub(subs: List<&2, List<&2, V.Field>>) -> Maybe<&2, List<&2, V.Field>>:
  List.last(&2, List<&2, V.Field>, subs)

def Trans.add.data(prev: Maybe<&2, List<&2, V.Field>>, +trans: List<&2, V.Field>) -> List<&2, V.Field>:
  match prev:
    case None{}:
      [V.Field{"amount", V.Value.nat(0n)}, V.Field{"payee", V.Txn.get(trans, "payee")},
        V.Field{"sort_order", V.Value.minus(1n)}]
    case Some{+p}:
      [V.Field{"amount", V.Value.nat(0n)},
        V.Field{"payee", V.Value.or_else(V.Txn.get(p, "payee"), V.Txn.get(trans, "payee"))},
        V.Field{"sort_order", V.VNum{Trans.minus(V.Value.num(V.Txn.get(p, "sort_order")), N.Num.from_nat(1n))}}]

# The callback of `addSplitTransaction`: one more part after the last.
def Trans.add.one(+trans: List<&2, V.Field>, id: String) -> List<&2, V.Field>:
  +subs = Trans.subs(trans)
  +child = Trans.make_child(trans, Trans.add.data(Trans.last_sub(subs), trans), id)
  Bool.pick(List<&2, V.Field>,
    Bool.and(Trans.truthy(trans, "is_parent"), V.Value.is_array(V.Txn.get(trans, "subtransactions"))),
    V.Txn.set(trans, "subtransactions", V.Value.array(Trans.objects(List.append(&2, List<&2, V.Field>, subs, [child])))),
    trans)

def Trans.replace.at(add: Bool, parent: Bool, child: Bool, +trans: List<&2, V.Field>,
  +rest: List<&2, List<&2, V.Field>>, id: String) -> List<&2, List<&2, V.Field>>:
  match add parent child:
    case _ False{} True{}:
      # 'Cannot find parent index'
      Nil{}
    case True{} True{} _:
      List.append(&2, List<&2, V.Field>,
        Trans.ungroup(Trans.add.one(Trans.group(Con{trans, Trans.children(rest)}), id)), Trans.after_children(rest))
    case False{} True{} _:
      List.append(&2, List<&2, V.Field>, Trans.ungroup(Trans.group(Con{trans, Trans.children(rest)})),
        Trans.after_children(rest))
    case True{} False{} False{}:
      Con{V.Txn.del(trans, "subtransactions"), List.append(&2, List<&2, V.Field>, Trans.subs(trans), rest)}
    case False{} False{} False{}:
      List.append(&2, List<&2, V.Field>, Trans.ungroup(Trans.split.one(trans, id)), rest)

# `replaceTransactions` for the first transaction of the list; `add` picks
# the callback of `addSplitTransaction` over that of `splitTransaction`.
def Trans.replace(transactions: List<&2, List<&2, V.Field>>, add: Bool, id: String) -> List<&2, List<&2, V.Field>>:
  match transactions:
    case Nil{}:
      Nil{}
    case Con{+trans, rest}:
      Trans.replace.at(add, Trans.truthy(trans, "is_parent"), Trans.truthy(trans, "is_child"), trans, rest, id)

def Trans.heads(transactions: List<&2, List<&2, V.Field>>, id: V.Value) -> Bool:
  match transactions:
    case Nil{}:
      False{}
    case Con{h, t}:
      V.Value.strict_eq(V.Txn.get(h, "id"), id)

# `splitTransaction(transactions, id).data`; `child_id` is the id of the part
# it creates.
def Trans.split_transaction(+transactions: List<&2, List<&2, V.Field>>, id: V.Value, child_id: String) ->
  List<&2, List<&2, V.Field>>:
  Bool.pick(List<&2, List<&2, V.Field>>, Trans.heads(transactions, id), Trans.replace(transactions, False{}, child_id),
    transactions)

# `addSplitTransaction(transactions, id).data`
def Trans.add_split_transaction(+transactions: List<&2, List<&2, V.Field>>, id: V.Value, child_id: String) ->
  List<&2, List<&2, V.Field>>:
  Bool.pick(List<&2, List<&2, V.Field>>, Trans.heads(transactions, id), Trans.replace(transactions, True{}, child_id),
    transactions)

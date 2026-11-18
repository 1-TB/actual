# An index from a field's value to the rules that can apply to it: a port of
# packages/loot-core/src/server/rules/rule-indexer.ts. The class
# `RuleIndexer` is the datatype below; `new RuleIndexer({ field, method })` is
# `RuleIndexer.new`, and `index` and `remove` answer the changed indexer
# where the TS mutates it.
#
# Deviations:
# - The TS keeps a `Map<string, Set<Rule>>` whose sets hold rules by object
#   identity. Here a set is a list without repeats and two rules are the same
#   when they serialize to the same JSON, so indexing two identical rules
#   keeps one.
# - `getIndex` and `getIndexForValue` hand out the mutable sets; here
#   `RuleIndexer.get_index` and `RuleIndexer.get_index_for_value` answer their
#   rules, and do not add an empty set for an unknown key (which nothing can
#   observe through the other methods).
# - `getApplicableRules` answers a `Set`; here its rules in iteration order.
# - With the 'firstchar' method the key is the first code point of the value,
#   lowered with `Value.lower`; JS takes the first UTF-16 unit.
import Base
import ../lib/core.bend as C
import ./value.bend as V
import ./types.bend as Y
import ./rule.bend as R

type RuleIndexer.Bucket is Data:
  Bucket{key: String, rules: List<&2, Y.Rule>}

type RuleIndexer is Data:
  RuleIndexer{field: String, firstchar: Bool, buckets: List<&2, RuleIndexer.Bucket>}

# `method` is the TS option: Some{"firstchar"} indexes by first character.
def RuleIndexer.new(field: String, method: Maybe<&2, String>) -> RuleIndexer:
  RuleIndexer{field, String.eq(Maybe.default(&2, String, method, ""), "firstchar"), Nil{}}

def RuleIndexer.same(a: Y.Rule, b: Y.Rule) -> Bool:
  String.eq(V.Txn.show(R.Rule.serialize(a)), V.Txn.show(R.Rule.serialize(b)))

def RuleIndexer.add(rules: List<&2, Y.Rule>, +rule: Y.Rule) -> List<&2, Y.Rule>:
  match rules:
    case Nil{}:
      [rule]
    case Con{+h, +t}:
      C.If(List<&2, Y.Rule>, RuleIndexer.same(h, rule), u => Con{h, t}, u => Con{h, RuleIndexer.add(t, rule)})

def RuleIndexer.del(rules: List<&2, Y.Rule>, +rule: Y.Rule) -> List<&2, Y.Rule>:
  match rules:
    case Nil{}:
      Nil{}
    case Con{+h, +t}:
      C.If(List<&2, Y.Rule>, RuleIndexer.same(h, rule), u => t, u => Con{h, RuleIndexer.del(t, rule)})

# set1 then the rules of set2 it lacks: `fastSetMerge`.
def RuleIndexer.merge(set2: List<&2, Y.Rule>, set1: List<&2, Y.Rule>) -> List<&2, Y.Rule>:
  match set2:
    case Nil{}:
      set1
    case Con{h, t}:
      RuleIndexer.merge(t, RuleIndexer.add(set1, h))

def RuleIndexer.find(buckets: List<&2, RuleIndexer.Bucket>, +key: String) -> List<&2, Y.Rule>:
  match buckets:
    case Nil{}:
      Nil{}
    case Con{Bucket{k, rules}, t}:
      C.If(List<&2, Y.Rule>, String.eq(k, key), u => rules, u => RuleIndexer.find(t, key))

# `getIndex(key)`: the rules filed under a key.
def RuleIndexer.get_index(ix: RuleIndexer, key: String) -> List<&2, Y.Rule>:
  match ix:
    case RuleIndexer{field, firstchar, buckets}:
      RuleIndexer.find(buckets, key)

def RuleIndexer.key_of(s: String, firstchar: Bool) -> Maybe<&2, String>:
  match s firstchar:
    case SNil{} _:
      None{}
    case SCon{h, t} True{}:
      Some{SCon{V.Value.lower_char(h), SNil{}}}
    case SCon{h, t} False{}:
      Some{V.Value.lower(SCon{h, t})}

def RuleIndexer.key(firstchar: Bool, value: V.Value) -> Maybe<&2, String>:
  match value:
    case V.VStr{s}:
      RuleIndexer.key_of(s, firstchar)
    case other:
      None{}

# `getKey(value)`: the key a value is filed under; None (JS null) unless it
# is a non-empty string.
def RuleIndexer.get_key(ix: RuleIndexer, value: V.Value) -> Maybe<&2, String>:
  match ix:
    case RuleIndexer{field, firstchar, buckets}:
      RuleIndexer.key(firstchar, value)

# getKey(value) || '*'
def RuleIndexer.key_or_star(firstchar: Bool, value: V.Value) -> String:
  Maybe.default(&2, String, RuleIndexer.key(firstchar, value), "*")

# `getIndexForValue(value)`
def RuleIndexer.get_index_for_value(ix: RuleIndexer, value: V.Value) -> List<&2, Y.Rule>:
  match ix:
    case RuleIndexer{field, firstchar, buckets}:
      RuleIndexer.find(buckets, RuleIndexer.key_or_star(firstchar, value))

def RuleIndexer.keys.all(values: List<&2, V.Value>, +firstchar: Bool) -> List<&2, String>:
  match values:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{RuleIndexer.key_or_star(firstchar, h), RuleIndexer.keys.all(t, firstchar)}

def RuleIndexer.plain(value: Y.Parsed) -> V.Value:
  match value:
    case Y.PValue{v}:
      v
    case other:
      V.VMissing{}

def RuleIndexer.keys.cond(op: String, +value: V.Value, +firstchar: Bool) -> List<&2, String>:
  match op:
    case "oneOf":
      RuleIndexer.keys.all(V.Value.items(value), firstchar)
    case "notOneOf":
      RuleIndexer.keys.all(V.Value.items(value), firstchar)
    case "is":
      [RuleIndexer.key_or_star(firstchar, value)]
    case "isNot":
      [RuleIndexer.key_or_star(firstchar, value)]
    case other:
      ["*"]

# The keys of the first condition on the indexed field, or '*' without one.
def RuleIndexer.keys.conds(conds: List<&2, Y.Condition>, +name: String, +firstchar: Bool) -> List<&2, String>:
  match conds:
    case Nil{}:
      ["*"]
    case Con{Y.Cond{+op, field, +value, raw, unparsed, options, kind}, +t}:
      C.If(List<&2, String>, String.eq(field, name),
        u => RuleIndexer.keys.cond(op, RuleIndexer.plain(value), firstchar),
        u => RuleIndexer.keys.conds(t, name, firstchar))

# The keys of the sets `getIndexes(rule)` answers.
def RuleIndexer.keys(ix: RuleIndexer, rule: Y.Rule) -> List<&2, String>:
  match ix rule:
    case RuleIndexer{field, firstchar, buckets} Y.Rule{id, stage, conditions_op, conditions, actions}:
      RuleIndexer.keys.conds(conditions, field, firstchar)

def RuleIndexer.change(buckets: List<&2, RuleIndexer.Bucket>, +key: String, +rule: Y.Rule, +add: Bool) ->
  List<&2, RuleIndexer.Bucket>:
  match buckets:
    case Nil{}:
      [Bucket{key, Bool.pick(List<&2, Y.Rule>, add, [rule], Nil{})}]
    case Con{Bucket{+k, +rules}, +t}:
      C.If(List<&2, RuleIndexer.Bucket>, String.eq(k, key),
        u => Con{Bucket{k, Bool.pick(List<&2, Y.Rule>, add, RuleIndexer.add(rules, rule), RuleIndexer.del(rules, rule))}, t},
        u => Con{Bucket{k, rules}, RuleIndexer.change(t, key, rule, add)})

def RuleIndexer.change_all(keys: List<&2, String>, buckets: List<&2, RuleIndexer.Bucket>, +rule: Y.Rule, +add: Bool) ->
  List<&2, RuleIndexer.Bucket>:
  match keys:
    case Nil{}:
      buckets
    case Con{k, t}:
      RuleIndexer.change_all(t, RuleIndexer.change(buckets, k, rule, add), rule, add)

def RuleIndexer.update(+ix: RuleIndexer, +rule: Y.Rule, add: Bool) -> RuleIndexer:
  match ix:
    case RuleIndexer{field, firstchar, buckets}:
      RuleIndexer{field, firstchar, RuleIndexer.change_all(RuleIndexer.keys(ix, rule), buckets, rule, add)}

# `index(rule)`: files the rule under each of its keys.
def RuleIndexer.index(ix: RuleIndexer, rule: Y.Rule) -> RuleIndexer:
  RuleIndexer.update(ix, rule, True{})

# `remove(rule)`: takes the rule out from under each of its keys.
def RuleIndexer.remove(ix: RuleIndexer, rule: Y.Rule) -> RuleIndexer:
  RuleIndexer.update(ix, rule, False{})

def RuleIndexer.applicable(key: Maybe<&2, String>, +buckets: List<&2, RuleIndexer.Bucket>) -> List<&2, Y.Rule>:
  match key:
    case None{}:
      RuleIndexer.find(buckets, "*")
    case Some{k}:
      RuleIndexer.merge(RuleIndexer.find(buckets, "*"), RuleIndexer.find(buckets, k))

# `getApplicableRules(object)`: the rules filed under the object's value of
# the field, then those filed under '*'.
def RuleIndexer.get_applicable_rules(ix: RuleIndexer, object: List<&2, V.Field>) -> List<&2, Y.Rule>:
  match ix:
    case RuleIndexer{field, +firstchar, buckets}:
      RuleIndexer.applicable(RuleIndexer.key(firstchar, V.Txn.get(object, field)), buckets)

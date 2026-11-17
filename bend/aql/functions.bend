# What the AQL functions and operators compile to once their arguments are
# compiled: the `switch` of `compileFunction` and of `compileOp` in
# packages/loot-core/src/server/aql/compiler.ts.
#
# `$condition` and the `ORDER BY` of `$sumOver` compile more of the query, so
# they are in compiler.bend.
import Base
import ../json/json.bend as J
import ../lib/core.bend as C
import ./js.bend as V
import ./state.bend as A
import ./cast.bend as K
import ./normalise.bend as N

# `args[n]`; `undefined` never reaches a use after the argument count check.
def Fn.arg(+args: List<&2, A.Typed>, +n: Nat) -> A.Typed:
  Maybe.default(&2, A.Typed, List.get(&2, A.Typed, args, n), A.Typed.make("undefined", "undefined"))

# `xs[n]` in a template string.
def Fn.str(+xs: List<&2, String>, +n: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, xs, n), "undefined")

def Fn.kind(+args: List<&2, A.Typed>) -> String:
  A.Typed.kind(Fn.arg(args, 0n))

# `validateArgLength(args, min, max)`, then `valArray(state, args, kinds)`.
def Fn.with(
  +st: A.State, +args: List<&2, A.Typed>, +min: Nat, +max: Nat, +kinds: List<&2, String>,
  k: A.State -> List<&2, String> -> A.Res()
) -> A.Res():
  A.Res.then_texts(
    K.Cast.arity(st, List.length(&2, A.Typed, args), min, max, s => K.Cast.vals(args, s, kinds)), k)

def Fn.sum(+st: A.State, +args: List<&2, A.Typed>) -> A.Res():
  Fn.with(st, args, 1n, 1n, ["float"], s => xs =>
    A.Res.typed(s, A.Typed.make("SUM(" ++ Fn.str(xs, 0n) ++ ")", Fn.kind(args))))

def Fn.count(+st: A.State, +args: List<&2, A.Typed>) -> A.Res():
  Fn.with(st, args, 1n, 1n, [], s => xs =>
    A.Res.typed(s, A.Typed.make("COUNT(" ++ Fn.str(xs, 0n) ++ ")", "integer")))

def Fn.substr(+st: A.State, +args: List<&2, A.Typed>) -> A.Res():
  Fn.with(st, args, 2n, 3n, ["string", "integer", "integer"], s => +xs =>
    A.Res.typed(s, A.Typed.make(
      "SUBSTR(" ++ Fn.str(xs, 0n) ++ ", " ++ Fn.str(xs, 1n) ++ ", " ++ Fn.str(xs, 2n) ++ ")",
      "string")))

def Fn.lower(+st: A.State, +args: List<&2, A.Typed>) -> A.Res():
  Fn.with(st, args, 1n, 1n, ["string"], s => xs =>
    A.Res.typed(s, A.Typed.make("UNICODE_LOWER(" ++ Fn.str(xs, 0n) ++ ")", "string")))

def Fn.neg(+st: A.State, +args: List<&2, A.Typed>) -> A.Res():
  Fn.with(st, args, 1n, 1n, ["float"], s => xs =>
    A.Res.typed(s, A.Typed.make("(-" ++ A.Typed.sql(Fn.arg(args, 0n)) ++ ")", Fn.kind(args))))

def Fn.abs(+st: A.State, +args: List<&2, A.Typed>) -> A.Res():
  Fn.with(st, args, 1n, 1n, ["float"], s => xs =>
    A.Res.typed(s, A.Typed.make("ABS(" ++ A.Typed.sql(Fn.arg(args, 0n)) ++ ")", Fn.kind(args))))

def Fn.idiv(+st: A.State, +args: List<&2, A.Typed>) -> A.Res():
  Fn.with(st, args, 2n, 2n, ["integer", "integer"], s => xs =>
    A.Res.typed(s, A.Typed.make(
      "(" ++ A.Typed.sql(Fn.arg(args, 0n)) ++ " / " ++ A.Typed.sql(Fn.arg(args, 1n)) ++ ")",
      Fn.kind(args))))

def Fn.id(+st: A.State, +args: List<&2, A.Typed>) -> A.Res():
  K.Cast.arity(st, List.length(&2, A.Typed, args), 1n, 1n, s =>
    A.Res.typed(s, A.Typed.make(A.Typed.sql(Fn.arg(args, 0n)), Fn.kind(args))))

# `$day`, `$month` and `$year`: a cast.
def Fn.date(+st: A.State, +args: List<&2, A.Typed>, +kind: String) -> A.Res():
  K.Cast.arity(st, List.length(&2, A.Typed, args), 1n, 1n, s =>
    K.Cast.cast(s, Fn.arg(args, 0n), kind))

def Fn.nocase(+st: A.State, +args: List<&2, A.Typed>) -> A.Res():
  Fn.with(st, args, 1n, 1n, ["string"], s => xs =>
    A.Res.typed(s, A.Typed.make(Fn.str(xs, 0n) ++ " COLLATE NOCASE", Fn.kind(args))))

def Fn.literal(+st: A.State, +args: List<&2, A.Typed>) -> A.Res():
  K.Cast.arity(st, List.length(&2, A.Typed, args), 1n, 1n, +s =>
    C.If(A.Res(), A.Typed.literal(Fn.arg(args, 0n)),
      u => A.Res.typed(s, Fn.arg(args, 0n)),
      u => A.Res.throw(s, "Literal not passed to $literal")))

# The `switch (name)` of `compileFunction`, but for `$condition` and
# `$sumOver`.
def Fn.apply(+st: A.State, +name: String, +args: List<&2, A.Typed>) -> A.Res():
  match name:
    case "$sum":
      Fn.sum(st, args)
    case "$count":
      Fn.count(st, args)
    case "$substr":
      Fn.substr(st, args)
    case "$lower":
      Fn.lower(st, args)
    case "$neg":
      Fn.neg(st, args)
    case "$abs":
      Fn.abs(st, args)
    case "$idiv":
      Fn.idiv(st, args)
    case "$id":
      Fn.id(st, args)
    case "$day":
      Fn.date(st, args, "date")
    case "$month":
      Fn.date(st, args, "date-month")
    case "$year":
      Fn.date(st, args, "date-year")
    case "$nocase":
      Fn.nocase(st, args)
    case "$literal":
      Fn.literal(st, args)
    case other:
      A.Res.throw(st, "Unknown function: " ++ other)

# `$sumOver`, first half: `valArray(state, args, ['float'])[0]`.
def Fn.sum_over.arg(+st: A.State, +args: List<&2, A.Typed>) -> A.Res():
  A.Res.then_texts(K.Cast.vals(args, st, ["float"]), s => xs => A.Res.text(s, Fn.str(xs, 0n)))

# `$sumOver`, second half, with its `ORDER BY` clause compiled.
def Fn.sum_over(+st: A.State, +args: List<&2, A.Typed>, +arg: String, +order: String) -> A.Res():
  match args:
    case Nil{}:
      A.Res.type_error("Cannot read properties of undefined (reading 'type')")
    case Con{first, rest}:
      A.Res.typed(st, A.Typed.make(
        "(SUM(" ++ arg ++ ") OVER (" ++ order ++ " ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING))",
        A.Typed.kind(first)))

# Operators
# ---------

# `valArray(state, [lhs, rhs], [lk, rk])`, then the rest with left and right.
def Op.vals(
  +st: A.State, +lhs: A.Typed, +rhs: A.Typed, +lk: String, +rk: String,
  k: A.State -> String -> String -> A.Res()
) -> A.Res():
  A.Res.then_texts(K.Cast.vals([lhs, rhs], st, [lk, rk]), s => +xs =>
    k(s, Fn.str(xs, 0n), Fn.str(xs, 1n)))

# `$gte`, `$lte`, `$gt` and `$lt`.
def Op.compare(+st: A.State, +lhs: A.Typed, +rhs: A.Typed, +sign: String) -> A.Res():
  Op.vals(st, lhs, rhs, "", A.Typed.kind(lhs), s => l => r => A.Res.text(s, l ++ sign ++ r))

# The `CASE` of `$eq` and `$ne` against a parameter, which may be bound to
# null; `ne` is "NOT " for `$ne`.
def Op.case(+l: String, +r: String, +ne: String) -> String:
  "CASE\n          WHEN " ++ l ++ " IS NULL THEN " ++ r ++ " IS " ++ ne ++ "NULL\n          ELSE " ++
    l ++ Bool.pick(String, String.is_empty(ne), " = ", " IS NOT ") ++ r ++ "\n        END"

# The comparison of `$eq` (plain is `l = r`) and `$ne`. A parameter on the
# right is listed twice, once per `?` of the `CASE`.
def Op.equal.rest(+st: A.State, +lhs: A.Typed, +rhs: A.Typed, +ne: Bool) -> A.Res():
  Op.vals(st, lhs, rhs, "", A.Typed.kind(lhs), +s => +l => +r =>
    C.If(A.Res(), String.eq(A.Typed.kind(rhs), "param"),
      u => A.Res.text(A.State.dup_param(s, A.Typed.pid(rhs)),
        Op.case(l, r, Bool.pick(String, ne, "NOT ", ""))),
      u => A.Res.text(s, Bool.pick(String, ne,
        "(" ++ l ++ " != " ++ r ++ " OR " ++ l ++ " IS NULL)", l ++ " = " ++ r))))

# `$eq` and `$ne`.
def Op.equal(+st: A.State, +lhs: A.Typed, +rhs: A.Typed, +ne: Bool) -> A.Res():
  A.Res.then_typed(K.Cast.cast(st, rhs, A.Typed.kind(lhs)), +s => c =>
    C.If(A.Res(), String.eq(A.Typed.kind(c), "null"),
      u => A.Res.text(s, A.Typed.sql(lhs) ++ Bool.pick(String, ne, " IS NOT NULL", " IS NULL")),
      u => Op.equal.rest(s, lhs, rhs, ne)))

# What tells two values of a `Set` apart; empty for an array or an object,
# which is never the same as another.
def Op.key(+j: J.Json) -> String:
  match j:
    case J.JNull{}:
      "null"
    case J.JBool{b}:
      "b" ++ V.Js.string(j)
    case J.JInt{i}:
      "n" ++ V.Js.string(j)
    case J.JDec{t}:
      "n" ++ t
    case J.JStr{s}:
      "s" ++ s
    case other:
      ""

def Op.ids.seen(r: Set() & Bool, k: Set() -> Bool -> List<&2, String>) -> List<&2, String>:
  match r:
    case Tuple{seen, hit}:
      k(seen, hit)

def Op.ids.put(+id: String, +rest: List<&2, String>, +skip: Bool) -> List<&2, String>:
  match skip:
    case True{}:
      rest
    case False{}:
      id <> rest

# `[...new Set(values)].map(id => `'${String(id)}'`)`.
def Op.ids(+items: List<&2, J.Json>, +seen: Set()) -> List<&2, String>:
  match items:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Op.ids.seen(Set.has(seen, Op.key(h)), +s => +hit =>
        Op.ids.put("'" ++ V.Js.string(h) ++ "'",
          Op.ids(t, Set.add(s, Op.key(h))),
          Bool.and(hit, Bool.not(String.is_empty(Op.key(h))))))

def Op.chars(+s: String) -> List<&2, J.Json>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{c, t}:
      J.JStr{SCon{c, SNil{}}} <> Op.chars(t)

# The values of `new Set(right)`: the elements of an array, or the
# characters of a string.
def Op.items(+t: A.Typed) -> List<&2, J.Json>:
  match t:
    case A.Typed{value, kind, literal, pid, Some{arr}}:
      J.Json.items(arr)
    case A.Typed{value, kind, literal, pid, None{}}:
      Op.chars(value)

def Op.oneof(+st: A.State, +lhs: A.Typed, +rhs: A.Typed) -> A.Res():
  A.Res.then_typed(K.Cast.cast(st, rhs, "array"), s => c =>
    A.Res.text(s, A.Typed.sql(lhs) ++ " IN (" ++ String.join(Op.ids(Op.items(c), Set.new()), ",") ++ ")"))

def Op.like(+st: A.State, +lhs: A.Typed, +rhs: A.Typed, +not: Bool) -> A.Res():
  Op.vals(st, lhs, rhs, "string", "string", s => +l => +r =>
    A.Res.text(s, Bool.pick(String, not,
      "(NOT UNICODE_LIKE(" ++ N.Norm.string(r) ++ ", NORMALISE(" ++ l ++ "))\n OR " ++ l ++ " IS NULL)",
      "UNICODE_LIKE(" ++ N.Norm.string(r) ++ ", NORMALISE(" ++ l ++ "))")))

def Op.regexp(+st: A.State, +lhs: A.Typed, +rhs: A.Typed, +not: Bool) -> A.Res():
  Op.vals(st, lhs, rhs, "string", "string", s => +l => +r =>
    A.Res.text(s, Bool.pick(String, not,
      "(NOT REGEXP(" ++ r ++ ", " ++ l ++ ") OR " ++ l ++ " IS NULL)",
      "REGEXP(" ++ r ++ ", " ++ l ++ ")")))

# The `switch (op)` of `compileOp`.
def Op.apply(+st: A.State, +op: String, +lhs: A.Typed, +rhs: A.Typed) -> A.Res():
  match op:
    case "$gte":
      Op.compare(st, lhs, rhs, " >= ")
    case "$lte":
      Op.compare(st, lhs, rhs, " <= ")
    case "$gt":
      Op.compare(st, lhs, rhs, " > ")
    case "$lt":
      Op.compare(st, lhs, rhs, " < ")
    case "$eq":
      Op.equal(st, lhs, rhs, False{})
    case "$ne":
      Op.equal(st, lhs, rhs, True{})
    case "$oneof":
      Op.oneof(st, lhs, rhs)
    case "$like":
      Op.like(st, lhs, rhs, False{})
    case "$notlike":
      Op.like(st, lhs, rhs, True{})
    case "$regexp":
      Op.regexp(st, lhs, rhs, False{})
    case "$notregexp":
      Op.regexp(st, lhs, rhs, True{})
    case other:
      A.Res.throw(st, "Unknown operator: " ++ other)

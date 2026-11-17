# The AQL compiler: packages/loot-core/src/server/aql/compiler.ts. It turns
# a query state into SQL text.
#
# Deviations:
# - `compileExpr`, `compileFunction`, `compileOp`, `compileConditions`,
#   `compileAnd`, `compileOr` and `compileOrderBy` call each other, and Bend
#   has no mutual recursion, so they are the modes of one def, `Aql.go`,
#   which also holds their loops and counts down fuel on each call.
# - A thrown `CompileError` is a `Fail` with the same message, expression
#   stack included (`A.Err.show`). Where the TS code would crash on a
#   malformed query with a JS `TypeError`, the result is a `Fail` whose
#   message starts with "TypeError: "; the wording after it is not V8's.
# - The schema config is data (see types.bend), and `Date` and `undefined`
#   query values do not exist in JSON.
import Base
import ../json/json.bend as J
import ../lib/core.bend as C
import ./js.bend as V
import ./types.bend as S
import ./state.bend as A
import ./cast.bend as K
import ./paths.bend as P
import ./functions.bend as F
import ./query.bend as Q
import ./schema.bend as M

def Aql.is_keyword(+s: String) -> Bool:
  String.eq(s, "group")

# `quoteAlias(alias)`.
def Aql.quote_alias(+alias: String) -> String:
  Bool.pick(String, Bool.or(String.contains(alias, "."), Aql.is_keyword(alias)),
    "\"" ++ alias ++ "\"", alias)

# `appendWhere(whereStr, condition)`.
def Aql.append_where(+cond: String, +condition: String) -> String:
  Bool.pick(String, String.is_empty(cond), "WHERE " ++ condition, cond ++ " AND " ++ condition)

# `addTombstone(schema, tableName, tableId, whereStr)` for a table that
# has, or has not, a tombstone field.
def Aql.tombstone(+has: Bool, +id: String, +cond: String) -> String:
  match has:
    case False{}:
      cond
    case True{}:
      Aql.append_where(cond, id ++ ".tombstone = 0")

# Expressions
# -----------

# `Object.keys(expr).find(k => k[0] === '$')`.
def Aql.has_dollar(+cells: J.Json) -> Bool:
  match cells:
    case J.JPair{k, v, rest}:
      Bool.or(String.starts_with(k, "$"), Aql.has_dollar(rest))
    case other:
      False{}

# What an expression is: 0 a field reference, 1 a named parameter, 2 a
# function call, 3 a literal.
def Aql.expr.class(+j: J.Json) -> U32:
  match j:
    case J.JStr{SCon{'$', t}}:
      0
    case J.JStr{SCon{':', t}}:
      1
    case J.JObj{cells}:
      Bool.pick(U32, Aql.has_dollar(cells), 2, 3)
    case other:
      3

def Aql.field_ref.at(+env: A.Env, +st: A.State, +expr: String, +m: Maybe<&2, String>) -> A.Res():
  match m:
    case None{}:
      A.Res.throw(st, "Invalid field reference: " ++ expr)
    case Some{SNil{}}:
      A.Res.throw(st, "Invalid field reference: " ++ expr)
    case Some{name}:
      P.Paths.field(env, st, name)

# A `$field` expression; `$` alone is the implicit field.
def Aql.field_ref(+env: A.Env, +st: A.State, +expr: String) -> A.Res():
  Aql.field_ref.at(env, st, expr,
    Bool.pick(Maybe<&2, String>, String.eq(expr, "$"), A.Env.field(env), Some{String.drop(expr, 1n)}))

# The body of `compileExpr`; `call` compiles the expression as a function.
def Aql.expr(+class: U32, +env: A.Env, +st: A.State, +a: J.Json, call: A.State -> A.Res()) -> A.Res():
  match class:
    case 0:
      Aql.field_ref(env, st, V.Js.text(a))
    case 1:
      Done{A.State.add_param(st, String.drop(V.Js.text(a), 1n))}
    case 2:
      call(st)
    case other:
      K.Cast.literal(st, a)

# Functions
# ---------

# The name of a function call and the cells of its argument expressions.
type Call is Data:
  Call{name: String, args: J.Json}

# `Array.isArray(argExprs) ? argExprs : [argExprs]`, as cells.
def Aql.cells(+v: J.Json) -> J.Json:
  match v:
    case J.JArr{cells}:
      cells
    case other:
      J.JElem{other, J.JEnd{}}

# `const [name] = Object.keys(func)` and `func[name]`.
def Aql.call(+j: J.Json) -> Maybe<&2, Call>:
  match j:
    case J.JObj{J.JPair{name, value, rest}}:
      Some{Call{name, Aql.cells(Maybe.default(&2, J.Json, J.Json.get(j, name), value))}}
    case J.JArr{J.JElem{v, rest}}:
      Some{Call{"0", Aql.cells(v)}}
    case other:
      None{}

# How a function compiles: 1 `$condition`, 2 `$sumOver`, 0 the others.
def Aql.func.class(+name: String) -> U32:
  match name:
    case "$condition":
      1
    case "$sumOver":
      2
    case other:
      0

# The head of `compileFunction`: the call's name, argument cells and class.
def Aql.func(
  +st: A.State, +call: Maybe<&2, Call>, k: A.State -> String -> J.Json -> U32 -> A.Res()
) -> A.Res():
  match call:
    case None{}:
      A.Res.type_error("Cannot read properties of undefined (reading '0')")
    case Some{Call{name, args}}:
      C.If(A.Res(), String.starts_with(name, "$"),
        u => k(st, name, args, Aql.func.class(name)),
        u => A.Res.throw(st, "Unknown property \"" ++ name ++
          ".\" Did you mean to call a function? Try prefixing it with $"))

def Aql.func.route(
  +class: U32, +st: A.State, plain: A.State -> A.Res(), cond: A.State -> A.Res(),
  over: A.State -> A.Res()
) -> A.Res():
  match class:
    case 1:
      cond(st)
    case 2:
      over(st)
    case other:
      plain(st)

def Aql.count(+cells: J.Json) -> Nat:
  match cells:
    case J.JElem{v, rest}:
      1n+Aql.count(rest)
    case other:
      0n

def Aql.first(+cells: J.Json) -> J.Json:
  match cells:
    case J.JElem{v, rest}:
      v
    case other:
      J.JNull{}

# `$condition`: one argument, left as it is for `compileConditions`.
def Aql.condition(+st: A.State, +args: J.Json, k: A.State -> J.Json -> A.Res()) -> A.Res():
  K.Cast.arity(st, Aql.count(args), 1n, 1n, s => k(s, Aql.first(args)))

# `state.orders ? 'ORDER BY ' + compileOrderBy(state, state.orders) : ''`.
def Aql.over_order(+orders: Maybe<&2, J.Json>, +st: A.State, run: J.Json -> A.State -> A.Res()) ->
  A.Res():
  match orders:
    case None{}:
      A.Res.text(st, "")
    case Some{o}:
      A.Res.then_text(run(o, st), s => x => A.Res.text(s, "ORDER BY " ++ x))

# The next cell of a chain of elements.
def Aql.each(
  +cells: J.Json, +st: A.State, nil: A.State -> A.Res(),
  cons: J.Json -> J.Json -> A.State -> A.Res()
) -> A.Res():
  match cells:
    case J.JElem{v, rest}:
      cons(v, rest, st)
    case other:
      nil(st)

# The next cell of a chain of members.
def Aql.pair(
  +cells: J.Json, +st: A.State, nil: A.State -> A.Res(),
  cons: String -> J.Json -> J.Json -> A.State -> A.Res()
) -> A.Res():
  match cells:
    case J.JPair{k, v, rest}:
      cons(k, v, rest, st)
    case other:
      nil(st)

# Operators
# ---------

# `opData` taken apart: `$transform` when truthy, the first other key, and
# its value.
type OpParts is Data:
  OpParts{transform: Maybe<&2, J.Json>, op: Maybe<&2, String>, rhs: Maybe<&2, J.Json>}

def Aql.op.truthy(+m: Maybe<&2, J.Json>) -> Maybe<&2, J.Json>:
  match m:
    case None{}:
      None{}
    case Some{j}:
      Bool.pick(Maybe<&2, J.Json>, V.Js.truthy(j), Some{j}, None{})

# The first member that is not `$transform`.
def Aql.op.first(+ms: List<&2, J.Json.Member>) -> Maybe<&2, J.Json.Member>:
  match ms:
    case Nil{}:
      None{}
    case Con{J.Member{k, v}, rest}:
      Bool.pick(Maybe<&2, J.Json.Member>, String.eq(k, "$transform"),
        Aql.op.first(rest), Some{J.Member{k, v}})

def Aql.op.parts.of(+b: J.Json, +first: Maybe<&2, J.Json.Member>) -> OpParts:
  match first:
    case None{}:
      OpParts{Aql.op.truthy(J.Json.get(b, "$transform")), None{}, None{}}
    case Some{J.Member{k, v}}:
      OpParts{Aql.op.truthy(J.Json.get(b, "$transform")), Some{k},
        Some{Maybe.default(&2, J.Json, J.Json.get(b, k), v)}}

def Aql.op.parts(+b: J.Json) -> OpParts:
  Aql.op.parts.of(b, Aql.op.first(V.Js.entries(b)))

def Aql.op.name(+p: OpParts) -> String:
  match p:
    case OpParts{transform, op, rhs}:
      Maybe.default(&2, String, op, "undefined")

# `const {$transform, ...opExpr} = opData`.
def Aql.op.start(+st: A.State, +b: J.Json, k: A.State -> OpParts -> A.Res()) -> A.Res():
  match b:
    case J.JNull{}:
      A.Res.type_error("Cannot destructure 'opData' as it is null.")
    case other:
      k(st, Aql.op.parts(b))

# `compileExpr(state, opData[op])`; with no operator the value is
# `undefined`.
def Aql.op.rhs(+st: A.State, +p: OpParts, run: J.Json -> A.State -> A.Res()) -> A.Res():
  match p:
    case OpParts{transform, op, None{}}:
      A.Res.throw(A.State.push(st, A.Frame{"expr", None{}, J.JNull{}}),
        "`undefined` is not a valid query value")
    case OpParts{transform, op, Some{j}}:
      run(j, st)

# The left side: the field, or `$transform` applied to it.
def Aql.op.lhs(
  +st: A.State, +p: OpParts, +field: String, plain: J.Json -> A.State -> A.Res(),
  func: J.Json -> A.State -> A.Res()
) -> A.Res():
  match p:
    case OpParts{None{}, op, rhs}:
      plain(J.JStr{"$" ++ field}, st)
    case OpParts{Some{J.JStr{name}}, op, rhs}:
      func(V.Js.single(name, J.JStr{"$"}), st)
    case OpParts{Some{t}, op, rhs}:
      func(t, st)

# Conditions
# ----------

def Aql.conds.items(+items: List<&2, J.Json>) -> List<&2, J.Json.Member>:
  match items:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      List.append(&2, J.Json.Member,
        Bool.pick(List<&2, J.Json.Member>, V.Js.truthy(h), V.Js.entries(h), Nil{}),
        Aql.conds.items(t))

# Every `[field, cond]` of the conditions, in order: of each truthy object
# of an array, or of the one object.
def Aql.conds.pairs(+a: J.Json) -> List<&2, J.Json.Member>:
  match a:
    case J.JArr{cells}:
      Aql.conds.items(J.Json.items(a))
    case other:
      V.Js.entries(a)

def Aql.conds(+st: A.State, +a: J.Json, k: A.State -> J.Json -> A.Res()) -> A.Res():
  match a:
    case J.JNull{}:
      A.Res.type_error("Cannot convert undefined or null to object")
    case other:
      k(st, J.Json.pairs(Aql.conds.pairs(a)))

def Aql.is_empty_array(+j: J.Json) -> Bool:
  match j:
    case J.JArr{J.JEnd{}}:
      True{}
    case other:
      False{}

def Aql.cond.value(+cond: J.Json) -> U32:
  match cond:
    case J.JArr{cells}:
      4
    case J.JObj{cells}:
      5
    case other:
      3

# How a `[field, cond]` compiles: 0 not at all, 1 `$and`, 2 `$or`, 3 an
# equality with a primitive, 4 each operator of an array, 5 one operator.
def Aql.cond.class(+field: String, +cond: J.Json) -> U32:
  match field:
    case "$and":
      Bool.pick(U32, V.Js.truthy(cond), 1, 0)
    case "$or":
      Bool.pick(U32, Bool.and(V.Js.truthy(cond), Bool.not(Aql.is_empty_array(cond))), 2, 0)
    case other:
      Aql.cond.value(cond)

def Aql.one(r: A.Res()) -> A.Res():
  A.Res.then_text(r, s => x => A.Res.texts(s, [x]))

# `cond.map(..).join(' AND ')`, dropped when empty.
def Aql.joined(r: A.Res()) -> A.Res():
  A.Res.then_texts(r, s => +xs =>
    A.Res.texts(s, Bool.pick(List<&2, String>, List.is_empty(&2, String, xs), Nil{},
      [String.join(xs, " AND ")])))

# The strings one `[field, cond]` adds to the conditions.
def Aql.cond(
  +class: U32, +st: A.State, and: A.State -> A.Res(), or: A.State -> A.Res(),
  eq: A.State -> A.Res(), all: A.State -> A.Res(), op: A.State -> A.Res()
) -> A.Res():
  match class:
    case 1:
      Aql.one(and(st))
    case 2:
      Aql.one(or(st))
    case 3:
      Aql.one(eq(st))
    case 4:
      Aql.joined(all(st))
    case 5:
      Aql.one(op(st))
    case other:
      A.Res.texts(st, Nil{})

def Aql.is_true(+j: J.Json) -> Bool:
  match j:
    case J.JBool{b}:
      b
    case other:
      False{}

# The text of `compileAnd` (and = true) or `compileOr` for its conditions.
def Aql.group(+xs: List<&2, String>, +and: Bool) -> String:
  match xs:
    case Nil{}:
      Bool.pick(String, and, "1", "0")
    case other:
      "(" ++ String.join(other, Bool.pick(String, and, "\n  AND ", "\n  OR ")) ++ ")"

# Orders
# ------

# An order expression: kind 0 orders by a field expression, 1 by a
# function, 2 is a crash; `dir` is null when there is none.
type OrderPlan is Data:
  OrderPlan{kind: U32, target: J.Json, dir: J.Json}

def Aql.order.no_dir(+ms: List<&2, J.Json.Member>) -> List<&2, J.Json.Member>:
  match ms:
    case Nil{}:
      Nil{}
    case Con{J.Member{k, v}, rest}:
      List.append(&2, J.Json.Member,
        Bool.pick(List<&2, J.Json.Member>, String.eq(k, "$dir"), Nil{}, [J.Member{k, v}]),
        Aql.order.no_dir(rest))

# `const {$dir, ...func} = expr`.
def Aql.order.func(+e: J.Json) -> OrderPlan:
  OrderPlan{1, J.Json.object(Aql.order.no_dir(J.Json.members(e))),
    Maybe.default(&2, J.Json, J.Json.get(e, "$dir"), J.JNull{})}

def Aql.order.entries(+e: J.Json, +entries: List<&2, J.Json.Member>) -> OrderPlan:
  match entries:
    case Con{J.Member{k, v}, Nil{}}:
      Bool.pick(OrderPlan, String.starts_with(k, "$"), Aql.order.func(e),
        OrderPlan{0, J.JStr{"$" ++ k}, v})
    case other:
      Aql.order.func(e)

def Aql.order.plan(+e: J.Json) -> OrderPlan:
  match e:
    case J.JStr{s}:
      OrderPlan{0, J.JStr{"$" ++ s}, J.JNull{}}
    case J.JNull{}:
      OrderPlan{2, J.JNull{}, J.JNull{}}
    case other:
      Aql.order.entries(e, V.Js.entries(e))

# The compiled order with its direction.
def Aql.order.dir(+st: A.State, +compiled: String, +dir: J.Json) -> A.Res():
  match dir:
    case J.JNull{}:
      A.Res.text(st, compiled)
    case J.JStr{"desc"}:
      A.Res.text(st, compiled ++ " desc")
    case J.JStr{"asc"}:
      A.Res.text(st, compiled ++ " asc")
    case other:
      A.Res.throw(st, "Invalid order direction: " ++ V.Js.string(dir))

def Aql.order(
  +plan: OrderPlan, +st: A.State, expr: J.Json -> A.State -> A.Res(),
  func: J.Json -> A.State -> A.Res()
) -> A.Res():
  match plan:
    case OrderPlan{0, target, dir}:
      A.Res.then_typed(expr(target, st), s => t => Aql.order.dir(s, A.Typed.value(t), dir))
    case OrderPlan{1, target, dir}:
      A.Res.then_typed(func(target, st), s => t => Aql.order.dir(s, A.Typed.value(t), dir))
    case other:
      A.Res.type_error("Cannot convert undefined or null to object")

# The compiler's recursion
# ------------------------

# Modes: 0 `compileExpr(a)`; 1 `compileFunction(a)`; 2 the expressions in
# the cells a; 3 `compileOp(a, b)` with a the field name; 4
# `compileConditions(a)`; 5 the `[field, cond]` members in the cells a; 6
# `compileOp(b, c)` for each c in the cells a; 8 `compileAnd(a)` when b is
# true, else `compileOr(a)`; 10 `compileOrderBy(a)`; 11 the orders in the
# cells a. Each call spends one unit of fuel, which bounds the depth.
def Aql.go(+fuel: Nat, mode: U32, +env: A.Env, +st: A.State, +a: J.Json, +b: J.Json) -> A.Res():
  match fuel mode:
    case 0n _:
      A.Res.plain("RangeError: Maximum call stack size exceeded")
    case 1n+f 0:
      A.Res.framed(st, A.Frame{"expr", Some{a}, J.JNull{}}, s0 =>
        Aql.expr(Aql.expr.class(a), env, s0, a, s1 => Aql.go(f, 1, env, s1, a, J.JNull{})))
    case 1n+f 1:
      A.Res.framed(st, A.Frame{"function", Some{a}, J.JNull{}}, s0 =>
        Aql.func(s0, Aql.call(a), s1 => +name => +args => class =>
          Aql.func.route(class, s1,
            s2 => A.Res.then_typeds(Aql.go(f, 2, env, s2, args, J.JNull{}), s3 => ts =>
              F.Fn.apply(s3, name, ts)),
            s2 => Aql.condition(s2, args, s3 => c =>
              A.Res.then_texts(Aql.go(f, 4, env, s3, c, J.JNull{}), s4 => xs =>
                A.Res.typed(s4, A.Typed.make(String.join(xs, " AND "), "boolean")))),
            s2 => A.Res.then_typeds(Aql.go(f, 2, env, s2, args, J.JNull{}), s3 => +ts =>
              A.Res.then_text(F.Fn.sum_over.arg(s3, ts), s4 => +arg =>
                A.Res.then_text(
                  Aql.over_order(A.Env.orders(env), s4, o => s5 => Aql.go(f, 10, env, s5, o, J.JNull{})),
                  s6 => order => F.Fn.sum_over(s6, ts, arg, order)))))))
    case 1n+f 2:
      Aql.each(a, st, s => A.Res.typeds(s, Nil{}), v => rest => s =>
        A.Res.then_typed(Aql.go(f, 0, env, s, v, J.JNull{}), s1 => t =>
          A.Res.then_typeds(Aql.go(f, 2, env, s1, rest, J.JNull{}), s2 => ts =>
            A.Res.typeds(s2, t <> ts))))
    case 1n+f 3:
      A.Res.framed(st, A.Frame{"op", Some{a}, b}, s0 =>
        Aql.op.start(s0, b, s1 => +p =>
          A.Res.then_typed(Aql.op.rhs(s1, p, j => s => Aql.go(f, 0, env, s, j, J.JNull{})),
            s2 => +rhs =>
              A.Res.then_typed(
                Aql.op.lhs(s2, p, V.Js.text(a),
                  j => s => Aql.go(f, 0, env, s, j, J.JNull{}),
                  j => s => A.Res.scoped(s, s3 =>
                    Aql.go(f, 1, A.Env.with_field(env, V.Js.text(a)), s3, j, J.JNull{}))),
                s4 => lhs => F.Op.apply(s4, Aql.op.name(p), lhs, rhs)))))
    case 1n+f 4:
      Aql.conds(st, a, s => cells => Aql.go(f, 5, env, s, cells, J.JNull{}))
    case 1n+f 5:
      Aql.pair(a, st, s => A.Res.texts(s, Nil{}), +field => +cond => rest => s =>
        A.Res.then_texts(
          Aql.cond(Aql.cond.class(field, cond), s,
            s1 => Aql.go(f, 8, env, s1, cond, J.JBool{True{}}),
            s1 => Aql.go(f, 8, env, s1, cond, J.JBool{False{}}),
            s1 => Aql.go(f, 3, env, s1, J.JStr{field}, V.Js.single("$eq", cond)),
            s1 => Aql.go(f, 6, env, s1, Aql.cells(cond), J.JStr{field}),
            s1 => Aql.go(f, 3, env, s1, J.JStr{field}, cond)),
          s2 => xs => A.Res.then_texts(Aql.go(f, 5, env, s2, rest, J.JNull{}), s3 => ys =>
            A.Res.texts(s3, List.append(&2, String, xs, ys)))))
    case 1n+f 6:
      Aql.each(a, st, s => A.Res.texts(s, Nil{}), c => rest => s =>
        A.Res.then_text(Aql.go(f, 3, env, s, b, c), s1 => x =>
          A.Res.then_texts(Aql.go(f, 6, env, s1, rest, b), s2 => xs =>
            A.Res.texts(s2, x <> xs))))
    case 1n+f 8:
      C.If(A.Res(), V.Js.truthy(a),
        u => A.Res.then_texts(Aql.go(f, 4, env, st, a, J.JNull{}), s => xs =>
          A.Res.text(s, Aql.group(xs, Aql.is_true(b)))),
        u => A.Res.text(st, Aql.group(Nil{}, Aql.is_true(b))))
    case 1n+f 10:
      A.Res.framed(st, A.Frame{"orderBy", Some{a}, J.JNull{}}, s0 =>
        A.Res.then_texts(Aql.go(f, 11, env, s0, Aql.cells(a), J.JNull{}), s1 => xs =>
          A.Res.text(s1, String.join(xs, ", "))))
    case 1n+f 11:
      Aql.each(a, st, s => A.Res.texts(s, Nil{}), e => rest => s =>
        A.Res.then_text(
          Aql.order(Aql.order.plan(e), s,
            j => s1 => Aql.go(f, 0, env, s1, j, J.JNull{}),
            j => s1 => Aql.go(f, 1, env, s1, j, J.JNull{})),
          s2 => x => A.Res.then_texts(Aql.go(f, 11, env, s2, rest, J.JNull{}), s3 => xs =>
            A.Res.texts(s3, x <> xs))))
    case 1n+f _:
      A.Res.bug()

# The depth a query may nest to; a long list counts one per element.
def Aql.fuel() -> Nat:
  1000000n

def Aql.run(+mode: U32, +env: A.Env, +st: A.State, +a: J.Json, +b: J.Json) -> A.Res():
  Aql.go(Aql.fuel(), mode, env, st, a, b)

# `compileExpr(state, '$' + field)`.
def Aql.field_expr(+env: A.Env, +st: A.State, +field: String) -> A.Res():
  Aql.run(0, env, st, J.JStr{"$" ++ field}, J.JNull{})

# Table references
# ----------------

# What `tableRef` closes over: the config, `withDead` and `tableOptions`.
type Refs is Data:
  Refs{cfg: S.Config, with_dead: Bool, options: J.Json}

# `view || name`.
def Aql.view(+view: Maybe<&2, J.Json>, +name: String) -> String:
  match view:
    case Some{J.JStr{SCon{c, t}}}:
      SCon{c, t}
    case other:
      name

# `tableRef(name, isJoin)`.
def Aql.table_ref(+r: Refs, +name: String, +is_join: Bool) -> String:
  match r:
    case Refs{cfg, with_dead, options}:
      C.If(String, S.Config.actual_views(cfg),
        u => M.Actual.table_view(name, with_dead, is_join, options),
        u => Aql.view(J.Json.get(S.Config.views(cfg), name), name))

def Aql.refs.cfg(+r: Refs) -> S.Config:
  match r:
    case Refs{cfg, with_dead, options}:
      cfg

# The first complaint about the internal filters in the cells.
def Aql.filters.check(+cells: J.Json) -> Maybe<&2, String>:
  match cells:
    case J.JElem{J.JArr{c}, rest}:
      Some{"Invalid internal table filter: only object filters are supported"}
    case J.JElem{J.JObj{J.JPair{k, v, more}}, rest}:
      Bool.pick(Maybe<&2, String>, String.contains(k, "."),
        Some{"Invalid internal table filter: field names cannot contain paths"},
        Aql.filters.check(rest))
    case J.JElem{other, rest}:
      Aql.filters.check(rest)
    case other:
      None{}

def Aql.filters.at(
  +st: A.State, +filters: J.Json, +bad: Maybe<&2, String>, k: A.State -> J.Json -> A.Res()
) -> A.Res():
  match bad:
    case Some{msg}:
      A.Res.throw(st, msg)
    case None{}:
      k(st, filters)

# `internalTableFilters(name)`: the table's filters, an array.
def Aql.filters(+st: A.State, +cfg: S.Config, +name: String, k: A.State -> J.Json -> A.Res()) ->
  A.Res():
  Aql.filters.at(st, S.Config.filters(cfg, name),
    Aql.filters.check(Aql.cells(S.Config.filters(cfg, name))), k)

# Select
# ------

# `compiled.value + ' AS ' + quoteAlias(name)`, with the output type set.
def Aql.select.as(+name: String, r: A.Res()) -> A.Res():
  A.Res.then_typed(r, s => +t =>
    A.Res.text(A.State.set_type(s, name, A.Typed.kind(t)),
      A.Typed.value(t) ++ " AS " ++ Aql.quote_alias(name)))

# The field `field` selected as `name`.
def Aql.select.field(+env: A.Env, +st: A.State, +name: String, +field: String) -> A.Res():
  Aql.select.as(name, Aql.field_expr(env, st, field))

def Aql.select.fields(+fields: List<&2, String>, +env: A.Env, +st: A.State) -> A.Res():
  match fields:
    case Nil{}:
      A.Res.texts(st, Nil{})
    case Con{f, rest}:
      A.Res.then_text(Aql.select.field(env, st, f, f), s => x =>
        A.Res.then_texts(Aql.select.fields(rest, env, s), s2 => xs => A.Res.texts(s2, x <> xs)))

# `*` or `path.*`: every field of the table.
def Aql.select.star(+env: A.Env, +st: A.State, +expr: String) -> A.Res():
  A.Res.then_texts(P.Paths.star(env, st, expr), s => fields =>
    A.Res.then_texts(Aql.select.fields(fields, env, s), s2 => xs =>
      A.Res.text(s2, String.join(xs, ", "))))

# A function selected as `name`, compiled on `{...state, orders}`.
def Aql.select.func(+env: A.Env, +st: A.State, +name: String, +value: J.Json, +orders: J.Json) ->
  A.Res():
  Aql.select.as(name, A.Res.scoped(st, s =>
    Aql.run(1, A.Env.with_orders(env, orders), s, value, J.JNull{})))

def Aql.select.value(+env: A.Env, +st: A.State, +name: String, +value: J.Json, +orders: J.Json) ->
  A.Res():
  match value:
    case J.JStr{field}:
      Aql.select.field(env, st, name, field)
    case other:
      Aql.select.func(env, st, name, value, orders)

# `{name: value}`.
def Aql.select.named(
  +env: A.Env, +st: A.State, +expr: J.Json, +orders: J.Json, +first: Maybe<&2, J.Json.Member>
) -> A.Res():
  match first:
    case None{}:
      A.Res.type_error("undefined is not iterable")
    case Some{J.Member{name, value}}:
      C.If(A.Res(), String.starts_with(name, "$"),
        u => A.Res.throw(A.State.push(st, A.Frame{"value", Some{expr}, J.JNull{}}),
          "Invalid field \"" ++ name ++
            "\", are you trying to select a function? You need to name the expression"),
        u => Aql.select.value(env, st, name, value, orders))

def Aql.select.one(+env: A.Env, +st: A.State, +expr: J.Json, +orders: J.Json) -> A.Res():
  match expr:
    case J.JStr{s}:
      C.If(A.Res(), String.contains(s, "*"),
        u => Aql.select.star(env, st, s),
        u => Aql.select.field(env, st, s, s))
    case J.JNull{}:
      A.Res.type_error("Cannot convert undefined or null to object")
    case other:
      Aql.select.named(env, st, expr, orders, List.head(&2, J.Json.Member, V.Js.entries(expr)))

def Aql.select.go(+exprs: List<&2, J.Json>, +env: A.Env, +st: A.State, +orders: J.Json) -> A.Res():
  match exprs:
    case Nil{}:
      A.Res.texts(st, Nil{})
    case Con{e, rest}:
      A.Res.then_text(Aql.select.one(env, st, e, orders), s => x =>
        A.Res.then_texts(Aql.select.go(rest, env, s, orders), s2 => xs => A.Res.texts(s2, x <> xs)))

# `exprs.includes(name)`.
def Aql.select.has(+exprs: List<&2, J.Json>, +name: String) -> Bool:
  match exprs:
    case Nil{}:
      False{}
    case Con{J.JStr{s}, rest}:
      Bool.or(String.eq(s, name), Aql.select.has(rest, name))
    case Con{other, rest}:
      Aql.select.has(rest, name)

# The id is always selected, unless the query aggregates.
def Aql.select.with_id(+exprs: List<&2, J.Json>, +aggregate: Bool) -> List<&2, J.Json>:
  Bool.pick(List<&2, J.Json>,
    Bool.or(aggregate, Bool.or(Aql.select.has(exprs, "id"), Aql.select.has(exprs, "*"))),
    exprs, List.append(&2, J.Json, exprs, [J.JStr{"id"}]))

# `compileSelect(state, exprs, isAggregate, orders)`.
def Aql.select(
  +env: A.Env, +st: A.State, +exprs: List<&2, J.Json>, +aggregate: Bool, +orders: J.Json
) -> A.Res():
  A.Res.framed(st, A.Frame{"select", Some{J.Json.array(exprs)}, J.JNull{}}, s =>
    A.Res.then_texts(Aql.select.go(Aql.select.with_id(exprs, aggregate), env, s, orders),
      s2 => xs => A.Res.text(s2, String.join(xs, ", "))))

# Group by, where, order by
# -------------------------

def Aql.group_by.one(+env: A.Env, +st: A.State, +expr: J.Json) -> A.Res():
  match expr:
    case J.JStr{s}:
      Aql.field_expr(env, st, s)
    case other:
      Aql.run(1, env, st, expr, J.JNull{})

def Aql.group_by.go(+exprs: List<&2, J.Json>, +env: A.Env, +st: A.State) -> A.Res():
  match exprs:
    case Nil{}:
      A.Res.texts(st, Nil{})
    case Con{e, rest}:
      A.Res.then_typed(Aql.group_by.one(env, st, e), s => t =>
        A.Res.then_texts(Aql.group_by.go(rest, env, s), s2 => xs =>
          A.Res.texts(s2, A.Typed.value(t) <> xs)))

# `compileGroupBy(state, exprs)`.
def Aql.group_by(+env: A.Env, +st: A.State, +exprs: List<&2, J.Json>) -> A.Res():
  A.Res.framed(st, A.Frame{"groupBy", Some{J.Json.array(exprs)}, J.JNull{}}, s =>
    A.Res.then_texts(Aql.group_by.go(exprs, env, s), s2 => xs =>
      A.Res.text(s2, String.join(xs, ", "))))

def Aql.where.text(+xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case other:
      "(" ++ String.join(other, "\n  AND ") ++ ")"

# `compileWhere(state, conds)`; empty for null.
def Aql.where(+env: A.Env, +st: A.State, +conds: List<&2, J.Json>) -> A.Res():
  A.Res.framed(st, A.Frame{"filter", Some{J.Json.array(conds)}, J.JNull{}}, s =>
    A.Res.then_texts(Aql.run(4, env, s, J.Json.array(conds), J.JNull{}), s2 => xs =>
      A.Res.text(s2, Aql.where.text(xs))))

# `compileOrderBy(state, exprs)`.
def Aql.order_by(+env: A.Env, +st: A.State, +exprs: List<&2, J.Json>) -> A.Res():
  Aql.run(10, env, st, J.Json.array(exprs), J.JNull{})

# Joins
# -----

# The `ON` condition of a path's join: the ids, and the joined table's
# internal filters compiled with that table as the implicit one.
def Aql.join.on(+env: A.Env, +refs: Refs, +st: A.State, +p: A.Path, +filters: J.Json) -> A.Res():
  match p:
    case A.Path{key, table, id, field, join}:
      C.If(A.Res(), Aql.is_empty_array(filters),
        u => A.Res.text(st,
          id ++ ".id = " ++ Aql.table_ref(refs, join, False{}) ++ "." ++ Aql.quote_alias(field)),
        u => A.Res.then_text(
          A.Res.scoped(st, s =>
            Aql.run(8, A.Env.with_table(env, table, id), s, filters, J.JBool{True{}})),
          s2 => x => A.Res.text(s2,
            id ++ ".id = " ++ Aql.table_ref(refs, join, False{}) ++ "." ++ Aql.quote_alias(field) ++
              " AND " ++ x)))

def Aql.join.line(+refs: Refs, +st: A.State, +p: A.Path, +on: String, +t: Maybe<&2, S.Table>) ->
  A.Res():
  match t:
    case None{}:
      A.Res.type_error("Cannot read properties of undefined (reading 'tombstone')")
    case Some{table}:
      A.Res.text(st, "LEFT JOIN " ++ Aql.table_ref(refs, A.Path.table(p), True{}) ++ " " ++
        A.Path.id(p) ++ " ON " ++ Aql.tombstone(S.Table.has(table, "tombstone"), A.Path.id(p), on))

# One `LEFT JOIN` line.
def Aql.join(+env: A.Env, +refs: Refs, +st: A.State, +p: A.Path) -> A.Res():
  Aql.filters(st, Aql.refs.cfg(refs), A.Path.table(p), s => fs =>
    A.Res.then_text(Aql.join.on(env, refs, s, p, fs), s2 => on =>
      Aql.join.line(refs, s2, p, on, S.Schema.table(A.Env.schema(env), A.Path.table(p)))))

def Aql.joins.at(
  +p: Maybe<&2, A.Path>, +st: A.State, more: A.Path -> A.State -> A.Res()
) -> A.Res():
  match p:
    case None{}:
      A.Res.texts(st, Nil{})
    case Some{path}:
      more(path, st)

# The join of each path from the i-th on. A join's filters may add paths,
# which are joined too, as `Map.forEach` visits entries added on the way.
def Aql.joins.go(+fuel: Nat, +i: Nat, +env: A.Env, +refs: Refs, +st: A.State) -> A.Res():
  match fuel:
    case 0n:
      A.Res.plain("RangeError: Maximum call stack size exceeded")
    case 1n+f:
      Aql.joins.at(List.get(&2, A.Path, A.State.paths(st), i), st, p => s =>
        A.Res.then_text(Aql.join(env, refs, s, p), s2 => x =>
          A.Res.then_texts(Aql.joins.go(f, 1n+i, env, refs, s2), s3 => xs =>
            A.Res.texts(s3, x <> xs))))

# `compileJoins(state, tableRef, internalTableFilters)`.
def Aql.joins(+env: A.Env, +refs: Refs, +st: A.State) -> A.Res():
  A.Res.then_texts(Aql.joins.go(Aql.fuel(), 0n, env, refs, st), s => xs =>
    A.Res.text(s, String.join(xs, "\n")))

def Aql.deps.add(+deps: List<&2, String>, +table: String) -> List<&2, String>:
  Bool.pick(List<&2, String>, Q.Query.has_key(deps, table), deps,
    List.append(&2, String, deps, [table]))

# `state.dependencies`: the query's table and each joined table, once.
def Aql.deps(+paths: List<&2, A.Path>, +deps: List<&2, String>) -> List<&2, String>:
  match paths:
    case Nil{}:
      deps
    case Con{p, rest}:
      Aql.deps(rest, Aql.deps.add(deps, A.Path.table(p)))

# Aggregates
# ----------

# 0 false, 1 true, 2 a crash; `a || b` where a crash in a wins over b.
def Aql.agg.or(+a: U32, +b: U32) -> U32:
  match a:
    case 0:
      b
    case other:
      a

def Aql.agg.name(+name: String) -> Bool:
  Bool.or(String.eq(name, "$sum"), String.eq(name, "$count"))

# `isAggregateFunction(expr)`; with `cells`, whether any element of a chain
# of cells is one.
def Aql.agg(+j: J.Json, +cells: Bool) -> U32:
  match j cells:
    case J.JElem{v, rest} True{}:
      Aql.agg.or(Aql.agg(v, False{}), Aql.agg(rest, True{}))
    case _ True{}:
      0
    case J.JNull{} False{}:
      2
    case J.JObj{J.JEnd{}} False{}:
      2
    case J.JObj{J.JPair{name, J.JArr{args}, rest}} False{}:
      Bool.pick(U32, Aql.agg.name(name), 1, Aql.agg(args, True{}))
    case J.JObj{J.JPair{name, arg, rest}} False{}:
      Bool.pick(U32, Aql.agg.name(name), 1, Aql.agg(arg, False{}))
    case _ False{}:
      0

# Whether a select expression is an aggregate function.
def Aql.agg.select(+expr: J.Json) -> U32:
  match expr:
    case J.JStr{s}:
      0
    case J.JObj{J.JPair{name, value, rest}}:
      Aql.agg(value, False{})
    case J.JArr{J.JElem{value, rest}}:
      Aql.agg(value, False{})
    case other:
      2

def Aql.agg.any(+exprs: List<&2, J.Json>) -> U32:
  match exprs:
    case Nil{}:
      0
    case Con{e, rest}:
      Aql.agg.or(Aql.agg.select(e), Aql.agg.any(rest))

def Aql.agg.query(+groups: List<&2, J.Json>, +selects: List<&2, J.Json>) -> U32:
  match groups:
    case Nil{}:
      Aql.agg.any(selects)
    case other:
      1

def Aql.agg.answer(+code: U32) -> Maybe<&2, Bool>:
  match code:
    case 0:
      Some{False{}}
    case 1:
      Some{True{}}
    case other:
      None{}

# `isAggregateQuery(queryState)`: a `groupBy` exists or `select` uses an
# aggregate function. None where the TS code crashes on a malformed select.
def Aql.is_aggregate_query(+q: Q.QueryState) -> Maybe<&2, Bool>:
  Aql.agg.answer(Aql.agg.query(Q.Query.group_expressions(q), Q.Query.select_expressions(q)))

# The query
# ---------

# `SqlPieces`.
type Pieces is Data:
  Pieces{select: String, from: String, joins: String, filter: String, group_by: String,
    order_by: String, limit: J.Json, offset: J.Json}

# What `compileQuery` returns: the pieces and the compiler state. Of the
# state, `env` has the schema and the implicit table name and id, `state`
# the paths, named parameters and output types.
type Compiled is Data:
  Compiled{pieces: Pieces, state: A.State, env: A.Env, dependencies: List<&2, String>}

# The clauses compiled so far: select, where, group by, order by.
type Parts is Data:
  Parts{select: String, filter: String, group_by: String, order_by: String}

def Aql.q.joins(+env: A.Env, +refs: Refs, +st: A.State, +p: Parts) -> A.Res():
  match p:
    case Parts{select, filter, group_by, order_by}:
      C.If(A.Res(), List.is_empty(&2, A.Path, A.State.paths(st)),
        u => A.Res.texts(st, [select, "", filter, group_by, order_by]),
        u => A.Res.then_text(Aql.joins(env, refs, st), s => joins =>
          A.Res.texts(s, [select, joins, filter, group_by, order_by])))

def Aql.q.order(+env: A.Env, +refs: Refs, +q: Q.QueryState, +st: A.State, +p: Parts) -> A.Res():
  match p:
    case Parts{select, filter, group_by, order_by}:
      C.If(A.Res(), List.is_empty(&2, J.Json, Q.Query.order_expressions(q)),
        u => Aql.q.joins(env, refs, st, p),
        u => A.Res.then_text(Aql.order_by(env, st, Q.Query.order_expressions(q)), s => x =>
          Aql.q.joins(env, refs, s, Parts{select, filter, group_by, "ORDER BY " ++ x})))

def Aql.q.group(+env: A.Env, +refs: Refs, +q: Q.QueryState, +st: A.State, +p: Parts) -> A.Res():
  match p:
    case Parts{select, filter, group_by, order_by}:
      C.If(A.Res(), List.is_empty(&2, J.Json, Q.Query.group_expressions(q)),
        u => Aql.q.order(env, refs, q, st, p),
        u => A.Res.then_text(Aql.group_by(env, st, Q.Query.group_expressions(q)), s => x =>
          Aql.q.order(env, refs, q, s, Parts{select, filter, "GROUP BY " ++ x, order_by})))

# The internal filters of the query's table, unless in raw mode.
def Aql.q.internal(+env: A.Env, +refs: Refs, +q: Q.QueryState, +st: A.State, +p: Parts) -> A.Res():
  match p:
    case Parts{select, filter, group_by, order_by}:
      C.If(A.Res(), Q.Query.raw_mode(q),
        u => Aql.q.group(env, refs, q, st, p),
        u => Aql.filters(st, Aql.refs.cfg(refs), Q.Query.table(q), +s => +fs =>
          C.If(A.Res(), Aql.is_empty_array(fs),
            v => Aql.q.group(env, refs, q, s, p),
            v => A.Res.then_text(Aql.run(8, env, s, fs, J.JBool{True{}}), s2 => x =>
              Aql.q.group(env, refs, q, s2,
                Parts{select, Aql.append_where(filter, x), group_by, order_by})))))

def Aql.q.filter_text(+x: String) -> String:
  Bool.pick(String, String.is_empty(x), "", "WHERE " ++ x)

def Aql.q.where(+env: A.Env, +refs: Refs, +q: Q.QueryState, +st: A.State, +select: String) ->
  A.Res():
  C.If(A.Res(), List.is_empty(&2, J.Json, Q.Query.filter_expressions(q)),
    u => Aql.q.internal(env, refs, q, st, Parts{select, "", "", ""}),
    u => A.Res.then_text(Aql.where(env, st, Q.Query.filter_expressions(q)), s => x =>
      Aql.q.internal(env, refs, q, s, Parts{select, Aql.q.filter_text(x), "", ""})))

def Aql.q.select(
  +env: A.Env, +refs: Refs, +q: Q.QueryState, +st: A.State, +aggregate: Maybe<&2, Bool>
) -> A.Res():
  match aggregate:
    case None{}:
      A.Res.type_error("Cannot convert undefined or null to object")
    case Some{agg}:
      A.Res.then_text(
        Aql.select(env, st, Q.Query.select_expressions(q), agg,
          J.Json.array(Q.Query.order_expressions(q))),
        s => x => Aql.q.where(env, refs, q, s, x))

# `customizeQuery(queryState)`.
def Aql.customize(+cfg: S.Config, +q: Q.QueryState) -> Q.QueryState:
  C.If(Q.QueryState, S.Config.customize(cfg), u => M.Actual.customize_query(q), u => q)

def Aql.refs(+cfg: S.Config, +q: Q.QueryState) -> Refs:
  Refs{cfg, Q.Query.is_with_dead(q), Q.Query.table_options(q)}

def Aql.env(+schema: S.Schema, +q: Q.QueryState, +from: String) -> A.Env:
  A.Env{schema, Q.Query.table(q), from, None{}, Q.Query.validate_refs(q), None{}}

def Aql.compiled(+r: A.Res(), +env: A.Env, +q: Q.QueryState) -> Result<&2, &2, A.Err, Compiled>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{A.R{st, A.OTexts{Con{select, Con{joins, Con{filter, Con{group, Con{order, Nil{}}}}}}}}}:
      Done{Compiled{
        Pieces{select, A.Env.table_id(env), joins, filter, group, order,
          Q.Query.get_limit(q), Q.Query.get_offset(q)},
        st, env, Aql.deps(A.State.paths(st), [A.Env.table(env)])}}
    case Done{other}:
      Fail{A.Err{False{}, "internal error: unexpected result", Nil{}}}

def Aql.compile_query.in(+env: A.Env, +refs: Refs, +q: Q.QueryState, +agg: Maybe<&2, Bool>) ->
  Result<&2, &2, A.Err, Compiled>:
  Aql.compiled(Aql.q.select(env, refs, q, A.State.new(), agg), env, q)

def Aql.compile_query.with(+schema: S.Schema, +refs: Refs, +q: Q.QueryState, +agg: Maybe<&2, Bool>) ->
  Result<&2, &2, A.Err, Compiled>:
  Aql.compile_query.in(Aql.env(schema, q, Aql.table_ref(refs, Q.Query.table(q), False{})), refs, q, agg)

# `compileQuery(queryState, schema, schemaConfig)`.
def Aql.compile_query(+q: Q.QueryState, +schema: S.Schema, +cfg: S.Config) ->
  Result<&2, &2, A.Err, Compiled>:
  Aql.compile_query.with(schema, Aql.refs(cfg, q), Aql.customize(cfg, q), Aql.is_aggregate_query(q))

def Aql.limit(+word: String, +n: J.Json) -> String:
  match n:
    case J.JNull{}:
      ""
    case other:
      word ++ V.Js.string(n)

def Aql.sql(+p: Pieces, +filter: String) -> String:
  match p:
    case Pieces{select, from, joins, old, group_by, order_by, limit, offset}:
      "\n    SELECT " ++ select ++ " FROM " ++ from ++ "\n    " ++ joins ++ "\n    " ++ filter ++
        "\n    " ++ group_by ++ "\n    " ++ order_by ++ "\n    " ++ Aql.limit("LIMIT ", limit) ++
        "\n    " ++ Aql.limit("OFFSET ", offset) ++ "\n  "

def Aql.pieces.filter(+p: Pieces) -> String:
  match p:
    case Pieces{select, from, joins, filter, group_by, order_by, limit, offset}:
      filter

def Aql.construct.at(+c: Compiled, +dead: Bool, +t: Maybe<&2, S.Table>) -> Result<&2, &2, A.Err, String>:
  match c dead t:
    case Compiled{pieces, state, env, deps} True{} _:
      Done{Aql.sql(pieces, Aql.pieces.filter(pieces))}
    case Compiled{pieces, state, env, deps} False{} None{}:
      Fail{A.Err{False{}, "TypeError: Cannot read properties of undefined (reading 'tombstone')", Nil{}}}
    case Compiled{pieces, state, env, deps} False{} Some{table}:
      Done{Aql.sql(pieces, Aql.tombstone(S.Table.has(table, "tombstone"), A.Env.table_id(env),
        Aql.pieces.filter(pieces)))}

def Aql.compiled.env(+c: Compiled) -> A.Env:
  match c:
    case Compiled{pieces, state, env, deps}:
      env

# `defaultConstructQuery(queryState, compilerState, sqlPieces)`.
def Aql.construct(+q: Q.QueryState, +c: Compiled) -> Result<&2, &2, A.Err, String>:
  Aql.construct.at(c, Q.Query.is_with_dead(q),
    S.Schema.table(A.Env.schema(Aql.compiled.env(c)), A.Env.table(Aql.compiled.env(c))))

# What `generateSQLWithState` returns: the SQL and the compiled query.
type Output is Data:
  Output{sql: String, compiled: Compiled}

def Aql.output(+c: Compiled, +sql: Result<&2, &2, A.Err, String>) -> Result<&2, &2, String, Output>:
  match sql:
    case Fail{e}:
      Fail{A.Err.show(e)}
    case Done{text}:
      Done{Output{text, c}}

def Aql.generate(+q: Q.QueryState, +r: Result<&2, &2, A.Err, Compiled>) -> Result<&2, &2, String, Output>:
  match r:
    case Fail{e}:
      Fail{A.Err.show(e)}
    case Done{c}:
      Aql.output(c, Aql.construct(q, c))

# `generateSQLWithState(queryState, schema, schemaConfig)`: the SQL text and
# the compiler state, or the message of the error the TS code throws.
def Aql.compile(+schema: S.Schema, +cfg: S.Config, +q: Q.QueryState) -> Result<&2, &2, String, Output>:
  Aql.generate(q, Aql.compile_query(q, schema, cfg))

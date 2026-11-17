# The state of the AQL compiler (`CompilerState` of
# packages/loot-core/src/server/aql/compiler.ts), typed expressions, and the
# error-carrying state monad the compiler runs in.
#
# Deviations: the mutable `state` object is split into `Env`, what a call
# reads (schema, implicit table and field, orders), and `State`, what it
# changes (paths, parameters, output types, the stack of `saveStack`), which
# every def takes and returns. `throw new CompileError(msg)` is
# `Res.throw(st, msg)`: a `Fail` holding the message and the stack at that
# point; any other JS error is `Res.plain(msg)`. `_uid` is `State.uid`.
import Base
import ../json/json.bend as J
import ../lib/core.bend as C
import ./js.bend as V
import ./types.bend as S

# `typed(value, type, {literal})`. `value` is the JS value as text; `arr` is
# the array of an array literal; `pid` names the parameter object of a named
# parameter (0 for anything else).
type Typed is Data:
  Typed{value: String, kind: String, literal: Bool, pid: Nat, arr: Maybe<&2, J.Json>}

# An entry of `state.paths`: its key and `{tableName, tableId, joinField,
# joinTable}`.
type Path is Data:
  Path{key: String, table: String, id: String, field: String, join: String}

# An entry of `state.namedParameters`; `kind` is `paramType`, empty until
# inferred. `id` is 0 for the copy `$eq` and `$ne` add.
type Param is Data:
  Param{id: Nat, name: String, kind: String}

# An entry of `state.compileStack`: `a` is `args[0]` (None for `undefined`)
# and `b` is `args[1]` of an `op`.
type Frame is Data:
  Frame{kind: String, a: Maybe<&2, J.Json>, b: J.Json}

# An entry of `state.outputTypes`.
type OutType is Data:
  OutType{name: String, kind: String}

type State is Data:
  State{uid: Nat, pid: Nat, paths: List<&2, Path>, params: List<&2, Param>,
    frozen: Maybe<&2, List<&2, Param>>, stack: List<&2, Frame>, types: List<&2, OutType>}

type Env is Data:
  Env{schema: S.Schema, table: String, table_id: String, field: Maybe<&2, String>,
    validate: Bool, orders: Maybe<&2, J.Json>}

type Err is Data:
  Err{compile: Bool, msg: String, stack: List<&2, Frame>}

type Out is Data:
  OTyped{t: Typed}
  OTypeds{ts: List<&2, Typed>}
  OText{s: String}
  OTexts{xs: List<&2, String>}
  OPath{p: Path}

type R is Data:
  R{st: State, out: Out}

def Res() -> Data:
  Result<&2, &2, Err, R>

# Typed expressions
# -----------------

def Typed.make(+value: String, +kind: String) -> Typed:
  Typed{value, kind, False{}, 0n, None{}}

def Typed.lit(+value: String, +kind: String) -> Typed:
  Typed{value, kind, True{}, 0n, None{}}

def Typed.flag(+value: String, +kind: String, +literal: Bool) -> Typed:
  Typed{value, kind, literal, 0n, None{}}

def Typed.value(+t: Typed) -> String:
  match t:
    case Typed{value, kind, literal, pid, arr}:
      value

def Typed.kind(+t: Typed) -> String:
  match t:
    case Typed{value, kind, literal, pid, arr}:
      kind

def Typed.literal(+t: Typed) -> Bool:
  match t:
    case Typed{value, kind, literal, pid, arr}:
      literal

def Typed.pid(+t: Typed) -> Nat:
  match t:
    case Typed{value, kind, literal, pid, arr}:
      pid

def Typed.arr(+t: Typed) -> Maybe<&2, J.Json>:
  match t:
    case Typed{value, kind, literal, pid, arr}:
      arr

# `value.replace(/'/g, "''")`.
def Typed.escape(+s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{'\'', t}:
      SCon{'\'', SCon{'\'', Typed.escape(t)}}
    case SCon{c, t}:
      SCon{c, Typed.escape(t)}

# `val(state, expr)` without a cast: the SQL text of an expression.
def Typed.sql(+t: Typed) -> String:
  match t:
    case Typed{value, "id", True{}, pid, arr}:
      "'" ++ value ++ "'"
    case Typed{value, "string", True{}, pid, arr}:
      "'" ++ Typed.escape(value) ++ "'"
    case Typed{value, kind, literal, pid, arr}:
      value

# Environment
# -----------

def Env.schema(+e: Env) -> S.Schema:
  match e:
    case Env{schema, table, table_id, field, validate, orders}:
      schema

def Env.table(+e: Env) -> String:
  match e:
    case Env{schema, table, table_id, field, validate, orders}:
      table

def Env.table_id(+e: Env) -> String:
  match e:
    case Env{schema, table, table_id, field, validate, orders}:
      table_id

def Env.field(+e: Env) -> Maybe<&2, String>:
  match e:
    case Env{schema, table, table_id, field, validate, orders}:
      field

def Env.validate(+e: Env) -> Bool:
  match e:
    case Env{schema, table, table_id, field, validate, orders}:
      validate

def Env.orders(+e: Env) -> Maybe<&2, J.Json>:
  match e:
    case Env{schema, table, table_id, field, validate, orders}:
      orders

# `{...state, implicitField: field}`.
def Env.with_field(+e: Env, +f: String) -> Env:
  match e:
    case Env{schema, table, table_id, field, validate, orders}:
      Env{schema, table, table_id, Some{f}, validate, orders}

# `{...state, orders}`.
def Env.with_orders(+e: Env, +o: J.Json) -> Env:
  match e:
    case Env{schema, table, table_id, field, validate, orders}:
      Env{schema, table, table_id, field, validate, Some{o}}

# `{...state, implicitTableName: name, implicitTableId: id}`.
def Env.with_table(+e: Env, +name: String, +id: String) -> Env:
  match e:
    case Env{schema, table, table_id, field, validate, orders}:
      Env{schema, name, id, field, validate, orders}

# State
# -----

def State.new() -> State:
  State{0n, 0n, Nil{}, Nil{}, None{}, Nil{}, Nil{}}

def State.paths(+s: State) -> List<&2, Path>:
  match s:
    case State{uid, pid, paths, params, frozen, stack, types}:
      paths

def State.params(+s: State) -> List<&2, Param>:
  match s:
    case State{uid, pid, paths, params, frozen, stack, types}:
      params

def State.stack(+s: State) -> List<&2, Frame>:
  match s:
    case State{uid, pid, paths, params, frozen, stack, types}:
      stack

def State.types(+s: State) -> List<&2, OutType>:
  match s:
    case State{uid, pid, paths, params, frozen, stack, types}:
      types

def State.uid(+s: State) -> Nat:
  match s:
    case State{uid, pid, paths, params, frozen, stack, types}:
      uid

# `state.compileStack.push(frame)`.
def State.push(+s: State, +f: Frame) -> State:
  match s:
    case State{uid, pid, paths, params, frozen, stack, types}:
      State{uid, pid, paths, params, frozen, f <> stack, types}

# `state.compileStack.pop()`.
def State.pop(+s: State) -> State:
  match s:
    case State{uid, pid, paths, params, frozen, stack, types}:
      State{uid, pid, paths, params, frozen, List.tail(&2, Frame, stack), types}

def Path.key(+p: Path) -> String:
  match p:
    case Path{key, table, id, field, join}:
      key

def Path.table(+p: Path) -> String:
  match p:
    case Path{key, table, id, field, join}:
      table

def Path.id(+p: Path) -> String:
  match p:
    case Path{key, table, id, field, join}:
      id

def Path.find(+paths: List<&2, Path>, +key: String) -> Maybe<&2, Path>:
  match paths:
    case Nil{}:
      None{}
    case Con{+p, rest}:
      Bool.pick(Maybe<&2, Path>, String.eq(Path.key(p), key), Some{p}, Path.find(rest, key))

# `state.paths.get(key)`.
def State.path(+s: State, +key: String) -> Maybe<&2, Path>:
  Path.find(State.paths(s), key)

# `state.paths.set(key, {tableName, tableId: uid(tableName), joinField,
# joinTable})` for a new key: the state and the new path.
def State.add_path(+s: State, +key: String, +table: String, +field: String, +join: String) -> R:
  match s:
    case State{+uid, pid, paths, params, frozen, stack, types}:
      +p = {Path{key, table, table ++ Nat.show(1n+uid), field, join} : Path}
      R{State{1n+uid, pid, List.append(&2, Path, paths, [p]), params, frozen, stack, types}, OPath{p}}

def OutType.set(+types: List<&2, OutType>, +name: String, +kind: String) -> List<&2, OutType>:
  match types:
    case Nil{}:
      [OutType{name, kind}]
    case Con{OutType{+n, k}, rest}:
      Bool.pick(List<&2, OutType>, String.eq(n, name),
        OutType{n, kind} <> rest,
        OutType{n, k} <> OutType.set(rest, name, kind))

# `state.outputTypes.set(name, kind)`.
def State.set_type(+s: State, +name: String, +kind: String) -> State:
  match s:
    case State{uid, pid, paths, params, frozen, stack, types}:
      State{uid, pid, paths, params, frozen, stack, OutType.set(types, name, kind)}

# Named parameters
# ----------------

# A new parameter object pushed on `state.namedParameters`: the state and
# its expression.
def State.add_param(+s: State, +name: String) -> R:
  match s:
    case State{uid, +pid, paths, params, frozen, stack, types}:
      R{State{uid, 1n+pid, paths, List.append(&2, Param, params, [Param{1n+pid, name, ""}]),
          frozen, stack, types},
        OTyped{Typed{"?", "param", False{}, 1n+pid, None{}}}}

def State.set_params(+s: State, +ps: List<&2, Param>) -> State:
  match s:
    case State{uid, pid, paths, params, frozen, stack, types}:
      State{uid, pid, paths, ps, frozen, stack, types}

def Param.name(+p: Param) -> String:
  match p:
    case Param{id, name, kind}:
      name

def Param.kind(+p: Param) -> String:
  match p:
    case Param{id, name, kind}:
      kind

def Param.find(+ps: List<&2, Param>, +pid: Nat) -> Maybe<&2, Param>:
  match ps:
    case Nil{}:
      None{}
    case Con{Param{+id, name, kind}, rest}:
      Bool.pick(Maybe<&2, Param>, Nat.is_eq(id, pid), Some{Param{id, name, kind}},
        Param.find(rest, pid))

def Param.set(+ps: List<&2, Param>, +pid: Nat, +kind: String) -> List<&2, Param>:
  match ps:
    case Nil{}:
      Nil{}
    case Con{Param{+id, name, old}, rest}:
      Param{id, name, Bool.pick(String, Nat.is_eq(id, pid), kind, old)} <> Param.set(rest, pid, kind)

# `casts[type].includes(existing)`.
def Param.casts(+kind: String, +existing: String) -> Bool:
  match kind existing:
    case "date" "string":
      True{}
    case "date-month" "date":
      True{}
    case "date-year" "date":
      True{}
    case "date-year" "date-month":
      True{}
    case "id" "string":
      True{}
    case "float" "integer":
      True{}
    case _ _:
      False{}

# Whether a parameter already inferred as `existing` may be read as `kind`.
def Param.fits(+existing: String, +kind: String) -> Bool:
  Bool.or(String.is_empty(existing),
    Bool.or(String.eq(existing, kind), Param.casts(kind, existing)))

# The parameters with the one named `pid` followed by a copy of itself.
def Param.dup(+ps: List<&2, Param>, +pid: Nat) -> List<&2, Param>:
  match ps:
    case Nil{}:
      Nil{}
    case Con{Param{+id, +name, +kind}, rest}:
      List.append(&2, Param,
        Bool.pick(List<&2, Param>, Bool.and(Nat.is_eq(id, pid), Nat.is_ne(pid, 0n)),
          [Param{id, name, kind}, Param{0n, name, kind}], [Param{id, name, kind}]),
        Param.dup(rest, pid))

# `state.namedParameters = [...]` with the parameter `pid` doubled. The
# assignment gives this state object a new array, so a state it was copied
# from (`{...state}`) keeps the array as it was: `frozen` remembers it.
def State.dup_param(+s: State, +pid: Nat) -> State:
  match s:
    case State{uid, p, paths, +params, frozen, stack, types}:
      State{uid, p, paths, Param.dup(params, pid),
        Some{Maybe.default(&2, List<&2, Param>, frozen, params)}, stack, types}

# Entering `{...state}`: the copy shares the parameter array.
def State.enter(+s: State) -> State:
  match s:
    case State{uid, pid, paths, params, frozen, stack, types}:
      State{uid, pid, paths, params, None{}, stack, types}

# Leaving a copy: the outer state object sees the array it still holds.
def State.leave(+s: State, +saved: Maybe<&2, List<&2, Param>>) -> State:
  match s:
    case State{uid, pid, paths, params, frozen, stack, types}:
      State{uid, pid, paths, Maybe.default(&2, List<&2, Param>, frozen, params), saved, stack, types}

def State.frozen(+s: State) -> Maybe<&2, List<&2, Param>>:
  match s:
    case State{uid, pid, paths, params, frozen, stack, types}:
      frozen

# Results
# -------

def Res.ok(+st: State, +out: Out) -> Res():
  Done{R{st, out}}

def Res.typed(+st: State, +t: Typed) -> Res():
  Done{R{st, OTyped{t}}}

def Res.typeds(+st: State, +ts: List<&2, Typed>) -> Res():
  Done{R{st, OTypeds{ts}}}

def Res.text(+st: State, +s: String) -> Res():
  Done{R{st, OText{s}}}

def Res.texts(+st: State, +xs: List<&2, String>) -> Res():
  Done{R{st, OTexts{xs}}}

# `throw new CompileError(msg)`.
def Res.throw(+st: State, +msg: String) -> Res():
  Fail{Err{True{}, msg, State.stack(st)}}

# Any other JS error: it is not given the expression stack.
def Res.plain(+msg: String) -> Res():
  Fail{Err{False{}, msg, Nil{}}}

# What stands for a JS `TypeError` on a malformed query.
def Res.type_error(+what: String) -> Res():
  Res.plain("TypeError: " ++ what)

def Res.bug() -> Res():
  Res.plain("internal error: unexpected result")

def Res.then(+r: Res(), f: State -> Out -> Res()) -> Res():
  match r:
    case Fail{e}:
      Fail{e}
    case Done{R{st, out}}:
      f(st, out)

def Res.then_typed(+r: Res(), f: State -> Typed -> Res()) -> Res():
  match r:
    case Fail{e}:
      Fail{e}
    case Done{R{st, OTyped{t}}}:
      f(st, t)
    case Done{other}:
      Res.bug()

def Res.then_typeds(+r: Res(), f: State -> List<&2, Typed> -> Res()) -> Res():
  match r:
    case Fail{e}:
      Fail{e}
    case Done{R{st, OTypeds{ts}}}:
      f(st, ts)
    case Done{other}:
      Res.bug()

def Res.then_text(+r: Res(), f: State -> String -> Res()) -> Res():
  match r:
    case Fail{e}:
      Fail{e}
    case Done{R{st, OText{s}}}:
      f(st, s)
    case Done{other}:
      Res.bug()

def Res.then_texts(+r: Res(), f: State -> List<&2, String> -> Res()) -> Res():
  match r:
    case Fail{e}:
      Fail{e}
    case Done{R{st, OTexts{xs}}}:
      f(st, xs)
    case Done{other}:
      Res.bug()

def Res.then_path(+r: Res(), f: State -> Path -> Res()) -> Res():
  match r:
    case Fail{e}:
      Fail{e}
    case Done{R{st, OPath{p}}}:
      f(st, p)
    case Done{other}:
      Res.bug()

# A pure step that may throw a CompileError: its text, or the message.
def Res.from(+st: State, +r: Result<&2, &2, String, String>, f: State -> String -> Res()) -> Res():
  match r:
    case Fail{msg}:
      Res.throw(st, msg)
    case Done{s}:
      f(st, s)

def Res.pop(+r: Res()) -> Res():
  match r:
    case Fail{e}:
      Fail{e}
    case Done{R{st, out}}:
      Done{R{State.pop(st), out}}

# `saveStack(type, func)`: the frame is on the stack while the body runs and
# stays there when it throws.
def Res.framed(+st: State, +frame: Frame, body: State -> Res()) -> Res():
  Res.pop(body(State.push(st, frame)))

def Res.leave(+saved: Maybe<&2, List<&2, Param>>, +r: Res()) -> Res():
  match r:
    case Fail{e}:
      Fail{e}
    case Done{R{st, out}}:
      Done{R{State.leave(st, saved), out}}

# Runs a body on a copy of the state object, `{...state}`.
def Res.scoped(+st: State, body: State -> Res()) -> Res():
  Res.leave(State.frozen(st), body(State.enter(st)))

# `inferParam(param, kind)` for the parameter of an expression.
def Res.infer.at(+st: State, +pid: Nat, +kind: String, +p: Maybe<&2, Param>) -> Res():
  match p:
    case None{}:
      Res.text(st, "")
    case Some{Param{id, +name, +old}}:
      C.If(Res(), Param.fits(old, kind),
        u => Res.text(State.set_params(st,
          Param.set(State.params(st), pid, Bool.pick(String, String.is_empty(old), kind, old))), ""),
        u => Res.plain("Parameter \"" ++ name ++ "\" can't convert to " ++ kind ++
          " (already inferred as " ++ old ++ ")"))

def Res.infer(+st: State, +pid: Nat, +kind: String) -> Res():
  Res.infer.at(st, pid, kind, Param.find(State.params(st), pid))

# Errors
# ------

# `prettyValue(value)`.
def Err.pretty.long(+j: J.Json, +s: String) -> String:
  Bool.pick(String, Nat.is_gt(String.length(s), 70n), V.Js.pretty(j, "  "), s)

def Err.pretty(+j: J.Json) -> String:
  match j:
    case J.JStr{s}:
      s
    case other:
      Err.pretty.long(other, J.Json.show(other))

def Err.pretty_opt(+m: Maybe<&2, J.Json>) -> String:
  match m:
    case None{}:
      "undefined"
    case Some{j}:
      Err.pretty(j)

# The line of a frame that is not the root.
def Err.entry(+f: Frame) -> String:
  match f:
    case Frame{"expr", a, b}:
      Err.pretty_opt(a)
    case Frame{"function", a, b}:
      Err.pretty_opt(a)
    case Frame{"value", a, b}:
      Err.pretty_opt(a)
    case Frame{"op", Some{J.JStr{field}}, b}:
      Err.pretty(V.Js.single(field, b))
    case other:
      ""

# `methodArgs.length === 1 ? methodArgs[0] : methodArgs`.
def Err.root_arg(+m: Maybe<&2, J.Json>) -> String:
  match m:
    case Some{J.JArr{J.JElem{v, J.JEnd{}}}}:
      Err.pretty(v)
    case other:
      Err.pretty_opt(other)

# The stack, newest frame first, as the lines of the message.
def Err.lines(+stack: List<&2, Frame>) -> String:
  match stack:
    case Nil{}:
      ""
    case Con{Frame{kind, a, b}, Nil{}}:
      "\n  " ++ kind ++ "(" ++ Err.root_arg(a) ++ ")"
    case Con{f, rest}:
      "\n  " ++ Err.entry(f) ++ Err.lines(rest)

# `getCompileError(error, stack).message`.
def Err.show(+e: Err) -> String:
  match e:
    case Err{False{}, msg, stack}:
      msg
    case Err{True{}, msg, Nil{}}:
      msg
    case Err{True{}, msg, stack}:
      msg ++ "\n\nExpression stack:" ++ Err.lines(stack)

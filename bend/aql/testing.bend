# What the generated AQL tests share: reading a schema, a config and a query
# state written as JSON, and showing a compile result as text the way the
# generator (scratchpad aql/gen_tests.ts) shows the TS compiler's.
import Base
import ../json/json.bend as J
import ./types.bend as S
import ./state.bend as A
import ./query.bend as Q
import ./schema.bend as M
import ./compiler.bend as K

def Testing.json(+text: String) -> J.Json:
  Maybe.default(&2, J.Json, J.Json.parse(text), J.JNull{})

def Testing.schema(+text: String) -> S.Schema:
  S.Schema.read(Testing.json(text))

def Testing.config(+text: String) -> S.Config:
  S.Config.read(Testing.json(text))

def Testing.query(+text: String) -> Q.QueryState:
  Q.Query.read(Testing.json(text))

def Testing.path(+p: A.Path) -> String:
  match p:
    case A.Path{key, table, id, field, join}:
      key ++ "=" ++ table ++ "/" ++ id ++ "/" ++ field ++ "/" ++ join

def Testing.paths(+ps: List<&2, A.Path>) -> List<&2, String>:
  match ps:
    case Nil{}:
      Nil{}
    case Con{p, rest}:
      Testing.path(p) <> Testing.paths(rest)

def Testing.types(+ts: List<&2, A.OutType>) -> List<&2, String>:
  match ts:
    case Nil{}:
      Nil{}
    case Con{A.OutType{name, kind}, rest}:
      (name ++ ":" ++ kind) <> Testing.types(rest)

def Testing.params(+ps: List<&2, A.Param>) -> List<&2, String>:
  match ps:
    case Nil{}:
      Nil{}
    case Con{A.Param{id, name, kind}, rest}:
      (name ++ ":" ++ kind) <> Testing.params(rest)

def Testing.state(+st: A.State, +deps: List<&2, String>) -> String:
  "\n--paths " ++ String.join(Testing.paths(A.State.paths(st)), ";") ++
    "\n--deps " ++ String.join(deps, ",") ++
    "\n--types " ++ String.join(Testing.types(A.State.types(st)), ",") ++
    "\n--params " ++ String.join(Testing.params(A.State.params(st)), ",")

# An error message; a JS `TypeError`, whose wording is the engine's, is
# shown by its name alone.
def Testing.error(+msg: String) -> String:
  Bool.pick(String, Bool.or(String.starts_with(msg, "TypeError"), String.starts_with(msg, "RangeError")),
    "ERROR: TypeError", "ERROR: " ++ msg)

def Testing.show(+r: Result<&2, &2, String, K.Output>) -> String:
  match r:
    case Fail{msg}:
      Testing.error(msg)
    case Done{K.Output{sql, K.Compiled{pieces, state, env, deps}}}:
      sql ++ Testing.state(state, deps)

# The SQL and state of a query state given as JSON.
def Testing.run(+schema: S.Schema, +cfg: S.Config, +query: String) -> String:
  Testing.show(K.Aql.compile(schema, cfg, Testing.query(query)))

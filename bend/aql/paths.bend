# Field references and table joins of the AQL compiler: `popPath`,
# `getFieldDescription`, `makePath`, `resolvePath`, `transformField` and
# `expandStar` of packages/loot-core/src/server/aql/compiler.ts.
import Base
import ../lib/core.bend as C
import ./types.bend as S
import ./state.bend as A

# `popPath(path)`: `{path, field}`.
type Popped is Data:
  Popped{path: String, field: String}

def Paths.last(+parts: List<&2, String>) -> String:
  Maybe.default(&2, String, List.last(&2, String, parts), "")

# `parts.slice(0, -1)`.
def Paths.init(+parts: List<&2, String>) -> List<&2, String>:
  List.take(&2, String, parts, Nat.sub(List.length(&2, String, parts), 1n))

def Paths.pop.of(+parts: List<&2, String>) -> Popped:
  Popped{String.join(Paths.init(parts), "."), Paths.last(parts)}

def Paths.pop(+path: String) -> Popped:
  Paths.pop.of(String.split(path, '.'))

def Paths.step.field(+m: Maybe<&2, S.Field>, +table: String, +field: String) ->
  Result<&2, &2, String, String>:
  match m:
    case Some{S.Field{name, kind, Some{ref}, required, default}}:
      Done{ref}
    case other:
      Fail{"Field not joinable on table " ++ table ++ ": \"" ++ field ++ "\""}

def Paths.step.table(+m: Maybe<&2, S.Table>, +table: String, +field: String) ->
  Result<&2, &2, String, String>:
  match m:
    case None{}:
      Fail{"Path error: " ++ table ++ " table does not exist"}
    case Some{t}:
      Paths.step.field(S.Table.field(t, field), table, field)

# The table a field of a table refers to.
def Paths.step(+schema: S.Schema, +table: String, +field: String) -> Result<&2, &2, String, String>:
  Paths.step.table(S.Schema.table(schema, table), table, field)

# The table at the end of a chain of reference fields.
def Paths.walk(+fields: List<&2, String>, +schema: S.Schema, +table: String) ->
  Result<&2, &2, String, String>:
  match fields:
    case Nil{}:
      Done{table}
    case Con{f, rest}:
      Result.bind(&2, &2, String, String, String, Paths.step(schema, table, f),
        t => Paths.walk(rest, schema, t))

def Paths.join.at(+st: A.State, +m: Maybe<&2, A.Path>, +key: String, k: A.State -> String -> A.Res()) ->
  A.Res():
  match m:
    case None{}:
      A.Res.throw(st, "Path does not exist: " ++ key)
    case Some{p}:
      k(st, A.Path.id(p))

# The table or table id a path joins on: its parent.
def Paths.join(+st: A.State, +parent: List<&2, String>, k: A.State -> String -> A.Res()) -> A.Res():
  match parent:
    case Con{table, Nil{}}:
      k(st, table)
    case other:
      Paths.join.at(st, A.State.path(st, String.join(other, ".")), String.join(other, "."), k)

def Paths.make.of(+env: A.Env, +st: A.State, +path: String, +parts: List<&2, String>) -> A.Res():
  match parts:
    case Con{first, Con{second, rest}}:
      A.Res.from(st, Paths.walk(Con{second, rest}, A.Env.schema(env), first), s1 => +table =>
        Paths.join(s1, Paths.init(parts), s2 => join =>
          Done{A.State.add_path(s2, path, table, Paths.last(parts), join)}))
    case other:
      A.Res.throw(st, "Invalid path: " ++ path)

# `makePath(state, path)` and `state.paths.set(path, ..)`.
def Paths.make(+env: A.Env, +st: A.State, +path: String) -> A.Res():
  Paths.make.of(env, st, path, String.split(path, '.'))

def Paths.ensure.at(+env: A.Env, +st: A.State, +key: String, +m: Maybe<&2, A.Path>) -> A.Res():
  match m:
    case Some{p}:
      A.Res.ok(st, A.OPath{p})
    case None{}:
      Paths.make(env, st, key)

# The path of a key, made when new.
def Paths.ensure(+env: A.Env, +st: A.State, +key: String) -> A.Res():
  Paths.ensure.at(env, st, key, A.State.path(st, key))

def Paths.resolve.go(+names: List<&2, String>, +env: A.Env, +st: A.State, +context: String) -> A.Res():
  match names:
    case Nil{}:
      A.Res.bug()
    case Con{name, Nil{}}:
      Paths.ensure(env, st, context ++ "." ++ name)
    case Con{name, rest}:
      A.Res.then_path(Paths.ensure(env, st, context ++ "." ++ name), s => p =>
        Paths.resolve.go(rest, env, s, context ++ "." ++ name))

# `resolvePath(state, path)`.
def Paths.resolve(+env: A.Env, +st: A.State, +path: String) -> A.Res():
  Paths.resolve.go(String.split(path, '.'), env, st, A.Env.table(env))

def Paths.describe.field(+m: Maybe<&2, S.Field>, +table: String, +field: String) ->
  Result<&2, &2, String, S.Field>:
  match m:
    case None{}:
      Fail{"Field \"" ++ field ++ "\" does not exist in table \"" ++ table ++ "\""}
    case Some{f}:
      Done{f}

def Paths.describe.table(+m: Maybe<&2, S.Table>, +table: String, +field: String) ->
  Result<&2, &2, String, S.Field>:
  match m:
    case None{}:
      Fail{"Table \"" ++ table ++ "\" does not exist in the schema"}
    case Some{t}:
      Paths.describe.field(S.Table.field(t, field), table, field)

# `getFieldDescription(schema, table, field)`.
def Paths.describe(+schema: S.Schema, +table: String, +field: String) -> Result<&2, &2, String, S.Field>:
  Paths.describe.table(S.Schema.table(schema, table), table, field)

# Whether a field is read through a join that drops dead rows.
def Paths.is_ref(+env: A.Env, +f: S.Field, +field: String) -> Bool:
  Bool.and(A.Env.validate(env),
    Bool.and(Maybe.is_some(&2, String, S.Field.get_ref(f)),
      Bool.and(String.eq(S.Field.type(f), "id"), Bool.not(String.eq(field, "id")))))

# The implicit table as a path.
def Paths.implicit(+env: A.Env) -> A.Path:
  A.Path{"", A.Env.table(env), A.Env.table_id(env), "", ""}

# The table a field name is read from.
def Paths.info(+env: A.Env, +st: A.State, +path: String) -> A.Res():
  C.If(A.Res(), String.is_empty(path),
    u => A.Res.ok(st, A.OPath{Paths.implicit(env)}),
    u => Paths.resolve(env, st, path))

def Paths.field.typed(
  +env: A.Env, +st: A.State, +name: String, +field: String, +info: A.Path,
  +desc: Result<&2, &2, String, S.Field>
) -> A.Res():
  match desc:
    case Fail{msg}:
      A.Res.throw(st, msg)
    case Done{f}:
      C.If(A.Res(), Paths.is_ref(env, f, field),
        u => A.Res.then_path(Paths.ensure(env, st, A.Env.table(env) ++ "." ++ name), s => p =>
          A.Res.typed(s, A.Typed.make(A.Path.id(p) ++ ".id", S.Field.type(f)))),
        u => A.Res.typed(st, A.Typed.make(A.Path.id(info) ++ "." ++ field, S.Field.type(f))))

def Paths.field.of(+env: A.Env, +st: A.State, +name: String, +popped: Popped) -> A.Res():
  match popped:
    case Popped{path, field}:
      A.Res.then_path(Paths.info(env, st, path), +s => +info =>
        Paths.field.typed(env, s, name, field, info,
          Paths.describe(A.Env.schema(env), A.Path.table(info), field)))

# `transformField(state, name)`.
def Paths.field(+env: A.Env, +st: A.State, +name: String) -> A.Res():
  Paths.field.of(env, st, name, Paths.pop(name))

def Paths.star.names(+fields: List<&2, String>, +path: String) -> List<&2, String>:
  match fields:
    case Nil{}:
      Nil{}
    case Con{f, rest}:
      Bool.pick(String, String.is_empty(path), f, path ++ "." ++ f) <> Paths.star.names(rest, path)

def Paths.star.table(+st: A.State, +m: Maybe<&2, S.Table>, +table: String, +path: String) -> A.Res():
  match m:
    case None{}:
      A.Res.plain("Table \"" ++ table ++ "\" does not exist")
    case Some{t}:
      A.Res.texts(st, Paths.star.names(S.Table.keys(t), path))

def Paths.star.at(+env: A.Env, +st: A.State, +info: A.Path, +path: String) -> A.Res():
  Paths.star.table(st, S.Schema.table(A.Env.schema(env), A.Path.table(info)), A.Path.table(info), path)

def Paths.star.path(+env: A.Env, +st: A.State, +popped: Popped) -> A.Res():
  match popped:
    case Popped{path, field}:
      A.Res.then_path(Paths.resolve(env, st, path), s => info => Paths.star.at(env, s, info, path))

# `expandStar(state, expr)`: the field names `*` or `path.*` stands for.
def Paths.star(+env: A.Env, +st: A.State, +expr: String) -> A.Res():
  C.If(A.Res(), String.eq(expr, "*"),
    u => Paths.star.at(env, st, Paths.implicit(env), ""),
    u => C.If(A.Res(), String.ends_with(expr, ".*"),
      v => Paths.star.path(env, st, Paths.pop(expr)),
      v => A.Res.type_error("Cannot read properties of undefined (reading 'tableName')")))

# The SQL that creates the views of a schema config:
# packages/loot-core/src/server/aql/views.ts.
#
# Deviation: a view function of the config is data, the SQL around its field
# list and the overrides it passes its maker (see types.bend). A table of
# the config that the schema lacks has no fields here; the TS code crashes.
import Base
import ../lib/core.bend as C
import ./types.bend as S
import ./compiler.bend as K

# `!field.match(/[ .]/)`.
def Views.is_identifier(+field: String) -> Bool:
  Bool.not(Bool.or(String.contains(field, " "), String.contains(field, ".")))

# One field of a select list: `sql AS name`, an identifier taken from the
# root table `_`.
def Views.field(+r: S.Rename) -> String:
  match r:
    case S.Rename{name, sql}:
      Bool.pick(String, Views.is_identifier(sql), "_." ++ sql, sql) ++
        Bool.pick(String, String.eq(sql, name), "", " AS " ++ K.Aql.quote_alias(name))

def Views.fields(+rs: List<&2, S.Rename>) -> List<&2, String>:
  match rs:
    case Nil{}:
      Nil{}
    case Con{r, rest}:
      Views.field(r) <> Views.fields(rest)

# `selectFields(fields)`.
def Views.select_fields(+rs: List<&2, S.Rename>) -> String:
  String.join(Views.fields(rs), ", ")

# `{...fields, [name]: sql}`: a present key keeps its place.
def Views.set(+rs: List<&2, S.Rename>, +name: String, +sql: String) -> List<&2, S.Rename>:
  match rs:
    case Nil{}:
      [S.Rename{name, sql}]
    case Con{S.Rename{n, old}, rest}:
      Bool.pick(List<&2, S.Rename>, String.eq(n, name),
        S.Rename{n, sql} <> rest,
        S.Rename{n, old} <> Views.set(rest, name, sql))

# `{...fields, ...overrides}`.
def Views.merge(+overrides: List<&2, S.Rename>, +fields: List<&2, S.Rename>) -> List<&2, S.Rename>:
  match overrides:
    case Nil{}:
      fields
    case Con{S.Rename{name, sql}, rest}:
      Views.merge(rest, Views.set(fields, name, sql))

# `Object.fromEntries(Object.keys(schema[table]).map(name => [name, name]))`.
def Views.public.of(+names: List<&2, String>) -> List<&2, S.Rename>:
  match names:
    case Nil{}:
      Nil{}
    case Con{n, rest}:
      S.Rename{n, n} <> Views.public.of(rest)

def Views.public.at(+t: Maybe<&2, S.Table>) -> List<&2, S.Rename>:
  match t:
    case None{}:
      Nil{}
    case Some{table}:
      Views.public.of(S.Table.keys(table))

def Views.public(+schema: S.Schema, +table: String) -> List<&2, S.Rename>:
  Views.public.at(S.Schema.table(schema, table))

# `sql.replace(/;$/, '')` on trimmed text.
def Views.no_semicolon(+s: String) -> String:
  Bool.pick(String, String.ends_with(s, ";"), String.take(s, Nat.sub(String.length(s), 1n)), s)

# The SQL of a view: the string, or what its function returns.
def Views.sql(+v: S.View, +public: List<&2, S.Rename>, +internal: List<&2, S.Rename>) -> String:
  match v:
    case S.View{name, 0, overrides, head, tail}:
      head
    case S.View{name, 1, overrides, head, tail}:
      head ++ Views.select_fields(Views.merge(overrides, internal)) ++ tail
    case S.View{name, maker, overrides, head, tail}:
      head ++ Views.select_fields(Views.merge(overrides, public)) ++ tail

def Views.name(+v: S.View) -> String:
  match v:
    case S.View{name, maker, overrides, head, tail}:
      name

def Views.statement(+name: String, +sql: String) -> String:
  "\n        DROP VIEW IF EXISTS " ++ name ++ ";\n        CREATE VIEW " ++ name ++ " AS " ++ sql ++
    ";\n      "

def Views.views(+vs: List<&2, S.View>, +public: List<&2, S.Rename>, +internal: List<&2, S.Rename>) ->
  List<&2, String>:
  match vs:
    case Nil{}:
      Nil{}
    case Con{v, rest}:
      Views.statement(Views.name(v), Views.no_semicolon(String.trim(Views.sql(v, public, internal)))) <>
        Views.views(rest, public, internal)

def Views.table.of(+t: S.TableViews, +public: List<&2, S.Rename>) -> List<&2, String>:
  match t:
    case S.TableViews{table, fields, views}:
      Views.views(views, public, Views.merge(fields, public))

def Views.table.name(+t: S.TableViews) -> String:
  match t:
    case S.TableViews{table, fields, views}:
      table

def Views.tables(+ts: List<&2, S.TableViews>, +schema: S.Schema) -> List<&2, String>:
  match ts:
    case Nil{}:
      Nil{}
    case Con{t, rest}:
      List.append(&2, String, Views.table.of(t, Views.public(schema, Views.table.name(t))),
        Views.tables(rest, schema))

# `makeViews(schema, schemaConfig)`.
def Views.make(+schema: S.Schema, +cfg: S.Config) -> String:
  String.join(Views.tables(S.Config.defs(cfg), schema), "\n")

# The shapes the AQL compiler reads: a table schema (the `schema` object of
# packages/loot-core/src/server/aql/schema/index.ts) and a schema config
# (`SchemaConfig` of server/aql/compiler.ts).
#
# Deviations: a schema is an ordered list of tables with ordered fields, not
# an object. A schema config's JS functions become data: `tableViews` is a
# name -> view object or the function of schema/index.ts (`actual_views`),
# `tableFilters` is a table -> filters object, and `customizeQuery` is either
# the identity or the function of schema/index.ts (`customize`). A field's
# function default (`() => Date.now()`) is `Now`.
import Base
import ../json/json.bend as J
import ./js.bend as Js

type Default is Data:
  NoDefault{}
  Value{json: J.Json}
  Now{}

type Field is Data:
  Field{name: String, kind: String, ref: Maybe<&2, String>, required: Bool, default: Default}

type Table is Data:
  Table{name: String, fields: List<&2, Field>}

type Schema is Data:
  Schema{tables: List<&2, Table>}

type Config is Data:
  Config{views: J.Json, actual_views: Bool, filters: J.Json, customize: Bool}

# `f(type)`.
def Field.of(name: String, kind: String) -> Field:
  Field{name, kind, None{}, False{}, NoDefault{}}

def Field.ref(f: Field, ref: String) -> Field:
  match f:
    case Field{name, kind, old, required, default}:
      Field{name, kind, Some{ref}, required, default}

def Field.required(f: Field) -> Field:
  match f:
    case Field{name, kind, ref, old, default}:
      Field{name, kind, ref, True{}, default}

def Field.default(f: Field, d: Default) -> Field:
  match f:
    case Field{name, kind, ref, required, old}:
      Field{name, kind, ref, required, d}

def Field.name(f: Field) -> String:
  match f:
    case Field{name, kind, ref, required, default}:
      name

def Field.type(f: Field) -> String:
  match f:
    case Field{name, kind, ref, required, default}:
      kind

def Field.get_ref(f: Field) -> Maybe<&2, String>:
  match f:
    case Field{name, kind, ref, required, default}:
      ref

def Field.is_required(f: Field) -> Bool:
  match f:
    case Field{name, kind, ref, required, default}:
      required

def Field.get_default(f: Field) -> Default:
  match f:
    case Field{name, kind, ref, required, default}:
      default

def Table.name(t: Table) -> String:
  match t:
    case Table{name, fields}:
      name

def Table.fields(t: Table) -> List<&2, Field>:
  match t:
    case Table{name, fields}:
      fields

def Table.field.go(fields: List<&2, Field>, +name: String) -> Maybe<&2, Field>:
  match fields:
    case Nil{}:
      None{}
    case Con{+f, rest}:
      Bool.pick(Maybe<&2, Field>, String.eq(Field.name(f), name), Some{f},
        Table.field.go(rest, name))

# `table[name]`.
def Table.field(t: Table, +name: String) -> Maybe<&2, Field>:
  Table.field.go(Table.fields(t), name)

def Table.has(t: Table, +name: String) -> Bool:
  Maybe.is_some(&2, Field, Table.field(t, name))

# `Object.keys(table)`.
def Table.keys(t: Table) -> List<&2, String>:
  Js.Js.map(~Field, ~String, ~Field.name, Table.fields(t))

def Schema.tables(s: Schema) -> List<&2, Table>:
  match s:
    case Schema{tables}:
      tables

def Schema.table.go(tables: List<&2, Table>, +name: String) -> Maybe<&2, Table>:
  match tables:
    case Nil{}:
      None{}
    case Con{+t, rest}:
      Bool.pick(Maybe<&2, Table>, String.eq(Table.name(t), name), Some{t},
        Schema.table.go(rest, name))

# `schema[name]`.
def Schema.table(s: Schema, +name: String) -> Maybe<&2, Table>:
  Schema.table.go(Schema.tables(s), name)

# Reading a schema written as JSON: `{table: {field: {type, ref?, required?,
# default?}}}`.

def Schema.read.default(m: Maybe<&2, J.Json>) -> Default:
  match m:
    case None{}:
      NoDefault{}
    case Some{j}:
      Value{j}

def Schema.read.field(m: J.Json.Member) -> Field:
  match m:
    case J.Member{name, +desc}:
      Field{name,
        Js.Js.text(Maybe.default(&2, J.Json, J.Json.get(desc, "type"), J.JNull{})),
        Maybe.bind(&2, J.Json, String, J.Json.get(desc, "ref"), J.Json.as_string),
        Js.Js.truthy(Maybe.default(&2, J.Json, J.Json.get(desc, "required"), J.JNull{})),
        Schema.read.default(J.Json.get(desc, "default"))}

def Schema.read.table(m: J.Json.Member) -> Table:
  match m:
    case J.Member{name, fields}:
      Table{name, Js.Js.map(~J.Json.Member, ~Field, ~Schema.read.field, J.Json.members(fields))}

def Schema.read(j: J.Json) -> Schema:
  Schema{Js.Js.map(~J.Json.Member, ~Table, ~Schema.read.table, J.Json.members(j))}

# The config with no views, no filters and no customization: `{}`.
def Config.empty() -> Config:
  Config{J.JObj{J.JEnd{}}, False{}, J.JObj{J.JEnd{}}, False{}}

def Config.get(j: J.Json, key: String) -> J.Json:
  Maybe.default(&2, J.Json, J.Json.get(j, key), J.JObj{J.JEnd{}})

# Reading a config written as JSON: `{tableViews?: {name: view},
# tableFilters?: {table: [filter]}}`.
def Config.read(+j: J.Json) -> Config:
  Config{Config.get(j, "tableViews"), False{}, Config.get(j, "tableFilters"), False{}}

def Config.views(c: Config) -> J.Json:
  match c:
    case Config{views, actual_views, filters, customize}:
      views

def Config.actual_views(c: Config) -> Bool:
  match c:
    case Config{views, actual_views, filters, customize}:
      actual_views

def Config.customize(c: Config) -> Bool:
  match c:
    case Config{views, actual_views, filters, customize}:
      customize

# `tableFilters(name)`: the filters of a table, an array; empty when none.
def Config.filters(c: Config, name: String) -> J.Json:
  match c:
    case Config{views, actual_views, filters, customize}:
      Maybe.default(&2, J.Json, J.Json.get(filters, name), J.JArr{J.JEnd{}})

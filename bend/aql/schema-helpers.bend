# Converting rows between the app and the database by a table schema:
# packages/loot-core/src/server/aql/schema-helpers.ts, with `toDateRepr` and
# `fromDateRepr` of server/models.ts.
#
# Deviations: rows and values are JSON, so a value is never a `Date`
# (`dayFromDate` is not needed) and an `undefined` field is an absent one.
# A thrown `Error` is a `Fail` with its message; where the TS code crashes
# with a JS `TypeError` (a number given for a date, say) the message starts
# with "TypeError". `Date.now()`, the default of a `Now` field, is the
# argument `now`. `parseInt` answering NaN is null.
import Base
import ../json/json.bend as J
import ../lib/core.bend as C
import ./js.bend as V
import ./types.bend as S

def Helpers.Res() -> Data:
  Result<&2, &2, String, J.Json>

# `isRequired(name, fieldDesc)`.
def Helpers.is_required(+f: S.Field) -> Bool:
  Bool.or(S.Field.is_required(f), String.eq(S.Field.name(f), "id"))

def Helpers.no_dash(+s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{'-', t}:
      Helpers.no_dash(t)
    case SCon{c, t}:
      SCon{c, Helpers.no_dash(t)}

# The decimal digits a text starts with.
def Helpers.digits(+s: String) -> String:
  match s:
    case SCon{c, t}:
      Bool.pick(String, Char.is_digit(c), SCon{c, Helpers.digits(t)}, SNil{})
    case SNil{}:
      SNil{}

def Helpers.number(+m: Maybe<&2, Nat>) -> J.Json:
  match m:
    case None{}:
      J.JNull{}
    case Some{n}:
      J.Json.nat(n)

def Helpers.parse_int(+digits: String) -> J.Json:
  Bool.pick(J.Json, String.is_empty(digits), J.JNull{}, Helpers.number(Nat.read(digits)))

# `toDateRepr(str)`: `parseInt(str.replace(/-/g, ''))`.
def Helpers.to_date_repr(+s: String) -> J.Json:
  Helpers.parse_int(Helpers.digits(Helpers.no_dash(s)))

def Helpers.shape(+s: String, +pat: String) -> Bool:
  match s pat:
    case SNil{} SNil{}:
      True{}
    case SCon{c, t} SCon{'d', p}:
      Bool.and(Char.is_digit(c), Helpers.shape(t, p))
    case SCon{c, t} SCon{q, p}:
      Bool.and(Char.is_eq(c, q), Helpers.shape(t, p))
    case _ _:
      False{}

def Helpers.input.date(+value: J.Json) -> Helpers.Res():
  match value:
    case J.JStr{s}:
      Bool.pick(Helpers.Res(),
        Bool.and(Helpers.shape(s, "dddd-dd-dd"), String.is_ge(s, "1995-01-01")),
        Done{Helpers.to_date_repr(s)}, Fail{"Invalid date: " ++ s})
    case other:
      Fail{"TypeError: value.match is not a function"}

# `toDateRepr(value.slice(0, n))`.
def Helpers.input.part(+value: J.Json, +n: Nat) -> Helpers.Res():
  match value:
    case J.JStr{s}:
      Done{Helpers.to_date_repr(String.take(s, n))}
    case other:
      Fail{"TypeError: value.slice is not a function"}

def Helpers.input.id(+value: J.Json) -> Helpers.Res():
  match value:
    case J.JStr{s}:
      Done{value}
    case other:
      Fail{"Invalid id, must be string: " ++ V.Js.string(value)}

def Helpers.input.integer(+value: J.Json) -> Helpers.Res():
  match value:
    case J.JInt{i}:
      Done{value}
    case other:
      Fail{"Can't convert to integer: " ++ J.Json.show(value)}

def Helpers.input.typed(+value: J.Json, +kind: String) -> Helpers.Res():
  match kind:
    case "date":
      Helpers.input.date(value)
    case "date-month":
      Helpers.input.part(value, 7n)
    case "date-year":
      Helpers.input.part(value, 4n)
    case "boolean":
      Done{J.Json.nat(Bool.pick(Nat, V.Js.truthy(value), 1n, 0n))}
    case "id":
      Helpers.input.id(value)
    case "integer":
      Helpers.input.integer(value)
    case "json":
      Done{J.JStr{J.Json.show(value)}}
    case other:
      Done{value}

def Helpers.null(+kind: String, +zero: J.Json) -> J.Json:
  match kind:
    case "boolean":
      zero
    case other:
      J.JNull{}

# `convertInputType(value, type)`.
def Helpers.convert_input_type(+value: J.Json, +kind: String) -> Helpers.Res():
  match value:
    case J.JNull{}:
      Done{Helpers.null(kind, J.Json.nat(0n))}
    case other:
      Helpers.input.typed(value, kind)

# `fromDateRepr(number)`.
def Helpers.from_date_repr.text(+s: String) -> String:
  String.take(s, 4n) ++ "-" ++ String.take(String.drop(s, 4n), 2n) ++ "-" ++ String.drop(s, 6n)

def Helpers.from_date_repr(+value: Maybe<&2, J.Json>) -> Result<&2, &2, String, String>:
  match value:
    case Some{J.JInt{i}}:
      Done{Helpers.from_date_repr.text(V.Js.string(J.JInt{i}))}
    case Some{J.JDec{t}}:
      Done{Helpers.from_date_repr.text(t)}
    case Some{other}:
      Fail{"fromDateRepr not passed a number: " ++ V.Js.string(other)}
    case None{}:
      Fail{"fromDateRepr not passed a number: undefined"}

def Helpers.output.date(+r: Result<&2, &2, String, String>, +n: Nat) -> Result<&2, &2, String, Maybe<&2, J.Json>>:
  match r:
    case Fail{msg}:
      Fail{msg}
    case Done{s}:
      Done{Some{J.JStr{String.take(s, n)}}}

# `JSON.parse(value)`, or what the `catch` answers.
def Helpers.output.json(+value: Maybe<&2, J.Json>, +fallback: Bool) -> Maybe<&2, J.Json>:
  match value:
    case None{}:
      Bool.pick(Maybe<&2, J.Json>, fallback, None{}, Some{J.JNull{}})
    case Some{v}:
      Some{Maybe.default(&2, J.Json, J.Json.parse(V.Js.string(v)),
        Bool.pick(J.Json, fallback, v, J.JNull{}))}

def Helpers.is_one(+value: Maybe<&2, J.Json>) -> Bool:
  match value:
    case Some{J.JInt{i}}:
      String.eq(V.Js.string(J.JInt{i}), "1")
    case other:
      False{}

def Helpers.output.typed(+value: Maybe<&2, J.Json>, +kind: String) ->
  Result<&2, &2, String, Maybe<&2, J.Json>>:
  match kind:
    case "date":
      Helpers.output.date(Helpers.from_date_repr(value), 10n)
    case "date-month":
      Helpers.output.date(Helpers.from_date_repr(value), 7n)
    case "date-year":
      Helpers.output.date(Helpers.from_date_repr(value), 4n)
    case "boolean":
      Done{Some{J.JBool{Helpers.is_one(value)}}}
    case "json":
      Done{Helpers.output.json(value, False{})}
    case "json/fallback":
      Done{Helpers.output.json(value, True{})}
    case other:
      Done{value}

# `convertOutputType(value, type)`; None is `undefined`.
def Helpers.convert_output_type(+value: Maybe<&2, J.Json>, +kind: String) ->
  Result<&2, &2, String, Maybe<&2, J.Json>>:
  match value:
    case Some{J.JNull{}}:
      Done{Some{Helpers.null(kind, J.JBool{False{}})}}
    case other:
      Helpers.output.typed(value, kind)

def Helpers.rename.at(+rs: List<&2, S.Rename>, +field: String) -> String:
  match rs:
    case Nil{}:
      field
    case Con{S.Rename{name, sql}, rest}:
      Bool.pick(String, Bool.and(String.eq(name, field), Bool.not(String.is_empty(sql))), sql,
        Helpers.rename.at(rest, field))

# `fieldRef(field)`: the column a field of a table is stored in.
def Helpers.rename(+defs: List<&2, S.TableViews>, +table: String, +field: String) -> String:
  match defs:
    case Nil{}:
      field
    case Con{S.TableViews{name, fields, views}, rest}:
      Bool.pick(String, String.eq(name, table), Helpers.rename.at(fields, field),
        Helpers.rename(rest, table, field))

# What `conform` reads besides the row: the config, the table and its name,
# the whole row for messages, and `skipNull`.
type Conform is Data:
  Conform{cfg: S.Config, name: String, table: S.Table, obj: J.Json, skip_null: Bool}

def Helpers.put(+key: String, +r: Helpers.Res(), +rest: Result<&2, &2, String, List<&2, J.Json.Member>>) ->
  Result<&2, &2, String, List<&2, J.Json.Member>>:
  match r rest:
    case Fail{msg} _:
      Fail{msg}
    case Done{v} Fail{msg}:
      Fail{msg}
    case Done{v} Done{ms}:
      Done{J.Member{key, v} <> ms}

# One field of a row: 0 skip it, 1 it does not exist, 2 it is required, 3
# convert it.
def Helpers.conform.class(+c: Conform, +field: String, +value: J.Json, +desc: Maybe<&2, S.Field>) -> U32:
  match c desc:
    case Conform{cfg, name, table, obj, skip_null} None{}:
      Bool.pick(U32, String.starts_with(field, "_"), 0, 1)
    case Conform{cfg, name, table, obj, skip_null} Some{f}:
      Bool.pick(U32, String.starts_with(field, "_"), 0,
        Bool.pick(U32, Bool.and(Helpers.is_required(f), V.Js.is_null(value)), 2,
          Bool.pick(U32, Bool.and(skip_null, V.Js.is_null(value)), 0, 3)))

def Helpers.conform.kind(+desc: Maybe<&2, S.Field>) -> String:
  match desc:
    case None{}:
      ""
    case Some{f}:
      S.Field.type(f)

def Helpers.conform.one(
  +class: U32, +c: Conform, +field: String, +value: J.Json, +kind: String,
  +rest: Result<&2, &2, String, List<&2, J.Json.Member>>
) -> Result<&2, &2, String, List<&2, J.Json.Member>>:
  match class c:
    case 0 _:
      rest
    case 1 Conform{cfg, name, table, obj, skip_null}:
      Fail{"Field \"" ++ field ++ "\" does not exist on table " ++ name ++ ": " ++ J.Json.show(obj)}
    case 2 Conform{cfg, name, table, obj, skip_null}:
      Fail{"\"" ++ field ++ "\" is required for table \"" ++ name ++ "\": " ++ J.Json.show(obj)}
    case _ Conform{cfg, name, table, obj, skip_null}:
      Helpers.put(Helpers.rename(S.Config.defs(cfg), name, field),
        Helpers.convert_input_type(value, kind), rest)

def Helpers.conform.table(+c: Conform) -> S.Table:
  match c:
    case Conform{cfg, name, table, obj, skip_null}:
      table

# The fields of a row, in order; the first failure wins.
def Helpers.conform.go(+ms: List<&2, J.Json.Member>, +c: Conform) ->
  Result<&2, &2, String, List<&2, J.Json.Member>>:
  match ms:
    case Nil{}:
      Done{Nil{}}
    case Con{J.Member{field, value}, rest}:
      Helpers.conform.one(
        Helpers.conform.class(c, field, value, S.Table.field(Helpers.conform.table(c), field)),
        c, field, value, Helpers.conform.kind(S.Table.field(Helpers.conform.table(c), field)),
        Helpers.conform.go(rest, c))

def Helpers.object(+r: Result<&2, &2, String, List<&2, J.Json.Member>>) -> Helpers.Res():
  match r:
    case Fail{msg}:
      Fail{msg}
    case Done{ms}:
      Done{J.Json.object(ms)}

def Helpers.conform.at(
  +t: Maybe<&2, S.Table>, +cfg: S.Config, +name: String, +obj: J.Json, +skip_null: Bool
) -> Helpers.Res():
  match t:
    case None{}:
      Fail{"Table \"" ++ name ++ "\" does not exist"}
    case Some{table}:
      Helpers.object(Helpers.conform.go(J.Json.members(obj), Conform{cfg, name, table, obj, skip_null}))

# `conform(schema, schemaConfig, table, obj, {skipNull})`.
def Helpers.conform(+schema: S.Schema, +cfg: S.Config, +table: String, +obj: J.Json, +skip_null: Bool) ->
  Helpers.Res():
  Helpers.conform.at(S.Schema.table(schema, table), cfg, table, obj, skip_null)

# `obj[key] = value`: a present key keeps its place.
def Helpers.set(+ms: List<&2, J.Json.Member>, +key: String, +value: J.Json) -> List<&2, J.Json.Member>:
  match ms:
    case Nil{}:
      [J.Member{key, value}]
    case Con{J.Member{k, v}, rest}:
      Bool.pick(List<&2, J.Json.Member>, String.eq(k, key),
        J.Member{k, value} <> rest,
        J.Member{k, v} <> Helpers.set(rest, key, value))

# `obj[field] == null`.
def Helpers.is_nullish(+m: Maybe<&2, J.Json>) -> Bool:
  match m:
    case Some{J.JNull{}}:
      True{}
    case None{}:
      True{}
    case other:
      False{}

# A field that the row leaves null takes its default, or must not be
# required.
def Helpers.insert.fill(+f: S.Field, +name: String, +obj: List<&2, J.Json.Member>, +now: J.Json) ->
  Result<&2, &2, String, List<&2, J.Json.Member>>:
  match f:
    case S.Field{field, kind, ref, required, S.Value{json}}:
      Done{Helpers.set(obj, field, json)}
    case S.Field{field, kind, ref, required, S.Now{}}:
      Done{Helpers.set(obj, field, now)}
    case S.Field{field, kind, ref, required, S.NoDefault{}}:
      Bool.pick(Result<&2, &2, String, List<&2, J.Json.Member>>,
        Bool.or(required, String.eq(field, "id")),
        Fail{"\"" ++ field ++ "\" is required for table \"" ++ name ++ "\": " ++
          J.Json.show(J.Json.object(obj))},
        Done{obj})

def Helpers.insert.step(+f: S.Field, +name: String, +obj: List<&2, J.Json.Member>, +now: J.Json) ->
  Result<&2, &2, String, List<&2, J.Json.Member>>:
  C.If(Result<&2, &2, String, List<&2, J.Json.Member>>,
    Helpers.is_nullish(J.Json.get(J.Json.object(obj), S.Field.name(f))),
    u => Helpers.insert.fill(f, name, obj, now),
    u => Done{obj})

def Helpers.insert.go(+fields: List<&2, S.Field>, +name: String, +obj: List<&2, J.Json.Member>, +now: J.Json) ->
  Result<&2, &2, String, List<&2, J.Json.Member>>:
  match fields:
    case Nil{}:
      Done{obj}
    case Con{f, rest}:
      Result.bind(&2, &2, String, List<&2, J.Json.Member>, List<&2, J.Json.Member>,
        Helpers.insert.step(f, name, obj, now), o => Helpers.insert.go(rest, name, o, now))

def Helpers.insert.conform(
  +schema: S.Schema, +cfg: S.Config, +table: String,
  +r: Result<&2, &2, String, List<&2, J.Json.Member>>
) -> Helpers.Res():
  match r:
    case Fail{msg}:
      Fail{msg}
    case Done{ms}:
      Helpers.conform(schema, cfg, table, J.Json.object(ms), True{})

def Helpers.insert.at(
  +t: Maybe<&2, S.Table>, +schema: S.Schema, +cfg: S.Config, +table: String, +obj: J.Json, +now: J.Json
) -> Helpers.Res():
  match t:
    case None{}:
      Fail{"Error inserting: table \"" ++ table ++ "\" does not exist"}
    case Some{desc}:
      Helpers.insert.conform(schema, cfg, table,
        Helpers.insert.go(S.Table.fields(desc), table, J.Json.members(obj), now))

# `convertForInsert(schema, schemaConfig, table, rawObj)`; `now` is
# `Date.now()`.
def Helpers.convert_for_insert(
  +schema: S.Schema, +cfg: S.Config, +table: String, +obj: J.Json, +now: J.Json
) -> Helpers.Res():
  Helpers.insert.at(S.Schema.table(schema, table), schema, cfg, table, obj, now)

def Helpers.update.at(
  +t: Maybe<&2, S.Table>, +schema: S.Schema, +cfg: S.Config, +table: String, +obj: J.Json
) -> Helpers.Res():
  match t:
    case None{}:
      Fail{"Error updating: table \"" ++ table ++ "\" does not exist"}
    case Some{desc}:
      Helpers.conform(schema, cfg, table, obj, False{})

# `convertForUpdate(schema, schemaConfig, table, rawObj)`.
def Helpers.convert_for_update(+schema: S.Schema, +cfg: S.Config, +table: String, +obj: J.Json) ->
  Helpers.Res():
  Helpers.update.at(S.Schema.table(schema, table), schema, cfg, table, obj)

def Helpers.select.put(
  +key: String, +r: Result<&2, &2, String, Maybe<&2, J.Json>>,
  +rest: Result<&2, &2, String, List<&2, J.Json.Member>>
) -> Result<&2, &2, String, List<&2, J.Json.Member>>:
  match r rest:
    case Fail{msg} _:
      Fail{msg}
    case Done{v} Fail{msg}:
      Fail{msg}
    case Done{None{}} Done{ms}:
      Done{ms}
    case Done{Some{v}} Done{ms}:
      Done{J.Member{key, v} <> ms}

def Helpers.select.go(+fields: List<&2, S.Field>, +obj: J.Json) ->
  Result<&2, &2, String, List<&2, J.Json.Member>>:
  match fields:
    case Nil{}:
      Done{Nil{}}
    case Con{f, rest}:
      Helpers.select.put(S.Field.name(f),
        Helpers.convert_output_type(J.Json.get(obj, S.Field.name(f)), S.Field.type(f)),
        Helpers.select.go(rest, obj))

def Helpers.select.at(+t: Maybe<&2, S.Table>, +table: String, +obj: J.Json) -> Helpers.Res():
  match t:
    case None{}:
      Fail{"Table \"" ++ table ++ "\" does not exist"}
    case Some{desc}:
      Helpers.object(Helpers.select.go(S.Table.fields(desc), obj))

# `convertFromSelect(schema, schemaConfig, table, obj)`: every field of the
# table, an `undefined` one left out.
def Helpers.convert_from_select(+schema: S.Schema, +cfg: S.Config, +table: String, +obj: J.Json) ->
  Helpers.Res():
  Helpers.select.at(S.Schema.table(schema, table), table, obj)

# The query builder of packages/loot-core/src/shared/query.ts.
#
# Deviations: the `Query` class is its `QueryState`; each method is a def
# from a state to a new state. Expressions are JSON values. `unfilter()`
# with no argument is `Query.unfilter_all`.
import Base
import ../json/json.bend as J
import ../lib/core.bend as C
import ./js.bend as V

type QueryState is Data:
  QueryState{table: String, table_options: J.Json, filter_expressions: List<&2, J.Json>,
    select_expressions: List<&2, J.Json>, group_expressions: List<&2, J.Json>,
    order_expressions: List<&2, J.Json>, calculation: Bool, raw_mode: Bool, with_dead: Bool,
    validate_refs: Bool, limit: J.Json, offset: J.Json}

# `q(table)`.
def Query.q(+table: String) -> QueryState:
  QueryState{table, J.JObj{J.JEnd{}}, Nil{}, Nil{}, Nil{}, Nil{}, False{}, False{}, False{}, True{},
    J.JNull{}, J.JNull{}}

def Query.table(+q: QueryState) -> String:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      table

def Query.table_options(+q: QueryState) -> J.Json:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      options

def Query.filter_expressions(+q: QueryState) -> List<&2, J.Json>:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      filters

def Query.select_expressions(+q: QueryState) -> List<&2, J.Json>:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      selects

def Query.group_expressions(+q: QueryState) -> List<&2, J.Json>:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      groups

def Query.order_expressions(+q: QueryState) -> List<&2, J.Json>:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      orders

def Query.calculation(+q: QueryState) -> Bool:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      calc

def Query.raw_mode(+q: QueryState) -> Bool:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      raw

def Query.is_with_dead(+q: QueryState) -> Bool:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      dead

def Query.validate_refs(+q: QueryState) -> Bool:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      refs

def Query.get_limit(+q: QueryState) -> J.Json:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      limit

def Query.get_offset(+q: QueryState) -> J.Json:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      offset

# `Array.isArray(exprs) ? exprs : [exprs]`.
def Query.list(+exprs: J.Json) -> List<&2, J.Json>:
  match exprs:
    case J.JArr{cells}:
      J.Json.items(exprs)
    case other:
      [exprs]

def Query.filter(+q: QueryState, +expr: J.Json) -> QueryState:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      QueryState{table, options, List.append(&2, J.Json, filters, [expr]), selects, groups, orders,
        calc, raw, dead, refs, limit, offset}

def Query.set_filters(+q: QueryState, +fs: List<&2, J.Json>) -> QueryState:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      QueryState{table, options, fs, selects, groups, orders, calc, raw, dead, refs, limit, offset}

# `unfilter()`: no filters.
def Query.unfilter_all(+q: QueryState) -> QueryState:
  Query.set_filters(q, Nil{})

def Query.has_key(+keys: List<&2, String>, +key: String) -> Bool:
  match keys:
    case Nil{}:
      False{}
    case Con{k, rest}:
      Bool.or(String.eq(k, key), Query.has_key(rest, key))

# `exprSet.has(Object.keys(expr)[0])`.
def Query.first_in(+expr: J.Json, +keys: List<&2, String>) -> Bool:
  match expr:
    case J.JObj{J.JPair{k, v, rest}}:
      Query.has_key(keys, k)
    case other:
      False{}

def Query.unfilter.go(+fs: List<&2, J.Json>, +keys: List<&2, String>) -> List<&2, J.Json>:
  match fs:
    case Nil{}:
      Nil{}
    case Con{f, rest}:
      List.append(&2, J.Json,
        Bool.pick(List<&2, J.Json>, Query.first_in(f, keys), Nil{}, [f]),
        Query.unfilter.go(rest, keys))

# `unfilter(exprs)`: without the filters whose first key is one of `keys`.
def Query.unfilter(+q: QueryState, +keys: List<&2, String>) -> QueryState:
  Query.set_filters(q, Query.unfilter.go(Query.filter_expressions(q), keys))

def Query.set_selects(+q: QueryState, +exprs: List<&2, J.Json>, +calculation: Bool) -> QueryState:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      QueryState{table, options, filters, exprs, groups, orders, calculation, raw, dead, refs, limit, offset}

# `select(exprs)`; `select()` is `Query.select(q, [])`.
def Query.select(+q: QueryState, +exprs: J.Json) -> QueryState:
  Query.set_selects(q, Query.list(exprs), False{})

def Query.calculate(+q: QueryState, +expr: J.Json) -> QueryState:
  Query.set_selects(q, [V.Js.single("result", expr)], True{})

def Query.group_by(+q: QueryState, +exprs: J.Json) -> QueryState:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      QueryState{table, options, filters, selects, List.append(&2, J.Json, groups, Query.list(exprs)),
        orders, calc, raw, dead, refs, limit, offset}

def Query.order_by(+q: QueryState, +exprs: J.Json) -> QueryState:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      QueryState{table, options, filters, selects, groups,
        List.append(&2, J.Json, orders, Query.list(exprs)), calc, raw, dead, refs, limit, offset}

# `{...queryState, orderExpressions: exprs}`.
def Query.set_orders(+q: QueryState, +exprs: List<&2, J.Json>) -> QueryState:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      QueryState{table, options, filters, selects, groups, exprs, calc, raw, dead, refs, limit, offset}

def Query.limit(+q: QueryState, +num: J.Json) -> QueryState:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, num, offset}

def Query.offset(+q: QueryState, +num: J.Json) -> QueryState:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, num}

def Query.raw(+q: QueryState) -> QueryState:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      QueryState{table, options, filters, selects, groups, orders, calc, True{}, dead, refs, limit, offset}

def Query.with_dead(+q: QueryState) -> QueryState:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      QueryState{table, options, filters, selects, groups, orders, calc, raw, True{}, refs, limit, offset}

def Query.without_validated_refs(+q: QueryState) -> QueryState:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, False{}, limit, offset}

def Query.options(+q: QueryState, +opts: J.Json) -> QueryState:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      QueryState{table, opts, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}

def Query.reset(+q: QueryState) -> QueryState:
  Query.q(Query.table(q))

# `serialize()` as the JSON object `serializeAsString()` writes, its keys in
# the order the `Query` constructor sets them.
def Query.serialize(+q: QueryState) -> J.Json:
  match q:
    case QueryState{table, options, filters, selects, groups, orders, calc, raw, dead, refs, limit, offset}:
      J.Json.object([
        J.Member{"tableOptions", options},
        J.Member{"filterExpressions", J.Json.array(filters)},
        J.Member{"selectExpressions", J.Json.array(selects)},
        J.Member{"groupExpressions", J.Json.array(groups)},
        J.Member{"orderExpressions", J.Json.array(orders)},
        J.Member{"calculation", J.JBool{calc}},
        J.Member{"rawMode", J.JBool{raw}},
        J.Member{"withDead", J.JBool{dead}},
        J.Member{"validateRefs", J.JBool{refs}},
        J.Member{"limit", limit},
        J.Member{"offset", offset},
        J.Member{"table", J.JStr{table}}])

def Query.serialize_as_string(+q: QueryState) -> String:
  J.Json.show(Query.serialize(q))

def Query.read.get(+j: J.Json, +key: String) -> J.Json:
  Maybe.default(&2, J.Json, J.Json.get(j, key), J.JNull{})

# `state.key || []`.
def Query.read.list(+j: J.Json, +key: String) -> List<&2, J.Json>:
  J.Json.items(Query.read.get(j, key))

# A key's value, or `d` when the key is absent.
def Query.read.flag(+j: J.Json, +key: String, +d: Bool) -> Bool:
  Maybe.default(&2, Bool, Maybe.map(&2, J.Json, Bool, v => V.Js.truthy(v), J.Json.get(j, key)), d)

def Query.read.options(+j: J.Json) -> J.Json:
  Bool.pick(J.Json, V.Js.truthy(j), j, J.JObj{J.JEnd{}})

# `new Query(state).state` for a state written as JSON, as `serialize()`
# gives it; an absent key takes the constructor's default.
def Query.read(+j: J.Json) -> QueryState:
  QueryState{V.Js.text(Query.read.get(j, "table")),
    Query.read.options(Query.read.get(j, "tableOptions")),
    Query.read.list(j, "filterExpressions"), Query.read.list(j, "selectExpressions"),
    Query.read.list(j, "groupExpressions"), Query.read.list(j, "orderExpressions"),
    Query.read.flag(j, "calculation", False{}), Query.read.flag(j, "rawMode", False{}),
    Query.read.flag(j, "withDead", False{}), Query.read.flag(j, "validateRefs", True{}),
    Query.read.get(j, "limit"), Query.read.get(j, "offset")}

def Query.order_of.first(+m: Maybe<&2, J.Json.Member>) -> J.Json:
  match m:
    case None{}:
      J.JObj{J.JEnd{}}
    case Some{J.Member{field, order}}:
      J.Json.object([J.Member{"field", J.JStr{field}}, J.Member{"order", order}])

def Query.order_of.expr(+first: J.Json) -> J.Json:
  match first:
    case J.JStr{field}:
      J.Json.object([J.Member{"field", first}, J.Member{"order", J.JStr{"asc"}}])
    case other:
      Query.order_of.first(List.head(&2, J.Json.Member, V.Js.entries(first)))

def Query.without_order(+ms: List<&2, J.Json.Member>) -> List<&2, J.Json.Member>:
  match ms:
    case Nil{}:
      Nil{}
    case Con{J.Member{k, v}, rest}:
      List.append(&2, J.Json.Member,
        Bool.pick(List<&2, J.Json.Member>, String.eq(k, "order"), Nil{}, [J.Member{k, v}]),
        Query.without_order(rest))

# `{order: 'asc', ...defaultOrderBy}`, or null without a default.
def Query.order_of.default(+d: J.Json) -> J.Json:
  C.If(J.Json, V.Js.truthy(d),
    u => J.Json.object(
      J.Member{"order", Maybe.default(&2, J.Json, J.Json.get(d, "order"), J.JStr{"asc"})} <>
        Query.without_order(J.Json.members(d))),
    u => J.JNull{})

def Query.order_of.pick(+orders: List<&2, J.Json>, +d: J.Json) -> J.Json:
  match orders:
    case Nil{}:
      Query.order_of.default(d)
    case Con{first, rest}:
      Query.order_of.expr(first)

# `getPrimaryOrderBy(query, defaultOrderBy)`: `{field, order}`, or null.
def Query.get_primary_order_by(+q: QueryState, +default_order_by: J.Json) -> J.Json:
  Query.order_of.pick(Query.order_expressions(q), default_order_by)

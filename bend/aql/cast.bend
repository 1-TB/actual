# Literals, type casts and SQL values of the AQL compiler: `compileLiteral`,
# `parseDate`, `parseMonth`, `parseYear`, `castInput`, `val`, `valArray` and
# `validateArgLength` of packages/loot-core/src/server/aql/compiler.ts.
#
# Deviations: a query value is JSON, so there is no `undefined` and no `Date`
# literal (`nativeDateToInt` is not ported). A number written with a
# fraction or an exponent is a float even when its value is whole, and is
# written to SQL as it was read.
import Base
import ../json/json.bend as J
import ../lib/int.bend as I
import ../lib/core.bend as C
import ./js.bend as V
import ./state.bend as A

# Whether s has the shape of pat, where `d` stands for one digit and any
# other character for itself: "dddd-dd-dd" is /^\d{4}-\d{2}-\d{2}$/.
def Cast.shape(+s: String, +pat: String) -> Bool:
  match s pat:
    case SNil{} SNil{}:
      True{}
    case SCon{c, t} SCon{'d', p}:
      Bool.and(Char.is_digit(c), Cast.shape(t, p))
    case SCon{c, t} SCon{q, p}:
      Bool.and(Char.is_eq(c, q), Cast.shape(t, p))
    case _ _:
      False{}

def Cast.no_dash(+s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{'-', t}:
      Cast.no_dash(t)
    case SCon{c, t}:
      SCon{c, Cast.no_dash(t)}

# `String(parseInt(digits))`: no leading zeros.
def Cast.int_text(+s: String) -> String:
  match s:
    case SCon{'0', SNil{}}:
      "0"
    case SCon{'0', t}:
      Cast.int_text(t)
    case other:
      other

# `dateToInt(date)` as text.
def Cast.date_int(+s: String) -> String:
  Cast.int_text(Cast.no_dash(s))

def Cast.parse(+s: String, +pat: String) -> Maybe<&2, A.Typed>:
  Bool.pick(Maybe<&2, A.Typed>, Cast.shape(s, pat),
    Some{A.Typed.lit(Cast.date_int(s), "date")}, None{})

# `parseDate(str)`.
def Cast.parse_date(+s: String) -> Maybe<&2, A.Typed>:
  Cast.parse(s, "dddd-dd-dd")

# `parseMonth(str)`.
def Cast.parse_month(+s: String) -> Maybe<&2, A.Typed>:
  Cast.parse(s, "dddd-dd")

# `parseYear(str)`.
def Cast.parse_year(+s: String) -> Maybe<&2, A.Typed>:
  Cast.parse(s, "dddd")

# `value.replace(/\\\$/g, '$')`.
def Cast.unescape(+s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{'\\', SCon{'$', t}}:
      SCon{'$', Cast.unescape(t)}
    case SCon{c, t}:
      SCon{c, Cast.unescape(t)}

# `compileLiteral(value)`.
def Cast.literal(+st: A.State, +j: J.Json) -> A.Res():
  match j:
    case J.JNull{}:
      A.Res.typed(st, A.Typed.lit("NULL", "null"))
    case J.JStr{s}:
      A.Res.typed(st, A.Typed.lit(Cast.unescape(s), "string"))
    case J.JBool{b}:
      A.Res.typed(st, A.Typed.lit(Bool.pick(String, b, "1", "0"), "boolean"))
    case J.JInt{i}:
      A.Res.typed(st, A.Typed.lit(I.Int.show(i), "integer"))
    case J.JDec{text}:
      A.Res.typed(st, A.Typed.lit(text, "float"))
    case J.JArr{cells}:
      A.Res.typed(st, A.Typed{V.Js.string(j), "array", True{}, 0n, Some{j}})
    case other:
      A.Res.throw(st, "Unsupported type of expression: " ++ J.Json.show(j))

# The first parse that answers.
def Cast.first(+ms: List<&2, Maybe<&2, A.Typed>>) -> Maybe<&2, A.Typed>:
  match ms:
    case Nil{}:
      None{}
    case Con{Some{t}, rest}:
      Some{t}
    case Con{None{}, rest}:
      Cast.first(rest)

# The month (n = 6) or the year (n = 4) of a date expression.
def Cast.part(+st: A.State, +e: A.Typed, +n: Nat, +kind: String) -> A.Res():
  A.Res.typed(st, Bool.pick(A.Typed, A.Typed.literal(e),
    A.Typed.lit(Cast.date_int(String.take(A.Typed.value(e), n)), kind),
    A.Typed.make("CAST(SUBSTR(" ++ A.Typed.value(e) ++ ", 1, " ++ Nat.show(n) ++ ") AS integer)", kind)))

# A parsed date, or `badDateFormat(str, kind)`.
def Cast.parsed(+st: A.State, +m: Maybe<&2, A.Typed>, +str: String, +kind: String) -> A.Res():
  match m:
    case None{}:
      A.Res.throw(st, "Bad " ++ kind ++ " format: " ++ str)
    case Some{t}:
      A.Res.typed(st, t)

def Cast.to_date(+st: A.State, +e: A.Typed, +src: String, +literal: Bool) -> A.Res():
  match src literal:
    case "string" True{}:
      Cast.parsed(st, Cast.parse_date(A.Typed.value(e)), A.Typed.value(e), "date")
    case "string" False{}:
      A.Res.throw(st, "Casting string fields to dates is not supported")
    case other _:
      A.Res.throw(st, "Can't cast " ++ other ++ " to date")

def Cast.month_text(+st: A.State, +v: String) -> A.Res():
  A.Res.then_typed(
    Cast.parsed(st, Cast.first([Cast.parse_month(v), Cast.parse_date(v)]), v, "date-month"),
    s => t => Cast.part(s, t, 6n, "date-month"))

def Cast.to_month(+st: A.State, +e: A.Typed, +src: String) -> A.Res():
  match src:
    case "date":
      Cast.part(st, e, 6n, "date-month")
    case "string":
      Cast.month_text(st, A.Typed.value(e))
    case "any":
      Cast.month_text(st, A.Typed.value(e))
    case other:
      A.Res.throw(st, "Can't cast " ++ other ++ " to date-month")

def Cast.year_text(+st: A.State, +v: String) -> A.Res():
  A.Res.then_typed(
    Cast.parsed(st, Cast.first([Cast.parse_year(v), Cast.parse_month(v), Cast.parse_date(v)]),
      v, "date-year"),
    s => t => Cast.part(s, t, 4n, "date-year"))

def Cast.to_year(+st: A.State, +e: A.Typed, +src: String) -> A.Res():
  match src:
    case "date":
      Cast.part(st, e, 4n, "date-year")
    case "date-month":
      Cast.part(st, e, 4n, "date-year")
    case "string":
      Cast.year_text(st, A.Typed.value(e))
    case other:
      A.Res.throw(st, "Can't cast " ++ other ++ " to date-year")

# The last resort: an `any` expression takes the type, anything else fails.
def Cast.any(+st: A.State, +e: A.Typed, +kind: String) -> A.Res():
  C.If(A.Res(), String.eq(A.Typed.kind(e), "any"),
    u => A.Res.typed(st, A.Typed.flag(A.Typed.value(e), kind, A.Typed.literal(e))),
    u => A.Res.throw(st, "Can't convert " ++ A.Typed.kind(e) ++ " to " ++ kind))

# A cast to `kind` that only an expression of type `from` gets for free.
def Cast.widen(+st: A.State, +e: A.Typed, +kind: String, +from: String) -> A.Res():
  C.If(A.Res(), String.eq(A.Typed.kind(e), from),
    u => A.Res.typed(st, A.Typed.flag(A.Typed.value(e), kind, A.Typed.literal(e))),
    u => Cast.any(st, e, kind))

def Cast.to(+st: A.State, +e: A.Typed, +kind: String) -> A.Res():
  match kind:
    case "date":
      Cast.to_date(st, e, A.Typed.kind(e), A.Typed.literal(e))
    case "date-month":
      Cast.to_month(st, e, A.Typed.kind(e))
    case "date-year":
      Cast.to_year(st, e, A.Typed.kind(e))
    case "id":
      Cast.widen(st, e, "id", "string")
    case "float":
      Cast.widen(st, e, "float", "integer")
    case other:
      Cast.any(st, e, other)

def Cast.null(+st: A.State, +e: A.Typed, +kind: String, +literal: Bool) -> A.Res():
  match kind literal:
    case _ False{}:
      A.Res.throw(st, "A non-literal null doesn't make sense")
    case "boolean" True{}:
      A.Res.typed(st, A.Typed.lit("0", "boolean"))
    case other True{}:
      A.Res.typed(st, e)

def Cast.from(+st: A.State, +e: A.Typed, +kind: String, +src: String) -> A.Res():
  match src:
    case "param":
      A.Res.then_text(A.Res.infer(st, A.Typed.pid(e), kind),
        s => x => A.Res.typed(s, A.Typed.make(A.Typed.value(e), kind)))
    case "null":
      Cast.null(st, e, kind, A.Typed.literal(e))
    case other:
      Cast.to(st, e, kind)

# `castInput(state, expr, kind)`.
def Cast.cast(+st: A.State, +e: A.Typed, +kind: String) -> A.Res():
  C.If(A.Res(), String.eq(A.Typed.kind(e), kind),
    u => A.Res.typed(st, e),
    u => Cast.from(st, e, kind, A.Typed.kind(e)))

# `val(state, expr, kind)`; an empty kind is no cast.
def Cast.val(+st: A.State, +e: A.Typed, +kind: String) -> A.Res():
  C.If(A.Res(), String.is_empty(kind),
    u => A.Res.text(st, A.Typed.sql(e)),
    u => A.Res.then_typed(Cast.cast(st, e, kind), s => t => A.Res.text(s, A.Typed.sql(t))))

def Cast.kind_at(+kinds: List<&2, String>) -> String:
  match kinds:
    case Nil{}:
      ""
    case Con{k, rest}:
      k

# `valArray(state, arr, kinds)`.
def Cast.vals(+es: List<&2, A.Typed>, +st: A.State, +kinds: List<&2, String>) -> A.Res():
  match es:
    case Nil{}:
      A.Res.texts(st, Nil{})
    case Con{e, rest}:
      A.Res.then_text(Cast.val(st, e, Cast.kind_at(kinds)), s => x =>
        A.Res.then_texts(Cast.vals(rest, s, List.tail(&2, String, kinds)), s2 => xs =>
          A.Res.texts(s2, x <> xs)))

# `validateArgLength(arr, min, max)` for an array of n values, then the rest.
def Cast.arity(+st: A.State, +n: Nat, +min: Nat, +max: Nat, k: A.State -> A.Res()) -> A.Res():
  C.If(A.Res(), Nat.is_lt(n, min),
    u => A.Res.throw(st, "Too few arguments"),
    u => C.If(A.Res(), Nat.is_gt(n, max),
      v => A.Res.throw(st, "Too many arguments"),
      v => k(st)))

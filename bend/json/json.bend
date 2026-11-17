# JSON values, a strict RFC 8259 parser and a serializer that writes what JS
# `JSON.stringify(value)` writes.
#
# Bend defs cannot be mutually recursive, so the cells of arrays and objects
# are constructors of `Json` itself: `JArr{cells}` and `JObj{cells}` hold a
# chain of `JElem` or `JPair` cells ending in `JEnd`. Build them with
# `Json.array` and `Json.object`.
#
# Numbers: an integer that fits (up to 14 digits) is a `JInt`. Any other
# number (a fraction, an exponent, or more digits) is a `JDec` holding its
# source text, which is written back unchanged; JS would instead normalise it
# (`1.50` to `1.5`, `1e3` to `1000`).
#
# Objects keep every member in source order, a repeated key included;
# `Json.get` answers the last one, which is the one JS keeps.
import Base
import ../lib/core.bend as C
import ../lib/int.bend as I

type Json is Data:
  JNull{}
  JBool{value: Bool}
  JInt{value: I.Int}
  JDec{text: String}
  JStr{value: String}
  JArr{cells: Json}
  JObj{cells: Json}
  JElem{value: Json, rest: Json}
  JPair{key: String, value: Json, rest: Json}
  JEnd{}

type Json.Member is Data:
  Member{key: String, value: Json}

# Building
# --------

def Json.nat(n: Nat) -> Json:
  JInt{I.Int.from_nat(n)}

def Json.u32(n: U32) -> Json:
  JInt{I.Int.from_nat(U32.to_nat(n))}

def Json.cells(items: List<&2, Json>) -> Json:
  match items:
    case Nil{}:
      JEnd{}
    case Con{h, t}:
      JElem{h, Json.cells(t)}

def Json.array(items: List<&2, Json>) -> Json:
  JArr{Json.cells(items)}

def Json.pairs(members: List<&2, Json.Member>) -> Json:
  match members:
    case Nil{}:
      JEnd{}
    case Con{Member{k, v}, t}:
      JPair{k, v, Json.pairs(t)}

def Json.object(members: List<&2, Json.Member>) -> Json:
  JObj{Json.pairs(members)}

# Reading
# -------

# The elements of an array; empty for anything else.
def Json.items(j: Json) -> List<&2, Json>:
  match j:
    case JArr{cells}:
      Json.items(cells)
    case JElem{v, rest}:
      Con{v, Json.items(rest)}
    case other:
      Nil{}

# The members of an object, in order; empty for anything else.
def Json.members(j: Json) -> List<&2, Json.Member>:
  match j:
    case JObj{cells}:
      Json.members(cells)
    case JPair{k, v, rest}:
      Con{Member{k, v}, Json.members(rest)}
    case other:
      Nil{}

# The value of an object's member; the last one wins when a key repeats, as
# in JS. None when there is none or j is not an object.
def Json.get(j: Json, +key: String) -> Maybe<&2, Json>:
  match j:
    case JObj{cells}:
      Json.get(cells, key)
    case JPair{k, +v, rest}:
      Maybe.or(&2, Json, Json.get(rest, key),
        Bool.pick(Maybe<&2, Json>, String.eq(k, key), Some{v}, None{}))
    case other:
      None{}

# The element of an array at an index.
def Json.at(j: Json, n: Nat) -> Maybe<&2, Json>:
  List.get(&2, Json, Json.items(j), n)

def Json.as_string(j: Json) -> Maybe<&2, String>:
  match j:
    case JStr{s}:
      Some{s}
    case other:
      None{}

def Json.as_bool(j: Json) -> Maybe<&2, Bool>:
  match j:
    case JBool{b}:
      Some{b}
    case other:
      None{}

def Json.as_int(j: Json) -> Maybe<&2, I.Int>:
  match j:
    case JInt{i}:
      Some{i}
    case other:
      None{}

def Json.as_nat(j: Json) -> Maybe<&2, Nat>:
  match j:
    case JInt{I.Int{False{}, n}}:
      Some{n}
    case other:
      None{}

def Json.is_null(j: Json) -> Bool:
  match j:
    case JNull{}:
      True{}
    case other:
      False{}

# Writing
# -------

def Json.hex4.digit(+d: U32) -> Char:
  Chr{(d + 48 + Bool.to_u32((d > 9 : U32)) * 39 : U32)}

# `\u00xx` for a control character.
def Json.hex4(+x: U32) -> String:
  SCon{'\\', SCon{'u', SCon{'0', SCon{'0',
    SCon{Json.hex4.digit((x >> 4n : U32)), SCon{Json.hex4.digit((x .&. 15 : U32)), SNil{}}}}}}}

def Json.escape.chr(+x: U32) -> String:
  match x:
    case 34:
      "\\\""
    case 92:
      "\\\\"
    case 8:
      "\\b"
    case 12:
      "\\f"
    case 10:
      "\\n"
    case 13:
      "\\r"
    case 9:
      "\\t"
    case other:
      Bool.pick(String, (x < 32 : U32), Json.hex4(x), SCon{Chr{x}, SNil{}})

def Json.escape(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{x}, t}:
      String.append(Json.escape.chr(x), Json.escape(t))

# A string in quotes with JSON escapes.
def Json.quote(s: String) -> String:
  "\"" ++ Json.escape(s) ++ "\""

def Json.comma(rest: Json) -> String:
  match rest:
    case JEnd{}:
      ""
    case other:
      ","

# The compact text of a value.
def Json.show(j: Json) -> String:
  match j:
    case JNull{}:
      "null"
    case JBool{True{}}:
      "true"
    case JBool{False{}}:
      "false"
    case JInt{i}:
      I.Int.show(i)
    case JDec{text}:
      text
    case JStr{s}:
      Json.quote(s)
    case JArr{cells}:
      "[" ++ Json.show(cells) ++ "]"
    case JObj{cells}:
      "{" ++ Json.show(cells) ++ "}"
    case JElem{v, +rest}:
      Json.show(v) ++ Json.comma(rest) ++ Json.show(rest)
    case JPair{k, v, +rest}:
      Json.quote(k) ++ ":" ++ Json.show(v) ++ Json.comma(rest) ++ Json.show(rest)
    case JEnd{}:
      ""

# Parsing
# -------

def Json.ws(s: String) -> String:
  match s:
    case SCon{' ', t}:
      Json.ws(t)
    case SCon{'\n', t}:
      Json.ws(t)
    case SCon{'\r', t}:
      Json.ws(t)
    case SCon{'\t', t}:
      Json.ws(t)
    case other:
      other

def Json.is_digit(+x: U32) -> Bool:
  Bool.and((x >= 48 : U32), (x <= 57 : U32))

def Json.span.put(c: Char, r: String & String) -> String & String:
  (ds, rest) = r
  (SCon{c, ds}, rest)

# The decimal digits at the head of s, and what follows them.
def Json.span(s: String) -> String & String:
  match s:
    case SNil{}:
      (SNil{}, SNil{})
    case SCon{Chr{+x}, +t}:
      C.If(String & String, Json.is_digit(x),
        u => Json.span.put(Chr{x}, Json.span(t)),
        u => (SNil{}, SCon{Chr{x}, t}))

# The value of a hexadecimal digit, or 16.
def Json.hex_value(+x: U32) -> U32:
  Bool.pick(U32, Bool.and((x >= 48 : U32), (x <= 57 : U32)), (x - 48 : U32),
    Bool.pick(U32, Bool.and((x >= 65 : U32), (x <= 70 : U32)), (x - 55 : U32),
      Bool.pick(U32, Bool.and((x >= 97 : U32), (x <= 102 : U32)), (x - 87 : U32), 16)))

def Json.text.put(c: Char, r: Maybe<&1, String & String>) -> Maybe<&1, String & String>:
  match r:
    case None{}:
      None{}
    case Some{Tuple{str, rest}}:
      Some{(SCon{c, str}, rest)}

# Puts the UTF-16 code unit of four hexadecimal digits before a result.
def Json.text.unit(
  a: U32, b: U32, c: U32, d: U32, r: Maybe<&1, String & String>
) -> Maybe<&1, String & String>:
  +va = Json.hex_value(a)
  +vb = Json.hex_value(b)
  +vc = Json.hex_value(c)
  +vd = Json.hex_value(d)
  C.If(Maybe<&1, String & String>, ((va .|. vb .|. vc .|. vd) < 16 : U32),
    u => Json.text.put(Chr{(va * 4096 + vb * 256 + vc * 16 + vd : U32)}, r),
    u => None{})

# Reads the body of a string, after its opening quote, up to and including
# the closing quote: the text, with each `\uXXXX` as one UTF-16 code unit,
# and what follows.
def Json.text(s: String) -> Maybe<&1, String & String>:
  match s:
    case SNil{}:
      None{}
    case SCon{'"', t}:
      Some{(SNil{}, t)}
    case SCon{'\\', SCon{'"', t}}:
      Json.text.put('"', Json.text(t))
    case SCon{'\\', SCon{'\\', t}}:
      Json.text.put('\\', Json.text(t))
    case SCon{'\\', SCon{'/', t}}:
      Json.text.put('/', Json.text(t))
    case SCon{'\\', SCon{'b', t}}:
      Json.text.put(Chr{8}, Json.text(t))
    case SCon{'\\', SCon{'f', t}}:
      Json.text.put(Chr{12}, Json.text(t))
    case SCon{'\\', SCon{'n', t}}:
      Json.text.put('\n', Json.text(t))
    case SCon{'\\', SCon{'r', t}}:
      Json.text.put('\r', Json.text(t))
    case SCon{'\\', SCon{'t', t}}:
      Json.text.put('\t', Json.text(t))
    case SCon{'\\', SCon{'u', SCon{Chr{a}, SCon{Chr{b}, SCon{Chr{c}, SCon{Chr{d}, t}}}}}}:
      Json.text.unit(a, b, c, d, Json.text(t))
    case SCon{'\\', t}:
      None{}
    case SCon{Chr{+x}, +t}:
      C.If(Maybe<&1, String & String>, (x < 32 : U32),
        u => None{},
        u => Json.text.put(Chr{x}, Json.text(t)))

# A pending high surrogate as text; nothing for 0.
def Json.join.flush(+hi: U32) -> String:
  Bool.pick(String, U32.is_eq(hi, 0), SNil{}, SCon{Chr{hi}, SNil{}})

# Joins each high surrogate with the low surrogate after it into one code
# point; a lone surrogate stays. `hi` is the high surrogate just read, or 0.
def Json.join(s: String, +hi: U32) -> String:
  match s:
    case SNil{}:
      Json.join.flush(hi)
    case SCon{Chr{+x}, +t}:
      C.If(String, Bool.and(U32.is_ne(hi, 0), Bool.and((x >= 56320 : U32), (x < 57344 : U32))),
        u => SCon{Chr{(65536 + (hi - 55296) * 1024 + (x - 56320) : U32)}, Json.join(t, 0)},
        u => String.append(Json.join.flush(hi),
          C.If(String, Bool.and((x >= 55296 : U32), (x < 56320 : U32)),
            v => Json.join(t, x),
            v => SCon{Chr{x}, Json.join(t, 0)})))

def Json.string.fin(r: Maybe<&1, String & String>) -> Maybe<&1, String & String>:
  match r:
    case None{}:
      None{}
    case Some{Tuple{str, rest}}:
      Some{(Json.join(str, 0), rest)}

# Reads a string after its opening quote: its text and what follows.
def Json.string(s: String) -> Maybe<&1, String & String>:
  Json.string.fin(Json.text(s))

def Json.digits.ok(+ds: String) -> Bool:
  match ds:
    case SNil{}:
      False{}
    case SCon{'0', SNil{}}:
      True{}
    case SCon{'0', t}:
      False{}
    case other:
      True{}

# An optional fraction: the text consumed (with its dot) and the rest. None
# when a dot has no digit after it.
def Json.frac.fin(r: String & String) -> Maybe<&1, String & String>:
  match r:
    case Tuple{SNil{}, rest}:
      None{}
    case Tuple{ds, rest}:
      Some{("." ++ ds, rest)}

def Json.frac(s: String) -> Maybe<&1, String & String>:
  match s:
    case SCon{'.', t}:
      Json.frac.fin(Json.span(t))
    case other:
      Some{(SNil{}, other)}

def Json.exp.fin(lead: String, r: String & String) -> Maybe<&1, String & String>:
  match r:
    case Tuple{SNil{}, rest}:
      None{}
    case Tuple{ds, rest}:
      Some{(lead ++ ds, rest)}

def Json.exp.sign(lead: String, s: String) -> Maybe<&1, String & String>:
  match s:
    case SCon{'+', t}:
      Json.exp.fin(lead ++ "+", Json.span(t))
    case SCon{'-', t}:
      Json.exp.fin(lead ++ "-", Json.span(t))
    case other:
      Json.exp.fin(lead, Json.span(other))

def Json.exp(s: String) -> Maybe<&1, String & String>:
  match s:
    case SCon{'e', t}:
      Json.exp.sign("e", t)
    case SCon{'E', t}:
      Json.exp.sign("E", t)
    case other:
      Some{(SNil{}, other)}

def Json.number.make(+neg: Bool, +ds: String, +tail: String, rest: String) -> Json & String:
  (Bool.pick(Json,
    Bool.and(String.is_empty(tail), Nat.is_le(String.length(ds), 14n)),
    JInt{I.Int.make(neg, Maybe.default(&2, Nat, Nat.read(ds), 0n))},
    JDec{Bool.pick(String, neg, "-", "") ++ ds ++ tail}), rest)

def Json.number.exp(neg: Bool, ds: String, fr: String, e: Maybe<&1, String & String>) ->
  Maybe<&1, Json & String>:
  match e:
    case None{}:
      None{}
    case Some{Tuple{ex, rest}}:
      Some{Json.number.make(neg, ds, fr ++ ex, rest)}

def Json.number.frac(neg: Bool, ds: String, f: Maybe<&1, String & String>) ->
  Maybe<&1, Json & String>:
  match f:
    case None{}:
      None{}
    case Some{Tuple{fr, rest}}:
      Json.number.exp(neg, ds, fr, Json.exp(rest))

def Json.number.int(neg: Bool, r: String & String) -> Maybe<&1, Json & String>:
  match r:
    case Tuple{+ds, +rest}:
      C.If(Maybe<&1, Json & String>, Json.digits.ok(ds),
        u => Json.number.frac(neg, ds, Json.frac(rest)),
        u => None{})

# Reads a number: -?(0|[1-9][0-9]*)(.[0-9]+)?([eE][+-]?[0-9]+)?
def Json.number(s: String) -> Maybe<&1, Json & String>:
  match s:
    case SCon{'-', t}:
      Json.number.int(True{}, Json.span(t))
    case other:
      Json.number.int(False{}, Json.span(other))

def Json.word(+s: String, +w: String, j: Json) -> Maybe<&1, Json & String>:
  Bool.pick(Maybe<&1, Json & String>, String.starts_with(s, w),
    Some{(j, String.drop(s, String.length(w)))}, None{})

# What separates two cells: 1 for `,`, 2 for `]`, 3 for `}`, 0 otherwise,
# with the text after it, both sides skipped of whitespace.
def Json.sep.at(s: String) -> U32 & String:
  match s:
    case SCon{',', t}:
      (1, Json.ws(t))
    case SCon{']', t}:
      (2, t)
    case SCon{'}', t}:
      (3, t)
    case other:
      (0, other)

def Json.sep(s: String) -> U32 & String:
  Json.sep.at(Json.ws(s))

def Json.colon.at(s: String) -> Maybe<&2, String>:
  match s:
    case SCon{':', t}:
      Some{Json.ws(t)}
    case other:
      None{}

def Json.then(
  m: Maybe<&1, Json & String>, f: Json -> String -> Maybe<&1, Json & String>
) -> Maybe<&1, Json & String>:
  match m:
    case None{}:
      None{}
    case Some{Tuple{v, s}}:
      f(v, s)

def Json.then_key(
  m: Maybe<&1, String & String>, f: String -> String -> Maybe<&1, Json & String>
) -> Maybe<&1, Json & String>:
  match m:
    case None{}:
      None{}
    case Some{Tuple{k, s}}:
      f(k, s)

def Json.then_text(
  m: Maybe<&2, String>, f: String -> Maybe<&1, Json & String>
) -> Maybe<&1, Json & String>:
  match m:
    case None{}:
      None{}
    case Some{s}:
      f(s)

def Json.wrap(arr: Bool, r: Maybe<&1, Json & String>) -> Maybe<&1, Json & String>:
  match arr r:
    case _ None{}:
      None{}
    case True{} Some{Tuple{cells, s}}:
      Some{(JArr{cells}, s)}
    case False{} Some{Tuple{cells, s}}:
      Some{(JObj{cells}, s)}

def Json.str(r: Maybe<&1, String & String>) -> Maybe<&1, Json & String>:
  match r:
    case None{}:
      None{}
    case Some{Tuple{str, s}}:
      Some{(JStr{str}, s)}

# A cell with its rest replaced.
def Json.link(cell: Json, cells: Json) -> Json:
  match cell:
    case JElem{v, rest}:
      JElem{v, cells}
    case JPair{k, v, rest}:
      JPair{k, v, cells}
    case other:
      other

# After an element or member, held in `cell`: more cells on a comma, the end
# on the closing bracket `close` (2 for `]`, 3 for `}`), a failure otherwise.
def Json.next(
  +close: U32, sep: U32 & String,
  more: String -> Maybe<&1, Json & String>, +cell: Json
) -> Maybe<&1, Json & String>:
  match sep:
    case Tuple{+code, +rest}:
      C.If(Maybe<&1, Json & String>, U32.is_eq(code, 1),
        u => Json.then(more(rest), cells => s => Some{(Json.link(cell, cells), s)}),
        u => C.If(Maybe<&1, Json & String>, U32.is_eq(code, close),
          v => Some{(cell, rest)},
          v => None{}))

# The recursive-descent parser, as one def with a mode: 0 reads a value, 1 the
# cells of an array after `[`, 2 the members of an object after `{`, 3 one or
# more elements, 4 one or more members. `s` starts at a non-space character.
# Every call spends one unit of fuel.
def Json.parse.go(+fuel: Nat, mode: U32, s: String) -> Maybe<&1, Json & String>:
  match fuel mode s:
    case 0n _ _:
      None{}
    case 1n+f 0 SCon{'"', t}:
      Json.str(Json.string(t))
    case 1n+f 0 SCon{'[', t}:
      Json.wrap(True{}, Json.parse.go(f, 1, Json.ws(t)))
    case 1n+f 0 SCon{'{', t}:
      Json.wrap(False{}, Json.parse.go(f, 2, Json.ws(t)))
    case 1n+f 0 SCon{'t', t}:
      Json.word(SCon{'t', t}, "true", JBool{True{}})
    case 1n+f 0 SCon{'f', t}:
      Json.word(SCon{'f', t}, "false", JBool{False{}})
    case 1n+f 0 SCon{'n', t}:
      Json.word(SCon{'n', t}, "null", JNull{})
    case 1n+f 0 other:
      Json.number(other)
    case 1n+f 1 SCon{']', t}:
      Some{(JEnd{}, t)}
    case 1n+f 1 other:
      Json.parse.go(f, 3, other)
    case 1n+f 2 SCon{'}', t}:
      Some{(JEnd{}, t)}
    case 1n+f 2 other:
      Json.parse.go(f, 4, other)
    case 1n+f 3 other:
      Json.then(Json.parse.go(f, 0, other), +v => s1 =>
        Json.next(2, Json.sep(s1), rest => Json.parse.go(f, 3, rest), JElem{v, JEnd{}}))
    case 1n+f 4 SCon{'"', t}:
      Json.then_key(Json.string(t), +k => s1 =>
        Json.then_text(Json.colon.at(Json.ws(s1)), s2 =>
          Json.then(Json.parse.go(f, 0, s2), +v => s3 =>
            Json.next(3, Json.sep(s3), rest => Json.parse.go(f, 4, rest),
              JPair{k, v, JEnd{}}))))
    case 1n+f _ other:
      None{}

def Json.parse.fin(r: Maybe<&1, Json & String>) -> Maybe<&2, Json>:
  match r:
    case None{}:
      None{}
    case Some{Tuple{j, rest}}:
      Bool.pick(Maybe<&2, Json>, String.is_empty(Json.ws(rest)), Some{j}, None{})

# Parses a JSON text; None when it is not valid JSON.
def Json.parse(+s: String) -> Maybe<&2, Json>:
  Json.parse.fin(Json.parse.go((String.length(s) * 2n + 4n : Nat), 0, Json.ws(s)))

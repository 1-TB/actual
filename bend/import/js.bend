# JavaScript string and value semantics shared by the import parsers: the
# whitespace that `trim` and `\s` know, literal replacement, `Number(text)`,
# the coercions of loosely typed values, and the order of an object's keys.
#
# A loosely typed value (what xml2js hands back) is a `Json` from
# bend/json/json.bend: a string, an object or an array. `undefined` and
# `null` are both `None`.
import Base
import ../lib/core.bend as C
import ../lib/num.bend as N
import ../json/json.bend as J

# `List.map` for lists of `Data`.
def Js.map(~A: Data, ~B: Data, ~f: A -> B, xs: List<&2, A>) -> List<&2, B>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{f(h), Js.map(~A, ~B, ~f, t)}

# Whitespace
# ----------

# The ECMAScript WhiteSpace and LineTerminator code points: what `\s` matches
# and what `trim` removes.
def Js.is_space(+x: U32) -> Bool:
  (x >= 9 : U32) && (x <= 13 : U32) || U32.is_eq(x, 32) || U32.is_eq(x, 160) || U32.is_eq(x, 5760)
    || (x >= 8192 : U32) && (x <= 8202 : U32) || U32.is_eq(x, 8232) || U32.is_eq(x, 8233)
    || U32.is_eq(x, 8239) || U32.is_eq(x, 8287) || U32.is_eq(x, 12288) || U32.is_eq(x, 65279)

def Js.trim_start(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+x}, +t}:
      C.If(String, Js.is_space(x), u => Js.trim_start(t), u => SCon{Chr{x}, t})

def Js.trim_end(s: String) -> String:
  String.reverse(Js.trim_start(String.reverse(s)))

def Js.trim(s: String) -> String:
  Js.trim_end(Js.trim_start(s))

# Whether s is empty or all whitespace: `/^\s*$/`.
def Js.is_blank(s: String) -> Bool:
  String.is_empty(Js.trim_start(s))

# Text
# ----

# What follows the prefix p in s; None when s does not start with p.
def Js.strip_prefix(s: String, p: String) -> Maybe<&2, String>:
  match s p:
    case SNil{} SNil{}:
      Some{SNil{}}
    case SNil{} SCon{a, pt}:
      None{}
    case SCon{b, st} SNil{}:
      Some{SCon{b, st}}
    case SCon{b, st} SCon{a, pt}:
      C.If(Maybe<&2, String>, Char.is_eq(a, b), u => Js.strip_prefix(st, pt), u => None{})

# `s.replace(/from/g, to)` for a literal, non-empty `from`. `skip` counts the
# characters of a match still to pass over; `len` is the length of `from`
# less one.
def Js.replace_all.go(s: String, skip: Nat, +len: Nat, +from: String, +to: String) -> String:
  match s skip:
    case SNil{} _:
      SNil{}
    case SCon{h, t} 1n+k:
      Js.replace_all.go(t, k, len, from, to)
    case SCon{+h, +t} 0n:
      C.If(String, String.starts_with(SCon{h, t}, from),
        u => to ++ Js.replace_all.go(t, len, len, from, to),
        u => SCon{h, Js.replace_all.go(t, 0n, len, from, to)})

def Js.replace_all(s: String, +from: String, to: String) -> String:
  Js.replace_all.go(s, 0n, Nat.sub(String.length(from), 1n), from, to)

def Js.lines.cr(line: String) -> String:
  match line:
    case SCon{'\r', SNil{}}:
      SNil{}
    case SNil{}:
      SNil{}
    case SCon{h, t}:
      SCon{h, Js.lines.cr(t)}

def Js.lines.each(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case Con{h, Nil{}}:
      [h]
    case Con{h, t}:
      Con{Js.lines.cr(h), Js.lines.each(t)}

# `s.split(/\r?\n/)`: the lines of s, a `\r` before each `\n` dropped.
def Js.lines(s: String) -> List<&2, String>:
  Js.lines.each(String.split(s, '\n'))

def Js.is_digit(+x: U32) -> Bool:
  Bool.and((x >= 48 : U32), (x <= 57 : U32))

# `\w`: an ASCII letter, a digit or an underscore.
def Js.is_word(+x: U32) -> Bool:
  Bool.or(Js.is_digit(x),
    Bool.or(Bool.and((x >= 65 : U32), (x <= 90 : U32)),
      Bool.or(Bool.and((x >= 97 : U32), (x <= 122 : U32)), U32.is_eq(x, 95))))

def Js.span.put(c: Char, r: String & String) -> String & String:
  (ds, rest) = r
  (SCon{c, ds}, rest)

# The decimal digits at the head of s, and what follows.
def Js.digits(s: String) -> String & String:
  match s:
    case SNil{}:
      (SNil{}, SNil{})
    case SCon{Chr{+x}, +t}:
      C.If(String & String, Js.is_digit(x),
        u => Js.span.put(Chr{x}, Js.digits(t)),
        u => (SNil{}, SCon{Chr{x}, t}))

# The word characters at the head of s, and what follows.
def Js.word(s: String) -> String & String:
  match s:
    case SNil{}:
      (SNil{}, SNil{})
    case SCon{Chr{+x}, +t}:
      C.If(String & String, Js.is_word(x),
        u => Js.span.put(Chr{x}, Js.word(t)),
        u => (SNil{}, SCon{Chr{x}, t}))

# Numbers
# -------

def Js.zeros(s: String) -> String:
  match s:
    case SCon{'0', t}:
      Js.zeros(t)
    case other:
      other

# mantissa * 10^(exp - places), exactly; None when it does not fit.
def Js.number.scale(+v: N.Num, eneg: Bool, +e: Nat) -> Maybe<&2, N.Num>:
  Bool.pick(Maybe<&2, N.Num>, eneg, N.Num.div(v, N.Num.from_nat(e)), N.Num.mul(v, N.Num.from_nat(e)))

def Js.number.make(neg: Bool, +digits: String, places: Nat, eneg: Bool, +exp: Nat) -> Maybe<&2, N.Num>:
  +m = Maybe.default(&2, Nat, Nat.read(digits), 0n)
  C.If(Maybe<&2, N.Num>, Nat.is_le(String.length(digits), 14n),
    u => Maybe.bind(&2, Nat, N.Num, N.Num.pow10(places), d =>
      Maybe.bind(&2, Nat, N.Num, N.Num.pow10(Bool.pick(Nat, Nat.is_le(exp, 40n), exp, 41n)), e =>
        Js.number.scale(N.Num.make(neg, m, d), eneg, e))),
    u => None{})

def Js.number.exp_digits(neg: Bool, digits: String, places: Nat, eneg: Bool, r: String & String) -> Maybe<&2, N.Num>:
  (+ds, rest) = r
  C.If(Maybe<&2, N.Num>, Bool.and(Bool.not(String.is_empty(ds)), String.is_empty(rest)),
    u => Js.number.make(neg, digits, places, eneg,
      Bool.pick(Nat, Nat.is_le(String.length(Js.zeros(ds)), 3n), Maybe.default(&2, Nat, Nat.read(ds), 0n), 999n)),
    u => None{})

def Js.number.exp(neg: Bool, digits: String, places: Nat, rest: String) -> Maybe<&2, N.Num>:
  match rest:
    case SNil{}:
      Js.number.make(neg, digits, places, False{}, 0n)
    case SCon{'e', SCon{'-', t}}:
      Js.number.exp_digits(neg, digits, places, True{}, Js.digits(t))
    case SCon{'E', SCon{'-', t}}:
      Js.number.exp_digits(neg, digits, places, True{}, Js.digits(t))
    case SCon{'e', SCon{'+', t}}:
      Js.number.exp_digits(neg, digits, places, False{}, Js.digits(t))
    case SCon{'E', SCon{'+', t}}:
      Js.number.exp_digits(neg, digits, places, False{}, Js.digits(t))
    case SCon{'e', t}:
      Js.number.exp_digits(neg, digits, places, False{}, Js.digits(t))
    case SCon{'E', t}:
      Js.number.exp_digits(neg, digits, places, False{}, Js.digits(t))
    case other:
      None{}

def Js.number.frac(neg: Bool, +whole: String, r: String & String) -> Maybe<&2, N.Num>:
  (+frac, rest) = r
  C.If(Maybe<&2, N.Num>, Bool.and(String.is_empty(whole), String.is_empty(frac)),
    u => None{},
    u => Js.number.exp(neg, Js.zeros(whole ++ frac), String.length(frac), rest))

def Js.number.whole(neg: Bool, r: String & String) -> Maybe<&2, N.Num>:
  match r:
    case Tuple{+whole, SCon{'.', t}}:
      Js.number.frac(neg, whole, Js.digits(t))
    case Tuple{+whole, rest}:
      Js.number.frac(neg, whole, (SNil{}, rest))

def Js.number.sign(s: String) -> Maybe<&2, N.Num>:
  match s:
    case SNil{}:
      Some{N.Num.zero()}
    case SCon{'-', t}:
      Js.number.whole(True{}, Js.digits(t))
    case SCon{'+', t}:
      Js.number.whole(False{}, Js.digits(t))
    case other:
      Js.number.whole(False{}, Js.digits(other))

# `Number(text)` for decimal literals: surrounding whitespace, a sign,
# digits, a point, an exponent; the empty string is 0. None where JS answers
# NaN, and also for `Infinity`, for hexadecimal, octal and binary literals
# and for a value with more than 14 significant digits, which the exact
# `Num` cannot hold.
def Js.number(s: String) -> Maybe<&2, N.Num>:
  Js.number.sign(Js.trim(s))

# Loosely typed values
# --------------------

# `String(value)`, as a template literal coerces it: an object is
# "[object Object]", an array its elements joined by commas.
def Js.to_string(j: J.Json) -> String:
  match j:
    case J.JStr{s}:
      s
    case J.JObj{cells}:
      "[object Object]"
    case J.JArr{cells}:
      Js.to_string(cells)
    case J.JElem{v, J.JEnd{}}:
      Js.to_string(v)
    case J.JElem{v, rest}:
      Js.to_string(v) ++ "," ++ Js.to_string(rest)
    case J.JNull{}:
      "null"
    case J.JEnd{}:
      ""
    case other:
      J.Json.show(other)

# `String(value)` for a value that may be undefined.
def Js.show(m: Maybe<&2, J.Json>) -> String:
  match m:
    case None{}:
      "undefined"
    case Some{j}:
      Js.to_string(j)

# Whether a value is truthy: every object and array is, a string unless empty.
def Js.truthy(m: Maybe<&2, J.Json>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{J.JStr{s}}:
      Bool.not(String.is_empty(s))
    case Some{J.JNull{}}:
      False{}
    case Some{J.JBool{b}}:
      b
    case Some{other}:
      True{}

# `a || b`.
def Js.or(+a: Maybe<&2, J.Json>, b: Maybe<&2, J.Json>) -> Maybe<&2, J.Json>:
  Bool.pick(Maybe<&2, J.Json>, Js.truthy(a), a, b)

# `value[key]` for a property name that no string or array has: the member
# of an object, undefined for anything else.
def Js.get(m: Maybe<&2, J.Json>, key: String) -> Maybe<&2, J.Json>:
  match m:
    case Some{J.JObj{cells}}:
      J.Json.get(J.JObj{cells}, key)
    case other:
      None{}

def Js.is_array(m: Maybe<&2, J.Json>) -> Bool:
  match m:
    case Some{J.JArr{cells}}:
      True{}
    case other:
      False{}

# The string a value is, if it is one.
def Js.text(m: Maybe<&2, J.Json>) -> Maybe<&2, String>:
  match m:
    case Some{J.JStr{s}}:
      Some{s}
    case other:
      None{}

def Js.str(m: Maybe<&2, String>) -> Maybe<&2, J.Json>:
  match m:
    case None{}:
      None{}
    case Some{s}:
      Some{J.JStr{s}}

# A value as JSON text, `null` when missing.
def Js.json(m: Maybe<&2, J.Json>) -> String:
  match m:
    case None{}:
      "null"
    case Some{j}:
      J.Json.show(j)

# Object keys
# -----------

type Js.Entry<-V: Data> is Data:
  Entry{key: String, value: V}

def Js.index.fits(+ds: String) -> Bool:
  Bool.or(Nat.is_lt(String.length(ds), 10n),
    Bool.and(Nat.is_eq(String.length(ds), 10n), String.is_le(ds, "4294967294")))

def Js.index.at(+s: String, r: String & String) -> Maybe<&2, Nat>:
  (+ds, rest) = r
  C.If(Maybe<&2, Nat>,
    Bool.and(String.is_empty(rest), Bool.and(Bool.not(String.is_empty(ds)),
      Bool.and(Js.index.fits(ds), Bool.or(String.eq(s, "0"), Bool.not(String.starts_with(s, "0")))))),
    u => Nat.read(ds),
    u => None{})

# The array index a key is, when it is one: a canonical decimal below
# 2^32 - 1. An object lists such keys first, in numeric order.
def Js.index(+key: String) -> Maybe<&2, Nat>:
  Js.index.at(key, Js.digits(key))

def Js.has(-V: Data, es: List<&2, Js.Entry<V>>, +key: String) -> Bool:
  match es:
    case Nil{}:
      False{}
    case Con{Entry{k, v}, t}:
      Bool.or(String.eq(k, key), Js.has(V, t, key))

def Js.put(-V: Data, es: List<&2, Js.Entry<V>>, +key: String, +value: V) -> List<&2, Js.Entry<V>>:
  match es:
    case Nil{}:
      Nil{}
    case Con{Entry{+k, +v}, t}:
      Con{Bool.pick(Js.Entry<V>, String.eq(k, key), Entry{key, value}, Entry{k, v}), Js.put(V, t, key, value)}

def Js.before(a: Maybe<&2, Nat>, b: Maybe<&2, Nat>) -> Bool:
  match a b:
    case Some{x} Some{y}:
      Nat.is_lt(x, y)
    case Some{x} None{}:
      True{}
    case None{} _:
      False{}

def Js.add(-V: Data, es: List<&2, Js.Entry<V>>, +key: String, +value: V) -> List<&2, Js.Entry<V>>:
  match es:
    case Nil{}:
      [Entry{key, value}]
    case Con{Entry{+k, +v}, +t}:
      C.If(List<&2, Js.Entry<V>>, Js.before(Js.index(key), Js.index(k)),
        u => Con{Entry{key, value}, Con{Entry{k, v}, t}},
        u => Con{Entry{k, v}, Js.add(V, t, key, value)})

# `obj[key] = value` on an object held as its entries in the order JS lists
# them: a present key keeps its place, a new array index goes among the
# indices in numeric order, any other new key goes last.
def Js.set(-V: Data, +es: List<&2, Js.Entry<V>>, +key: String, +value: V) -> List<&2, Js.Entry<V>>:
  C.If(List<&2, Js.Entry<V>>, Js.has(V, es, key),
    u => Js.put(V, es, key, value),
    u => Js.add(V, es, key, value))

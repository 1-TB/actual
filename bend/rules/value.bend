# The values a rule can read from or write to a transaction, and the
# transaction itself. There is no TypeScript module behind this file: it
# stands in for the untyped JS objects that
# packages/loot-core/src/server/rules/ passes around.
#
# A `Value` is what a JS property can hold: `undefined` (`VMissing`), `null`,
# a boolean, a number, a string, an array or an object. Numbers are exact
# rationals (lib/num.bend); an integer amount is `Value.int(i)`. Arrays and
# objects are chains of `VElem` / `VPair` cells ending in `VEnd`, so that one
# def can walk a whole value (Bend has no mutual recursion); build them with
# `Value.array`, `Value.strs` and `Value.object`.
#
# A transaction (`Txn`) is a list of fields in insertion order, the order JS
# keeps for an object's keys.
#
# Deviations from JS:
# - `Value.lower` (JS `toLowerCase`) knows ASCII, Latin-1, Greek and Cyrillic
#   capitals only, and has no final-sigma rule.
# - `Value.to_number` (JS `Number(string)`) reads an optional sign, digits and
#   an optional fraction; an exponent, hex, or `Infinity` is NaN (`None`).
# - `Value.eq` compares arrays and objects by structure where JS `===` compares
#   them by identity; `Value.strict_eq` answers False for them, which is what
#   `===` gives for two separately built ones.
import Base
import ../lib/core.bend as C
import ../lib/int.bend as I
import ../lib/num.bend as N
import ../lib/text.bend as T
import ../json/json.bend as J
import ../shared/util.bend as U

type Value is Data:
  VMissing{}
  VNull{}
  VBool{value: Bool}
  VNum{value: N.Num}
  VStr{value: String}
  VArr{cells: Value}
  VObj{cells: Value}
  VElem{value: Value, rest: Value}
  VPair{key: String, value: Value, rest: Value}
  VEnd{}

type Field is Data:
  Field{key: String, value: Value}

# Building
# --------

def Value.int(i: I.Int) -> Value:
  VNum{N.Num.from_int(i)}

def Value.nat(n: Nat) -> Value:
  VNum{N.Num.from_nat(n)}

# The integer -n.
def Value.minus(n: Nat) -> Value:
  VNum{N.Num.make(True{}, n, 1n)}

def Value.cells(items: List<&2, Value>) -> Value:
  match items:
    case Nil{}:
      VEnd{}
    case Con{h, t}:
      VElem{h, Value.cells(t)}

def Value.array(items: List<&2, Value>) -> Value:
  VArr{Value.cells(items)}

def Value.str_cells(items: List<&2, String>) -> Value:
  match items:
    case Nil{}:
      VEnd{}
    case Con{h, t}:
      VElem{VStr{h}, Value.str_cells(t)}

# An array of strings, such as a list of ids.
def Value.strs(items: List<&2, String>) -> Value:
  VArr{Value.str_cells(items)}

def Value.pairs(fields: List<&2, Field>) -> Value:
  match fields:
    case Nil{}:
      VEnd{}
    case Con{Field{k, v}, t}:
      VPair{k, v, Value.pairs(t)}

def Value.object(fields: List<&2, Field>) -> Value:
  VObj{Value.pairs(fields)}

# Reading
# -------

# The elements of an array; empty for anything else.
def Value.items(v: Value) -> List<&2, Value>:
  match v:
    case VArr{cells}:
      Value.items(cells)
    case VElem{x, rest}:
      Con{x, Value.items(rest)}
    case other:
      Nil{}

# The fields of an object, in order; empty for anything else.
def Value.fields(v: Value) -> List<&2, Field>:
  match v:
    case VObj{cells}:
      Value.fields(cells)
    case VPair{k, x, rest}:
      Con{Field{k, x}, Value.fields(rest)}
    case other:
      Nil{}

def Value.is_array(v: Value) -> Bool:
  match v:
    case VArr{cells}:
      True{}
    case other:
      False{}

def Value.is_string(v: Value) -> Bool:
  match v:
    case VStr{s}:
      True{}
    case other:
      False{}

def Value.is_number(v: Value) -> Bool:
  match v:
    case VNum{n}:
      True{}
    case other:
      False{}

def Value.is_null(v: Value) -> Bool:
  match v:
    case VNull{}:
      True{}
    case other:
      False{}

def Value.is_missing(v: Value) -> Bool:
  match v:
    case VMissing{}:
      True{}
    case other:
      False{}

# JS `v == null`.
def Value.is_nullish(v: Value) -> Bool:
  match v:
    case VNull{}:
      True{}
    case VMissing{}:
      True{}
    case other:
      False{}

# JS `a ?? b`.
def Value.or_else(+a: Value, b: Value) -> Value:
  Bool.pick(Value, Value.is_nullish(a), b, a)

# JS truthiness.
def Value.truthy(v: Value) -> Bool:
  match v:
    case VMissing{}:
      False{}
    case VNull{}:
      False{}
    case VBool{b}:
      b
    case VNum{n}:
      Bool.not(N.Num.is_zero(n))
    case VStr{s}:
      Bool.not(String.is_empty(s))
    case other:
      True{}

# JS `a || b`.
def Value.or(+a: Value, b: Value) -> Value:
  Bool.pick(Value, Value.truthy(a), a, b)

# The number a value is when `typeof v === 'number'`, else 0: `num` of
# shared/transactions.ts.
def Value.num(v: Value) -> N.Num:
  match v:
    case VNum{n}:
      n
    case other:
      N.Num.zero()

# Text
# ----

def Value.lower_code(+x: U32) -> U32:
  +up = (x >= 65 : U32) && (x <= 90 : U32) || (x >= 192 : U32) && (x <= 222 : U32) && U32.is_ne(x, 215) ||
    (x >= 913 : U32) && (x <= 939 : U32) && U32.is_ne(x, 930) || (x >= 1040 : U32) && (x <= 1071 : U32)
  +far = (x >= 1024 : U32) && (x <= 1039 : U32)
  (x + Bool.to_u32(up) * 32 + Bool.to_u32(far) * 80 : U32)

def Value.lower_char(c: Char) -> Char:
  match c:
    case Chr{x}:
      Chr{Value.lower_code(x)}

# JS `s.toLowerCase()`.
def Value.lower(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{h, t}:
      SCon{Value.lower_char(h), Value.lower(t)}

def Value.join(v: Value) -> String:
  match v:
    case VElem{x, VEnd{}}:
      Value.join(x)
    case VElem{x, rest}:
      Value.join(x) ++ "," ++ Value.join(rest)
    case VArr{cells}:
      Value.join(cells)
    case VStr{s}:
      s
    case VNum{n}:
      N.Num.show(n)
    case VBool{True{}}:
      "true"
    case VBool{False{}}:
      "false"
    case VObj{cells}:
      "[object Object]"
    case other:
      ""

# JS `String(v)`.
def Value.to_string(v: Value) -> String:
  match v:
    case VMissing{}:
      "undefined"
    case VNull{}:
      "null"
    case other:
      Value.join(other)

def Value.to_json(v: Value) -> J.Json:
  match v:
    case VMissing{}:
      J.JNull{}
    case VNull{}:
      J.JNull{}
    case VBool{b}:
      J.JBool{b}
    case VNum{N.Num{neg, num, 1n}}:
      J.JInt{I.Int{neg, num}}
    case VNum{n}:
      J.JDec{N.Num.show(n)}
    case VStr{s}:
      J.JStr{s}
    case VArr{cells}:
      J.JArr{Value.to_json(cells)}
    case VObj{cells}:
      J.JObj{Value.to_json(cells)}
    case VElem{x, rest}:
      J.JElem{Value.to_json(x), Value.to_json(rest)}
    case VPair{k, VMissing{}, rest}:
      Value.to_json(rest)
    case VPair{k, x, rest}:
      J.JPair{k, Value.to_json(x), Value.to_json(rest)}
    case VEnd{}:
      J.JEnd{}

# JS `JSON.stringify(v)`: an object's undefined members are left out and
# `undefined` itself is the text "undefined", as a template literal prints it.
def Value.show(v: Value) -> String:
  match v:
    case VMissing{}:
      "undefined"
    case other:
      J.Json.show(Value.to_json(other))

def Value.digits(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{h, t}:
      Bool.and(Char.is_digit(h), Value.digits(t))

def Value.numeric.parts(ps: List<&2, String>) -> Bool:
  match ps:
    case Con{+a, Nil{}}:
      Bool.and(Bool.not(String.is_empty(a)), Value.digits(a))
    case Con{+a, Con{+b, Nil{}}}:
      Bool.and(Bool.not(String.is_empty(a ++ b)), Bool.and(Value.digits(a), Value.digits(b)))
    case other:
      False{}

def Value.unsigned(s: String) -> String:
  match s:
    case SCon{'-', t}:
      t
    case SCon{'+', t}:
      t
    case other:
      other

def Value.string_number(+s: String) -> Maybe<&2, N.Num>:
  C.If(Maybe<&2, N.Num>, String.is_empty(s),
    u => Some{N.Num.zero()},
    u => C.If(Maybe<&2, N.Num>, Value.numeric.parts(String.split(Value.unsigned(s), '.')),
      u => U.Util.parse_float(s),
      u => None{}))

def Value.trim_js(s: String) -> String:
  match s:
    case SCon{Chr{+x}, +t}:
      C.If(String, T.Text.is_js_space(x), u => Value.trim_js(t), u => SCon{Chr{x}, t})
    case SNil{}:
      SNil{}

# JS `Number(v)`; None is NaN.
def Value.to_number(v: Value) -> Maybe<&2, N.Num>:
  match v:
    case VNull{}:
      Some{N.Num.zero()}
    case VBool{b}:
      Some{N.Num.from_nat(U32.to_nat(Bool.to_u32(b)))}
    case VNum{n}:
      Some{n}
    case VStr{s}:
      Value.string_number(String.reverse(Value.trim_js(String.reverse(Value.trim_js(s)))))
    case other:
      None{}

# Equality
# --------

def Value.bool_eq(a: Bool, b: Bool) -> Bool:
  Bool.not(Bool.xor(a, b))

# Equal structure, all the way down.
def Value.eq(a: Value, b: Value) -> Bool:
  match a b:
    case VMissing{} VMissing{}:
      True{}
    case VNull{} VNull{}:
      True{}
    case VBool{x} VBool{y}:
      Value.bool_eq(x, y)
    case VNum{x} VNum{y}:
      N.Num.is_eq(x, y)
    case VStr{x} VStr{y}:
      String.eq(x, y)
    case VArr{x} VArr{y}:
      Value.eq(x, y)
    case VObj{x} VObj{y}:
      Value.eq(x, y)
    case VElem{x, r} VElem{y, s}:
      Bool.and(Value.eq(x, y), Value.eq(r, s))
    case VPair{k, x, r} VPair{l, y, s}:
      Bool.and(String.eq(k, l), Bool.and(Value.eq(x, y), Value.eq(r, s)))
    case VEnd{} VEnd{}:
      True{}
    case _ _:
      False{}

# JS `a === b` for two values that are not the same object.
def Value.strict_eq(a: Value, b: Value) -> Bool:
  match a b:
    case VArr{x} _:
      False{}
    case VObj{x} _:
      False{}
    case x y:
      Value.eq(x, y)

# Whether an array holds a value that is `===` to x: `xs.indexOf(x) !== -1`.
def Value.includes(xs: Value, +x: Value) -> Bool:
  match xs:
    case VArr{cells}:
      Value.includes(cells, x)
    case VElem{y, rest}:
      Bool.or(Value.strict_eq(y, x), Value.includes(rest, x))
    case other:
      False{}

# Transactions
# ------------

# The value of a field; `VMissing` when the transaction has no such key.
def Txn.get(t: List<&2, Field>, +key: String) -> Value:
  match t:
    case Nil{}:
      VMissing{}
    case Con{Field{k, v}, rest}:
      C.If(Value, String.eq(k, key), u => v, u => Txn.get(rest, key))

# JS `key in t`.
def Txn.has(t: List<&2, Field>, +key: String) -> Bool:
  match t:
    case Nil{}:
      False{}
    case Con{Field{k, v}, rest}:
      Bool.or(String.eq(k, key), Txn.has(rest, key))

# JS `t[key] = v`: an existing key keeps its place, a new one goes last.
def Txn.set(t: List<&2, Field>, +key: String, +v: Value) -> List<&2, Field>:
  match t:
    case Nil{}:
      [Field{key, v}]
    case Con{Field{+k, +w}, +rest}:
      C.If(List<&2, Field>, String.eq(k, key),
        u => Con{Field{k, v}, rest},
        u => Con{Field{k, w}, Txn.set(rest, key, v)})

# JS `delete t[key]`.
def Txn.del(t: List<&2, Field>, +key: String) -> List<&2, Field>:
  match t:
    case Nil{}:
      Nil{}
    case Con{Field{+k, +w}, +rest}:
      C.If(List<&2, Field>, String.eq(k, key), u => rest, u => Con{Field{k, w}, Txn.del(rest, key)})

def Txn.assign.go(changes: List<&2, Field>, t: List<&2, Field>) -> List<&2, Field>:
  match changes:
    case Nil{}:
      t
    case Con{Field{k, v}, rest}:
      Txn.assign.go(rest, Txn.set(t, k, v))

# JS `Object.assign(t, changes)`.
def Txn.assign(t: List<&2, Field>, changes: List<&2, Field>) -> List<&2, Field>:
  Txn.assign.go(changes, t)

# The transaction as JSON text, the way `JSON.stringify` writes it.
def Txn.show(t: List<&2, Field>) -> String:
  Value.show(Value.object(t))

# JavaScript's view of a JSON value, for the dynamically typed query and
# expression values of AQL: `String(v)`, truthiness, `Object.entries(v)`,
# `JSON.stringify(v, null, 2)` and the equality a `Set` uses.
#
# Deviation: an object keeps its members in source order, a repeated key
# included; JS moves integer-like keys first and keeps one member per key.
import Base
import ../json/json.bend as J
import ../lib/int.bend as I

def Js.comma(rest: J.Json) -> String:
  match rest:
    case J.JEnd{}:
      ""
    case other:
      ","

# `String(v)`: an array joins its elements with commas, a null element being
# empty; an object is "[object Object]".
def Js.string(j: J.Json) -> String:
  match j:
    case J.JNull{}:
      "null"
    case J.JBool{True{}}:
      "true"
    case J.JBool{False{}}:
      "false"
    case J.JInt{i}:
      I.Int.show(i)
    case J.JDec{text}:
      text
    case J.JStr{s}:
      s
    case J.JArr{cells}:
      Js.string(cells)
    case J.JObj{cells}:
      "[object Object]"
    case J.JElem{J.JNull{}, +rest}:
      Js.comma(rest) ++ Js.string(rest)
    case J.JElem{v, +rest}:
      Js.string(v) ++ Js.comma(rest) ++ Js.string(rest)
    case J.JPair{k, v, rest}:
      ""
    case J.JEnd{}:
      ""

# `!!v`.
def Js.truthy(j: J.Json) -> Bool:
  match j:
    case J.JNull{}:
      False{}
    case J.JBool{b}:
      b
    case J.JInt{i}:
      Bool.not(I.Int.is_zero(i))
    case J.JStr{s}:
      Bool.not(String.is_empty(s))
    case other:
      True{}

def Js.is_string(j: J.Json) -> Bool:
  match j:
    case J.JStr{s}:
      True{}
    case other:
      False{}

def Js.is_array(j: J.Json) -> Bool:
  match j:
    case J.JArr{cells}:
      True{}
    case other:
      False{}

def Js.is_object(j: J.Json) -> Bool:
  match j:
    case J.JObj{cells}:
      True{}
    case other:
      False{}

def Js.is_null(j: J.Json) -> Bool:
  match j:
    case J.JNull{}:
      True{}
    case other:
      False{}

# The elements of an array as index-keyed members.
def Js.indexed(cells: J.Json, +i: Nat) -> List<&2, J.Json.Member>:
  match cells:
    case J.JElem{v, rest}:
      J.Member{Nat.show(i), v} <> Js.indexed(rest, 1n+i)
    case other:
      Nil{}

# The characters of a string as index-keyed members.
def Js.chars(s: String, +i: Nat) -> List<&2, J.Json.Member>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{c, t}:
      J.Member{Nat.show(i), J.JStr{SCon{c, SNil{}}}} <> Js.chars(t, 1n+i)

# `Object.entries(v)` for anything but null.
def Js.entries(j: J.Json) -> List<&2, J.Json.Member>:
  match j:
    case J.JObj{cells}:
      J.Json.members(J.JObj{cells})
    case J.JArr{cells}:
      Js.indexed(cells, 0n)
    case J.JStr{s}:
      Js.chars(s, 0n)
    case other:
      Nil{}

# The object `{[key]: value}`.
def Js.single(key: String, value: J.Json) -> J.Json:
  J.JObj{J.JPair{key, value, J.JEnd{}}}

def Js.is_end(j: J.Json) -> Bool:
  match j:
    case J.JEnd{}:
      True{}
    case other:
      False{}

def Js.break(rest: J.Json) -> String:
  match rest:
    case J.JEnd{}:
      ""
    case other:
      ",\n"

# `JSON.stringify(v, null, 2)`; `ind` is the indentation of the line v starts
# on. Cells are written at `ind`, one per line.
def Js.pretty(j: J.Json, +ind: String) -> String:
  match j:
    case J.JArr{J.JEnd{}}:
      "[]"
    case J.JObj{J.JEnd{}}:
      "{}"
    case J.JArr{cells}:
      "[\n" ++ Js.pretty(cells, ind ++ "  ") ++ "\n" ++ ind ++ "]"
    case J.JObj{cells}:
      "{\n" ++ Js.pretty(cells, ind ++ "  ") ++ "\n" ++ ind ++ "}"
    case J.JElem{v, +rest}:
      ind ++ Js.pretty(v, ind) ++ Js.break(rest) ++ Js.pretty(rest, ind)
    case J.JPair{k, v, +rest}:
      ind ++ J.Json.quote(k) ++ ": " ++ Js.pretty(v, ind) ++ Js.break(rest) ++ Js.pretty(rest, ind)
    case J.JEnd{}:
      ""
    case other:
      J.Json.show(other)

# Whether a `Set` holds two values as one: primitives of one type with one
# value. Arrays and objects are never the same.
def Js.same(a: J.Json, b: J.Json) -> Bool:
  match a b:
    case J.JNull{} J.JNull{}:
      True{}
    case J.JBool{x} J.JBool{y}:
      Bool.not(Bool.xor(x, y))
    case J.JInt{x} J.JInt{y}:
      I.Int.is_eq(x, y)
    case J.JDec{x} J.JDec{y}:
      String.eq(x, y)
    case J.JStr{x} J.JStr{y}:
      String.eq(x, y)
    case _ _:
      False{}

# The text of a string value; empty for anything else.
def Js.text(j: J.Json) -> String:
  match j:
    case J.JStr{s}:
      s
    case other:
      ""

# `xs.map(f)` over a reusable list.
def Js.map(~A: Data, ~B: Data, ~f: A -> B, xs: List<&2, A>) -> List<&2, B>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      f(h) <> Js.map(~A, ~B, ~f, t)

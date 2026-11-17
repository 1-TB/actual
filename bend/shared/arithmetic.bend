# The arithmetic evaluator behind amount inputs ("12.50 + 3 * 2"): a port of
# packages/loot-core/src/shared/arithmetic.ts.
#
# The TypeScript parses to a tree and then evaluates it in floating point,
# answering a default when parsing throws or the result is not finite. Here
# the value is computed while parsing, in exact rationals (`N.Num`), and
# `Arith.eval` answers `None` where the TS answers its default. Two results
# differ from the TS: a fractional exponent (`2^.5`) and any value whose
# reduced fraction needs more than 48 bits answer `None`.
#
# Bend defs cannot be mutually recursive, so the grammar's functions are the
# modes of one def, `Arith.go`.
import Base
import ../lib/core.bend as C
import ../lib/num.bend as N
import ./util.bend as F

# A parsed value and the text after it.
type Arith.Step is Data:
  Step{value: N.Num, rest: String}

def Arith.within(+x: U32, lo: U32, hi: U32) -> Bool:
  Bool.and(U32.is_ge(x, lo), U32.is_le(x, hi))

# JS `\s`.
def Arith.is_space(+x: U32) -> Bool:
  Arith.within(x, 9, 13) ||
    U32.is_eq(x, 32) ||
    U32.is_eq(x, 160) ||
    U32.is_eq(x, 5760) ||
    Arith.within(x, 8192, 8202) ||
    U32.is_eq(x, 8232) ||
    U32.is_eq(x, 8233) ||
    U32.is_eq(x, 8239) ||
    U32.is_eq(x, 8287) ||
    U32.is_eq(x, 12288) ||
    U32.is_eq(x, 65279)

# `s.replace(/\s/g, '')`
def Arith.strip(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+x}, t}:
      Bool.pick(String, Arith.is_space(x), SNil{}, SCon{Chr{x}, SNil{}}) ++ Arith.strip(t)

# Unicode currency symbols, `\p{Sc}`.
def Arith.is_currency(+x: U32) -> Bool:
  U32.is_eq(x, 36) ||
    Arith.within(x, 162, 165) ||
    U32.is_eq(x, 1423) ||
    U32.is_eq(x, 1547) ||
    Arith.within(x, 2046, 2047) ||
    Arith.within(x, 2546, 2547) ||
    U32.is_eq(x, 2555) ||
    U32.is_eq(x, 2801) ||
    U32.is_eq(x, 3065) ||
    U32.is_eq(x, 3647) ||
    U32.is_eq(x, 6107) ||
    Arith.within(x, 8352, 8384) ||
    U32.is_eq(x, 43064) ||
    U32.is_eq(x, 65020) ||
    U32.is_eq(x, 65129) ||
    U32.is_eq(x, 65284) ||
    Arith.within(x, 65504, 65505) ||
    Arith.within(x, 65509, 65510)

# A character of a number: `[0-9,.'\u2019\u00A0\u202F ]|\p{Sc}`.
def Arith.is_number_char(+x: U32) -> Bool:
  Arith.within(x, 48, 57) ||
    U32.is_eq(x, 44) ||
    U32.is_eq(x, 46) ||
    U32.is_eq(x, 39) ||
    U32.is_eq(x, 8217) ||
    U32.is_eq(x, 160) ||
    U32.is_eq(x, 8239) ||
    U32.is_eq(x, 32) ||
    Arith.is_currency(x)

type Arith.Span is Data:
  Span{text: String, rest: String}

def Arith.span.put(c: Char, r: Arith.Span) -> Arith.Span:
  match r:
    case Span{text, rest}:
      Span{SCon{c, text}, rest}

# The number characters at the head of s, and what follows.
def Arith.span(s: String) -> Arith.Span:
  match s:
    case SNil{}:
      Span{SNil{}, SNil{}}
    case SCon{Chr{+x}, +t}:
      C.If(Arith.Span, Arith.is_number_char(x),
        u => Arith.span.put(Chr{x}, Arith.span(t)),
        u => Span{SNil{}, SCon{Chr{x}, t}})

def Arith.primary.make(neg: Bool, amount: Maybe<&2, N.Num>, rest: String) -> Maybe<&2, Arith.Step>:
  match neg amount:
    case _ None{}:
      None{}
    case True{} Some{a}:
      Some{Step{N.Num.neg(a), rest}}
    case False{} Some{a}:
      Some{Step{a, rest}}

def Arith.primary.at(neg: Bool, span: Arith.Span, f: F.NumberFormat) -> Maybe<&2, Arith.Step>:
  match span:
    case Span{SNil{}, rest}:
      None{}
    case Span{text, rest}:
      Arith.primary.make(neg, F.Util.currency_to_amount(text, f), rest)

# A number in the user's format, with an optional leading minus.
def Arith.primary(s: String, f: F.NumberFormat) -> Maybe<&2, Arith.Step>:
  match s:
    case SCon{'-', t}:
      Arith.primary.at(True{}, Arith.span(t), f)
    case other:
      Arith.primary.at(False{}, Arith.span(other), f)

def Arith.then(
  m: Maybe<&2, Arith.Step>, f: N.Num -> String -> Maybe<&2, Arith.Step>
) -> Maybe<&2, Arith.Step>:
  match m:
    case None{}:
      None{}
    case Some{Step{v, rest}}:
      f(v, rest)

def Arith.step(v: Maybe<&2, N.Num>, rest: String) -> Maybe<&2, Arith.Step>:
  match v:
    case None{}:
      None{}
    case Some{a}:
      Some{Step{a, rest}}

# Which operator, if any, is at the head of s: its code point, or 0.
def Arith.head(s: String) -> U32:
  match s:
    case SCon{Chr{x}, t}:
      x
    case other:
      0

# The grammar, one mode per function of the TS parser:
#   0 additive        = multiplicative (('+' | '-') multiplicative)*
#   1 multiplicative  = exponent (('*' | '/') exponent)*
#   2 exponent        = parens ('^' exponent)?
#   3 parens          = '(' additive ')' | primary
#   4 the tail of an additive, with the sum so far in `acc`
#   5 the tail of a multiplicative, with the product so far in `acc`
# Every call spends one unit of fuel.
def Arith.go(+fuel: Nat, mode: U32, +s: String, +acc: N.Num, +f: F.NumberFormat) -> Maybe<&2, Arith.Step>:
  match fuel mode:
    case 0n _:
      None{}
    case 1n+g 0:
      Arith.then(Arith.go(g, 1, s, N.Num.zero(), f), v => rest => Arith.go(g, 4, rest, v, f))
    case 1n+g 1:
      Arith.then(Arith.go(g, 2, s, N.Num.zero(), f), v => rest => Arith.go(g, 5, rest, v, f))
    case 1n+g 2:
      Arith.then(Arith.go(g, 3, s, N.Num.zero(), f), +v => +rest =>
        C.If(Maybe<&2, Arith.Step>, U32.is_eq(Arith.head(rest), 94),
          u => Arith.then(Arith.go(g, 2, String.drop(rest, 1n), N.Num.zero(), f),
            e => after => Arith.step(N.Num.pow(v, e), after)),
          u => Some{Step{v, rest}}))
    case 1n+g 3:
      C.If(Maybe<&2, Arith.Step>, U32.is_eq(Arith.head(s), 40),
        u => Arith.then(Arith.go(g, 0, String.drop(s, 1n), N.Num.zero(), f), v => +rest =>
          Bool.pick(Maybe<&2, Arith.Step>, U32.is_eq(Arith.head(rest), 41),
            Some{Step{v, String.drop(rest, 1n)}}, None{})),
        u => Arith.primary(s, f))
    case 1n+g 4:
      C.If(Maybe<&2, Arith.Step>, U32.is_eq(Arith.head(s), 43),
        u => Arith.then(Arith.go(g, 1, String.drop(s, 1n), N.Num.zero(), f), v => rest =>
          Arith.then(Arith.step(N.Num.add(acc, v), rest), sum => after => Arith.go(g, 4, after, sum, f))),
        u => C.If(Maybe<&2, Arith.Step>, U32.is_eq(Arith.head(s), 45),
          w => Arith.then(Arith.go(g, 1, String.drop(s, 1n), N.Num.zero(), f), v => rest =>
            Arith.then(Arith.step(N.Num.sub(acc, v), rest), sum => after => Arith.go(g, 4, after, sum, f))),
          w => Some{Step{acc, s}}))
    case 1n+g 5:
      C.If(Maybe<&2, Arith.Step>, U32.is_eq(Arith.head(s), 42),
        u => Arith.then(Arith.go(g, 2, String.drop(s, 1n), N.Num.zero(), f), v => rest =>
          Arith.then(Arith.step(N.Num.mul(acc, v), rest), p => after => Arith.go(g, 5, after, p, f))),
        u => C.If(Maybe<&2, Arith.Step>, U32.is_eq(Arith.head(s), 47),
          w => Arith.then(Arith.go(g, 2, String.drop(s, 1n), N.Num.zero(), f), v => rest =>
            Arith.then(Arith.step(N.Num.div(acc, v), rest), q => after => Arith.go(g, 5, after, q, f))),
          w => Some{Step{acc, s}}))
    case 1n+g _:
      None{}

def Arith.value(r: Maybe<&2, Arith.Step>) -> Maybe<&2, N.Num>:
  match r:
    case None{}:
      None{}
    case Some{Step{v, rest}}:
      Some{v}

def Arith.eval.text(+s: String, f: F.NumberFormat) -> Maybe<&2, N.Num>:
  Arith.value(Arith.go((String.length(s) * 8n + 16n : Nat), 0, s, N.Num.zero(), f))

# The value of an expression typed in the number format `f`; characters left
# over after a complete expression are ignored. None for an empty or
# malformed expression, a division by zero, and a result that does not fit:
# wherever `evalArithmetic` answers its default.
def Arith.eval(expression: String, f: F.NumberFormat) -> Maybe<&2, N.Num>:
  Arith.eval.text(Arith.strip(expression), f)

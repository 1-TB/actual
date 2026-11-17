# Exact rational numbers, standing in for the JS `number` wherever the
# TypeScript holds a decimal amount (3.45, 1222.45) or divides. Bend has no
# 64-bit floats, and exact arithmetic is what money wants anyway.
#
# A number is a sign and a reduced fraction of naturals. Bend's naturals stop
# at 2^48 - 1, so every operation answers `None` when a numerator or a
# denominator would pass that bound, and for a division by zero. Callers
# treat `None` as JS treats a non-finite result.
import Base
import ./core.bend as C
import ./int.bend as I
import ./text.bend as T

type Num is Data:
  Num{neg: Bool, num: Nat, den: Nat}

# 2^48 - 1, the largest natural.
def Num.limit() -> Nat:
  (16777216n * 16777215n + 16777215n : Nat)

# a * b, or None when it passes the limit.
def Num.times(+a: Nat, +b: Nat) -> Maybe<&2, Nat>:
  C.If(Maybe<&2, Nat>, Bool.or(Nat.is_eq(b, 0n), Nat.is_le(a, Nat.div(Num.limit(), b))),
    u => Some{(a * b : Nat)},
    u => None{})

# a + b, or None when it passes the limit.
def Num.plus(+a: Nat, +b: Nat) -> Maybe<&2, Nat>:
  C.If(Maybe<&2, Nat>, Nat.is_le(a, Nat.sub(Num.limit(), b)),
    u => Some{(a + b : Nat)},
    u => None{})

# The greatest common divisor, by Euclid; 48 bits need at most 70 steps.
def Num.gcd.go(fuel: Nat, +a: Nat, +b: Nat, done: Bool) -> Nat:
  match fuel done:
    case 0n _:
      a
    case 1n+f True{}:
      a
    case 1n+f False{}:
      +r = Nat.mod(a, b)
      Num.gcd.go(f, b, r, Nat.is_eq(r, 0n))

def Num.gcd(+a: Nat, +b: Nat) -> Nat:
  Bool.pick(Nat, Nat.is_eq(b, 0n), a, Num.gcd.go(80n, a, b, False{}))

# The reduced fraction num/den with a sign; zero is never negative. `den`
# must not be zero.
def Num.make(neg: Bool, +num: Nat, +den: Nat) -> Num:
  +g = C.Nat.hi(Num.gcd(num, den), 1n)
  Num{Bool.and(neg, Nat.is_ne(num, 0n)), Nat.div(num, g), Nat.div(den, g)}

def Num.zero() -> Num:
  Num{False{}, 0n, 1n}

def Num.from_nat(n: Nat) -> Num:
  Num{False{}, n, 1n}

def Num.from_int(i: I.Int) -> Num:
  match i:
    case I.Int{neg, abs}:
      Num{neg, abs, 1n}

def Num.neg(a: Num) -> Num:
  match a:
    case Num{neg, +num, den}:
      Num{Bool.and(Bool.not(neg), Nat.is_ne(num, 0n)), num, den}

def Num.is_zero(a: Num) -> Bool:
  match a:
    case Num{neg, num, den}:
      Nat.is_eq(num, 0n)

def Num.is_neg(a: Num) -> Bool:
  match a:
    case Num{neg, num, den}:
      neg

def Num.pow10(n: Nat) -> Maybe<&2, Nat>:
  match n:
    case 0n:
      Some{1n}
    case 1n+p:
      Maybe.bind(&2, Nat, Nat, Num.pow10(p), x => Num.times(x, 10n))

def Num.mul.fin(neg: Bool, n: Maybe<&2, Nat>, d: Maybe<&2, Nat>) -> Maybe<&2, Num>:
  match n d:
    case Some{x} Some{y}:
      Some{Num.make(neg, x, y)}
    case a b:
      None{}

# a * b. The factors are cross-reduced first, so a product that fits is
# never refused for an intermediate that does not.
def Num.mul(a: Num, b: Num) -> Maybe<&2, Num>:
  match a b:
    case Num{s, +an, +ad} Num{t, +bn, +bd}:
      +g1 = C.Nat.hi(Num.gcd(an, bd), 1n)
      +g2 = C.Nat.hi(Num.gcd(bn, ad), 1n)
      Num.mul.fin(Bool.xor(s, t),
        Num.times(Nat.div(an, g1), Nat.div(bn, g2)),
        Num.times(Nat.div(ad, g2), Nat.div(bd, g1)))

# 1 / a; None for zero.
def Num.inv(a: Num) -> Maybe<&2, Num>:
  match a:
    case Num{neg, +num, den}:
      Bool.pick(Maybe<&2, Num>, Nat.is_eq(num, 0n), None{}, Some{Num{neg, den, num}})

# a / b; None when b is zero.
def Num.div(a: Num, b: Num) -> Maybe<&2, Num>:
  Maybe.bind(&2, Num, Num, Num.inv(b), r => Num.mul(a, r))

def Num.add.fin(
  s: Bool, t: Bool, x: Maybe<&2, Nat>, y: Maybe<&2, Nat>, d: Maybe<&2, Nat>
) -> Maybe<&2, Num>:
  match s t x y d:
    case False{} False{} Some{p} Some{q} Some{den}:
      Maybe.map(&2, Nat, Num, n => Num.make(False{}, n, den), Num.plus(p, q))
    case True{} True{} Some{p} Some{q} Some{den}:
      Maybe.map(&2, Nat, Num, n => Num.make(True{}, n, den), Num.plus(p, q))
    case False{} True{} Some{+p} Some{+q} Some{den}:
      Some{Num.make(Nat.is_lt(p, q), Nat.sub(C.Nat.hi(p, q), C.Nat.lo(p, q)), den)}
    case True{} False{} Some{+p} Some{+q} Some{den}:
      Some{Num.make(Nat.is_gt(p, q), Nat.sub(C.Nat.hi(p, q), C.Nat.lo(p, q)), den)}
    case a b c e f:
      None{}

# a + b, over the least common denominator.
def Num.add(a: Num, b: Num) -> Maybe<&2, Num>:
  match a b:
    case Num{s, an, +ad} Num{t, bn, +bd}:
      +g = C.Nat.hi(Num.gcd(ad, bd), 1n)
      Num.add.fin(s, t, Num.times(an, Nat.div(bd, g)), Num.times(bn, Nat.div(ad, g)),
        Num.times(ad, Nat.div(bd, g)))

def Num.sub(a: Num, b: Num) -> Maybe<&2, Num>:
  Num.add(a, Num.neg(b))

# a to a natural power, by repeated multiplication.
def Num.pow.go(n: Nat, +a: Num) -> Maybe<&2, Num>:
  match n:
    case 0n:
      Some{Num.from_nat(1n)}
    case 1n+p:
      Maybe.bind(&2, Num, Num, Num.pow.go(p, a), r => Num.mul(r, a))

# a to the power b, for a whole b of magnitude up to 4096: a negative power
# is the reciprocal. None for a fractional exponent, for 0 to a negative
# power, and when the result does not fit.
def Num.pow(+a: Num, b: Num) -> Maybe<&2, Num>:
  match b:
    case Num{neg, +num, +den}:
      C.If(Maybe<&2, Num>, Bool.and(Nat.is_eq(den, 1n), Nat.is_le(num, 4096n)),
        u => Bool.pick(Maybe<&2, Num>, neg,
          Maybe.bind(&2, Num, Num, Num.pow.go(num, a), Num.inv),
          Num.pow.go(num, a)),
        u => None{})

def Num.cmp.fin(s: Bool, t: Bool, x: Maybe<&2, Nat>, y: Maybe<&2, Nat>) -> Cmp:
  match s t x y:
    case False{} True{} _ _:
      GT{}
    case True{} False{} _ _:
      LT{}
    case False{} False{} Some{p} Some{q}:
      Nat.cmp(p, q)
    case True{} True{} Some{p} Some{q}:
      Nat.cmp(q, p)
    case a b c d:
      EQ{}

# Orders two numbers. The cross products of two reduced fractions under the
# limit can pass it; such a pair compares equal.
def Num.cmp(a: Num, b: Num) -> Cmp:
  match a b:
    case Num{s, an, ad} Num{t, bn, bd}:
      Num.cmp.fin(s, t, Num.times(an, bd), Num.times(bn, ad))

def Num.is_eq(a: Num, b: Num) -> Bool:
  match a b:
    case Num{s, an, ad} Num{t, bn, bd}:
      Bool.and(Bool.not(Bool.xor(s, t)), Bool.and(Nat.is_eq(an, bn), Nat.is_eq(ad, bd)))

def Num.round.fin(neg: Bool, +twice: Nat, +den: Nat) -> I.Int:
  match neg:
    case False{}:
      # floor((2n + d) / 2d)
      I.Int.from_nat(Nat.div((twice + den : Nat), (den * 2n : Nat)))
    case True{}:
      # -floor((2n + d - 1) / 2d): a half rounds up, toward zero
      I.Int.minus(Nat.div(Nat.sub((twice + den : Nat), 1n), (den * 2n : Nat)))

def Num.round.at(neg: Bool, den: Nat, scaled: Maybe<&2, Nat>) -> Maybe<&2, I.Int>:
  match scaled:
    case None{}:
      None{}
    case Some{n}:
      Some{Num.round.fin(neg, (n * 2n : Nat), den)}

# `Math.round(a * 10^places)`: the nearest integer, a half going up.
def Num.round(a: Num, places: Nat) -> Maybe<&2, I.Int>:
  match a:
    case Num{neg, num, +den}:
      C.If(Maybe<&2, I.Int>, Nat.is_le(den, 8388608n),
        u => Num.round.at(neg, den,
          Maybe.bind(&2, Nat, Nat, Num.pow10(places), p =>
            Maybe.bind(&2, Nat, Nat, Num.times(num, p), +n =>
              Bool.pick(Maybe<&2, Nat>, Nat.is_le(n, (8388608n * 8388608n : Nat)), Some{n}, None{})))),
        u => None{})

# The integer i divided by 10^places.
def Num.from_scaled(i: I.Int, places: Nat) -> Maybe<&2, Num>:
  match i:
    case I.Int{neg, abs}:
      Maybe.map(&2, Nat, Num, d => Num.make(neg, abs, d), Num.pow10(places))

def Num.decimal.trim(s: String) -> String:
  match s:
    case SCon{'0', t}:
      Num.decimal.trim(t)
    case other:
      other

# The decimal digits of a natural with a point `places` from the right and no
# trailing zeros: (12345, 2) is "123.45", (5, 2) is "0.05", (1200, 2) is "12".
def Num.decimal(n: Nat, +places: Nat) -> String:
  +digits = T.Text.pad_left(Nat.show(n), 1n+places, '0')
  +cut = Nat.sub(String.length(digits), places)
  +frac = String.reverse(Num.decimal.trim(String.reverse(String.drop(digits, cut))))
  String.take(digits, cut) ++ Bool.pick(String, String.is_empty(frac), "", "." ++ frac)

# Finds the smallest k up to 15 with den dividing num * 10^k, and writes the
# decimal; None when the fraction does not terminate that soon.
def Num.show.go(fuel: Nat, +num: Nat, +den: Nat, +k: Nat) -> Maybe<&2, String>:
  match fuel:
    case 0n:
      None{}
    case 1n+f:
      C.If(Maybe<&2, String>, Nat.is_eq(Nat.mod(num, den), 0n),
        u => Some{Num.decimal(Nat.div(num, den), k)},
        u => Maybe.bind(&2, Nat, String, Num.times(num, 10n), n => Num.show.go(f, n, den, 1n+k)))

# The number as JS prints it when it is a short terminating decimal
# ("-3.45", "1222.45", "6"); otherwise the fraction, as "1/3".
def Num.show(a: Num) -> String:
  match a:
    case Num{neg, +num, +den}:
      Bool.pick(String, neg, "-", "") ++ Maybe.default(&2, String,
        Num.show.go(16n, num, den, 0n), Nat.show(num) ++ "/" ++ Nat.show(den))

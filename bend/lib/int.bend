# Signed integers: a sign and a magnitude. Bend's Base has only naturals
# (`Nat`, up to 2^48 - 1) and `U32`, while money amounts are signed integer
# cents. Zero is never negative, so equal integers are equal terms.
import Base

type Int is Data:
  Int{neg: Bool, abs: Nat}

# Builds an integer from a sign and a magnitude, keeping zero positive.
def Int.make(neg: Bool, +abs: Nat) -> Int:
  Int{Bool.and(neg, Nat.is_ne(abs, 0n)), abs}

def Int.zero() -> Int:
  Int{False{}, 0n}

def Int.from_nat(n: Nat) -> Int:
  Int{False{}, n}

# The integer -n.
def Int.minus(n: Nat) -> Int:
  Int.make(True{}, n)

def Int.abs(a: Int) -> Nat:
  match a:
    case Int{neg, abs}:
      abs

def Int.is_neg(a: Int) -> Bool:
  match a:
    case Int{neg, abs}:
      neg

def Int.is_zero(a: Int) -> Bool:
  Nat.is_eq(Int.abs(a), 0n)

def Int.neg(a: Int) -> Int:
  match a:
    case Int{neg, abs}:
      Int.make(Bool.not(neg), abs)

# The naturals a - b as an integer.
def Int.diff(+a: Nat, +b: Nat) -> Int:
  Bool.pick(Int, Nat.is_ge(a, b), Int{False{}, Nat.sub(a, b)}, Int{True{}, Nat.sub(b, a)})

def Int.add(a: Int, b: Int) -> Int:
  match a b:
    case Int{False{}, x} Int{False{}, y}:
      Int{False{}, (x + y : Nat)}
    case Int{True{}, x} Int{True{}, y}:
      Int{True{}, (x + y : Nat)}
    case Int{False{}, x} Int{True{}, y}:
      Int.diff(x, y)
    case Int{True{}, x} Int{False{}, y}:
      Int.diff(y, x)

def Int.sub(a: Int, b: Int) -> Int:
  Int.add(a, Int.neg(b))

def Int.mul(a: Int, b: Int) -> Int:
  match a b:
    case Int{s, x} Int{t, y}:
      Int.make(Bool.xor(s, t), (x * y : Nat))

# Division truncated toward zero, as JS `Math.trunc(a / b)`; 0 when b is 0.
def Int.div(a: Int, b: Int) -> Int:
  match a b:
    case Int{s, x} Int{t, y}:
      Int.make(Bool.xor(s, t), Nat.div(x, y))

# The remainder with the dividend's sign, as JS `a % b`; a when b is 0.
def Int.mod(a: Int, b: Int) -> Int:
  match a b:
    case Int{s, x} Int{t, y}:
      Int.make(s, Nat.mod(x, y))

def Int.cmp(a: Int, b: Int) -> Cmp:
  match a b:
    case Int{False{}, x} Int{False{}, y}:
      Nat.cmp(x, y)
    case Int{True{}, x} Int{True{}, y}:
      Nat.cmp(y, x)
    case Int{False{}, x} Int{True{}, y}:
      GT{}
    case Int{True{}, x} Int{False{}, y}:
      LT{}

def Int.is_eq(a: Int, b: Int) -> Bool:
  Cmp.is_eq(Int.cmp(a, b))

def Int.is_ne(a: Int, b: Int) -> Bool:
  Bool.not(Cmp.is_eq(Int.cmp(a, b)))

def Int.is_lt(a: Int, b: Int) -> Bool:
  Cmp.is_lt(Int.cmp(a, b))

def Int.is_le(a: Int, b: Int) -> Bool:
  Cmp.is_le(Int.cmp(a, b))

def Int.is_gt(a: Int, b: Int) -> Bool:
  Cmp.is_gt(Int.cmp(a, b))

def Int.is_ge(a: Int, b: Int) -> Bool:
  Cmp.is_ge(Int.cmp(a, b))

def Int.min(+a: Int, +b: Int) -> Int:
  Bool.pick(Int, Int.is_le(a, b), a, b)

def Int.max(+a: Int, +b: Int) -> Int:
  Bool.pick(Int, Int.is_ge(a, b), a, b)

# The integer in decimal, with a leading `-` when negative.
def Int.show(a: Int) -> String:
  match a:
    case Int{False{}, x}:
      Nat.show(x)
    case Int{True{}, x}:
      "-" ++ Nat.show(x)

# Reads an optional `-` and decimal digits.
def Int.read(s: String) -> Maybe<&2, Int>:
  match s:
    case SCon{'-', t}:
      Maybe.map(&2, Nat, Int, Int.minus, Nat.read(t))
    case t:
      Maybe.map(&2, Nat, Int, Int.from_nat, Nat.read(t))

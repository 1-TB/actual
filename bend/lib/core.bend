# Control helpers shared by every port.
import Base

# A lazy conditional: only the chosen branch runs. Bend's `match` reads a
# parameter, never a computed value, and defs cannot be mutually recursive, so
# a branch on a computed Bool that recurses goes through here.
def If(-A: Type, c: Bool, t: Unit -> A, f: Unit -> A) -> A:
  match c:
    case True{}:
      t(Unit{})
    case False{}:
      f(Unit{})

# The larger and the smaller of two naturals, without unary recursion.
def Nat.hi(+a: Nat, +b: Nat) -> Nat:
  Bool.pick(Nat, Nat.is_ge(a, b), a, b)

def Nat.lo(+a: Nat, +b: Nat) -> Nat:
  Bool.pick(Nat, Nat.is_le(a, b), a, b)

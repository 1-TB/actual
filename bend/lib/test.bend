# A tiny test runner. A test file builds a list of checks, each a name with
# the observed and the expected value as text, and `Test.run` prints one line
# per check and exits with status 1 when any differs.
import Base

type Test.Check is Data:
  Check{name: String, got: String, want: String}

def Test.bool(name: String, got: Bool, want: Bool) -> Test.Check:
  Check{name, Bool.show(got), Bool.show(want)}

def Test.nat(name: String, got: Nat, want: Nat) -> Test.Check:
  Check{name, Nat.show(got), Nat.show(want)}

def Test.u32(name: String, got: U32, want: U32) -> Test.Check:
  Check{name, U32.show(got), U32.show(want)}

def Test.report(+name: String, +got: String, +want: String, same: Bool) -> IO(U32):
  match same:
    case True{}:
      do IO<U32>:
        IO.print("ok   " ++ name)
        return 0
    case False{}:
      do IO<U32>:
        IO.print("FAIL " ++ name)
        IO.print("     got:  " ++ got)
        IO.print("     want: " ++ want)
        return 1

def Test.go(checks: List<&2, Test.Check>, +fails: U32, +total: U32) -> IO(U32 & U32):
  match checks:
    case Nil{}:
      IO.pure(U32 & U32, (fails, total))
    case Con{Check{+name, +got, +want}, rest}:
      do IO<U32 & U32>:
        bad : U32 <- Test.report(name, got, want, String.eq(got, want))
        Test.go(rest, (fails + bad : U32), (total + 1 : U32))

def Test.end(+fails: U32, total: U32, clean: Bool) -> IO(Unit):
  match clean:
    case True{}:
      IO.print("all " ++ U32.show(total) ++ " checks pass")
    case False{}:
      IO.die(Unit, 1, U32.show(fails) ++ " of " ++ U32.show(total) ++ " checks fail")

def Test.sum(r: U32 & U32) -> IO(Unit):
  (+fails, total) = r
  Test.end(fails, total, U32.is_zero(fails))

def Test.run(checks: List<&2, Test.Check>) -> IO(Unit):
  do IO<Unit>:
    r : U32 & U32 <- Test.go(checks, 0, 0)
    Test.sum(r)

# The cases of packages/crdt/src/crdt/timestamp.test.ts.
import Base
import ../lib/test.bend as T
import ./timestamp.bend as S

def show(m: Maybe<&2, S.Timestamp>) -> String:
  match m:
    case None{}:
      "null"
    case Some{t}:
      S.Timestamp.show(t)

def parsed(s: String) -> String:
  show(S.Timestamp.parse(s))

def result(r: Result<&2, &2, S.Timestamp.Error, S.Timestamp>) -> String:
  match r:
    case Fail{e}:
      "error: " ++ S.Timestamp.Error.show(e)
    case Done{t}:
      S.Timestamp.show(t)

# The clock after a step; a failed step leaves it as it was.
def step(+old: S.Timestamp, r: Result<&2, &2, S.Timestamp.Error, S.Timestamp>) -> S.Timestamp:
  match r:
    case Fail{e}:
      old
    case Done{t}:
      t

def send(clock: S.Timestamp, phys: Nat) -> Result<&2, &2, S.Timestamp.Error, S.Timestamp>:
  S.Timestamp.send(clock, phys, S.Timestamp.max_drift())

def recv(clock: S.Timestamp, msg: String, phys: Nat) -> Result<&2, &2, S.Timestamp.Error, S.Timestamp>:
  S.Timestamp.recv(clock, Maybe.default(&2, S.Timestamp, S.Timestamp.parse(msg), S.Timestamp.zero()),
    phys, S.Timestamp.max_drift())

# Sends n times at one wall time and answers the last result.
def spam(n: Nat, +clock: S.Timestamp, +phys: Nat) -> Result<&2, &2, S.Timestamp.Error, S.Timestamp>:
  match n:
    case 0n:
      send(clock, phys)
    case 1n+p:
      spam(p, step(clock, send(clock, phys)), phys)

def node1() -> S.Timestamp:
  S.Timestamp.init("1")

def comparison() -> List<&2, T.Test.Check>:
  +sent = step(node1(), send(node1(), 0n))
  [ T.Test.bool("max > zero", Cmp.is_gt(S.Timestamp.cmp(S.Timestamp.max(), S.Timestamp.zero())), True{}),
    T.Test.bool("sent > zero", Cmp.is_gt(S.Timestamp.cmp(sent, S.Timestamp.zero())), True{}),
    T.Test.bool("sent < max", Cmp.is_lt(S.Timestamp.cmp(sent, S.Timestamp.max())), True{}) ]

def parsing() -> List<&2, T.Test.Check>:
  [ T.Check{"no parse: empty", parsed(""), "null"},
    T.Check{"no parse: space", parsed(" "), "null"},
    T.Check{"no parse: 0", parsed("0"), "null"},
    T.Check{"no parse: invalid", parsed("invalid"), "null"},
    T.Check{"no parse: short fields", parsed("1969-1-1T0:0:0.0Z-0-0-0"), "null"},
    T.Check{"no parse: before epoch", parsed("1969-01-01T00:00:00.000Z-0000-0000000000000000"), "null"},
    T.Check{"no parse: year 10000", parsed("10000-01-01T00:00:00.000Z-FFFF-FFFFFFFFFFFFFFFF"), "null"},
    T.Check{"no parse: counter overflow", parsed("9999-12-31T23:59:59.999Z-10000-FFFFFFFFFFFFFFFF"), "null"},
    T.Check{"no parse: node overflow", parsed("9999-12-31T23:59:59.999Z-FFFF-10000000000000000"), "null"},
    T.Check{"parse: zero", parsed("1970-01-01T00:00:00.000Z-0000-0000000000000000"),
      "1970-01-01T00:00:00.000Z-0000-0000000000000000"},
    T.Check{"parse: 2015", parsed("2015-04-24T22:23:42.123Z-1000-0123456789ABCDEF"),
      "2015-04-24T22:23:42.123Z-1000-0123456789ABCDEF"},
    T.Check{"parse: max", parsed("9999-12-31T23:59:59.999Z-FFFF-FFFFFFFFFFFFFFFF"),
      "9999-12-31T23:59:59.999Z-FFFF-FFFFFFFFFFFFFFFF"},
    T.Check{"zero", S.Timestamp.show(S.Timestamp.zero()), "1970-01-01T00:00:00.000Z-0000-0000000000000000"},
    T.Check{"max", S.Timestamp.show(S.Timestamp.max()), "9999-12-31T23:59:59.999Z-FFFF-FFFFFFFFFFFFFFFF"},
    T.Test.u32("hash", S.Timestamp.hash(S.Timestamp.zero()), 4179357717) ]

def sending() -> List<&2, T.Test.Check>:
  +a1 = step(node1(), send(node1(), 10n))
  +a2 = step(a1, send(a1, 11n))
  +a3 = step(a2, send(a2, 12n))
  +b1 = step(node1(), send(node1(), 20n))
  +b2 = step(b1, send(b1, 20n))
  +b3 = step(b2, send(b2, 20n))
  +b4 = step(b3, send(b3, 21n))
  +c1 = step(node1(), send(node1(), 30n))
  +c2 = step(c1, send(c1, 29n))
  +c3 = step(c2, send(c2, 29n))
  +c4 = step(c3, send(c3, 31n))
  [ T.Check{"monotonic 1", S.Timestamp.show(a1), "1970-01-01T00:00:00.010Z-0000-0000000000000001"},
    T.Check{"monotonic 2", S.Timestamp.show(a2), "1970-01-01T00:00:00.011Z-0000-0000000000000001"},
    T.Check{"monotonic 3", S.Timestamp.show(a3), "1970-01-01T00:00:00.012Z-0000-0000000000000001"},
    T.Check{"stuttering 1", S.Timestamp.show(b1), "1970-01-01T00:00:00.020Z-0000-0000000000000001"},
    T.Check{"stuttering 2", S.Timestamp.show(b2), "1970-01-01T00:00:00.020Z-0001-0000000000000001"},
    T.Check{"stuttering 3", S.Timestamp.show(b3), "1970-01-01T00:00:00.020Z-0002-0000000000000001"},
    T.Check{"stuttering 4", S.Timestamp.show(b4), "1970-01-01T00:00:00.021Z-0000-0000000000000001"},
    T.Check{"regressing 1", S.Timestamp.show(c1), "1970-01-01T00:00:00.030Z-0000-0000000000000001"},
    T.Check{"regressing 2", S.Timestamp.show(c2), "1970-01-01T00:00:00.030Z-0001-0000000000000001"},
    T.Check{"regressing 3", S.Timestamp.show(c3), "1970-01-01T00:00:00.030Z-0002-0000000000000001"},
    T.Check{"regressing 4", S.Timestamp.show(c4), "1970-01-01T00:00:00.031Z-0000-0000000000000001"},
    T.Check{"counter overflow", result(spam(65536n, node1(), 40n)), "error: timestamp counter overflow"},
    T.Check{"last before overflow", result(spam(65535n, node1(), 40n)),
      "1970-01-01T00:00:00.040Z-FFFF-0000000000000001"},
    T.Check{"clock drift", result(send(step(node1(), send(node1(), 400001n)), 100000n)),
      "error: maximum clock drift exceeded 400001 100000 300000"} ]

def main() -> IO(Unit):
  T.Test.run(List.concat(&2, T.Test.Check, [comparison(), parsing(), sending()]))

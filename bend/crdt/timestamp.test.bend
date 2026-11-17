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

def receiving() -> List<&2, T.Test.Check>:
  +r0_0 = step(node1(), recv(node1(), "1970-01-01T00:00:00.051Z-0000-0000000000000002", 52n))
  +r0_1 = step(r0_0, recv(r0_0, "1970-01-01T00:00:00.053Z-0000-0000000000000002", 54n))
  +r0_2 = step(r0_1, recv(r0_1, "1970-01-01T00:00:00.055Z-0000-0000000000000002", 56n))
  +r1_0 = step(node1(), recv(node1(), "1970-01-01T00:00:00.062Z-0000-0000000000000002", 61n))
  +r1_1 = step(r1_0, recv(r1_0, "1970-01-01T00:00:00.062Z-0001-0000000000000002", 62n))
  +r1_2 = step(r1_1, recv(r1_1, "1970-01-01T00:00:00.062Z-0002-0000000000000002", 62n))
  +r1_3 = step(r1_2, recv(r1_2, "1970-01-01T00:00:00.062Z-0004-0000000000000002", 63n))
  +r2_0 = step(node1(), recv(node1(), "1970-01-01T00:00:00.071Z-0000-0000000000000002", 73n))
  +r2_1 = step(r2_0, recv(r2_0, "1970-01-01T00:00:00.072Z-0000-0000000000000002", 73n))
  +r2_2 = step(r2_1, recv(r2_1, "1970-01-01T00:00:00.073Z-0000-0000000000000002", 74n))
  +r3_0 = step(node1(), recv(node1(), "1970-01-01T00:00:00.083Z-0000-0000000000000002", 81n))
  +r3_1 = step(r3_0, recv(r3_0, "1970-01-01T00:00:00.083Z-0001-0000000000000002", 82n))
  +r3_2 = step(r3_1, recv(r3_1, "1970-01-01T00:00:00.083Z-0002-0000000000000002", 83n))
  +r3_3 = step(r3_2, recv(r3_2, "1970-01-01T00:00:00.083Z-0003-0000000000000002", 84n))
  +r4_0 = step(node1(), recv(node1(), "1970-01-01T00:00:00.091Z-0000-0000000000000002", 93n))
  +r4_1 = step(r4_0, recv(r4_0, "1970-01-01T00:00:00.092Z-0000-0000000000000002", 92n))
  +r4_2 = step(r4_1, recv(r4_1, "1970-01-01T00:00:00.093Z-0000-0000000000000002", 91n))
  +r5_0 = step(node1(), recv(node1(), "1970-01-01T00:00:00.103Z-0000-0000000000000002", 101n))
  +r5_1 = step(r5_0, recv(r5_0, "1970-01-01T00:00:00.102Z-0000-0000000000000002", 102n))
  +r5_2 = step(r5_1, recv(r5_1, "1970-01-01T00:00:00.101Z-0000-0000000000000002", 103n))
  [
    T.Check{"recv global monotonic 1", S.Timestamp.show(r0_0), "1970-01-01T00:00:00.052Z-0000-0000000000000001"},
    T.Check{"recv global monotonic 2", S.Timestamp.show(r0_1), "1970-01-01T00:00:00.054Z-0000-0000000000000001"},
    T.Check{"recv global monotonic 3", S.Timestamp.show(r0_2), "1970-01-01T00:00:00.056Z-0000-0000000000000001"},
    T.Check{"recv global stuttering 1", S.Timestamp.show(r1_0), "1970-01-01T00:00:00.062Z-0001-0000000000000001"},
    T.Check{"recv global stuttering 2", S.Timestamp.show(r1_1), "1970-01-01T00:00:00.062Z-0002-0000000000000001"},
    T.Check{"recv global stuttering 3", S.Timestamp.show(r1_2), "1970-01-01T00:00:00.062Z-0003-0000000000000001"},
    T.Check{"recv global stuttering 4", S.Timestamp.show(r1_3), "1970-01-01T00:00:00.063Z-0000-0000000000000001"},
    T.Check{"recv local stuttering 1", S.Timestamp.show(r2_0), "1970-01-01T00:00:00.073Z-0000-0000000000000001"},
    T.Check{"recv local stuttering 2", S.Timestamp.show(r2_1), "1970-01-01T00:00:00.073Z-0001-0000000000000001"},
    T.Check{"recv local stuttering 3", S.Timestamp.show(r2_2), "1970-01-01T00:00:00.074Z-0000-0000000000000001"},
    T.Check{"recv remote stuttering 1", S.Timestamp.show(r3_0), "1970-01-01T00:00:00.083Z-0001-0000000000000001"},
    T.Check{"recv remote stuttering 2", S.Timestamp.show(r3_1), "1970-01-01T00:00:00.083Z-0002-0000000000000001"},
    T.Check{"recv remote stuttering 3", S.Timestamp.show(r3_2), "1970-01-01T00:00:00.083Z-0003-0000000000000001"},
    T.Check{"recv remote stuttering 4", S.Timestamp.show(r3_3), "1970-01-01T00:00:00.084Z-0000-0000000000000001"},
    T.Check{"recv local regressing 1", S.Timestamp.show(r4_0), "1970-01-01T00:00:00.093Z-0000-0000000000000001"},
    T.Check{"recv local regressing 2", S.Timestamp.show(r4_1), "1970-01-01T00:00:00.093Z-0001-0000000000000001"},
    T.Check{"recv local regressing 3", S.Timestamp.show(r4_2), "1970-01-01T00:00:00.093Z-0002-0000000000000001"},
    T.Check{"recv remote regressing 1", S.Timestamp.show(r5_0), "1970-01-01T00:00:00.103Z-0001-0000000000000001"},
    T.Check{"recv remote regressing 2", S.Timestamp.show(r5_1), "1970-01-01T00:00:00.103Z-0002-0000000000000001"},
    T.Check{"recv remote regressing 3", S.Timestamp.show(r5_2), "1970-01-01T00:00:00.103Z-0003-0000000000000001"},
    T.Check{"recv clock drift", result(recv(node1(), "1980-01-01T00:00:00.101Z-0000-0000000000000002", 0n)),
      "error: maximum clock drift exceeded"} ]

def main() -> IO(Unit):
  T.Test.run(List.concat(&2, T.Test.Check, [comparison(), parsing(), sending(), receiving()]))

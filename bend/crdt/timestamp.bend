# Hybrid Unique Logical Clock (HULC) timestamps: a port of
# packages/crdt/src/crdt/timestamp.ts.
#
# Globally-unique, monotonic timestamps are generated from the combination of
# the unreliable system time, a counter, and an identifier for the current
# node. They serialize into a 46-character collatable string, for example
# `2015-04-24T22:23:42.123Z-1000-0123456789ABCDEF`.
#
# The TypeScript code keeps one mutable global clock and reads `Date.now()`
# inside `send` and `recv`. Here both are arguments: `send` and `recv` take the
# clock's timestamp and the wall time, and answer the clock's next timestamp,
# which is also the timestamp to transmit.
import Base
import ../lib/core.bend as C
import ../lib/text.bend as T
import ../lib/date.bend as D
import ./murmur.bend as M

type Timestamp is Data:
  Timestamp{millis: Nat, counter: U32, node: String}

type Timestamp.Error is Data:
  # the logical time ran ahead of the wall time by more than the limit
  ClockDrift{logical: Nat, phys: Nat, limit: Nat}
  # a received timestamp is ahead of the wall time by more than the limit
  RemoteDrift{}
  # more than 65535 timestamps within one millisecond
  Overflow{}

# The largest counter: 0xFFFF.
def Timestamp.max_counter() -> U32:
  65535

# Five minutes of clock drift, in milliseconds: the default limit.
def Timestamp.max_drift() -> Nat:
  300000n

def Timestamp.millis(t: Timestamp) -> Nat:
  match t:
    case Timestamp{millis, counter, node}:
      millis

def Timestamp.counter(t: Timestamp) -> U32:
  match t:
    case Timestamp{millis, counter, node}:
      counter

def Timestamp.node(t: Timestamp) -> String:
  match t:
    case Timestamp{millis, counter, node}:
      node

# The 46-character form: ISO time, 4 hex digits of counter, 16 of node.
def Timestamp.show(t: Timestamp) -> String:
  match t:
    case Timestamp{millis, counter, node}:
      D.Date.iso_from_millis(millis) ++ "-" ++
        T.Text.last("0000" ++ T.Text.hex_upper(counter), 4n) ++ "-" ++
        T.Text.last("0000000000000000" ++ node, 16n)

# The MurmurHash3 of the string form.
def Timestamp.hash(t: Timestamp) -> U32:
  M.Murmur.v3(Timestamp.show(t))

# Timestamps order as their string forms do.
def Timestamp.cmp(a: Timestamp, b: Timestamp) -> Cmp:
  String.order(Timestamp.show(a), Timestamp.show(b))

def Timestamp.is_eq(a: Timestamp, b: Timestamp) -> Bool:
  Cmp.is_eq(Timestamp.cmp(a, b))

# The value of a hexadecimal digit, or 16 for any other character.
def Timestamp.hex_value(+x: U32) -> U32:
  Bool.pick(U32, Bool.and((x >= 48 : U32), (x <= 57 : U32)), (x - 48 : U32),
    Bool.pick(U32, Bool.and((x >= 65 : U32), (x <= 70 : U32)), (x - 55 : U32),
      Bool.pick(U32, Bool.and((x >= 97 : U32), (x <= 102 : U32)), (x - 87 : U32), 16)))

# The hexadecimal digits at the head of s, as JS `parseInt(s, 16)` reads them:
# None when there is none. Values past 0xFFFF answer 65536, which no counter
# accepts, so the sum never outgrows a U32.
def Timestamp.parse_hex(s: String, +acc: U32, +seen: Bool) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      Bool.pick(Maybe<&2, U32>, seen, Some{acc}, None{})
    case SCon{Chr{+x}, t}:
      C.If(Maybe<&2, U32>, (Timestamp.hex_value(x) < 16 : U32),
        u => Timestamp.parse_hex(t,
          U32.min((acc * 16 + Timestamp.hex_value(x) : U32), 65536), True{}),
        u => Bool.pick(Maybe<&2, U32>, seen, Some{acc}, None{}))

def Timestamp.parse.parts(parts: List<&2, String>) -> Maybe<&2, Timestamp>:
  match parts:
    case Con{y, Con{m, Con{d, Con{c, Con{n, Nil{}}}}}}:
      do Maybe<&2, Timestamp>:
        millis : Nat <- D.Date.millis_from_iso(y ++ "-" ++ m ++ "-" ++ d)
        counter : U32 <- Timestamp.parse_hex(c, 0, False{})
        +cnt : U32 = counter
        +node : String = n
        ok : Unit <- T.Text.guard(Bool.and((cnt <= 65535 : U32),
          Nat.is_le(String.length(node), 16n)))
        return Timestamp{millis, cnt, node}
    case other:
      None{}

# Converts the fixed-length string form to the structured value; None when
# the string is not a timestamp.
def Timestamp.parse(s: String) -> Maybe<&2, Timestamp>:
  Timestamp.parse.parts(String.split(s, '-'))

# The minimum timestamp: 1970-01-01T00:00:00.000Z-0000-0000000000000000.
def Timestamp.zero() -> Timestamp:
  Timestamp{0n, 0, "0000000000000000"}

# The maximum timestamp: 9999-12-31T23:59:59.999Z-FFFF-FFFFFFFFFFFFFFFF.
def Timestamp.max() -> Timestamp:
  Timestamp{(253402300n * 1000000n + 799999n : Nat), 65535, "FFFFFFFFFFFFFFFF"}

# The string form of the first timestamp at an ISO time.
def Timestamp.since(iso: String) -> String:
  iso ++ "-0000-0000000000000000"

# A clock's first timestamp, for a node id; an empty id stays empty.
def Timestamp.init(+node: String) -> Timestamp:
  Timestamp{0n, 0, Bool.pick(String, String.is_empty(node), "",
    T.Text.last("0000000000000000" ++ node, 16n))}

def Timestamp.Error.show(e: Timestamp.Error) -> String:
  match e:
    case ClockDrift{logical, phys, limit}:
      "maximum clock drift exceeded " ++ Nat.show(logical) ++ " " ++
        Nat.show(phys) ++ " " ++ Nat.show(limit)
    case RemoteDrift{}:
      "maximum clock drift exceeded"
    case Overflow{}:
      "timestamp counter overflow"

def Timestamp.seal.pick(
  logical: Nat, counter: U32, node: String, phys: Nat, limit: Nat,
  drift: Bool, over: Bool, send: Bool
) -> Result<&2, &2, Timestamp.Error, Timestamp>:
  match drift over send:
    case True{} _ True{}:
      Fail{ClockDrift{logical, phys, limit}}
    case True{} _ False{}:
      Fail{RemoteDrift{}}
    case False{} True{} _:
      Fail{Overflow{}}
    case False{} False{} _:
      Done{Timestamp{logical, counter, node}}

# Checks a new logical time and counter for drift and overflow.
def Timestamp.seal(
  +logical: Nat, +counter: U32, node: String, +phys: Nat, +limit: Nat, send: Bool
) -> Result<&2, &2, Timestamp.Error, Timestamp>:
  Timestamp.seal.pick(logical, counter, node, phys, limit,
    Nat.is_gt(Nat.sub(logical, phys), limit), (counter > 65535 : U32), send)

# Generates a unique, monotonic timestamp suitable for transmission to another
# system. `clock` is the clock's current timestamp and `phys` the wall time in
# milliseconds; the answer is both the timestamp to send and the clock's next
# value.
def Timestamp.send(
  clock: Timestamp, +phys: Nat, limit: Nat
) -> Result<&2, &2, Timestamp.Error, Timestamp>:
  match clock:
    case Timestamp{+millis, counter, node}:
      # the logical time never goes backward; the counter advances when the
      # wall time does not
      +logical = C.Nat.hi(millis, phys)
      next = Bool.pick(U32, Nat.is_eq(millis, logical), (counter + 1 : U32), 0)
      Timestamp.seal(logical, next, node, phys, limit, True{})

# The next counter: if all logical clocks are equal, one past the larger
# counter; if the local clock leads, one past its counter; if the message
# leads, one past its counter; otherwise the wall time moved on, so zero.
def Timestamp.recv.counter(is_old: Bool, is_msg: Bool, c_old: U32, c_msg: U32) -> U32:
  match is_old is_msg:
    case True{} True{}:
      (U32.max(c_old, c_msg) + 1 : U32)
    case True{} False{}:
      (c_old + 1 : U32)
    case False{} True{}:
      (c_msg + 1 : U32)
    case False{} False{}:
      0

# Merges a timestamp received from a remote system into the local clock,
# preserving global uniqueness and monotonicity.
def Timestamp.recv(
  clock: Timestamp, msg: Timestamp, +phys: Nat, +limit: Nat
) -> Result<&2, &2, Timestamp.Error, Timestamp>:
  match clock msg:
    case Timestamp{+l_old, +c_old, node} Timestamp{+l_msg, +c_msg, other}:
      C.If(Result<&2, &2, Timestamp.Error, Timestamp>,
        Nat.is_gt(Nat.sub(l_msg, phys), limit),
        u => Fail{RemoteDrift{}},
        u => Timestamp.seal(
          C.Nat.hi(C.Nat.hi(l_old, phys), l_msg),
          Timestamp.recv.counter(
            Nat.is_eq(C.Nat.hi(C.Nat.hi(l_old, phys), l_msg), l_old),
            Nat.is_eq(C.Nat.hi(C.Nat.hi(l_old, phys), l_msg), l_msg),
            c_old, c_msg),
          node, phys, limit, False{}))

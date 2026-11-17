# The sync clock: a port of the clock functions of
# packages/crdt/src/crdt/timestamp.ts (`makeClock`, `serializeClock`,
# `deserializeClock`, `makeClientId`).
#
# The TypeScript keeps the clock in a module-level variable behind `setClock`
# and `getClock`; here the clock is a value its owner passes along.
# `deserializeClock` makes up a client id when the text is not JSON, so
# `Clock.deserialize` takes that id as an argument (see `Clock.client_id`).
import Base
import ../lib/int.bend as I
import ../json/json.bend as J
import ./timestamp.bend as S
import ./merkle.bend as M

type Clock is Data:
  Clock{timestamp: S.Timestamp, merkle: M.Trie}

type Clock.Error is Data:
  # `timestamp is not valid <text>`
  Invalid{text: String}

def Clock.Error.show(e: Clock.Error) -> String:
  match e:
    case Invalid{text}:
      "timestamp is not valid " ++ text

# A clock at a timestamp with a merkle trie; `M.Merkle.blank()` is the `{}`
# the TypeScript defaults to.
def Clock.make(timestamp: S.Timestamp, merkle: M.Trie) -> Clock:
  Clock{timestamp, merkle}

def Clock.timestamp(c: Clock) -> S.Timestamp:
  match c:
    case Clock{timestamp, merkle}:
      timestamp

def Clock.merkle(c: Clock) -> M.Trie:
  match c:
    case Clock{timestamp, merkle}:
      merkle

# `{"timestamp":"...","merkle":{...}}`, as `JSON.stringify` writes it.
def Clock.serialize(c: Clock) -> String:
  match c:
    case Clock{timestamp, merkle}:
      "{\"timestamp\":" ++ J.Json.quote(S.Timestamp.show(timestamp)) ++
        ",\"merkle\":" ++ M.Merkle.to_json(merkle) ++ "}"

# A JS number as the U32 a hash is: negative values wrap.
def Clock.hash(i: I.Int) -> U32:
  match i:
    case I.Int{False{}, n}:
      U32.from_nat(n)
    case I.Int{True{}, n}:
      (0 - U32.from_nat(n) : U32)

def Clock.trie.hash(j: J.Json) -> Maybe<&2, U32>:
  match j:
    case J.JInt{i}:
      Some{Clock.hash(i)}
    case other:
      None{}

# Sets one member of a node read from JSON.
def Clock.trie.put(node: M.Trie, key: String, child: M.Trie, value: J.Json) -> M.Trie:
  match node key:
    case M.Node{hash, zero, one, two} "0":
      M.Node{hash, child, one, two}
    case M.Node{hash, zero, one, two} "1":
      M.Node{hash, zero, child, two}
    case M.Node{hash, zero, one, two} "2":
      M.Node{hash, zero, one, child}
    case M.Node{hash, zero, one, two} "hash":
      M.Node{Clock.trie.hash(value), zero, one, two}
    case other _:
      other

# Reads a trie from its JSON object; anything but an object is a missing
# node. `acc` is the node built so far while walking an object's members.
def Clock.trie.go(j: J.Json, acc: M.Trie) -> M.Trie:
  match j:
    case J.JObj{cells}:
      Clock.trie.go(cells, M.Merkle.blank())
    case J.JPair{+key, +value, rest}:
      Clock.trie.go(rest, Clock.trie.put(acc, key, Clock.trie.go(value, M.Absent{}), value))
    case J.JEnd{}:
      acc
    case other:
      M.Absent{}

def Clock.trie(j: J.Json) -> M.Trie:
  Clock.trie.go(j, M.Absent{})

def Clock.deserialize.make(+text: String, ts: Maybe<&2, S.Timestamp>, merkle: M.Trie) ->
  Result<&2, &2, Clock.Error, Clock>:
  match ts:
    case None{}:
      Fail{Invalid{text}}
    case Some{t}:
      Done{Clock{t, merkle}}

def Clock.deserialize.data(+data: J.Json) -> Result<&2, &2, Clock.Error, Clock>:
  +text = Maybe.default(&2, String,
    Maybe.bind(&2, J.Json, String, J.Json.get(data, "timestamp"), J.Json.as_string), "undefined")
  Clock.deserialize.make(text, S.Timestamp.parse(text),
    Clock.trie(Maybe.default(&2, J.Json, J.Json.get(data, "merkle"), J.JNull{})))

def Clock.deserialize.json(parsed: Maybe<&2, J.Json>, client_id: String) ->
  Result<&2, &2, Clock.Error, Clock>:
  match parsed:
    case None{}:
      Done{Clock{S.Timestamp{0n, 0, client_id}, M.Merkle.blank()}}
    case Some{data}:
      Clock.deserialize.data(data)

# Reads a serialized clock. Text that is not JSON answers a fresh clock at
# time zero for `client_id`; JSON without a valid timestamp is an error.
def Clock.deserialize(text: String, client_id: String) -> Result<&2, &2, Clock.Error, Clock>:
  Clock.deserialize.json(J.Json.parse(text), client_id)

def Clock.hex8.go(n: Nat, +x: U32, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      Clock.hex8.go(p, (x >> 4n : U32),
        SCon{Chr{((x .&. 15) + 48 + Bool.to_u32(((x .&. 15) > 9 : U32)) * 39 : U32)}, acc})

# Eight lowercase hexadecimal digits.
def Clock.hex8(x: U32) -> String:
  Clock.hex8.go(8n, x, SNil{})

# A random 16-character client id: the last 16 hexadecimal digits of a UUID
# in the TypeScript, 64 random bits here.
def Clock.client_id() -> IO(String):
  do IO<String>:
    a : U32 <- IO.try(U32, IO.random_u32())
    b : U32 <- IO.try(U32, IO.random_u32())
    return Clock.hex8(a) ++ Clock.hex8(b)

# The merkle trie that lets two clients find when their message logs
# diverged: a port of packages/crdt/src/crdt/merkle.ts.
#
# The trie is a trinary radix trie keyed by the base-3 digits of a
# timestamp's time in minutes. Each node holds the XOR of the hashes of every
# timestamp inserted below it.
#
# In TypeScript a node is an object with optional keys '0', '1', '2' and
# `hash`. Here `Absent` is a missing child, and a node's hash is a `Maybe`
# because the TS code tells a missing hash from a zero one. `Merkle.build`
# folds its inserts; the TS `build` drops the result of each `insert` and so
# always answers the empty trie.
import Base
import ../lib/core.bend as C
import ./timestamp.bend as S

type Trie is Data:
  Absent{}
  Node{hash: Maybe<&2, U32>, zero: Trie, one: Trie, two: Trie}

# `{ hash: 0 }`
def Merkle.empty() -> Trie:
  Node{Some{0}, Absent{}, Absent{}, Absent{}}

# `{}`: a node with no hash and no children.
def Merkle.blank() -> Trie:
  Node{None{}, Absent{}, Absent{}, Absent{}}

# `trie.hash || 0`
def Merkle.hash(t: Trie) -> U32:
  match t:
    case Absent{}:
      0
    case Node{hash, zero, one, two}:
      Maybe.default(&2, U32, hash, 0)

def Merkle.is_present(t: Trie) -> Bool:
  match t:
    case Absent{}:
      False{}
    case other:
      True{}

# The node with its hash XORed with h; a missing node counts as `{}`.
def Merkle.mix(t: Trie, h: U32) -> Trie:
  match t:
    case Absent{}:
      Node{Some{h}, Absent{}, Absent{}, Absent{}}
    case Node{hash, zero, one, two}:
      Node{Some{(Maybe.default(&2, U32, hash, 0) .^. h : U32)}, zero, one, two}

# Inserts hash along the digits of key, most significant first. Every node
# below the root on the path has the hash XORed in.
def Merkle.insert_key(key: List<&2, U32>, trie: Trie, +h: U32) -> Trie:
  match key trie:
    case Nil{} t:
      t
    case Con{0, rest} Absent{}:
      Node{None{}, Merkle.mix(Merkle.insert_key(rest, Absent{}, h), h), Absent{}, Absent{}}
    case Con{1, rest} Absent{}:
      Node{None{}, Absent{}, Merkle.mix(Merkle.insert_key(rest, Absent{}, h), h), Absent{}}
    case Con{c, rest} Absent{}:
      Node{None{}, Absent{}, Absent{}, Merkle.mix(Merkle.insert_key(rest, Absent{}, h), h)}
    case Con{0, rest} Node{hash, zero, one, two}:
      Node{hash, Merkle.mix(Merkle.insert_key(rest, zero, h), h), one, two}
    case Con{1, rest} Node{hash, zero, one, two}:
      Node{hash, zero, Merkle.mix(Merkle.insert_key(rest, one, h), h), two}
    case Con{c, rest} Node{hash, zero, one, two}:
      Node{hash, zero, one, Merkle.mix(Merkle.insert_key(rest, two, h), h)}

# The base-3 digits of n, most significant first; "0" for zero, as JS
# `n.toString(3)`.
def Merkle.digits.go(fuel: Nat, +n: Nat, acc: List<&2, U32>, done: Bool) -> List<&2, U32>:
  match fuel done:
    case 0n _:
      acc
    case 1n+f True{}:
      acc
    case 1n+f False{}:
      +q = Nat.div(n, 3n)
      Merkle.digits.go(f, q, Con{U32.from_nat(Nat.mod(n, 3n)), acc}, Nat.is_eq(q, 0n))

def Merkle.digits(n: Nat) -> List<&2, U32>:
  Merkle.digits.go(32n, n, Nil{}, False{})

# The trie key of a time in milliseconds: its minutes in base 3.
def Merkle.key(millis: Nat) -> List<&2, U32>:
  Merkle.digits(Nat.div(millis, 60000n))

# Inserts a hash at a time in milliseconds, answering the new trie.
def Merkle.insert_hash(trie: Trie, millis: Nat, +h: U32) -> Trie:
  Merkle.insert_key(Merkle.key(millis), Merkle.mix(trie, h), h)

# Inserts a timestamp, answering the new trie.
def Merkle.insert(trie: Trie, +timestamp: S.Timestamp) -> Trie:
  Merkle.insert_hash(trie, S.Timestamp.millis(timestamp), S.Timestamp.hash(timestamp))

def Merkle.build.go(timestamps: List<&2, S.Timestamp>, trie: Trie) -> Trie:
  match timestamps:
    case Nil{}:
      trie
    case Con{t, rest}:
      Merkle.build.go(rest, Merkle.insert(trie, t))

# The trie of a list of timestamps.
def Merkle.build(timestamps: List<&2, S.Timestamp>) -> Trie:
  Merkle.build.go(timestamps, Merkle.empty())

def Merkle.pow3(n: Nat) -> Nat:
  match n:
    case 0n:
      1n
    case 1n+p:
      (3n * Merkle.pow3(p) : Nat)

# The time in milliseconds that a key prefix stands for: the prefix, of `len`
# digits and value `value` in base 3, is padded with zeros to 16 digits and
# read as minutes.
def Merkle.key_to_timestamp(value: Nat, len: Nat) -> Nat:
  (value * Merkle.pow3(Nat.sub(16n, len)) * 60000n : Nat)

# `a.hash === b.hash`, where a missing hash equals only a missing hash.
def Merkle.same_hash(a: Trie, b: Trie) -> Bool:
  match a b:
    case Node{Some{x}, a0, a1, a2} Node{Some{y}, b0, b1, b2}:
      U32.is_eq(x, y)
    case Node{None{}, a0, a1, a2} Node{None{}, b0, b1, b2}:
      True{}
    case Absent{} Absent{}:
      True{}
    case Absent{} Node{None{}, b0, b1, b2}:
      True{}
    case Node{None{}, a0, a1, a2} Absent{}:
      True{}
    case x y:
      False{}

# What one key says while scanning a pair of nodes in key order: 0 when
# neither node has the key, or both have it with equal hashes (keep scanning);
# 1 when only one has it (stop: pruning is lossy, so nothing below is known);
# 2 when both have it with different hashes (descend).
def Merkle.diff.look(a: Trie, b: Trie) -> U32:
  match a b:
    case Absent{} Absent{}:
      0
    case Absent{} y:
      1
    case x Absent{}:
      1
    case x y:
      Bool.pick(U32, Merkle.same_hash(x, y), 0, 2)

# The first key, 0 to 2, to descend into, or 3 to stop here.
def Merkle.diff.choose(l0: U32, l1: U32, l2: U32) -> U32:
  match l0 l1 l2:
    case 2 _ _:
      0
    case 1 _ _:
      3
    case _ 2 _:
      1
    case _ 1 _:
      3
    case _ _ 2:
      2
    case _ _ _:
      3

# Walks down both tries through the first key, in order, whose hashes differ,
# and stops where a key is missing on one side or no key differs. `value` and
# `len` are the base-3 value and the length of the path so far.
def Merkle.diff.go(+a: Trie, +b: Trie, +value: Nat, +len: Nat) -> Nat:
  match a b:
    case Node{ha, a0, a1, a2} Node{hb, b0, b1, b2}:
      C.If(Nat, U32.is_eq(Merkle.diff.choose(Merkle.diff.look(a0, b0),
          Merkle.diff.look(a1, b1), Merkle.diff.look(a2, b2)), 0),
        u => Merkle.diff.go(a0, b0, (value * 3n : Nat), 1n+len),
        u => C.If(Nat, U32.is_eq(Merkle.diff.choose(Merkle.diff.look(a0, b0),
            Merkle.diff.look(a1, b1), Merkle.diff.look(a2, b2)), 1),
          v => Merkle.diff.go(a1, b1, (value * 3n + 1n : Nat), 1n+len),
          v => C.If(Nat, U32.is_eq(Merkle.diff.choose(Merkle.diff.look(a0, b0),
              Merkle.diff.look(a1, b1), Merkle.diff.look(a2, b2)), 2),
            w => Merkle.diff.go(a2, b2, (value * 3n + 2n : Nat), 1n+len),
            w => Merkle.key_to_timestamp(value, len))))
    case x y:
      Merkle.key_to_timestamp(value, len)

# The time in milliseconds from which two tries differ, or None when their
# hashes are the same.
def Merkle.diff(+a: Trie, +b: Trie) -> Maybe<&2, Nat>:
  C.If(Maybe<&2, Nat>, Merkle.same_hash(a, b),
    u => None{},
    u => Some{Merkle.diff.go(a, b, 0n, 0n)})

def Merkle.count(present: Bool) -> Nat:
  match present:
    case True{}:
      1n
    case False{}:
      0n

# Keeps only the last n children of every node, recursively. A node with no
# hash, or a zero one, is left whole.
def Merkle.prune(+trie: Trie, +n: Nat) -> Trie:
  match trie:
    case Absent{}:
      Absent{}
    case Node{hash, zero, one, two}:
      C.If(Trie, U32.is_eq(Maybe.default(&2, U32, hash, 0), 0),
        u => Node{hash, zero, one, two},
        u => Node{hash,
          C.If(Trie, Bool.and(Merkle.is_present(zero), Nat.is_gt(n,
              (Merkle.count(Merkle.is_present(one)) + Merkle.count(Merkle.is_present(two)) : Nat))),
            v => Merkle.prune(zero, n), v => Absent{}),
          C.If(Trie, Bool.and(Merkle.is_present(one), Nat.is_gt(n,
              Merkle.count(Merkle.is_present(two)))),
            v => Merkle.prune(one, n), v => Absent{}),
          C.If(Trie, Bool.and(Merkle.is_present(two), Nat.is_gt(n, 0n)),
            v => Merkle.prune(two, n), v => Absent{})})

# A hash as JS prints it after `^`: a signed 32-bit integer.
def Merkle.show_hash(+h: U32) -> String:
  Bool.pick(String, (h >= 2147483648 : U32), "-" ++ U32.show((0 - h : U32)), U32.show(h))

def Merkle.debug.head(key: String, +indent: Nat, +h: U32) -> String:
  String.repeat(" ", indent) ++ key ++ "hash: " ++
    Bool.pick(String, U32.is_eq(h, 0), "(empty)", Merkle.show_hash(h)) ++ "\n"

# An indented listing of a trie, one node per line.
def Merkle.debug.go(trie: Trie, key: String, +indent: Nat) -> String:
  match trie:
    case Absent{}:
      ""
    case Node{hash, zero, one, two}:
      Merkle.debug.head(key, indent, Maybe.default(&2, U32, hash, 0)) ++
        Merkle.debug.go(zero, "k: 0 ", 2n+indent) ++
        Merkle.debug.go(one, "k: 1 ", 2n+indent) ++
        Merkle.debug.go(two, "k: 2 ", 2n+indent)

def Merkle.debug(trie: Trie) -> String:
  Merkle.debug.go(trie, "", 0n)

def Merkle.to_json.kid(key: String, json: String, rest: List<&2, String>) -> List<&2, String>:
  match json:
    case SNil{}:
      rest
    case SCon{h, t}:
      Con{"\"" ++ key ++ "\":" ++ SCon{h, t}, rest}

def Merkle.to_json.hash(hash: Maybe<&2, U32>) -> List<&2, String>:
  match hash:
    case None{}:
      Nil{}
    case Some{h}:
      ["\"hash\":" ++ Merkle.show_hash(h)]

# The trie as JS `JSON.stringify` writes it: the children present, in key
# order, then the hash. A missing child is the empty string.
def Merkle.to_json(trie: Trie) -> String:
  match trie:
    case Absent{}:
      ""
    case Node{hash, zero, one, two}:
      "{" ++ String.join(
        Merkle.to_json.kid("0", Merkle.to_json(zero),
          Merkle.to_json.kid("1", Merkle.to_json(one),
            Merkle.to_json.kid("2", Merkle.to_json(two), Merkle.to_json.hash(hash)))), ",") ++ "}"

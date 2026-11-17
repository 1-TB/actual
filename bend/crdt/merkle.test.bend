# The cases of packages/crdt/src/crdt/merkle.test.ts. The expected tries are
# `JSON.stringify` of what the TypeScript builds for the same inserts.
import Base
import ../lib/test.bend as T
import ../lib/date.bend as D
import ./timestamp.bend as S
import ./merkle.bend as M

def at(s: String) -> Nat:
  Maybe.default(&2, Nat, D.Date.millis_from_iso(s), 0n)

def ts(s: String) -> S.Timestamp:
  Maybe.default(&2, S.Timestamp, S.Timestamp.parse(s), S.Timestamp.zero())

def iso(m: Maybe<&2, Nat>) -> String:
  match m:
    case None{}:
      "null"
    case Some{ms}:
      D.Date.iso_from_millis(ms)

def added() -> M.Trie:
  M.Merkle.insert(M.Merkle.insert(M.Merkle.empty(),
    ts("2018-11-12T13:21:40.122Z-0000-0123456789ABCDEF")),
    ts("2018-11-13T13:21:40.122Z-0000-0123456789ABCDEF"))

def client1(t: M.Trie) -> M.Trie:
  M.Merkle.insert_hash(M.Merkle.insert_hash(M.Merkle.insert_hash(t,
    at("2018-11-13T13:20:40.122Z"), 1000),
    at("2018-11-14T13:05:35.122Z"), 1100),
    at("2018-11-15T22:19:00.122Z"), 1200)

def client2(t: M.Trie) -> M.Trie:
  M.Merkle.insert_hash(M.Merkle.insert_hash(t,
    at("2018-11-20T13:19:40.122Z"), 1300),
    at("2018-11-25T13:19:40.122Z"), 1400)

# Twelve messages nine minutes apart (seven for the ninth), hashes 1000 up.
def twelve(t: M.Trie) -> M.Trie:
  M.Merkle.insert_hash(M.Merkle.insert_hash(M.Merkle.insert_hash(M.Merkle.insert_hash(M.Merkle.insert_hash(M.Merkle.insert_hash(M.Merkle.insert_hash(M.Merkle.insert_hash(M.Merkle.insert_hash(M.Merkle.insert_hash(M.Merkle.insert_hash(M.Merkle.insert_hash(t,
    at("2018-11-01T01:00:00.000Z"), 1000),
    at("2018-11-01T01:09:00.000Z"), 1100),
    at("2018-11-01T01:18:00.000Z"), 1200),
    at("2018-11-01T01:27:00.000Z"), 1300),
    at("2018-11-01T01:36:00.000Z"), 1400),
    at("2018-11-01T01:45:00.000Z"), 1500),
    at("2018-11-01T01:54:00.000Z"), 1600),
    at("2018-11-01T02:03:00.000Z"), 1700),
    at("2018-11-01T02:10:00.000Z"), 1800),
    at("2018-11-01T02:19:00.000Z"), 1900),
    at("2018-11-01T02:28:00.000Z"), 2000),
    at("2018-11-01T02:37:00.000Z"), 2100)

def full() -> M.Trie:
  twelve(M.Merkle.empty())

# `insertMessages({}, messages)`: the same messages into a trie with no hash.
def loose() -> M.Trie:
  twelve(M.Merkle.blank())

def older(t: M.Trie) -> M.Trie:
  M.Merkle.insert_hash(t, at("2018-11-01T00:59:00.000Z"), 900)

def older2(t: M.Trie) -> M.Trie:
  M.Merkle.insert_hash(older(t), at("2018-11-01T01:15:00.000Z"), 1422)

def pruned(t: M.Trie) -> M.Trie:
  M.Merkle.prune(t, 2n)

def adding() -> List<&2, T.Test.Check>:
  [ T.Check{"adding an item works", M.Merkle.to_json(added()),
      "{\"1\":{\"2\":{\"1\":{\"0\":{\"1\":{\"0\":{\"0\":{\"2\":{\"0\":{\"1\":{\"1\":{\"0\":{\"2\":{\"2\":{\"0\":{\"0\":{\"hash\":1983295247},\"hash\":1983295247},\"hash\":1983295247},\"hash\":1983295247},\"hash\":1983295247},\"hash\":1983295247},\"hash\":1983295247},\"hash\":1983295247},\"1\":{\"0\":{\"1\":{\"0\":{\"2\":{\"0\":{\"0\":{\"0\":{\"hash\":1469038940},\"hash\":1469038940},\"hash\":1469038940},\"hash\":1469038940},\"hash\":1469038940},\"hash\":1469038940},\"hash\":1469038940},\"hash\":1469038940},\"hash\":565800531},\"hash\":565800531},\"hash\":565800531},\"hash\":565800531},\"hash\":565800531},\"hash\":565800531},\"hash\":565800531},\"hash\":565800531},\"hash\":565800531}"} ]

def diffing() -> List<&2, T.Test.Check>:
  [ T.Test.u32("trie1 hash", M.Merkle.hash(client1(M.Merkle.empty())), 788),
    T.Test.u32("trie2 hash", M.Merkle.hash(client2(M.Merkle.empty())), 108),
    T.Check{"diff returns the correct time difference",
      iso(M.Merkle.diff(client1(M.Merkle.empty()), client2(M.Merkle.empty()))),
      "2018-11-02T17:15:00.000Z"},
    T.Test.u32("merged hash", M.Merkle.hash(client2(client1(M.Merkle.empty()))), 888),
    T.Test.u32("merged the other way",
      M.Merkle.hash(client1(client2(M.Merkle.empty()))), 888),
    T.Check{"merged tries are equal", M.Merkle.to_json(client2(client1(M.Merkle.empty()))),
      M.Merkle.to_json(client1(client2(M.Merkle.empty())))},
    T.Check{"equal tries do not differ",
      iso(M.Merkle.diff(client2(client1(M.Merkle.empty())), client1(client2(M.Merkle.empty())))),
      "null"},
    T.Check{"diffing works with empty tries",
      iso(M.Merkle.diff(M.Merkle.empty(), M.Merkle.insert(M.Merkle.empty(),
        ts("2009-01-02T10:17:37.789Z-0000-0000testinguuid1")))),
      "1970-01-01T00:00:00.000Z"} ]

def pruning() -> List<&2, T.Test.Check>:
  [ T.Test.u32("full hash", M.Merkle.hash(full()), 2496),
    T.Check{"full trie", M.Merkle.to_json(full()),
      "{\"1\":{\"2\":{\"1\":{\"0\":{\"0\":{\"2\":{\"2\":{\"2\":{\"1\":{\"2\":{\"2\":{\"0\":{\"0\":{\"1\":{\"2\":{\"0\":{\"hash\":1000},\"hash\":1000},\"hash\":1000},\"2\":{\"2\":{\"0\":{\"hash\":1100},\"hash\":1100},\"hash\":1100},\"hash\":1956},\"1\":{\"0\":{\"2\":{\"0\":{\"hash\":1200},\"hash\":1200},\"hash\":1200},\"1\":{\"2\":{\"0\":{\"hash\":1300},\"hash\":1300},\"hash\":1300},\"2\":{\"2\":{\"0\":{\"hash\":1400},\"hash\":1400},\"hash\":1400},\"hash\":1244},\"2\":{\"0\":{\"2\":{\"0\":{\"hash\":1500},\"hash\":1500},\"hash\":1500},\"1\":{\"2\":{\"0\":{\"hash\":1600},\"hash\":1600},\"hash\":1600},\"2\":{\"2\":{\"0\":{\"hash\":1700},\"hash\":1700},\"hash\":1700},\"hash\":1336},\"hash\":1600},\"1\":{\"0\":{\"0\":{\"1\":{\"1\":{\"hash\":1800},\"hash\":1800},\"hash\":1800},\"1\":{\"1\":{\"1\":{\"hash\":1900},\"hash\":1900},\"hash\":1900},\"2\":{\"1\":{\"1\":{\"hash\":2000},\"hash\":2000},\"hash\":2000},\"hash\":1972},\"1\":{\"0\":{\"1\":{\"1\":{\"hash\":2100},\"hash\":2100},\"hash\":2100},\"hash\":2100},\"hash\":3968},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496}"},
    T.Test.u32("pruned hash", M.Merkle.hash(pruned(full())), 2496),
    T.Check{"pruned trie", M.Merkle.to_json(pruned(full())),
      "{\"1\":{\"2\":{\"1\":{\"0\":{\"0\":{\"2\":{\"2\":{\"2\":{\"1\":{\"2\":{\"2\":{\"0\":{\"1\":{\"1\":{\"2\":{\"0\":{\"hash\":1300},\"hash\":1300},\"hash\":1300},\"2\":{\"2\":{\"0\":{\"hash\":1400},\"hash\":1400},\"hash\":1400},\"hash\":1244},\"2\":{\"1\":{\"2\":{\"0\":{\"hash\":1600},\"hash\":1600},\"hash\":1600},\"2\":{\"2\":{\"0\":{\"hash\":1700},\"hash\":1700},\"hash\":1700},\"hash\":1336},\"hash\":1600},\"1\":{\"0\":{\"1\":{\"1\":{\"1\":{\"hash\":1900},\"hash\":1900},\"hash\":1900},\"2\":{\"1\":{\"1\":{\"hash\":2000},\"hash\":2000},\"hash\":2000},\"hash\":1972},\"1\":{\"0\":{\"1\":{\"1\":{\"hash\":2100},\"hash\":2100},\"hash\":2100},\"hash\":2100},\"hash\":3968},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496},\"hash\":2496}"},
    T.Check{"debug", M.Merkle.debug(pruned(full())),
      "hash: 2496\n  k: 1 hash: 2496\n    k: 2 hash: 2496\n      k: 1 hash: 2496\n        k: 0 hash: 2496\n          k: 0 hash: 2496\n            k: 2 hash: 2496\n              k: 2 hash: 2496\n                k: 2 hash: 2496\n                  k: 1 hash: 2496\n                    k: 2 hash: 2496\n                      k: 2 hash: 2496\n                        k: 0 hash: 1600\n                          k: 1 hash: 1244\n                            k: 1 hash: 1300\n                              k: 2 hash: 1300\n                                k: 0 hash: 1300\n                            k: 2 hash: 1400\n                              k: 2 hash: 1400\n                                k: 0 hash: 1400\n                          k: 2 hash: 1336\n                            k: 1 hash: 1600\n                              k: 2 hash: 1600\n                                k: 0 hash: 1600\n                            k: 2 hash: 1700\n                              k: 2 hash: 1700\n                                k: 0 hash: 1700\n                        k: 1 hash: 3968\n                          k: 0 hash: 1972\n                            k: 1 hash: 1900\n                              k: 1 hash: 1900\n                                k: 1 hash: 1900\n                            k: 2 hash: 2000\n                              k: 1 hash: 2000\n                                k: 1 hash: 2000\n                          k: 1 hash: 2100\n                            k: 0 hash: 2100\n                              k: 1 hash: 2100\n                                k: 1 hash: 2100\n"} ]

def shapes() -> List<&2, T.Test.Check>:
  [ T.Check{"empty against trie", iso(M.Merkle.diff(M.Merkle.empty(), loose())),
      "1970-01-01T00:00:00.000Z"},
    T.Check{"trie against empty", iso(M.Merkle.diff(loose(), M.Merkle.empty())),
      "1970-01-01T00:00:00.000Z"},
    T.Check{"case 1: normal", iso(M.Merkle.diff(older(loose()), loose())),
      "2018-11-01T00:54:00.000Z"},
    T.Check{"case 1: pruned new", iso(M.Merkle.diff(pruned(older(loose())), loose())),
      "2018-11-01T00:45:00.000Z"},
    T.Check{"case 1: pruned original", iso(M.Merkle.diff(older(loose()), pruned(loose()))),
      "2018-11-01T00:45:00.000Z"},
    T.Check{"case 1: pruned both",
      iso(M.Merkle.diff(pruned(older(loose())), pruned(loose()))),
      "2018-11-01T00:45:00.000Z"},
    T.Check{"case 2: normal", iso(M.Merkle.diff(older2(loose()), loose())),
      "2018-11-01T00:54:00.000Z"},
    T.Check{"case 2: pruned new", iso(M.Merkle.diff(pruned(older2(loose())), loose())),
      "2018-11-01T00:45:00.000Z"},
    T.Check{"case 2: pruned original", iso(M.Merkle.diff(older2(loose()), pruned(loose()))),
      "2018-11-01T00:45:00.000Z"},
    T.Check{"case 2: pruned both",
      iso(M.Merkle.diff(pruned(older2(loose())), pruned(loose()))),
      "2018-11-01T01:12:00.000Z"} ]

def main() -> IO(Unit):
  T.Test.run(List.concat(&2, T.Test.Check, [adding(), diffing(), pruning(), shapes()]))

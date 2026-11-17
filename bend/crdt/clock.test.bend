# Tests for clock.bend; the expected texts are what the TypeScript
# `serializeClock` writes for the same clock.
import Base
import ../lib/test.bend as T
import ./timestamp.bend as S
import ./merkle.bend as M
import ./clock.bend as K

def ts(s: String) -> S.Timestamp:
  Maybe.default(&2, S.Timestamp, S.Timestamp.parse(s), S.Timestamp.zero())

def first() -> S.Timestamp:
  ts("2018-11-12T13:21:40.122Z-0001-0123456789ABCDEF")

def clock() -> K.Clock:
  K.Clock.make(first(), M.Merkle.insert(M.Merkle.insert(M.Merkle.empty(), first()),
    ts("2018-11-13T13:21:40.122Z-0000-0123456789ABCDEF")))

def text() -> String:
  "{\"timestamp\":\"2018-11-12T13:21:40.122Z-0001-0123456789ABCDEF\",\"merkle\":{\"1\":{\"2\":{\"1\":{\"0\":{\"1\":{\"0\":{\"0\":{\"2\":{\"0\":{\"1\":{\"1\":{\"0\":{\"2\":{\"2\":{\"0\":{\"0\":{\"hash\":166083570},\"hash\":166083570},\"hash\":166083570},\"hash\":166083570},\"hash\":166083570},\"hash\":166083570},\"hash\":166083570},\"hash\":166083570},\"1\":{\"0\":{\"1\":{\"0\":{\"2\":{\"0\":{\"0\":{\"0\":{\"hash\":1469038940},\"hash\":1469038940},\"hash\":1469038940},\"hash\":1469038940},\"hash\":1469038940},\"hash\":1469038940},\"hash\":1469038940},\"hash\":1469038940},\"hash\":1584003758},\"hash\":1584003758},\"hash\":1584003758},\"hash\":1584003758},\"hash\":1584003758},\"hash\":1584003758},\"hash\":1584003758},\"hash\":1584003758},\"hash\":1584003758}}"

def read(r: Result<&2, &2, K.Clock.Error, K.Clock>) -> String:
  match r:
    case Fail{e}:
      "error: " ++ K.Clock.Error.show(e)
    case Done{c}:
      K.Clock.serialize(c)

def main() -> IO(Unit):
  do IO<Unit>:
    id : String <- K.Clock.client_id()
    +cid : String = id
    T.Test.run([
      T.Check{"serialize", K.Clock.serialize(clock()), text()},
      T.Check{"deserialize then serialize", read(K.Clock.deserialize(text(), "x")), text()},
      T.Check{"default merkle", K.Clock.serialize(K.Clock.make(first(), M.Merkle.blank())),
        "{\"timestamp\":\"2018-11-12T13:21:40.122Z-0001-0123456789ABCDEF\",\"merkle\":{}}"},
      T.Check{"not JSON: a fresh clock", read(K.Clock.deserialize("not json", "0123456789abcdef")),
        "{\"timestamp\":\"1970-01-01T00:00:00.000Z-0000-0123456789abcdef\",\"merkle\":{}}"},
      T.Check{"bad timestamp", read(K.Clock.deserialize("{\"timestamp\":\"bad\",\"merkle\":{}}", "x")),
        "error: timestamp is not valid bad"},
      T.Check{"missing timestamp", read(K.Clock.deserialize("{\"merkle\":{}}", "x")),
        "error: timestamp is not valid undefined"},
      T.Test.nat("client id length", String.length(cid), 16n),
      T.Check{"client id is lowercase hex", String.to_lower(cid), cid} ])

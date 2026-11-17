# Tests for json.bend. Each "valid" case parses a text and writes it back; the
# expected text is JS `JSON.stringify(JSON.parse(text))`, except that
# non-integer numbers keep their source text and a repeated key stays twice. Each "invalid" case is a text
# that JS `JSON.parse` rejects.
import Base
import ../lib/test.bend as T
import ../lib/int.bend as I
import ./json.bend as J

def shown(m: Maybe<&2, J.Json>) -> String:
  match m:
    case None{}:
      "invalid"
    case Some{j}:
      J.Json.show(j)

def roundtrip(s: String) -> String:
  shown(J.Json.parse(s))

def sample() -> J.Json:
  J.Json.object([
    J.Member{"name", J.JStr{"line\nbreak \"q\""}},
    J.Member{"amount", J.JInt{I.Int.minus(1250n)}},
    J.Member{"tags", J.Json.array([J.JStr{"a"}, J.JNull{}, J.JBool{True{}}, J.Json.nat(7n)])},
    J.Member{"empty", J.Json.object([])} ])

def lookup(m: Maybe<&2, J.Json>) -> String:
  match m:
    case None{}:
      "undefined"
    case Some{j}:
      J.Json.show(j)

def parsing() -> List<&2, T.Test.Check>:
  [
    T.Check{"valid 0", roundtrip("null"), "null"},
    T.Check{"valid 1", roundtrip("true"), "true"},
    T.Check{"valid 2", roundtrip("false"), "false"},
    T.Check{"valid 3", roundtrip("0"), "0"},
    T.Check{"valid 4", roundtrip("-0"), "0"},
    T.Check{"valid 5", roundtrip("42"), "42"},
    T.Check{"valid 6", roundtrip("-17"), "-17"},
    T.Check{"valid 7", roundtrip("281474976710"), "281474976710"},
    T.Check{"valid 8", roundtrip("[]"), "[]"},
    T.Check{"valid 9", roundtrip("{}"), "{}"},
    T.Check{"valid 10", roundtrip("[1,2,3]"), "[1,2,3]"},
    T.Check{"valid 11", roundtrip(" [ 1 , \"a\" , null ] "), "[1,\"a\",null]"},
    T.Check{"valid 12", roundtrip("{\"a\":1,\"b\":[true,false,null],\"c\":{\"d\":\"e\"}}"), "{\"a\":1,\"b\":[true,false,null],\"c\":{\"d\":\"e\"}}"},
    T.Check{"valid 13", roundtrip("\"hello\""), "\"hello\""},
    T.Check{"valid 14", roundtrip("\"quote \\\" backslash \\\\ slash \\/\""), "\"quote \\\" backslash \\\\ slash /\""},
    T.Check{"valid 15", roundtrip("\"tab\\tnewline\\nreturn\\rbs\\bff\\f\""), "\"tab\\tnewline\\nreturn\\rbs\\bff\\f\""},
    T.Check{"valid 16", roundtrip("\"\\u0041\\u00e9\\u20ac\""), "\"Aé€\""},
    T.Check{"valid 17", roundtrip("\"\\ud83d\\ude00\""), "\"😀\""},
    T.Check{"valid 18", roundtrip("\"\\u0001\\u001f\""), "\"\\u0001\\u001f\""},
    T.Check{"valid 19", roundtrip("\"héllo € 😀\""), "\"héllo € 😀\""},
    T.Check{"valid 20", roundtrip("{\"timestamp\":\"2015-04-24T22:23:42.123Z-1000-0123456789ABCDEF\",\"merkle\":{\"1\":{\"hash\":-5},\"hash\":-5}}"), "{\"timestamp\":\"2015-04-24T22:23:42.123Z-1000-0123456789ABCDEF\",\"merkle\":{\"1\":{\"hash\":-5},\"hash\":-5}}"},
    T.Check{"valid 21", roundtrip("[[[[]]]]"), "[[[[]]]]"},
    T.Check{"valid 22", roundtrip("{\"a\":{\"a\":{\"a\":{}}}}"), "{\"a\":{\"a\":{\"a\":{}}}}"},
    T.Check{"valid 23", roundtrip("\n{\t\"k\" :\r\n \"v\" }\n"), "{\"k\":\"v\"}"},
    T.Check{"valid 24", roundtrip("{\"a\":1,\"a\":2}"), "{\"a\":1,\"a\":2}"},
    T.Check{"valid 25", roundtrip("[1.5,2e3,-0.25,1E-2,12345678901234567890]"), "[1.5,2e3,-0.25,1E-2,12345678901234567890]"},
    T.Check{"valid 26", roundtrip("{\"\":\"\"}"), "{\"\":\"\"}"},
    T.Check{"invalid 0", roundtrip(""), "invalid"},
    T.Check{"invalid 1", roundtrip(" "), "invalid"},
    T.Check{"invalid 2", roundtrip("["), "invalid"},
    T.Check{"invalid 3", roundtrip("]"), "invalid"},
    T.Check{"invalid 4", roundtrip("{"), "invalid"},
    T.Check{"invalid 5", roundtrip("[1,]"), "invalid"},
    T.Check{"invalid 6", roundtrip("{\"a\":1,}"), "invalid"},
    T.Check{"invalid 7", roundtrip("{a:1}"), "invalid"},
    T.Check{"invalid 8", roundtrip("{'a':1}"), "invalid"},
    T.Check{"invalid 9", roundtrip("01"), "invalid"},
    T.Check{"invalid 10", roundtrip("1."), "invalid"},
    T.Check{"invalid 11", roundtrip(".5"), "invalid"},
    T.Check{"invalid 12", roundtrip("+1"), "invalid"},
    T.Check{"invalid 13", roundtrip("1e"), "invalid"},
    T.Check{"invalid 14", roundtrip("tru"), "invalid"},
    T.Check{"invalid 15", roundtrip("nul"), "invalid"},
    T.Check{"invalid 16", roundtrip("truee"), "invalid"},
    T.Check{"invalid 17", roundtrip("\"abc"), "invalid"},
    T.Check{"invalid 18", roundtrip("\"\\x\""), "invalid"},
    T.Check{"invalid 19", roundtrip("\"\\u12\""), "invalid"},
    T.Check{"invalid 20", roundtrip("\"\\u12G4\""), "invalid"},
    T.Check{"invalid 21", roundtrip("[1 2]"), "invalid"},
    T.Check{"invalid 22", roundtrip("{\"a\" 1}"), "invalid"},
    T.Check{"invalid 23", roundtrip("{\"a\":}"), "invalid"},
    T.Check{"invalid 24", roundtrip("1 2"), "invalid"},
    T.Check{"invalid 25", roundtrip("\"a\tb\""), "invalid"},
    T.Check{"invalid 26", roundtrip("-"), "invalid"},
    T.Check{"invalid 27", roundtrip("[,1]"), "invalid"},
    T.Check{"invalid 28", roundtrip("NaN"), "invalid"},
    T.Check{"invalid 29", roundtrip("undefined"), "invalid"},
    T.Check{"invalid 30", roundtrip("{\"a\":1]"), "invalid"},
    T.Check{"invalid 31", roundtrip("[1}"), "invalid"} ]

def building() -> List<&2, T.Test.Check>:
  [ T.Check{"show built value", J.Json.show(sample()),
      "{\"name\":\"line\\nbreak \\\"q\\\"\",\"amount\":-1250,\"tags\":[\"a\",null,true,7],\"empty\":{}}"},
    T.Check{"built value round-trips", roundtrip(J.Json.show(sample())), J.Json.show(sample())},
    T.Check{"get member", lookup(J.Json.get(sample(), "amount")), "-1250"},
    T.Check{"get missing member", lookup(J.Json.get(sample(), "nope")), "undefined"},
    T.Check{"get of a non-object", lookup(J.Json.get(J.JNull{}, "a")), "undefined"},
    T.Check{"repeated key: last wins",
      lookup(J.Json.get(Maybe.default(&2, J.Json, J.Json.parse("{\"a\":1,\"a\":2}"), J.JNull{}), "a")), "2"},
    T.Check{"index", lookup(J.Json.at(Maybe.default(&2, J.Json, J.Json.get(sample(), "tags"), J.JNull{}), 3n)), "7"},
    T.Check{"index out of range", lookup(J.Json.at(J.Json.array([J.JNull{}]), 1n)), "undefined"},
    T.Test.nat("member count", List.length(&2, J.Json.Member, J.Json.members(sample())), 4n),
    T.Test.bool("is_null", J.Json.is_null(J.JNull{}), True{}),
    T.Check{"control characters escape", J.Json.show(J.JStr{SCon{Chr{1}, SCon{Chr{31}, SNil{}}}}),
      "\"\\u0001\\u001f\""} ]

def main() -> IO(Unit):
  T.Test.run(List.concat(&2, T.Test.Check, [parsing(), building()]))

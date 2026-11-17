# Tests for cleanup_template.bend. The expected text is `JSON.stringify` of
# what the Peggy parser generated from cleanup-template.pegjs answers, or
# `error` where it throws.
import Base
import ../lib/test.bend as T
import ../json/json.bend as J
import ./cleanup_template.bend as G

def parse(line: String) -> String:
  Maybe.default(&2, String, Maybe.map(&2, J.Json, String, j => J.Json.show(j), G.CleanupTemplate.parse(line)), "error")

def main() -> IO(Unit):
  T.Test.run([
    T.Check{"#cleanup source", parse("#cleanup source"), "{\"group\":null,\"type\":\"source\"}"},
    T.Check{"#cleanup sink", parse("#cleanup sink"), "{\"type\":\"sink\",\"weight\":1,\"group\":null}"},
    T.Check{"#cleanup sink 2", parse("#cleanup sink 2"), "{\"type\":\"sink\",\"weight\":2,\"group\":null}"},
    T.Check{"#cleanup sink2", parse("#cleanup sink2"), "{\"type\":\"sink\",\"weight\":2,\"group\":null}"},
    T.Check{"#cleanup sink 0", parse("#cleanup sink 0"), "{\"type\":\"sink\",\"weight\":1,\"group\":null}"},
    T.Check{"#cleanup sink  10", parse("#cleanup sink  10"), "{\"type\":\"sink\",\"weight\":10,\"group\":null}"},
    T.Check{"#cleanup Savings source", parse("#cleanup Savings source"), "{\"group\":\"Savings\",\"type\":\"source\"}"},
    T.Check{"#cleanup Savings sink", parse("#cleanup Savings sink"), "{\"type\":\"sink\",\"weight\":1,\"group\":\"Savings\"}"},
    T.Check{"#cleanup Savings sink 3", parse("#cleanup Savings sink 3"), "{\"type\":\"sink\",\"weight\":3,\"group\":\"Savings\"}"},
    T.Check{"#cleanup My Group  source", parse("#cleanup My Group  source"), "{\"group\":\"My Group \",\"type\":\"source\"}"},
    T.Check{"#cleanup My Group", parse("#cleanup My Group"), "{\"group\":\"My Group\",\"type\":null}"},
    T.Check{"#cleanup", parse("#cleanup"), "error"},
    T.Check{"#cleanup ", parse("#cleanup "), "{\"group\":\"\",\"type\":null}"},
    T.Check{"#cleanup   source", parse("#cleanup   source"), "{\"group\":null,\"type\":\"source\"}"},
    T.Check{"#cleanupsource", parse("#cleanupsource"), "error"},
    T.Check{"#cleanup source extra", parse("#cleanup source extra"), "error"},
    T.Check{"#cleanup sink x", parse("#cleanup sink x"), "error"},
    T.Check{"#cleanup a sink b", parse("#cleanup a sink b"), "error"},
    T.Check{"#cleanup a source b", parse("#cleanup a source b"), "error"},
    T.Check{"#cleanup group sink 2 ", parse("#cleanup group sink 2 "), "error"},
    T.Check{"#cleanup source sink", parse("#cleanup source sink"), "error"},
    T.Check{"#cleanup sinker", parse("#cleanup sinker"), "error"},
    T.Check{"#cleanup x sink sink", parse("#cleanup x sink sink"), "error"},
    T.Check{"#cleanup a source source", parse("#cleanup a source source"), "error"},
    T.Check{"#Cleanup source", parse("#Cleanup source"), "error"},
    T.Check{"cleanup source", parse("cleanup source"), "error"},
    T.Check{"#cleanup  ", parse("#cleanup  "), "{\"group\":\"\",\"type\":null}"},
    T.Check{"#cleanup g1 sink 007", parse("#cleanup g1 sink 007"), "{\"type\":\"sink\",\"weight\":7,\"group\":\"g1\"}"},
    T.Check{"#cleanup sources", parse("#cleanup sources"), "error"},
    T.Check{"#cleanup é source", parse("#cleanup é source"), "{\"group\":\"é\",\"type\":\"source\"}"} ])

# Tests for graph.bend: sequences of graph operations, some hand-written and
# some random, replayed here and in the TypeScript `Graph`. The expected
# state is the TS maps written as `node:neighbours;...|node:sources;...` and
# the expected orders are what `topologicalSort` answers.
import Base
import ../lib/test.bend as T
import ./graph.bend as G

def dump.map(m: List<&2, G.Graph.Entry>) -> List<&2, String>:
  match m:
    case Nil{}:
      Nil{}
    case Con{G.Entry{n, set}, t}:
      Con{n ++ ":" ++ String.join(set, ","), dump.map(t)}

def dump(g: G.Graph) -> String:
  match g:
    case G.Graph{edges, incoming}:
      String.join(dump.map(edges), ";") ++ "|" ++ String.join(dump.map(incoming), ";")

def graph_0() -> G.Graph:
  G.Graph.new()

def graph_1() -> G.Graph:
  G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.new(), "a", "b"), "b", "c"), "a", "c"), "c", "d")

def graph_2() -> G.Graph:
  G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.new(), "a", "b"), "b", "a"), "b", "c"), "c", "a")

def graph_3() -> G.Graph:
  G.Graph.add_edge(G.Graph.remove_incoming_edges(G.Graph.add_node(G.Graph.remove_node(G.Graph.remove_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.new(), "a", "b"), "a", "c"), "a", "d"), "a", "c"), "b"), "e"), "zz"), "a", "a")

def graph_4() -> G.Graph:
  G.Graph.remove_node(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_node(G.Graph.remove_node(G.Graph.new(), "a"), "a"), "a"), "a", "a"), "a", "a"), "a", "a"), "a", "a"), "a", "a"), "a"), "a"), "a", "a"), "a"), "a", "a"), "a", "a"), "a"), "a")

def graph_5() -> G.Graph:
  G.Graph.add_node(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.remove_node(G.Graph.remove_node(G.Graph.remove_node(G.Graph.add_node(G.Graph.remove_node(G.Graph.add_node(G.Graph.new(), "a"), "a"), "a"), "a"), "a"), "a"), "a", "a"), "a", "a"), "a", "a"), "a"), "a", "a"), "a"), "a", "a"), "a", "a"), "a", "a"), "a"), "a", "a"), "a"), "a", "a"), "a")

def graph_6() -> G.Graph:
  G.Graph.add_node(G.Graph.add_node(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.new(), "a", "a"), "a", "a"), "a", "a"), "a"), "a", "a"), "a", "a"), "a"), "a", "a"), "a", "a"), "a"), "a"), "a")

def graph_7() -> G.Graph:
  G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.remove_node(G.Graph.remove_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.new(), "a", "a"), "a", "a"), "a", "a"), "a"), "a"), "a", "a"), "a", "a"), "a"), "a"), "a", "a"), "a", "a"), "a"), "a"), "a", "a"), "a", "a"), "a"), "a", "a"), "a", "a"), "a", "a"), "a", "a")

def graph_8() -> G.Graph:
  G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_node(G.Graph.remove_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_node(G.Graph.new(), "a"), "a", "a"), "a"), "a", "a"), "a", "a"), "a", "a"), "a", "a"), "a", "a"), "a", "a"), "a", "a"), "a", "a"), "a", "a"), "a", "a"), "a", "a"), "a"), "a"), "a", "a"), "a", "a"), "a"), "a", "a"), "a", "a"), "a", "a")

def graph_9() -> G.Graph:
  G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_node(G.Graph.new(), "a"), "a"), "a", "a"), "a"), "a", "a"), "a"), "a", "a"), "a", "a")

def graph_10() -> G.Graph:
  G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_edge(G.Graph.remove_node(G.Graph.remove_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_node(G.Graph.add_edge(G.Graph.new(), "a", "a"), "a"), "a"), "a", "a"), "a", "a"), "a"), "a", "a"), "a", "a"), "a"), "a"), "a", "a"), "a"), "a", "a"), "a", "a"), "a"), "a", "a"), "a", "a"), "a", "a")

def graph_11() -> G.Graph:
  G.Graph.add_node(G.Graph.remove_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.new(), "a", "a"), "a", "a"), "a", "a"), "a", "a"), "a", "a"), "a", "a"), "a"), "a")

def graph_12() -> G.Graph:
  G.Graph.add_node(G.Graph.add_node(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.remove_node(G.Graph.remove_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_node(G.Graph.remove_node(G.Graph.remove_node(G.Graph.add_edge(G.Graph.new(), "a", "a"), "a"), "a"), "a"), "a"), "a", "a"), "a"), "a", "a"), "a", "a"), "a", "a"), "a"), "a"), "a", "a"), "a", "a"), "a"), "a", "a"), "a"), "a", "a"), "a", "a"), "a"), "a"), "a")

def graph_13() -> G.Graph:
  G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_node(G.Graph.remove_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_edge(G.Graph.remove_node(G.Graph.new(), "a"), "a", "a"), "a"), "a", "a"), "a", "a"), "a"), "a"), "a", "a"), "a", "a"), "a"), "a", "a"), "a", "a"), "a", "a"), "a"), "a"), "a", "a"), "a"), "a", "a")

def graph_14() -> G.Graph:
  G.Graph.add_edge(G.Graph.add_edge(G.Graph.remove_node(G.Graph.remove_node(G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_node(G.Graph.remove_node(G.Graph.add_node(G.Graph.add_edge(G.Graph.new(), "a", "a"), "a"), "a"), "a"), "a", "a"), "a", "a"), "a", "a"), "a"), "a"), "a", "a"), "a", "a"), "a", "a"), "a"), "a", "a"), "a"), "a"), "a", "a"), "a", "a")

def graph_15() -> G.Graph:
  G.Graph.add_edge(G.Graph.remove_node(G.Graph.add_node(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_node(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_edge(G.Graph.add_node(G.Graph.new(), "a"), "a", "a"), "a", "a"), "a", "a"), "a", "a"), "a", "a"), "a", "a"), "a"), "a", "a"), "a"), "a"), "a", "a"), "a"), "a", "a"), "a"), "a"), "a"), "a", "a")

def main() -> IO(Unit):
  T.Test.run([
    T.Check{"graph 0: state", dump(graph_0()), "|"},
    T.Check{"graph 0: sort from a", String.join(G.Graph.topological_sort(graph_0(), ["a"]), ","), "a"},
    T.Check{"graph 0: sort from a b c d e f", String.join(G.Graph.topological_sort(graph_0(), ["a", "b", "c", "d", "e", "f"]), ","), "f,e,d,c,b,a"},
    T.Check{"graph 0: sort from f e sheet!x", String.join(G.Graph.topological_sort(graph_0(), ["f", "e", "sheet!x"]), ","), "sheet!x,e,f"},
    T.Check{"graph 0: sort from zz", String.join(G.Graph.topological_sort(graph_0(), ["zz"]), ","), "zz"},
    T.Check{"graph 0: sort from ", String.join(G.Graph.topological_sort(graph_0(), []), ","), ""},
    T.Check{"graph 0: adjacent a", String.join(G.Graph.adjacent(graph_0(), "a"), ","), ""},
    T.Check{"graph 0: incoming b", String.join(G.Graph.adjacent_incoming(graph_0(), "b"), ","), ""},
    T.Check{"graph 1: state", dump(graph_1()), "a:b,c;b:c;c:d;d:|a:;b:a;c:b,a;d:c"},
    T.Check{"graph 1: sort from a", String.join(G.Graph.topological_sort(graph_1(), ["a"]), ","), "a,b,c,d"},
    T.Check{"graph 1: sort from a b c d e f", String.join(G.Graph.topological_sort(graph_1(), ["a", "b", "c", "d", "e", "f"]), ","), "f,e,a,b,c,d"},
    T.Check{"graph 1: sort from f e sheet!x", String.join(G.Graph.topological_sort(graph_1(), ["f", "e", "sheet!x"]), ","), "sheet!x,e,f"},
    T.Check{"graph 1: sort from zz", String.join(G.Graph.topological_sort(graph_1(), ["zz"]), ","), "zz"},
    T.Check{"graph 1: sort from ", String.join(G.Graph.topological_sort(graph_1(), []), ","), ""},
    T.Check{"graph 1: adjacent a", String.join(G.Graph.adjacent(graph_1(), "a"), ","), "b,c"},
    T.Check{"graph 1: incoming b", String.join(G.Graph.adjacent_incoming(graph_1(), "b"), ","), "a"},
    T.Check{"graph 2: state", dump(graph_2()), "a:b;b:a,c;c:a|a:b,c;b:a;c:b"},
    T.Check{"graph 2: sort from a", String.join(G.Graph.topological_sort(graph_2(), ["a"]), ","), "a,b,c"},
    T.Check{"graph 2: sort from a b c d e f", String.join(G.Graph.topological_sort(graph_2(), ["a", "b", "c", "d", "e", "f"]), ","), "f,e,d,a,b,c"},
    T.Check{"graph 2: sort from f e sheet!x", String.join(G.Graph.topological_sort(graph_2(), ["f", "e", "sheet!x"]), ","), "sheet!x,e,f"},
    T.Check{"graph 2: sort from zz", String.join(G.Graph.topological_sort(graph_2(), ["zz"]), ","), "zz"},
    T.Check{"graph 2: sort from ", String.join(G.Graph.topological_sort(graph_2(), []), ","), ""},
    T.Check{"graph 2: adjacent a", String.join(G.Graph.adjacent(graph_2(), "a"), ","), "b"},
    T.Check{"graph 2: incoming b", String.join(G.Graph.adjacent_incoming(graph_2(), "b"), ","), "a"},
    T.Check{"graph 3: state", dump(graph_3()), "a:d,a;c:;d:;e:|a:a;c:;d:a;e:;zz:"},
    T.Check{"graph 3: sort from a", String.join(G.Graph.topological_sort(graph_3(), ["a"]), ","), "a,d"},
    T.Check{"graph 3: sort from a b c d e f", String.join(G.Graph.topological_sort(graph_3(), ["a", "b", "c", "d", "e", "f"]), ","), "f,e,c,b,a,d"},
    T.Check{"graph 3: sort from f e sheet!x", String.join(G.Graph.topological_sort(graph_3(), ["f", "e", "sheet!x"]), ","), "sheet!x,e,f"},
    T.Check{"graph 3: sort from zz", String.join(G.Graph.topological_sort(graph_3(), ["zz"]), ","), "zz"},
    T.Check{"graph 3: sort from ", String.join(G.Graph.topological_sort(graph_3(), []), ","), ""},
    T.Check{"graph 3: adjacent a", String.join(G.Graph.adjacent(graph_3(), "a"), ","), "d,a"},
    T.Check{"graph 3: incoming b", String.join(G.Graph.adjacent_incoming(graph_3(), "b"), ","), ""},
    T.Check{"graph 4: state", dump(graph_4()), "|"},
    T.Check{"graph 4: sort from a", String.join(G.Graph.topological_sort(graph_4(), ["a"]), ","), "a"},
    T.Check{"graph 4: sort from a b c d e f", String.join(G.Graph.topological_sort(graph_4(), ["a", "b", "c", "d", "e", "f"]), ","), "f,e,d,c,b,a"},
    T.Check{"graph 4: sort from f e sheet!x", String.join(G.Graph.topological_sort(graph_4(), ["f", "e", "sheet!x"]), ","), "sheet!x,e,f"},
    T.Check{"graph 4: sort from zz", String.join(G.Graph.topological_sort(graph_4(), ["zz"]), ","), "zz"},
    T.Check{"graph 4: sort from ", String.join(G.Graph.topological_sort(graph_4(), []), ","), ""},
    T.Check{"graph 4: adjacent a", String.join(G.Graph.adjacent(graph_4(), "a"), ","), ""},
    T.Check{"graph 4: incoming b", String.join(G.Graph.adjacent_incoming(graph_4(), "b"), ","), ""},
    T.Check{"graph 5: state", dump(graph_5()), "a:a|a:a"},
    T.Check{"graph 5: sort from a", String.join(G.Graph.topological_sort(graph_5(), ["a"]), ","), "a"},
    T.Check{"graph 5: sort from a b c d e f", String.join(G.Graph.topological_sort(graph_5(), ["a", "b", "c", "d", "e", "f"]), ","), "f,e,d,c,b,a"},
    T.Check{"graph 5: sort from f e sheet!x", String.join(G.Graph.topological_sort(graph_5(), ["f", "e", "sheet!x"]), ","), "sheet!x,e,f"},
    T.Check{"graph 5: sort from zz", String.join(G.Graph.topological_sort(graph_5(), ["zz"]), ","), "zz"},
    T.Check{"graph 5: sort from ", String.join(G.Graph.topological_sort(graph_5(), []), ","), ""},
    T.Check{"graph 5: adjacent a", String.join(G.Graph.adjacent(graph_5(), "a"), ","), "a"},
    T.Check{"graph 5: incoming b", String.join(G.Graph.adjacent_incoming(graph_5(), "b"), ","), ""},
    T.Check{"graph 6: state", dump(graph_6()), "a:a|a:a"},
    T.Check{"graph 6: sort from a", String.join(G.Graph.topological_sort(graph_6(), ["a"]), ","), "a"},
    T.Check{"graph 6: sort from a b c d e f", String.join(G.Graph.topological_sort(graph_6(), ["a", "b", "c", "d", "e", "f"]), ","), "f,e,d,c,b,a"},
    T.Check{"graph 6: sort from f e sheet!x", String.join(G.Graph.topological_sort(graph_6(), ["f", "e", "sheet!x"]), ","), "sheet!x,e,f"},
    T.Check{"graph 6: sort from zz", String.join(G.Graph.topological_sort(graph_6(), ["zz"]), ","), "zz"},
    T.Check{"graph 6: sort from ", String.join(G.Graph.topological_sort(graph_6(), []), ","), ""},
    T.Check{"graph 6: adjacent a", String.join(G.Graph.adjacent(graph_6(), "a"), ","), "a"},
    T.Check{"graph 6: incoming b", String.join(G.Graph.adjacent_incoming(graph_6(), "b"), ","), ""},
    T.Check{"graph 7: state", dump(graph_7()), "a:a|a:a"},
    T.Check{"graph 7: sort from a", String.join(G.Graph.topological_sort(graph_7(), ["a"]), ","), "a"},
    T.Check{"graph 7: sort from a b c d e f", String.join(G.Graph.topological_sort(graph_7(), ["a", "b", "c", "d", "e", "f"]), ","), "f,e,d,c,b,a"},
    T.Check{"graph 7: sort from f e sheet!x", String.join(G.Graph.topological_sort(graph_7(), ["f", "e", "sheet!x"]), ","), "sheet!x,e,f"},
    T.Check{"graph 7: sort from zz", String.join(G.Graph.topological_sort(graph_7(), ["zz"]), ","), "zz"},
    T.Check{"graph 7: sort from ", String.join(G.Graph.topological_sort(graph_7(), []), ","), ""},
    T.Check{"graph 7: adjacent a", String.join(G.Graph.adjacent(graph_7(), "a"), ","), "a"},
    T.Check{"graph 7: incoming b", String.join(G.Graph.adjacent_incoming(graph_7(), "b"), ","), ""},
    T.Check{"graph 8: state", dump(graph_8()), "a:a|a:a"},
    T.Check{"graph 8: sort from a", String.join(G.Graph.topological_sort(graph_8(), ["a"]), ","), "a"},
    T.Check{"graph 8: sort from a b c d e f", String.join(G.Graph.topological_sort(graph_8(), ["a", "b", "c", "d", "e", "f"]), ","), "f,e,d,c,b,a"},
    T.Check{"graph 8: sort from f e sheet!x", String.join(G.Graph.topological_sort(graph_8(), ["f", "e", "sheet!x"]), ","), "sheet!x,e,f"},
    T.Check{"graph 8: sort from zz", String.join(G.Graph.topological_sort(graph_8(), ["zz"]), ","), "zz"},
    T.Check{"graph 8: sort from ", String.join(G.Graph.topological_sort(graph_8(), []), ","), ""},
    T.Check{"graph 8: adjacent a", String.join(G.Graph.adjacent(graph_8(), "a"), ","), "a"},
    T.Check{"graph 8: incoming b", String.join(G.Graph.adjacent_incoming(graph_8(), "b"), ","), ""},
    T.Check{"graph 9: state", dump(graph_9()), "a:a|a:a"},
    T.Check{"graph 9: sort from a", String.join(G.Graph.topological_sort(graph_9(), ["a"]), ","), "a"},
    T.Check{"graph 9: sort from a b c d e f", String.join(G.Graph.topological_sort(graph_9(), ["a", "b", "c", "d", "e", "f"]), ","), "f,e,d,c,b,a"},
    T.Check{"graph 9: sort from f e sheet!x", String.join(G.Graph.topological_sort(graph_9(), ["f", "e", "sheet!x"]), ","), "sheet!x,e,f"},
    T.Check{"graph 9: sort from zz", String.join(G.Graph.topological_sort(graph_9(), ["zz"]), ","), "zz"},
    T.Check{"graph 9: sort from ", String.join(G.Graph.topological_sort(graph_9(), []), ","), ""},
    T.Check{"graph 9: adjacent a", String.join(G.Graph.adjacent(graph_9(), "a"), ","), "a"},
    T.Check{"graph 9: incoming b", String.join(G.Graph.adjacent_incoming(graph_9(), "b"), ","), ""},
    T.Check{"graph 10: state", dump(graph_10()), "a:a|a:a"},
    T.Check{"graph 10: sort from a", String.join(G.Graph.topological_sort(graph_10(), ["a"]), ","), "a"},
    T.Check{"graph 10: sort from a b c d e f", String.join(G.Graph.topological_sort(graph_10(), ["a", "b", "c", "d", "e", "f"]), ","), "f,e,d,c,b,a"},
    T.Check{"graph 10: sort from f e sheet!x", String.join(G.Graph.topological_sort(graph_10(), ["f", "e", "sheet!x"]), ","), "sheet!x,e,f"},
    T.Check{"graph 10: sort from zz", String.join(G.Graph.topological_sort(graph_10(), ["zz"]), ","), "zz"},
    T.Check{"graph 10: sort from ", String.join(G.Graph.topological_sort(graph_10(), []), ","), ""},
    T.Check{"graph 10: adjacent a", String.join(G.Graph.adjacent(graph_10(), "a"), ","), "a"},
    T.Check{"graph 10: incoming b", String.join(G.Graph.adjacent_incoming(graph_10(), "b"), ","), ""},
    T.Check{"graph 11: state", dump(graph_11()), "a:|a:"},
    T.Check{"graph 11: sort from a", String.join(G.Graph.topological_sort(graph_11(), ["a"]), ","), "a"},
    T.Check{"graph 11: sort from a b c d e f", String.join(G.Graph.topological_sort(graph_11(), ["a", "b", "c", "d", "e", "f"]), ","), "f,e,d,c,b,a"},
    T.Check{"graph 11: sort from f e sheet!x", String.join(G.Graph.topological_sort(graph_11(), ["f", "e", "sheet!x"]), ","), "sheet!x,e,f"},
    T.Check{"graph 11: sort from zz", String.join(G.Graph.topological_sort(graph_11(), ["zz"]), ","), "zz"},
    T.Check{"graph 11: sort from ", String.join(G.Graph.topological_sort(graph_11(), []), ","), ""},
    T.Check{"graph 11: adjacent a", String.join(G.Graph.adjacent(graph_11(), "a"), ","), ""},
    T.Check{"graph 11: incoming b", String.join(G.Graph.adjacent_incoming(graph_11(), "b"), ","), ""},
    T.Check{"graph 12: state", dump(graph_12()), "a:a|a:a"},
    T.Check{"graph 12: sort from a", String.join(G.Graph.topological_sort(graph_12(), ["a"]), ","), "a"},
    T.Check{"graph 12: sort from a b c d e f", String.join(G.Graph.topological_sort(graph_12(), ["a", "b", "c", "d", "e", "f"]), ","), "f,e,d,c,b,a"},
    T.Check{"graph 12: sort from f e sheet!x", String.join(G.Graph.topological_sort(graph_12(), ["f", "e", "sheet!x"]), ","), "sheet!x,e,f"},
    T.Check{"graph 12: sort from zz", String.join(G.Graph.topological_sort(graph_12(), ["zz"]), ","), "zz"},
    T.Check{"graph 12: sort from ", String.join(G.Graph.topological_sort(graph_12(), []), ","), ""},
    T.Check{"graph 12: adjacent a", String.join(G.Graph.adjacent(graph_12(), "a"), ","), "a"},
    T.Check{"graph 12: incoming b", String.join(G.Graph.adjacent_incoming(graph_12(), "b"), ","), ""},
    T.Check{"graph 13: state", dump(graph_13()), "a:a|a:a"},
    T.Check{"graph 13: sort from a", String.join(G.Graph.topological_sort(graph_13(), ["a"]), ","), "a"},
    T.Check{"graph 13: sort from a b c d e f", String.join(G.Graph.topological_sort(graph_13(), ["a", "b", "c", "d", "e", "f"]), ","), "f,e,d,c,b,a"},
    T.Check{"graph 13: sort from f e sheet!x", String.join(G.Graph.topological_sort(graph_13(), ["f", "e", "sheet!x"]), ","), "sheet!x,e,f"},
    T.Check{"graph 13: sort from zz", String.join(G.Graph.topological_sort(graph_13(), ["zz"]), ","), "zz"},
    T.Check{"graph 13: sort from ", String.join(G.Graph.topological_sort(graph_13(), []), ","), ""},
    T.Check{"graph 13: adjacent a", String.join(G.Graph.adjacent(graph_13(), "a"), ","), "a"},
    T.Check{"graph 13: incoming b", String.join(G.Graph.adjacent_incoming(graph_13(), "b"), ","), ""},
    T.Check{"graph 14: state", dump(graph_14()), "a:a|a:a"},
    T.Check{"graph 14: sort from a", String.join(G.Graph.topological_sort(graph_14(), ["a"]), ","), "a"},
    T.Check{"graph 14: sort from a b c d e f", String.join(G.Graph.topological_sort(graph_14(), ["a", "b", "c", "d", "e", "f"]), ","), "f,e,d,c,b,a"},
    T.Check{"graph 14: sort from f e sheet!x", String.join(G.Graph.topological_sort(graph_14(), ["f", "e", "sheet!x"]), ","), "sheet!x,e,f"},
    T.Check{"graph 14: sort from zz", String.join(G.Graph.topological_sort(graph_14(), ["zz"]), ","), "zz"},
    T.Check{"graph 14: sort from ", String.join(G.Graph.topological_sort(graph_14(), []), ","), ""},
    T.Check{"graph 14: adjacent a", String.join(G.Graph.adjacent(graph_14(), "a"), ","), "a"},
    T.Check{"graph 14: incoming b", String.join(G.Graph.adjacent_incoming(graph_14(), "b"), ","), ""},
    T.Check{"graph 15: state", dump(graph_15()), "a:a|a:a"},
    T.Check{"graph 15: sort from a", String.join(G.Graph.topological_sort(graph_15(), ["a"]), ","), "a"},
    T.Check{"graph 15: sort from a b c d e f", String.join(G.Graph.topological_sort(graph_15(), ["a", "b", "c", "d", "e", "f"]), ","), "f,e,d,c,b,a"},
    T.Check{"graph 15: sort from f e sheet!x", String.join(G.Graph.topological_sort(graph_15(), ["f", "e", "sheet!x"]), ","), "sheet!x,e,f"},
    T.Check{"graph 15: sort from zz", String.join(G.Graph.topological_sort(graph_15(), ["zz"]), ","), "zz"},
    T.Check{"graph 15: sort from ", String.join(G.Graph.topological_sort(graph_15(), []), ","), ""},
    T.Check{"graph 15: adjacent a", String.join(G.Graph.adjacent(graph_15(), "a"), ","), "a"},
    T.Check{"graph 15: incoming b", String.join(G.Graph.adjacent_incoming(graph_15(), "b"), ","), ""},
    T.Check{"generate_dot", G.Graph.generate_dot(graph_1()),
      "\n    digraph G {\n      a -> {b,c}\nb -> {c}\nc -> {d}\nd -> {}\n    }\n    "} ])

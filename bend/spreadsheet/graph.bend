# The dependency graph of spreadsheet cells: a port of
# packages/loot-core/src/server/spreadsheet/graph-data-structure.ts.
#
# The TypeScript graph is a closure over two mutable `Map`s of `Set`s; here a
# graph is a value and every operation answers the new graph. The maps are
# association lists in insertion order, because that order decides the
# topological order. `Graph.generate_dot` writes what `generateDOT` was meant
# to write: the TS calls `join` on a `Set`, which throws.
import Base
import ../lib/core.bend as C

# A node and the set of its neighbours, in insertion order.
type Graph.Entry is Data:
  Entry{node: String, set: List<&2, String>}

type Graph is Data:
  # edges: node -> the nodes it points to; incoming: node -> the nodes that
  # point to it
  Graph{edges: List<&2, Graph.Entry>, incoming: List<&2, Graph.Entry>}

def Graph.new() -> Graph:
  Graph{Nil{}, Nil{}}

# Sets
# ----

def Graph.set.has(xs: List<&2, String>, +x: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{h, t}:
      Bool.or(String.eq(h, x), Graph.set.has(t, x))

# xs with x added at the end unless present.
def Graph.set.add(xs: List<&2, String>, +x: String) -> List<&2, String>:
  match xs:
    case Nil{}:
      [x]
    case Con{+h, +t}:
      C.If(List<&2, String>, String.eq(h, x), u => Con{h, t}, u => Con{h, Graph.set.add(t, x)})

def Graph.set.del(xs: List<&2, String>, +x: String) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+h, +t}:
      C.If(List<&2, String>, String.eq(h, x), u => t, u => Con{h, Graph.set.del(t, x)})

# Maps
# ----

# `map.get(node) || new Set()`
def Graph.map.get(m: List<&2, Graph.Entry>, +node: String) -> List<&2, String>:
  match m:
    case Nil{}:
      Nil{}
    case Con{Entry{n, +set}, +t}:
      C.If(List<&2, String>, String.eq(n, node), u => set, u => Graph.map.get(t, node))

def Graph.map.has(m: List<&2, Graph.Entry>, +node: String) -> Bool:
  match m:
    case Nil{}:
      False{}
    case Con{Entry{n, set}, t}:
      Bool.or(String.eq(n, node), Graph.map.has(t, node))

# `map.set(node, set)`: an existing key keeps its place.
def Graph.map.set(m: List<&2, Graph.Entry>, +node: String, +set: List<&2, String>) -> List<&2, Graph.Entry>:
  match m:
    case Nil{}:
      [Entry{node, set}]
    case Con{Entry{+n, +old}, +t}:
      C.If(List<&2, Graph.Entry>, String.eq(n, node),
        u => Con{Entry{n, set}, t},
        u => Con{Entry{n, old}, Graph.map.set(t, node, set)})

def Graph.map.del(m: List<&2, Graph.Entry>, +node: String) -> List<&2, Graph.Entry>:
  match m:
    case Nil{}:
      Nil{}
    case Con{Entry{+n, +set}, +t}:
      C.If(List<&2, Graph.Entry>, String.eq(n, node),
        u => t,
        u => Con{Entry{n, set}, Graph.map.del(t, node)})

# Removes x from the set of node, if node is a key.
def Graph.map.drop(m: List<&2, Graph.Entry>, +node: String, +x: String) -> List<&2, Graph.Entry>:
  match m:
    case Nil{}:
      Nil{}
    case Con{Entry{+n, +set}, +t}:
      C.If(List<&2, Graph.Entry>, String.eq(n, node),
        u => Con{Entry{n, Graph.set.del(set, x)}, t},
        u => Con{Entry{n, set}, Graph.map.drop(t, node, x)})

# Graph
# -----

# The nodes a node points to.
def Graph.adjacent(g: Graph, node: String) -> List<&2, String>:
  match g:
    case Graph{edges, incoming}:
      Graph.map.get(edges, node)

# The nodes that point to a node.
def Graph.adjacent_incoming(g: Graph, node: String) -> List<&2, String>:
  match g:
    case Graph{edges, incoming}:
      Graph.map.get(incoming, node)

def Graph.add_node(g: Graph, +node: String) -> Graph:
  match g:
    case Graph{+edges, +incoming}:
      Graph{Graph.map.set(edges, node, Graph.map.get(edges, node)),
        Graph.map.set(incoming, node, Graph.map.get(incoming, node))}

def Graph.add_edge.link(g: Graph, +from: String, +to: String) -> Graph:
  match g:
    case Graph{+edges, +incoming}:
      Graph{Graph.map.set(edges, from, Graph.set.add(Graph.map.get(edges, from), to)),
        Graph.map.set(incoming, to, Graph.set.add(Graph.map.get(incoming, to), from))}

# Adds an edge from one node to another, adding the nodes if need be.
def Graph.add_edge(g: Graph, +from: String, +to: String) -> Graph:
  Graph.add_edge.link(Graph.add_node(Graph.add_node(g, from), to), from, to)

# Removes the edge from one node to another; the nodes stay.
def Graph.remove_edge(g: Graph, +from: String, +to: String) -> Graph:
  match g:
    case Graph{edges, incoming}:
      Graph{Graph.map.drop(edges, from, to), Graph.map.drop(incoming, to, from)}

def Graph.remove_incoming_edges.go(sources: List<&2, String>, g: Graph, +node: String) -> Graph:
  match sources:
    case Nil{}:
      g
    case Con{h, t}:
      Graph.remove_incoming_edges.go(t, Graph.remove_edge(g, h, node), node)

# Removes every edge that points to a node. As in the TS, the node gains an
# empty incoming set even if it was not in the graph.
def Graph.remove_incoming_edges(g: Graph, +node: String) -> Graph:
  match g:
    case Graph{edges, +incoming}:
      Graph.remove_incoming_edges.go(Graph.map.get(incoming, node),
        Graph{edges, Graph.map.set(incoming, node, Nil{})}, node)

def Graph.remove_node.drop(g: Graph, +node: String) -> Graph:
  match g:
    case Graph{edges, incoming}:
      Graph{Graph.map.del(edges, node), Graph.map.del(incoming, node)}

# Removes a node and the edges that point to it.
def Graph.remove_node(g: Graph, +node: String) -> Graph:
  Graph.remove_node.drop(Graph.remove_incoming_edges(g, node), node)

# Topological sort
# ----------------

# A node being visited and its neighbours still to look at. The bottom frame
# is the root, whose neighbours are the source nodes and which is not itself
# a node.
type Graph.Frame is Data:
  Frame{value: String, neighbors: List<&2, String>, root: Bool}

def Graph.count(m: List<&2, Graph.Entry>) -> Nat:
  match m:
    case Nil{}:
      0n
    case Con{Entry{n, set}, t}:
      (2n + List.length(&2, String, set) + Graph.count(t) : Nat)

# A depth-first walk with an explicit stack. Each step skips a visited
# neighbour, enters an unvisited one, or leaves a finished node, putting it in
# front of `sorted`: the nodes come out in reverse post-order.
def Graph.sort.go(
  fuel: Nat, stack: List<&2, Graph.Frame>, +visited: List<&2, String>, +sorted: List<&2, String>,
  +edges: List<&2, Graph.Entry>
) -> List<&2, String>:
  match fuel stack:
    case 0n _:
      sorted
    case 1n+f Nil{}:
      sorted
    case 1n+f Con{Frame{value, Nil{}, True{}}, rest}:
      sorted
    case 1n+f Con{Frame{value, Nil{}, False{}}, rest}:
      Graph.sort.go(f, rest, visited, Con{value, sorted}, edges)
    case 1n+ +f Con{Frame{+value, Con{+n, +ns}, +root}, +rest}:
      C.If(List<&2, String>, Graph.set.has(visited, n),
        u => Graph.sort.go(f, Con{Frame{value, ns, root}, rest}, visited, sorted, edges),
        u => Graph.sort.go(f,
          Con{Frame{n, List.reverse(&2, String, Graph.map.get(edges, n)), False{}},
            Con{Frame{value, ns, root}, rest}},
          Con{n, visited}, sorted, edges))

# The nodes reachable from the sources, each before the nodes it points to.
def Graph.topological_sort(g: Graph, +sources: List<&2, String>) -> List<&2, String>:
  match g:
    case Graph{+edges, incoming}:
      Graph.sort.go((Graph.count(edges) + List.length(&2, String, sources) * 2n + 4n : Nat),
        [Frame{"", sources, True{}}], Nil{}, Nil{}, edges)

# DOT
# ---

def Graph.dot.name(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{'!', t}:
      SCon{'_', Graph.dot.name(t)}
    case SCon{h, t}:
      SCon{h, Graph.dot.name(t)}

def Graph.dot.lines(m: List<&2, Graph.Entry>) -> List<&2, String>:
  match m:
    case Nil{}:
      Nil{}
    case Con{Entry{n, set}, t}:
      Con{Graph.dot.name(n ++ " -> {" ++ String.join(set, ",") ++ "}"), Graph.dot.lines(t)}

# The graph in Graphviz DOT form, `!` in cell names written `_`.
def Graph.generate_dot(g: Graph) -> String:
  match g:
    case Graph{edges, incoming}:
      "\n    digraph G {\n      " ++ String.join(Graph.dot.lines(edges), "\n") ++ "\n    }\n    "

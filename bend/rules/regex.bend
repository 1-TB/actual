# A small backtracking matcher for JS regular expressions, standing in for
# `new RegExp(source).test(text)` in the `matches` condition of
# packages/loot-core/src/server/rules/condition.ts. There is no TypeScript
# module behind this file.
#
# `Regex.compile` reads the pattern as JS reads one without the `u` flag
# (the "Annex B" grammar) and `Regex.exec` says whether it matches anywhere
# in a text; only the yes/no answer of `test` is provided, so greedy and lazy
# quantifiers are the same thing here and groups capture nothing.
#
# Supported: literals, `.`, classes `[a-z]` `[^...]` with ranges and escapes,
# `\d \D \w \W \s \S`, `\b \B`, `^` and `$`, groups `(...)`, `(?:...)` and
# `(?<name>...)`, lookahead `(?=...)` `(?!...)`, alternation `|`, the
# quantifiers `* + ? {n} {n,} {n,m}` and their lazy forms, the escapes
# `\t \n \r \f \v \0 \xHH \uHHHH \cX`, identity escapes such as `\.`, and the
# case-insensitive flag (`Regex.test_i`).
#
# Not supported (`Regex.compile` answers `Fail{"unsupported: ..."}`, and
# `Regex.test` then answers False): backreferences `\1` and `\k<name>`,
# legacy octal escapes, and lookbehind `(?<=...)` `(?<!...)`. The flags other
# than `i` (`m`, `s`, `u`, `v`, `y`, `g`) are not modelled, so `^` and `$`
# are the ends of the whole text and `.` stops at a line terminator.
#
# Other differences from JS:
# - Pattern and text are walked as UTF-16 code units, as JS does without the
#   `u` flag: a character past U+FFFF counts as its two surrogates.
# - Case-insensitive matching folds ASCII, Latin-1, Greek and Cyrillic.
# - A syntax error is `Fail{"invalid: ..."}`; the wording is not V8's.
# - The search is bounded by a step budget of 2^40 along any one path, which
#   no real match reaches; a pattern with runaway backtracking takes as long
#   as it does in JS.
import Base
import ../lib/core.bend as C
import ../lib/text.bend as T
import ./value.bend as V

type Regex.Item is Data:
  # the code points lo to hi
  Range{lo: U32, hi: U32}
  # 0 is \d, 1 \D, 2 \w, 3 \W, 4 \s, 5 \S
  Class{kind: U32}

type Regex.Node is Data:
  Nop{}
  # one character that is in the items (or, with neg, is not)
  One{neg: Bool, items: List<&2, Regex.Item>}
  Bol{}
  Eol{}
  # \b, or with neg \B
  Word{neg: Bool}
  Seq{a: Regex.Node, b: Regex.Node}
  Alt{a: Regex.Node, b: Regex.Node}
  # node repeated min to max times, without limit when inf
  Rep{node: Regex.Node, min: Nat, max: Nat, inf: Bool}
  # (?=node), or with neg (?!node)
  Ahead{neg: Bool, node: Regex.Node}
  # used by the matcher: one optional round of a Rep was started with len
  # characters left
  Iter{node: Regex.Node, max: Nat, inf: Bool, len: Nat}

# ---------------------------------------------------------------------------
# Matching

# The "previous character" at the start of the text.
def Regex.none() -> U32:
  4294967295

def Regex.is_word(+x: U32) -> Bool:
  T.Text.within(x, 48, 57) || T.Text.within(x, 65, 90) || T.Text.within(x, 97, 122) || U32.is_eq(x, 95)

def Regex.in_class(kind: U32, +x: U32) -> Bool:
  match kind:
    case 0:
      T.Text.within(x, 48, 57)
    case 1:
      Bool.not(T.Text.within(x, 48, 57))
    case 2:
      Regex.is_word(x)
    case 3:
      Bool.not(Regex.is_word(x))
    case 4:
      T.Text.is_js_space(x)
    case other:
      Bool.not(T.Text.is_js_space(x))

def Regex.member(items: List<&2, Regex.Item>, +x: U32) -> Bool:
  match items:
    case Nil{}:
      False{}
    case Con{Range{lo, hi}, rest}:
      Bool.or(T.Text.within(x, lo, hi), Regex.member(rest, x))
    case Con{Class{kind}, rest}:
      Bool.or(Regex.in_class(kind, x), Regex.member(rest, x))

def Regex.upper_code(+x: U32) -> U32:
  +low = T.Text.within(x, 97, 122) || T.Text.within(x, 224, 254) && U32.is_ne(x, 247) ||
    T.Text.within(x, 945, 971) && U32.is_ne(x, 962) || T.Text.within(x, 1072, 1103)
  +far = T.Text.within(x, 1104, 1119)
  (x - Bool.to_u32(low) * 32 - Bool.to_u32(far) * 80 : U32)

# Whether the character x is one a `One` node accepts.
def Regex.hit(neg: Bool, +items: List<&2, Regex.Item>, +x: U32, ic: Bool) -> Bool:
  Bool.xor(neg, Bool.or(Regex.member(items, x),
    Bool.and(ic, Bool.or(Regex.member(items, V.Value.lower_code(x)), Regex.member(items, Regex.upper_code(x))))))

# The code of the first character, or `Regex.none` at the end.
def Regex.head(s: String) -> U32:
  match s:
    case SNil{}:
      Regex.none()
    case SCon{Chr{x}, +t}:
      x

def Regex.at_word_edge(+prev: U32, s: String) -> Bool:
  Bool.xor(Bool.and(U32.is_ne(prev, Regex.none()), Regex.is_word(prev)), Regex.is_word(Regex.head(s)))

# Whether the nodes of `todo`, one after the other, match a prefix of s.
# `prev` is the character before s and `len` the length of s.
def Regex.go(+fuel: Nat, todo: List<&2, Regex.Node>, +s: String, +prev: U32, +len: Nat, +ic: Bool) -> Bool:
  match fuel:
    case 0n:
      False{}
    case 1n+g:
      match todo:
        case Nil{}:
          True{}
        case Con{Nop{}, rest}:
          Regex.go(g, rest, s, prev, len, ic)
        case Con{One{neg, items}, +rest}:
          match s:
            case SNil{}:
              False{}
            case SCon{Chr{+x}, +t}:
              C.If(Bool, Regex.hit(neg, items, x, ic),
                u => Regex.go(g, rest, t, x, Nat.sub(len, 1n), ic),
                u => False{})
        case Con{Bol{}, +rest}:
          C.If(Bool, U32.is_eq(prev, Regex.none()), u => Regex.go(g, rest, s, prev, len, ic), u => False{})
        case Con{Eol{}, +rest}:
          C.If(Bool, String.is_empty(s), u => Regex.go(g, rest, s, prev, len, ic), u => False{})
        case Con{Word{neg}, +rest}:
          C.If(Bool, Bool.xor(neg, Regex.at_word_edge(prev, s)), u => Regex.go(g, rest, s, prev, len, ic), u => False{})
        case Con{Seq{a, b}, rest}:
          Regex.go(g, Con{a, Con{b, rest}}, s, prev, len, ic)
        case Con{Alt{a, b}, +rest}:
          C.If(Bool, Regex.go(g, Con{a, rest}, s, prev, len, ic),
            u => True{},
            u => Regex.go(g, Con{b, rest}, s, prev, len, ic))
        case Con{Rep{+node, min, +max, +inf}, +rest}:
          match min:
            case 1n+m:
              Regex.go(g, Con{node, Con{Rep{node, m, Nat.sub(max, 1n), inf}, rest}}, s, prev, len, ic)
            case 0n:
              C.If(Bool, Bool.and(Bool.not(inf), Nat.is_eq(max, 0n)),
                u => Regex.go(g, rest, s, prev, len, ic),
                u => C.If(Bool, Regex.go(g, Con{node, Con{Iter{node, Nat.sub(max, 1n), inf, len}, rest}}, s, prev, len, ic),
                  u => True{},
                  u => Regex.go(g, rest, s, prev, len, ic)))
        case Con{Ahead{neg, node}, +rest}:
          C.If(Bool, Bool.xor(neg, Regex.go(g, [node], s, prev, len, ic)),
            u => Regex.go(g, rest, s, prev, len, ic),
            u => False{})
        case Con{Iter{+node, +max, +inf, start}, +rest}:
          # A round that used no character cannot be repeated.
          C.If(Bool, Nat.is_eq(start, len),
            u => False{},
            u => Regex.go(g, Con{Rep{node, 0n, max, inf}, rest}, s, prev, len, ic))

def Regex.fuel() -> Nat:
  (1048576n * 1048576n : Nat)

def Regex.search(s: String, +node: Regex.Node, +prev: U32, +len: Nat, +ic: Bool) -> Bool:
  match s:
    case SNil{}:
      Regex.go(Regex.fuel(), [node], SNil{}, prev, 0n, ic)
    case SCon{Chr{+x}, +t}:
      C.If(Bool, Regex.go(Regex.fuel(), [node], SCon{Chr{x}, t}, prev, len, ic),
        u => True{},
        u => Regex.search(t, node, x, Nat.sub(len, 1n), ic))

# The text as UTF-16 code units, which is what a JS pattern without the `u`
# flag walks: a character past U+FFFF becomes its two surrogates.
def Regex.utf16(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+x}, +t}:
      C.If(String, (x >= 65536 : U32),
        u => SCon{Chr{(55296 + ((x - 65536 : U32) >> 10n : U32) : U32)},
          SCon{Chr{(56320 + ((x - 65536 : U32) .&. 1023 : U32) : U32)}, Regex.utf16(t)}},
        u => SCon{Chr{x}, Regex.utf16(t)})

def Regex.exec.units(node: Regex.Node, ic: Bool, +s: String) -> Bool:
  Regex.search(s, node, Regex.none(), String.length(s), ic)

# Whether a compiled pattern matches somewhere in s; `ic` is the `i` flag.
def Regex.exec(node: Regex.Node, ic: Bool, s: String) -> Bool:
  Regex.exec.units(node, ic, Regex.utf16(s))

# ---------------------------------------------------------------------------
# Parsing

# An open group: kind 0 is the whole pattern, 1 a group, 2 a lookahead, 3 a
# negative lookahead. `alts` holds the finished alternatives and `seq` the
# items of the current one, both newest first. `q` says the last item can
# take a quantifier.
type Regex.Frame is Data:
  Frame{kind: U32, alts: List<&2, Regex.Node>, seq: List<&2, Regex.Node>, q: Bool}

type Regex.State is Data:
  State{rest: String, stack: List<&2, Regex.Frame>}

# What an escape stands for: kind 0 is the character `code`, 1 the class
# `code`, 2 a word boundary (negated when code is 1).
type Regex.Esc is Data:
  Esc{kind: U32, code: U32, rest: String}

type Regex.Hex is Data:
  Hex{value: U32, rest: String}

type Regex.Times is Data:
  Times{min: Nat, max: Nat, inf: Bool, rest: String}

def Regex.char(+x: U32) -> Regex.Node:
  One{False{}, [Range{x, x}]}

def Regex.seq.go(rev: List<&2, Regex.Node>, acc: Regex.Node) -> Regex.Node:
  match rev:
    case Nil{}:
      acc
    case Con{h, t}:
      Regex.seq.go(t, Seq{h, acc})

# The items of an alternative, newest first, as one node.
def Regex.seq(rev: List<&2, Regex.Node>) -> Regex.Node:
  match rev:
    case Nil{}:
      Nop{}
    case Con{h, t}:
      Regex.seq.go(t, h)

def Regex.alts(rev: List<&2, Regex.Node>, acc: Regex.Node) -> Regex.Node:
  match rev:
    case Nil{}:
      acc
    case Con{h, t}:
      Regex.alts(t, Alt{h, acc})

def Regex.finish(alts: List<&2, Regex.Node>, seq: List<&2, Regex.Node>) -> Regex.Node:
  Regex.alts(alts, Regex.seq(seq))

# Adds an item to the innermost open group.
def Regex.push(stack: List<&2, Regex.Frame>, node: Regex.Node, q: Bool) -> List<&2, Regex.Frame>:
  match stack:
    case Nil{}:
      [Frame{0, Nil{}, [node], q}]
    case Con{Frame{kind, alts, seq, old}, rest}:
      Con{Frame{kind, alts, Con{node, seq}, q}, rest}

def Regex.done(rest: String, stack: List<&2, Regex.Frame>) -> Result<&2, &2, String, Regex.State>:
  Done{State{rest, stack}}

def Regex.hex_value(+x: U32) -> Maybe<&2, U32>:
  C.If(Maybe<&2, U32>, T.Text.within(x, 48, 57),
    u => Some{(x - 48 : U32)},
    u => C.If(Maybe<&2, U32>, T.Text.within(x, 97, 102),
      u => Some{(x - 87 : U32)},
      u => Bool.pick(Maybe<&2, U32>, T.Text.within(x, 65, 70), Some{(x - 55 : U32)}, None{})))

def Regex.hex.next(d: Maybe<&2, U32>, +acc: U32, r: Maybe<&2, Regex.Hex>) -> Maybe<&2, Regex.Hex>:
  match d r:
    case Some{v} Some{Hex{value, rest}}:
      Some{Hex{value, rest}}
    case _ _:
      None{}

# The value of exactly n hex digits at the start of s, and what follows.
def Regex.hex(n: Nat, s: String, +acc: U32) -> Maybe<&2, Regex.Hex>:
  match n s:
    case 0n rest:
      Some{Hex{acc, rest}}
    case 1n+m SNil{}:
      None{}
    case 1n+m SCon{Chr{+x}, +t}:
      Regex.hex.next(Regex.hex_value(x),
        acc, Regex.hex(m, t, (acc * 16 + Maybe.default(&2, U32, Regex.hex_value(x), 0) : U32)))

def Regex.esc.hex(h: Maybe<&2, Regex.Hex>, +c: U32, t: String) -> Result<&2, &2, String, Regex.Esc>:
  match h:
    case None{}:
      Done{Esc{0, c, t}}
    case Some{Hex{value, rest}}:
      Done{Esc{0, value, rest}}

def Regex.is_letter(+x: U32) -> Bool:
  Bool.or(T.Text.within(x, 65, 90), T.Text.within(x, 97, 122))

# \c with what follows it: a control character when a letter follows; else
# the backslash stands for itself and the c is read again as a character.
def Regex.esc.control(+t: String) -> Result<&2, &2, String, Regex.Esc>:
  +x = Regex.head(t)
  C.If(Result<&2, &2, String, Regex.Esc>, Bool.and(U32.is_ne(x, Regex.none()), Regex.is_letter(x)),
    u => Done{Esc{0, (x % 32 : U32), String.drop(t, 1n)}},
    u => Done{Esc{0, 92, SCon{'c', t}}})

def Regex.esc.zero(+t: String) -> Result<&2, &2, String, Regex.Esc>:
  Bool.pick(Result<&2, &2, String, Regex.Esc>, T.Text.within(Regex.head(t), 48, 57),
    Fail{"unsupported: octal escape"}, Done{Esc{0, 0, t}})

# The escape whose backslash was just read. `cls` says it is inside a class.
def Regex.escape(s: String, cls: Bool) -> Result<&2, &2, String, Regex.Esc>:
  match s:
    case SNil{}:
      Fail{"invalid: \\ at end of pattern"}
    case SCon{'d', +t}:
      Done{Esc{1, 0, t}}
    case SCon{'D', +t}:
      Done{Esc{1, 1, t}}
    case SCon{'w', +t}:
      Done{Esc{1, 2, t}}
    case SCon{'W', +t}:
      Done{Esc{1, 3, t}}
    case SCon{'s', +t}:
      Done{Esc{1, 4, t}}
    case SCon{'S', +t}:
      Done{Esc{1, 5, t}}
    case SCon{'b', +t}:
      Bool.pick(Result<&2, &2, String, Regex.Esc>, cls, Done{Esc{0, 8, t}}, Done{Esc{2, 0, t}})
    case SCon{'B', +t}:
      Bool.pick(Result<&2, &2, String, Regex.Esc>, cls, Done{Esc{0, 66, t}}, Done{Esc{2, 1, t}})
    case SCon{'t', +t}:
      Done{Esc{0, 9, t}}
    case SCon{'n', +t}:
      Done{Esc{0, 10, t}}
    case SCon{'v', +t}:
      Done{Esc{0, 11, t}}
    case SCon{'f', +t}:
      Done{Esc{0, 12, t}}
    case SCon{'r', +t}:
      Done{Esc{0, 13, t}}
    case SCon{'0', +t}:
      Regex.esc.zero(t)
    case SCon{'x', +t}:
      Regex.esc.hex(Regex.hex(2n, t, 0), 120, t)
    case SCon{'u', +t}:
      Regex.esc.hex(Regex.hex(4n, t, 0), 117, t)
    case SCon{'c', +t}:
      Regex.esc.control(t)
    case SCon{'k', +t}:
      Bool.pick(Result<&2, &2, String, Regex.Esc>, U32.is_eq(Regex.head(t), 60),
        Fail{"unsupported: named backreference"}, Done{Esc{0, 107, t}})
    case SCon{Chr{+x}, +t}:
      Bool.pick(Result<&2, &2, String, Regex.Esc>, T.Text.within(x, 49, 57),
        Fail{"unsupported: backreference or octal escape"}, Done{Esc{0, x, t}})

# --- classes

# One member of a class: kind 0 is the character `code`, 1 the class `code`.
def Regex.class.atom(s: String) -> Result<&2, &2, String, Regex.Esc>:
  match s:
    case SNil{}:
      Fail{"invalid: unterminated character class"}
    case SCon{'\\', +t}:
      Regex.escape(t, True{})
    case SCon{Chr{x}, +t}:
      Done{Esc{0, x, t}}

def Regex.class.item(kind: U32, +code: U32) -> Regex.Item:
  match kind:
    case 0:
      Range{code, code}
    case other:
      Class{code}

type Regex.Class is Data:
  ClassOf{items: List<&2, Regex.Item>, rest: String}

# The members read so far, an atom a, and the atom b after "a-".
def Regex.class.range(
  +items: List<&2, Regex.Item>, +ak: U32, +ac: U32, b: Result<&2, &2, String, Regex.Esc>
) -> Result<&2, &2, String, Regex.Class>:
  match b:
    case Fail{e}:
      Fail{e}
    case Done{Esc{+bk, +bc, +rest}}:
      C.If(Result<&2, &2, String, Regex.Class>, Bool.and(U32.is_eq(ak, 0), U32.is_eq(bk, 0)),
        u => Bool.pick(Result<&2, &2, String, Regex.Class>, (ac <= bc : U32),
          Done{ClassOf{Con{Range{ac, bc}, items}, rest}}, Fail{"invalid: range out of order in character class"}),
        u => Done{ClassOf{Con{Regex.class.item(bk, bc), Con{Range{45, 45}, Con{Regex.class.item(ak, ac), items}}}, rest}})

# After an atom: a range when "-" and another atom follow, else the atom.
def Regex.class.after(+items: List<&2, Regex.Item>, a: Result<&2, &2, String, Regex.Esc>) -> Result<&2, &2, String, Regex.Class>:
  match a:
    case Fail{e}:
      Fail{e}
    case Done{Esc{+ak, +ac, SCon{'-', SCon{']', +t}}}}:
      Done{ClassOf{Con{Regex.class.item(ak, ac), items}, SCon{'-', SCon{']', t}}}}
    case Done{Esc{+ak, +ac, SCon{'-', SCon{c, t}}}}:
      Regex.class.range(items, ak, ac, Regex.class.atom(SCon{c, t}))
    case Done{Esc{ak, ac, rest}}:
      Done{ClassOf{Con{Regex.class.item(ak, ac), items}, rest}}

# The members of a class up to its "]", and what follows it.
def Regex.class.go(+fuel: Nat, r: Result<&2, &2, String, Regex.Class>) -> Result<&2, &2, String, Regex.Class>:
  match fuel r:
    case 0n _:
      Fail{"invalid: unterminated character class"}
    case 1n+g Fail{e}:
      Fail{e}
    case 1n+g Done{ClassOf{items, SCon{']', +t}}}:
      Done{ClassOf{items, t}}
    case 1n+g Done{ClassOf{+items, rest}}:
      Regex.class.go(g, Regex.class.after(items, Regex.class.atom(rest)))

def Regex.class.node(neg: Bool, r: Result<&2, &2, String, Regex.Class>, stack: List<&2, Regex.Frame>) ->
  Result<&2, &2, String, Regex.State>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{ClassOf{items, rest}}:
      Regex.done(rest, Regex.push(stack, One{neg, items}, True{}))

# The class whose "[" was just read.
def Regex.class(+s: String, stack: List<&2, Regex.Frame>) -> Result<&2, &2, String, Regex.State>:
  match s:
    case SCon{'^', +t}:
      Regex.class.node(True{}, Regex.class.go(1n+String.length(t), Done{ClassOf{Nil{}, t}}), stack)
    case other:
      Regex.class.node(False{}, Regex.class.go(1n+String.length(s), Done{ClassOf{Nil{}, s}}), stack)

# --- quantifiers

def Regex.quantify(stack: List<&2, Regex.Frame>, min: Nat, max: Nat, inf: Bool, rest: String) ->
  Result<&2, &2, String, Regex.State>:
  match stack rest:
    case Con{Frame{kind, alts, Con{last, seq}, True{}}, more} SCon{'?', +t}:
      Regex.done(t, Con{Frame{kind, alts, Con{Rep{last, min, max, inf}, seq}, False{}}, more})
    case Con{Frame{kind, alts, Con{last, seq}, True{}}, more} t:
      Regex.done(t, Con{Frame{kind, alts, Con{Rep{last, min, max, inf}, seq}, False{}}, more})
    case _ _:
      Fail{"invalid: nothing to repeat"}

type Regex.Run is Data:
  Run{digits: String, rest: String}

def Regex.count(+ds: String) -> Nat:
  Bool.pick(Nat, Nat.is_le(String.length(ds), 9n), Maybe.default(&2, Nat, Nat.read(ds), 0n), 999999999n)

# The digits at the start of s (newest first in acc), and what follows.
def Regex.digits(s: String, +acc: String) -> Regex.Run:
  match s:
    case SNil{}:
      Run{String.reverse(acc), SNil{}}
    case SCon{Chr{+x}, +t}:
      C.If(Regex.Run, T.Text.within(x, 48, 57),
        u => Regex.digits(t, SCon{Chr{x}, acc}),
        u => Run{String.reverse(acc), SCon{Chr{x}, t}})

def Regex.brace.upper(+n: Nat, r: Regex.Run) -> Maybe<&2, Regex.Times>:
  match r:
    case Run{+ds, SCon{'}', +t}}:
      Bool.pick(Maybe<&2, Regex.Times>, String.is_empty(ds), Some{Times{n, 0n, True{}, t}},
        Some{Times{n, Regex.count(ds), False{}, t}})
    case other:
      None{}

def Regex.brace.lower(r: Regex.Run) -> Maybe<&2, Regex.Times>:
  match r:
    case Run{SNil{}, rest}:
      None{}
    case Run{+ds, SCon{'}', +t}}:
      Some{Times{Regex.count(ds), Regex.count(ds), False{}, t}}
    case Run{ds, SCon{',', +t}}:
      Regex.brace.upper(Regex.count(ds), Regex.digits(t, SNil{}))
    case other:
      None{}

# {n}, {n,} or {n,m} after its "{"; None when the text is not one of them.
def Regex.brace(s: String) -> Maybe<&2, Regex.Times>:
  Regex.brace.lower(Regex.digits(s, SNil{}))

def Regex.brace.apply(q: Maybe<&2, Regex.Times>, t: String, +stack: List<&2, Regex.Frame>) ->
  Result<&2, &2, String, Regex.State>:
  match q:
    case None{}:
      Regex.done(t, Regex.push(stack, Regex.char(123), True{}))
    case Some{Times{+min, +max, +inf, +rest}}:
      C.If(Result<&2, &2, String, Regex.State>, Bool.and(Bool.not(inf), Nat.is_gt(min, max)),
        u => Fail{"invalid: numbers out of order in {} quantifier"},
        u => Regex.quantify(stack, min, max, inf, rest))

# --- groups

def Regex.frame(kind: U32) -> Regex.Frame:
  Frame{kind, Nil{}, Nil{}, False{}}

# The text after the ">" that ends a group name.
def Regex.name(s: String) -> Maybe<&2, String>:
  match s:
    case SNil{}:
      None{}
    case SCon{'>', +t}:
      Some{t}
    case SCon{c, t}:
      Regex.name(t)

def Regex.open.named(r: Maybe<&2, String>, stack: List<&2, Regex.Frame>) -> Result<&2, &2, String, Regex.State>:
  match r:
    case None{}:
      Fail{"invalid: group name"}
    case Some{t}:
      Regex.done(t, Con{Regex.frame(1), stack})

# The group whose "(" was just read.
def Regex.open(s: String, stack: List<&2, Regex.Frame>) -> Result<&2, &2, String, Regex.State>:
  match s:
    case SCon{'?', SCon{':', r}}:
      Regex.done(r, Con{Regex.frame(1), stack})
    case SCon{'?', SCon{'=', r}}:
      Regex.done(r, Con{Regex.frame(2), stack})
    case SCon{'?', SCon{'!', r}}:
      Regex.done(r, Con{Regex.frame(3), stack})
    case SCon{'?', SCon{'<', SCon{'=', r}}}:
      Fail{"unsupported: lookbehind"}
    case SCon{'?', SCon{'<', SCon{'!', r}}}:
      Fail{"unsupported: lookbehind"}
    case SCon{'?', SCon{'<', r}}:
      Regex.open.named(Regex.name(r), stack)
    case SCon{'?', r}:
      Fail{"invalid: group"}
    case other:
      Regex.done(other, Con{Regex.frame(1), stack})

def Regex.wrap(kind: U32, node: Regex.Node) -> Regex.Node:
  match kind:
    case 2:
      Ahead{False{}, node}
    case 3:
      Ahead{True{}, node}
    case other:
      node

def Regex.close(t: String, stack: List<&2, Regex.Frame>) -> Result<&2, &2, String, Regex.State>:
  match stack:
    case Con{Frame{kind, alts, seq, q}, Con{parent, more}}:
      Regex.done(t, Regex.push(Con{parent, more}, Regex.wrap(kind, Regex.finish(alts, seq)), True{}))
    case other:
      Fail{"invalid: unmatched )"}

def Regex.bar(t: String, stack: List<&2, Regex.Frame>) -> Result<&2, &2, String, Regex.State>:
  match stack:
    case Nil{}:
      Regex.done(t, [Frame{0, [Nop{}], Nil{}, False{}}])
    case Con{Frame{kind, alts, seq, q}, more}:
      Regex.done(t, Con{Frame{kind, Con{Regex.seq(seq), alts}, Nil{}, False{}}, more})

def Regex.esc.node(kind: U32, +code: U32) -> Regex.Node:
  match kind:
    case 0:
      Regex.char(code)
    case 1:
      One{False{}, [Class{code}]}
    case other:
      Word{U32.is_eq(code, 1)}

def Regex.step.escape(e: Result<&2, &2, String, Regex.Esc>, stack: List<&2, Regex.Frame>) ->
  Result<&2, &2, String, Regex.State>:
  match e:
    case Fail{m}:
      Fail{m}
    case Done{Esc{+kind, code, rest}}:
      Regex.done(rest, Regex.push(stack, Regex.esc.node(kind, code), U32.is_ne(kind, 2)))

# Reads one token of the pattern into the stack of open groups.
def Regex.step(s: String, stack: List<&2, Regex.Frame>) -> Result<&2, &2, String, Regex.State>:
  match s:
    case SNil{}:
      Regex.done(SNil{}, stack)
    case SCon{'(', +t}:
      Regex.open(t, stack)
    case SCon{')', +t}:
      Regex.close(t, stack)
    case SCon{'|', +t}:
      Regex.bar(t, stack)
    case SCon{'*', +t}:
      Regex.quantify(stack, 0n, 0n, True{}, t)
    case SCon{'+', +t}:
      Regex.quantify(stack, 1n, 0n, True{}, t)
    case SCon{'?', +t}:
      Regex.quantify(stack, 0n, 1n, False{}, t)
    case SCon{'{', +t}:
      Regex.brace.apply(Regex.brace(t), t, stack)
    case SCon{'[', +t}:
      Regex.class(t, stack)
    case SCon{'\\', +t}:
      Regex.step.escape(Regex.escape(t, False{}), stack)
    case SCon{'^', +t}:
      Regex.done(t, Regex.push(stack, Bol{}, False{}))
    case SCon{'$', +t}:
      Regex.done(t, Regex.push(stack, Eol{}, False{}))
    case SCon{'.', +t}:
      Regex.done(t, Regex.push(stack, One{True{}, [Range{10, 10}, Range{13, 13}, Range{8232, 8233}]}, True{}))
    case SCon{Chr{x}, +t}:
      Regex.done(t, Regex.push(stack, Regex.char(x), True{}))

def Regex.parse.end(stack: List<&2, Regex.Frame>) -> Result<&2, &2, String, Regex.Node>:
  match stack:
    case Nil{}:
      Done{Nop{}}
    case Con{Frame{kind, alts, seq, q}, Nil{}}:
      Done{Regex.finish(alts, seq)}
    case other:
      Fail{"invalid: unterminated group"}

def Regex.parse.go(fuel: Nat, st: Result<&2, &2, String, Regex.State>) -> Result<&2, &2, String, Regex.Node>:
  match fuel st:
    case 0n _:
      Fail{"invalid: pattern"}
    case 1n+g Fail{e}:
      Fail{e}
    case 1n+g Done{State{SNil{}, stack}}:
      Regex.parse.end(stack)
    case 1n+g Done{State{rest, stack}}:
      Regex.parse.go(g, Regex.step(rest, stack))

# The pattern as a node, or why it is not one: "invalid: ..." for what JS
# refuses with a SyntaxError, "unsupported: ..." for what this matcher lacks.
def Regex.compile.units(+src: String) -> Result<&2, &2, String, Regex.Node>:
  Regex.parse.go(2n+String.length(src), Done{State{src, [Regex.frame(0)]}})

def Regex.compile(src: String) -> Result<&2, &2, String, Regex.Node>:
  Regex.compile.units(Regex.utf16(src))

def Regex.run(r: Result<&2, &2, String, Regex.Node>, ic: Bool, s: String) -> Bool:
  match r:
    case Fail{e}:
      False{}
    case Done{node}:
      Regex.exec(node, ic, s)

# JS `new RegExp(source).test(s)`, with False for a pattern that does not
# compile.
def Regex.test(source: String, s: String) -> Bool:
  Regex.run(Regex.compile(source), False{}, s)

# JS `new RegExp(source, 'i').test(s)`.
def Regex.test_i(source: String, s: String) -> Bool:
  Regex.run(Regex.compile(source), True{}, s)

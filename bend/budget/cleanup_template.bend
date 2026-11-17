# The parser for end-of-month cleanup directives in category notes, such as
# `#cleanup source` or `#cleanup Savings sink 2`: a port of
# packages/loot-core/src/server/budget/cleanup-template.pegjs, with Peggy's
# semantics (see goal_template.bend). `CleanupTemplate.parse` answers the
# JSON value the Peggy actions build; None where Peggy throws.
import Base
import ../lib/core.bend as C
import ../json/json.bend as J

# A rule's value and the text after it.
type Cln.R is Data:
  R{value: J.Json, rest: String}

# Matched text and the text after it.
type Cln.Span is Data:
  Span{text: String, rest: String}

def Cln.or(a: Maybe<&2, Cln.R>, b: Maybe<&2, Cln.R>) -> Maybe<&2, Cln.R>:
  match a:
    case None{}:
      b
    case Some{r}:
      Some{r}

# `_?`: spaces.
def Cln.spaces(s: String) -> String:
  match s:
    case SCon{' ', t}:
      Cln.spaces(t)
    case other:
      other

def Cln.exact(+s: String, +w: String) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, String.starts_with(s, w), Some{String.drop(s, String.length(w))}, None{})

def Cln.put(c: Char, r: Cln.Span) -> Cln.Span:
  match r:
    case Span{text, rest}:
      Span{SCon{c, text}, rest}

# `(!stop .)*`: the characters before the first `stop`, or all of them.
def Cln.until(s: String, +stop: String) -> Cln.Span:
  match s:
    case SNil{}:
      Span{SNil{}, SNil{}}
    case SCon{+h, +t}:
      C.If(Cln.Span, String.starts_with(SCon{h, t}, stop),
        u => Span{SNil{}, SCon{h, t}},
        u => Cln.put(h, Cln.until(t, stop)))

def Cln.is_digit(+x: U32) -> Bool:
  Bool.and((x >= 48 : U32), (x <= 57 : U32))

# The digits at the head of s.
def Cln.digits(s: String) -> Cln.Span:
  match s:
    case SNil{}:
      Span{SNil{}, SNil{}}
    case SCon{Chr{+x}, +t}:
      C.If(Cln.Span, Cln.is_digit(x),
        u => Cln.put(Chr{x}, Cln.digits(t)),
        u => Span{SNil{}, SCon{Chr{x}, t}})

# `group || null`
def Cln.group(name: String) -> J.Json:
  match name:
    case SNil{}:
      J.JNull{}
    case other:
      J.JStr{other}

# `+weight || 1`, for the digits read; none, or a zero, is 1.
def Cln.weight(+digits: String) -> J.Json:
  Bool.pick(J.Json, Nat.is_eq(Maybe.default(&2, Nat, Nat.read(digits), 0n), 0n), J.Json.nat(1n),
    J.Json.nat(Maybe.default(&2, Nat, Nat.read(digits), 0n)))

def Cln.sink.make(group: J.Json, w: Cln.Span) -> Maybe<&2, Cln.R>:
  match w:
    case Span{digits, rest}:
      Some{R{J.Json.object([J.Member{"type", J.JStr{"sink"}}, J.Member{"weight", Cln.weight(digits)},
        J.Member{"group", group}]), rest}}

# `'sink' _? weight?`
def Cln.sink(s: String, group: J.Json) -> Maybe<&2, Cln.R>:
  Maybe.bind(&2, String, Cln.R, Cln.exact(s, "sink"), after => Cln.sink.make(group, Cln.digits(Cln.spaces(after))))

def Cln.source.make(group: J.Json, after: Maybe<&2, String>) -> Maybe<&2, Cln.R>:
  match after:
    case None{}:
      None{}
    case Some{rest}:
      Some{R{J.Json.object([J.Member{"group", group}, J.Member{"type", J.JStr{"source"}}]), rest}}

# `sourcegroup _? 'source'`
def Cln.group_source(g: Cln.Span) -> Maybe<&2, Cln.R>:
  match g:
    case Span{name, rest}:
      Cln.source.make(Cln.group(name), Cln.exact(Cln.spaces(rest), "source"))

# `sinkgroup? _? 'sink' _? weight?`
def Cln.group_sink(g: Cln.Span) -> Maybe<&2, Cln.R>:
  match g:
    case Span{name, rest}:
      Cln.sink(Cln.spaces(rest), Cln.group(name))

# `sourcegroup` alone: a group with no direction.
def Cln.group_only(g: Cln.Span) -> Maybe<&2, Cln.R>:
  match g:
    case Span{name, rest}:
      Some{R{J.Json.object([J.Member{"group", J.JStr{name}}, J.Member{"type", J.JNull{}}]), rest}}

# `inner`: the five forms, in the grammar's order.
def Cln.inner(+s: String) -> Maybe<&2, Cln.R>:
  Cln.or(Cln.source.make(J.JNull{}, Cln.exact(s, "source")),
    Cln.or(Cln.sink(s, J.JNull{}),
      Cln.or(Cln.group_source(Cln.until(s, " source")),
        Cln.or(Cln.group_sink(Cln.until(s, " sink")),
          Cln.group_only(Cln.until(s, " source"))))))

# `'#cleanup' _ inner`, where `_` is one or more spaces.
def Cln.expr(after: Maybe<&2, String>) -> Maybe<&2, Cln.R>:
  match after:
    case Some{SCon{' ', t}}:
      Cln.inner(Cln.spaces(t))
    case other:
      None{}

def Cln.whole(m: Maybe<&2, Cln.R>) -> Maybe<&2, J.Json>:
  match m:
    case Some{R{value, SNil{}}}:
      Some{value}
    case other:
      None{}

# Parses one cleanup line. None where the Peggy parser throws a syntax error.
def CleanupTemplate.parse(line: String) -> Maybe<&2, J.Json>:
  Cln.whole(Cln.expr(Cln.exact(line, "#cleanup")))

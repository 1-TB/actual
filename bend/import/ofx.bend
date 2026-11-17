# Port of packages/loot-core/src/server/transactions/import/ofx2json.ts: reads
# an OFX or QFX file, SGML or XML, into its headers and transactions.
#
# Deviations: the file arrives decoded, as a String (`decodeOfxBytes` stays
# outside). A rejected promise becomes a `Fail` carrying the error's message.
# The date of a transaction is computed on the proleptic Gregorian calendar,
# which is what `new Date(year, month, day)` formatted in local time gives
# wherever local midnight exists; a missing DTPOSTED formats `new Date(null)`,
# which is "1970-01-01" at UTC and east of it. `Number` reads decimal
# literals only (see `Js.number`). A value xml2js leaves loosely typed
# (TRNAMT, TRNTYPE, FITID) stays a `Json`.
import Base
import ../lib/core.bend as C
import ../lib/int.bend as I
import ../lib/num.bend as N
import ../lib/date.bend as D
import ../lib/text.bend as T
import ../json/json.bend as J
import ./js.bend as X
import ./xml.bend as M

type Ofx.Txn is Data:
  Txn{
    amount: Maybe<&2, J.Json>, kind: Maybe<&2, J.Json>, fit_id: Maybe<&2, J.Json>,
    date: String, name: Maybe<&2, String>, memo: Maybe<&2, String>
  }

# The header lines before `<OFX>`, as the object JS builds from them, and the
# transactions.
type Ofx.Data is Data:
  Parsed{headers: List<&2, X.Js.Entry<Maybe<&2, String>>>, transactions: List<&2, Ofx.Txn>}

# SGML to XML
# -----------

# Whether the whitespace run at the head of s ends at a `<`.
def Ofx.ws_then_lt(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{'<', t}:
      True{}
    case SCon{Chr{x}, t}:
      C.If(Bool, X.Js.is_space(x), u => Ofx.ws_then_lt(t), u => False{})

# `.replace(/\s+</g, '<')`: no whitespace before a tag.
def Ofx.strip_before(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+x}, +t}:
      C.If(String, X.Js.is_space(x) && Ofx.ws_then_lt(t),
        u => Ofx.strip_before(t),
        u => SCon{Chr{x}, Ofx.strip_before(t)})

# `.replace(/>\s+/g, '>')`: no whitespace after a tag.
def Ofx.strip_after(s: String, after: Bool) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+x}, +t}:
      C.If(String, after && X.Js.is_space(x),
        u => Ofx.strip_after(t, True{}),
        u => SCon{Chr{x}, Ofx.strip_after(t, U32.is_eq(x, 62))})

# `.replace(/\.(?=[^<>]*>)/g, '')` over the reversed text: a dot goes when
# the next angle bracket after it is a `>`, as inside a tag name.
def Ofx.strip_dots(rev: String, +gt: Bool, acc: String) -> String:
  match rev:
    case SNil{}:
      acc
    case SCon{'.', t}:
      Ofx.strip_dots(t, gt, Bool.pick(String, gt, acc, SCon{'.', acc}))
    case SCon{'>', t}:
      Ofx.strip_dots(t, True{}, SCon{'>', acc})
    case SCon{'<', t}:
      Ofx.strip_dots(t, False{}, SCon{'<', acc})
    case SCon{h, t}:
      Ofx.strip_dots(t, gt, SCon{h, acc})

def Ofx.opener.at(r: String & String) -> Maybe<&2, String>:
  match r:
    case Tuple{SNil{}, rest}:
      None{}
    case Tuple{name, SCon{'>', SCon{'<', rest}}}:
      None{}
    case Tuple{name, SCon{'>', SCon{h, rest}}}:
      Some{name}
    case Tuple{name, rest}:
      None{}

# The name of the tag that `/<(\w+?)>([^<]+)/` matches when s is what follows
# its `<`: word characters, `>`, and at least one character of text.
def Ofx.opener(s: String) -> Maybe<&2, String>:
  Ofx.opener.at(X.Js.word(s))

def Ofx.closer(pending: Maybe<&2, String>) -> String:
  match pending:
    case None{}:
      SNil{}
    case Some{name}:
      "</<added>" ++ name ++ ">"

# `.replace(/<(\w+?)>([^<]+)/g, '<$1>$2</<added>$1>')`: an end tag after the
# text of every element that has text. `pending` is the name of the element
# whose text is being copied.
def Ofx.add_ends(s: String, +pending: Maybe<&2, String>) -> String:
  match s:
    case SNil{}:
      Ofx.closer(pending)
    case SCon{'<', +t}:
      Ofx.closer(pending) ++ SCon{'<', Ofx.add_ends(t, Ofx.opener(t))}
    case SCon{h, t}:
      SCon{h, Ofx.add_ends(t, pending)}

type Ofx.Added is Data:
  Added{name: String, skip: Nat}

def Ofx.added.dup(+name: String, rest: String) -> Ofx.Added:
  Added{name, (10n + String.length(name) + Bool.pick(Nat,
    String.starts_with(rest, "</" ++ name ++ ">"), (String.length(name) + 3n : Nat), 0n) : Nat)}

def Ofx.added.at(r: String & String) -> Maybe<&2, Ofx.Added>:
  match r:
    case Tuple{SNil{}, rest}:
      None{}
    case Tuple{name, SCon{'>', rest}}:
      Some{Ofx.added.dup(name, rest)}
    case Tuple{name, rest}:
      None{}

def Ofx.added.name(m: Maybe<&2, String>) -> Maybe<&2, Ofx.Added>:
  match m:
    case None{}:
      None{}
    case Some{rest}:
      Ofx.added.at(X.Js.word(rest))

# What `/<\/<added>(\w+?)>(<\/\1>)?/` matches at the head of s: the name, and
# the count of characters after the first that the match covers.
def Ofx.added(s: String) -> Maybe<&2, Ofx.Added>:
  Ofx.added.name(X.Js.strip_prefix(s, "</<added>"))

def Ofx.merge_ends.at(m: Maybe<&2, Ofx.Added>, h: Char) -> String & Nat:
  match m:
    case None{}:
      (SCon{h, SNil{}}, 0n)
    case Some{Added{name, skip}}:
      ("</" ++ name ++ ">", skip)

def Ofx.merge_ends.put(r: String & Nat, t: String, next: String -> Nat -> String) -> String:
  (out, skip) = r
  out ++ next(t, skip)

# `.replace(/<\/<added>(\w+?)>(<\/\1>)?/g, '</$1>')`: an added end tag
# becomes a real one and swallows the real one that follows it.
def Ofx.merge_ends(s: String, skip: Nat) -> String:
  match s skip:
    case SNil{} _:
      SNil{}
    case SCon{h, t} 1n+k:
      Ofx.merge_ends(t, k)
    case SCon{+h, +t} 0n:
      Ofx.merge_ends.put(Ofx.merge_ends.at(Ofx.added(SCon{h, t}), h), t, rest => n => Ofx.merge_ends(rest, n))

# `sgml2Xml`: every `&` escaped, the whitespace around tags and the dots in
# tag names removed, and an end tag given to every element that has text.
def Ofx.sgml_to_xml(sgml: String) -> String:
  Ofx.merge_ends(Ofx.add_ends(Ofx.strip_dots(String.reverse(
    Ofx.strip_after(Ofx.strip_before(X.Js.replace_all(sgml, "&", "&#038;")), False{})), False{}, SNil{}),
    None{}), 0n)

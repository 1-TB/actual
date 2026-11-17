# Port of packages/loot-core/src/server/transactions/import/ofx2json.ts: reads
# an OFX or QFX file, SGML or XML, into its headers and transactions.
#
# Deviations: the file arrives decoded, as a String (`decodeOfxBytes` stays
# outside). A rejected promise becomes a `Fail` carrying the error's message.
# The date of a transaction is computed on the proleptic Gregorian calendar,
# which is what `new Date(year, month, day)` formatted in local time gives
# wherever local midnight exists; a missing DTPOSTED formats `new Date(null)`,
# which is "1970-01-01" at UTC and east of it. A value xml2js leaves loosely typed
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
def Ofx.strip_dots(rev: String, +gt: Bool, +acc: String) -> String:
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
  Added{name, (9n + String.length(name) + Bool.pick(Nat,
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

def Ofx.added.text(m: Maybe<&2, Ofx.Added>, h: Char) -> String:
  match m:
    case None{}:
      SCon{h, SNil{}}
    case Some{Added{name, skip}}:
      "</" ++ name ++ ">"

def Ofx.added.skip(m: Maybe<&2, Ofx.Added>) -> Nat:
  match m:
    case None{}:
      0n
    case Some{Added{name, skip}}:
      skip

# `.replace(/<\/<added>(\w+?)>(<\/\1>)?/g, '</$1>')`: an added end tag
# becomes a real one and swallows the real one that follows it.
def Ofx.merge_ends(s: String, skip: Nat) -> String:
  match s skip:
    case SNil{} _:
      SNil{}
    case SCon{h, t} 1n+k:
      Ofx.merge_ends(t, k)
    case SCon{+h, +t} 0n:
      +m = Ofx.added(SCon{h, t})
      Ofx.added.text(m, h) ++ Ofx.merge_ends(t, Ofx.added.skip(m))

# `sgml2Xml`: every `&` escaped, the whitespace around tags and the dots in
# tag names removed, and an end tag given to every element that has text.
def Ofx.sgml_to_xml(sgml: String) -> String:
  Ofx.merge_ends(Ofx.add_ends(Ofx.strip_dots(String.reverse(
    Ofx.strip_after(Ofx.strip_before(X.Js.replace_all(sgml, "&", "&#038;")), False{})), False{}, SNil{}),
    None{}), 0n)

# Text
# ----

# `/(&amp;|&#038;)/g` to `&`, in one pass, so that neither feeds the other.
def Ofx.unamp(s: String, skip: Nat) -> String:
  match s skip:
    case SNil{} _:
      SNil{}
    case SCon{h, t} 1n+k:
      Ofx.unamp(t, k)
    case SCon{+h, +t} 0n:
      C.If(String, String.starts_with(SCon{h, t}, "&amp;"),
        u => SCon{'&', Ofx.unamp(t, 4n)},
        u => C.If(String, String.starts_with(SCon{h, t}, "&#038;"),
          v => SCon{'&', Ofx.unamp(t, 5n)},
          v => SCon{h, Ofx.unamp(t, 0n)}))

# `html2Plain`: the HTML escapes of `<`, `>`, `'`, `"` and `&` undone, in the
# TypeScript's order.
def Ofx.html_to_plain(value: String) -> String:
  Ofx.unamp(X.Js.replace_all(X.Js.replace_all(X.Js.replace_all(X.Js.replace_all(value,
    "&lt;", "<"), "&gt;", ">"), "&#39;", "'"), "&quot;", "\""), 0n)

# Dates
# -----

# `Math.trunc`.
def Ofx.trunc(n: N.Num) -> I.Int:
  match n:
    case N.Num{neg, num, den}:
      I.Int.make(neg, Nat.div(num, den))

# `Number(text.substring(from, from + len))`; None is NaN.
def Ofx.part(text: String, from: Nat, len: Nat) -> Maybe<&2, N.Num>:
  X.Js.number(String.take(String.drop(text, from), len))

# The year the Date constructor reads: 0 to 99 mean 1900 to 1999.
def Ofx.year(y: I.Int) -> I.Int:
  match y:
    case I.Int{False{}, +abs}:
      I.Int.from_nat(Bool.pick(Nat, Nat.is_le(abs, 99n), (abs + 1900n : Nat), abs))
    case other:
      other

# floor(m / 12), for a month index m.
def Ofx.month_years(m: I.Int) -> I.Int:
  match m:
    case I.Int{False{}, abs}:
      I.Int.from_nat(Nat.div(abs, 12n))
    case I.Int{True{}, abs}:
      I.Int.minus(Nat.div((abs + 11n : Nat), 12n))

# m modulo 12, from 0 to 11.
def Ofx.month_index(m: I.Int) -> Nat:
  match m:
    case I.Int{False{}, abs}:
      Nat.mod(abs, 12n)
    case I.Int{True{}, abs}:
      Nat.mod(Nat.sub(12n, Nat.mod(abs, 12n)), 12n)

# `yyyy-MM-dd` as date-fns writes it: a year before 1 is written as its
# distance from year 1, without a sign.
def Ofx.date.show(c: D.Civil) -> String:
  match c:
    case D.Civil{+year, month, day}:
      T.Text.pad_nat(Bool.pick(Nat, Nat.is_gt(year, 400000n), Nat.sub(year, 400000n), Nat.sub(400001n, year)), 4n)
        ++ "-" ++ T.Text.pad_nat(month, 2n) ++ "-" ++ T.Text.pad_nat(day, 2n)

# The day `total` days after the start of the year -398030 (the epoch moved
# back 1000 Gregorian cycles, so the arithmetic stays in the naturals); None
# outside the range of a JS Date, 100,000,000 days either side of 1970.
def Ofx.date.at(total: I.Int) -> Maybe<&2, String>:
  match total:
    case I.Int{False{}, +days}:
      Bool.pick(Maybe<&2, String>,
        Nat.is_ge(days, 46097000n) && Nat.is_le(days, 246097000n),
        Some{Ofx.date.show(D.Date.civil_from_days(days))}, None{})
    case other:
      None{}

# `new Date(year, month, day)` for integers, as `yyyy-MM-dd`: months and days
# out of range roll over.
def Ofx.date.make(y: I.Int, +m: I.Int, d: I.Int) -> Maybe<&2, String>:
  +year = Ofx.year(y)
  C.If(Maybe<&2, String>, Nat.is_le(I.Int.abs(year), 300000n),
    u => Ofx.date.at(I.Int.add(
      I.Int.from_nat(D.Date.days_from_civil(
        I.Int.abs(I.Int.add(I.Int.add(year, Ofx.month_years(m)), I.Int.from_nat(400000n))),
        1n+Ofx.month_index(m), 1n)),
      I.Int.sub(d, I.Int.from_nat(1n)))),
    u => None{})

# The day of a DTPOSTED value (`YYYYMMDD...`), as the TypeScript computes it
# with `new Date(Number(year), Number(month) - 1, Number(day))`; None where
# the Date is invalid and formatting it throws.
def Ofx.date(+posted: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    y : N.Num <- Ofx.part(posted, 0n, 4n)
    m0 : N.Num <- Ofx.part(posted, 4n, 2n)
    d : N.Num <- Ofx.part(posted, 6n, 2n)
    m : N.Num <- N.Num.sub(m0, N.Num.from_nat(1n))
    Ofx.date.make(Ofx.trunc(y), Ofx.trunc(m), Ofx.trunc(d))

# Transactions
# ------------

# `getAsArray`.
def Ofx.as_array(m: Maybe<&2, J.Json>) -> List<&2, J.Json>:
  match m:
    case None{}:
      Nil{}
    case Some{J.JArr{cells}}:
      J.Json.items(J.JArr{cells})
    case Some{other}:
      [other]

def Ofx.some(xs: List<&2, J.Json>) -> List<&2, Maybe<&2, J.Json>>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{Some{h}, Ofx.some(t)}

# The STMTTRN values of each statement response of a bank or credit card
# message set.
def Ofx.bank.each(rs: List<&2, J.Json>, +stmt: String) -> List<&2, J.Json>:
  match rs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      List.append(&2, J.Json,
        Ofx.as_array(X.Js.get(X.Js.get(X.Js.get(Some{h}, stmt), "BANKTRANLIST"), "STMTTRN")),
        Ofx.bank.each(t, stmt))

# `getBankStmtTrn` and `getCcStmtTrn`.
def Ofx.bank(ofx: Maybe<&2, J.Json>, msg: String, rs: String, stmt: String) -> List<&2, J.Json>:
  Ofx.bank.each(Ofx.as_array(X.Js.get(X.Js.get(ofx, msg), rs)), stmt)

# `t => t?.['STMTTRN']` under `flatMap`: an array is spread, a missing value
# stays as one undefined element.
def Ofx.inv.spread(ts: J.Json) -> List<&2, Maybe<&2, J.Json>>:
  match ts:
    case J.JArr{cells}:
      Ofx.inv.spread(cells)
    case J.JElem{+t, rest}:
      List.append(&2, Maybe<&2, J.Json>,
        Bool.pick(List<&2, Maybe<&2, J.Json>>, Maybe.is_some(&2, J.Json, X.Js.get(Some{t}, "STMTTRN")),
          Ofx.some(Ofx.as_array(X.Js.get(Some{t}, "STMTTRN"))), [None{}]),
        Ofx.inv.spread(rest))
    case other:
      Nil{}

# The transactions of one investment statement: INVBANKTRAN must be an
# array (several elements), since the TypeScript calls `flatMap` on it.
def Ofx.inv.one(tran: Maybe<&2, J.Json>) -> Result<&2, &2, String, List<&2, Maybe<&2, J.Json>>>:
  match tran:
    case None{}:
      Done{Nil{}}
    case Some{J.JArr{cells}}:
      Done{Ofx.inv.spread(cells)}
    case Some{other}:
      Fail{"tranList?.INVBANKTRAN?.flatMap is not a function"}

def Ofx.inv.join(
  h: Result<&2, &2, String, List<&2, Maybe<&2, J.Json>>>, t: Result<&2, &2, String, List<&2, Maybe<&2, J.Json>>>
) -> Result<&2, &2, String, List<&2, Maybe<&2, J.Json>>>:
  match h t:
    case Fail{e} _:
      Fail{e}
    case Done{xs} Fail{e}:
      Fail{e}
    case Done{xs} Done{ys}:
      Done{List.append(&2, Maybe<&2, J.Json>, xs, ys)}

# `getInvStmtTrn`.
def Ofx.inv(rs: List<&2, J.Json>) -> Result<&2, &2, String, List<&2, Maybe<&2, J.Json>>>:
  match rs:
    case Nil{}:
      Done{Nil{}}
    case Con{h, t}:
      Ofx.inv.join(
        Ofx.inv.one(X.Js.get(X.Js.get(X.Js.get(Some{h}, "INVSTMTRS"), "INVTRANLIST"), "INVBANKTRAN")),
        Ofx.inv(t))

# `getStmtTrn`: the transactions of the credit card message set when there
# is one, else of the investment one, else of the bank one.
def Ofx.statements(data: Maybe<&2, J.Json>) -> Result<&2, &2, String, List<&2, Maybe<&2, J.Json>>>:
  +ofx = X.Js.get(data, "OFX")
  C.If(Result<&2, &2, String, List<&2, Maybe<&2, J.Json>>>,
    Maybe.is_some(&2, J.Json, X.Js.get(ofx, "CREDITCARDMSGSRSV1")),
    u => Done{Ofx.some(Ofx.bank(ofx, "CREDITCARDMSGSRSV1", "CCSTMTTRNRS", "CCSTMTRS"))},
    u => C.If(Result<&2, &2, String, List<&2, Maybe<&2, J.Json>>>,
      Maybe.is_some(&2, J.Json, X.Js.get(ofx, "INVSTMTMSGSRSV1")),
      v => Ofx.inv(Ofx.as_array(X.Js.get(X.Js.get(ofx, "INVSTMTMSGSRSV1"), "INVSTMTTRNRS"))),
      v => Done{Ofx.some(Ofx.bank(ofx, "BANKMSGSRSV1", "STMTTRNRS", "STMTRS"))}))

# The day of a transaction from its DTPOSTED value.
def Ofx.posted(m: Maybe<&2, J.Json>) -> Result<&2, &2, String, String>:
  match m:
    case None{}:
      Done{"1970-01-01"}
    case Some{J.JStr{SNil{}}}:
      Done{"1970-01-01"}
    case Some{J.JStr{text}}:
      Maybe.default(&2, Result<&2, &2, String, String>,
        Maybe.map(&2, String, Result<&2, &2, String, String>, day => Done{day}, Ofx.date(text)),
        Fail{"Invalid time value"})
    case Some{other}:
      Fail{"dtPosted.substring is not a function"}

# `html2Plain(value)` for a value that may be missing or not a string.
def Ofx.plain(m: Maybe<&2, J.Json>) -> Result<&2, &2, String, Maybe<&2, String>>:
  match m:
    case None{}:
      Done{None{}}
    case Some{J.JStr{text}}:
      Done{Some{Ofx.html_to_plain(text)}}
    case Some{other}:
      Fail{"value?.replace is not a function"}

def Ofx.txn.make(
  amount: Maybe<&2, J.Json>, kind: Maybe<&2, J.Json>, fit_id: Maybe<&2, J.Json>,
  date: Result<&2, &2, String, String>, name: Result<&2, &2, String, Maybe<&2, String>>,
  memo: Result<&2, &2, String, Maybe<&2, String>>
) -> Result<&2, &2, String, Ofx.Txn>:
  match date name memo:
    case Fail{e} _ _:
      Fail{e}
    case Done{d} Fail{e} _:
      Fail{e}
    case Done{d} Done{n} Fail{e}:
      Fail{e}
    case Done{d} Done{n} Done{m}:
      Done{Txn{amount, kind, fit_id, d, n, m}}

# `mapOfxTransaction`.
def Ofx.txn(v: Maybe<&2, J.Json>) -> Result<&2, &2, String, Ofx.Txn>:
  match v:
    case None{}:
      Fail{"Cannot read properties of undefined (reading 'DTPOSTED')"}
    case Some{+j}:
      Ofx.txn.make(X.Js.get(Some{j}, "TRNAMT"), X.Js.get(Some{j}, "TRNTYPE"), X.Js.get(Some{j}, "FITID"),
        Ofx.posted(X.Js.get(Some{j}, "DTPOSTED")), Ofx.plain(X.Js.get(Some{j}, "NAME")),
        Ofx.plain(X.Js.get(Some{j}, "MEMO")))

def Ofx.txns.join(
  h: Result<&2, &2, String, Ofx.Txn>, t: Result<&2, &2, String, List<&2, Ofx.Txn>>
) -> Result<&2, &2, String, List<&2, Ofx.Txn>>:
  match h t:
    case Fail{e} _:
      Fail{e}
    case Done{x} Fail{e}:
      Fail{e}
    case Done{x} Done{xs}:
      Done{Con{x, xs}}

def Ofx.txns(vs: List<&2, Maybe<&2, J.Json>>) -> Result<&2, &2, String, List<&2, Ofx.Txn>>:
  match vs:
    case Nil{}:
      Done{Nil{}}
    case Con{h, t}:
      Ofx.txns.join(Ofx.txn(h), Ofx.txns(t))

# The file
# --------

# What follows `<OFX>` or `<OFX` + one whitespace + `>` at the head of s.
def Ofx.root.after(m: Maybe<&2, String>) -> Maybe<&2, String>:
  match m:
    case Some{SCon{'>', rest}}:
      Some{rest}
    case Some{SCon{Chr{x}, SCon{'>', rest}}}:
      Bool.pick(Maybe<&2, String>, X.Js.is_space(x), Some{rest}, None{})
    case other:
      None{}

type Ofx.Cut is Data:
  Cut{before: String, after: Maybe<&2, String>}

def Ofx.cut.put(h: Char, c: Ofx.Cut) -> Ofx.Cut:
  match c:
    case Cut{before, after}:
      Cut{SCon{h, before}, after}

# s split at the first `/<OFX\s?>/`: what is before it and, when it is
# there, what is after it.
def Ofx.cut(s: String) -> Ofx.Cut:
  match s:
    case SNil{}:
      Cut{SNil{}, None{}}
    case SCon{+h, +t}:
      +m = Ofx.root.after(X.Js.strip_prefix(SCon{h, t}, "<OFX"))
      C.If(Ofx.Cut, Maybe.is_some(&2, String, m),
        u => Cut{SNil{}, m},
        u => Ofx.cut.put(h, Ofx.cut(t)))

def Ofx.cut.before(c: Ofx.Cut) -> String:
  match c:
    case Cut{before, after}:
      before

# `split(/:/, 2)` of a header line, set on the headers object.
def Ofx.header(hs: List<&2, X.Js.Entry<Maybe<&2, String>>>, parts: List<&2, String>) -> List<&2, X.Js.Entry<Maybe<&2, String>>>:
  match parts:
    case Nil{}:
      hs
    case Con{key, Nil{}}:
      X.Js.set(Maybe<&2, String>, hs, key, None{})
    case Con{key, Con{value, rest}}:
      X.Js.set(Maybe<&2, String>, hs, key, Some{value})

def Ofx.headers(lines: List<&2, String>, hs: List<&2, X.Js.Entry<Maybe<&2, String>>>) -> List<&2, X.Js.Entry<Maybe<&2, String>>>:
  match lines:
    case Nil{}:
      hs
    case Con{SNil{}, rest}:
      Ofx.headers(rest, hs)
    case Con{line, rest}:
      Ofx.headers(rest, Ofx.header(hs, String.split(line, ':')))

def Ofx.finish(
  headers: List<&2, X.Js.Entry<Maybe<&2, String>>>, txns: Result<&2, &2, String, List<&2, Ofx.Txn>>
) -> Result<&2, &2, String, Ofx.Data>:
  match txns:
    case Fail{e}:
      Fail{e}
    case Done{list}:
      Done{Parsed{headers, list}}

def Ofx.map(
  headers: List<&2, X.Js.Entry<Maybe<&2, String>>>, vs: Result<&2, &2, String, List<&2, Maybe<&2, J.Json>>>
) -> Result<&2, &2, String, Ofx.Data>:
  match vs:
    case Fail{e}:
      Fail{e}
    case Done{list}:
      Ofx.finish(headers, Ofx.txns(list))

def Ofx.read(
  headers: List<&2, X.Js.Entry<Maybe<&2, String>>>, parsed: Result<&2, &2, String, Maybe<&2, J.Json>>
) -> Result<&2, &2, String, Ofx.Data>:
  match parsed:
    case Fail{e}:
      Fail{e}
    case Done{data}:
      Ofx.map(headers, Ofx.statements(data))

# The body parsed as XML, or, when that fails, as SGML made into XML.
def Ofx.body(+content: String, first: Result<&2, &2, String, Maybe<&2, J.Json>>) -> Result<&2, &2, String, Maybe<&2, J.Json>>:
  match first:
    case Done{data}:
      Done{data}
    case Fail{e}:
      M.Xml.parse(Ofx.sgml_to_xml(content), True{})

def Ofx.split(first: Ofx.Cut) -> Result<&2, &2, String, Ofx.Data>:
  match first:
    case Cut{before, None{}}:
      Ofx.read(Ofx.headers(X.Js.lines(before), Nil{}),
        Ofx.body("<OFX>undefined", M.Xml.parse("<OFX>undefined", True{})))
    case Cut{before, Some{rest}}:
      +content = "<OFX>" ++ Ofx.cut.before(Ofx.cut(rest))
      Ofx.read(Ofx.headers(X.Js.lines(before), Nil{}), Ofx.body(content, M.Xml.parse(content, True{})))

# `ofx2json(text)`: the headers and the transactions, or the message of the
# error the promise is rejected with.
def Ofx.parse(ofx: String) -> Result<&2, &2, String, Ofx.Data>:
  Ofx.split(Ofx.cut(ofx))

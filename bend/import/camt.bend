# Port of packages/loot-core/src/server/transactions/import/xmlcamt2json.ts:
# reads a CAMT.053 (ISO 20022) bank statement into transactions.
#
# Deviations: the file arrives decoded, as a String (`decodeXmlContent`
# stays outside). A rejected promise becomes a `Fail` carrying the error's
# message. Amounts are exact (`Num`), read as `Number` reads them (see
# `Js.number` for the few literals it cannot hold). What the TypeScript
# leaves loosely typed stays a `Json`: a date, a payee, a note or an id is a
# string in any well-formed statement, but an element with attributes or
# children arrives as an object and a repeated one as an array, exactly as
# xml2js builds them. `None` stands for both null and undefined.
import Base
import ../lib/core.bend as C
import ../lib/num.bend as N
import ../json/json.bend as J
import ./js.bend as X
import ./xml.bend as M

type Camt.Txn is Data:
  Txn{
    amount: N.Num, date: J.Json, payee_name: Maybe<&2, J.Json>, imported_payee: Maybe<&2, J.Json>,
    notes: Maybe<&2, J.Json>, imported_id: Maybe<&2, J.Json>
  }

def Camt.is_object(j: J.Json) -> Bool:
  match j:
    case J.JObj{cells}:
      True{}
    case J.JArr{cells}:
      True{}
    case other:
      False{}

# What a matching key adds: the elements of an array, or the value itself.
def Camt.spread(j: J.Json) -> List<&2, J.Json>:
  match j:
    case J.JArr{cells}:
      J.Json.items(J.JArr{cells})
    case other:
      [other]

# `findKeys`: every value under `key` at any depth, in the order JS walks
# the object; an array found under the key gives its elements and is then
# walked too.
def Camt.find_keys(obj: J.Json, +key: String) -> List<&2, J.Json>:
  match obj:
    case J.JObj{cells}:
      Camt.find_keys(cells, key)
    case J.JArr{cells}:
      Camt.find_keys(cells, key)
    case J.JPair{k, +v, rest}:
      List.concat(&2, J.Json, [
        Bool.pick(List<&2, J.Json>, String.eq(k, key), Camt.spread(v), Nil{}),
        C.If(List<&2, J.Json>, Camt.is_object(v), u => Camt.find_keys(v, key), u => Nil{}),
        Camt.find_keys(rest, key)])
    case J.JElem{+v, rest}:
      List.append(&2, J.Json,
        C.If(List<&2, J.Json>, Camt.is_object(v), u => Camt.find_keys(v, key), u => Nil{}),
        Camt.find_keys(rest, key))
    case other:
      Nil{}

def Camt.find(m: Maybe<&2, J.Json>, key: String) -> List<&2, J.Json>:
  match m:
    case None{}:
      Nil{}
    case Some{j}:
      Camt.find_keys(j, key)

# `getPayeeNameFromTxDtls`: the first name of the creditor for a debit, of
# the debtor for a credit.
def Camt.payee(details: Maybe<&2, J.Json>, is_debit: Bool) -> Maybe<&2, J.Json>:
  +parties = X.Js.get(details, "RltdPties")
  C.If(Maybe<&2, J.Json>, X.Js.truthy(parties),
    u => List.head(&2, J.Json, Camt.find(X.Js.get(parties, Bool.pick(String, is_debit, "Cdtr", "Dbtr")), "Nm")),
    u => None{})

def Camt.join(items: List<&2, J.Json>) -> String:
  String.join(X.Js.map(~J.Json, ~String, ~X.Js.to_string, items), " ")

def Camt.notes.of(ustrd: Maybe<&2, J.Json>) -> Maybe<&2, J.Json>:
  match ustrd:
    case Some{J.JArr{cells}}:
      Some{J.JStr{Camt.join(J.Json.items(J.JArr{cells}))}}
    case other:
      other

# `getNotesFromTxDtls`: the unstructured remittance information, several
# lines joined by spaces.
def Camt.notes(details: Maybe<&2, J.Json>) -> Maybe<&2, J.Json>:
  +info = X.Js.get(details, "RmtInf")
  C.If(Maybe<&2, J.Json>, X.Js.truthy(info),
    u => Camt.notes.of(X.Js.get(info, "Ustrd")),
    u => None{})

# `convertToNumberOrNull(amt?._)`: the text of an amount element that has
# attributes (its currency), as a number.
def Camt.amount(amt: Maybe<&2, J.Json>) -> Maybe<&2, N.Num>:
  Maybe.bind(&2, String, N.Num, X.Js.text(X.Js.get(amt, "_")), X.Js.number)

# `isDebit ? -amount : amount`: a missing amount negates to zero.
def Camt.signed(is_debit: Bool, amount: Maybe<&2, N.Num>) -> Maybe<&2, N.Num>:
  match is_debit amount:
    case True{} None{}:
      Some{N.Num.zero()}
    case True{} Some{n}:
      Some{N.Num.neg(n)}
    case False{} other:
      other

def Camt.slice(dt: Maybe<&2, J.Json>) -> Result<&2, &2, String, Maybe<&2, J.Json>>:
  match dt:
    case Some{J.JStr{text}}:
      Done{Some{J.JStr{String.take(text, 10n)}}}
    case Some{J.JArr{cells}}:
      Done{Some{J.Json.array(List.take(&2, J.Json, J.Json.items(J.JArr{cells}), 10n))}}
    case other:
      Fail{"Date.DtTm.slice is not a function"}

# `getDtOrDtTm`: the first ten characters of the date-time, or the date.
def Camt.date(d: Maybe<&2, J.Json>) -> Result<&2, &2, String, Maybe<&2, J.Json>>:
  match d:
    case None{}:
      Done{None{}}
    case Some{J.JStr{SNil{}}}:
      Done{None{}}
    case Some{J.JStr{text}}:
      Fail{"Cannot use 'in' operator to search for 'DtTm' in " ++ text}
    case Some{+j}:
      C.If(Result<&2, &2, String, Maybe<&2, J.Json>>, Maybe.is_some(&2, J.Json, X.Js.get(Some{j}, "DtTm")),
        u => Camt.slice(X.Js.get(Some{j}, "DtTm")),
        u => Done{X.Js.get(Some{j}, "Dt")})

# `getDtOrDtTm(entry.ValDt) || getDtOrDtTm(entry.BookgDt)`.
def Camt.dates(value: Result<&2, &2, String, Maybe<&2, J.Json>>, +entry: J.Json) -> Result<&2, &2, String, Maybe<&2, J.Json>>:
  match value:
    case Fail{e}:
      Fail{e}
    case Done{+d}:
      C.If(Result<&2, &2, String, Maybe<&2, J.Json>>, X.Js.truthy(d),
        u => Done{d},
        u => Camt.date(X.Js.get(Some{entry}, "BookgDt")))

# The transaction, unless its date or its amount is missing.
def Camt.keep(
  amount: Maybe<&2, N.Num>, date: Maybe<&2, J.Json>, +payee: Maybe<&2, J.Json>, notes: Maybe<&2, J.Json>,
  id: Maybe<&2, J.Json>
) -> List<&2, Camt.Txn>:
  match amount date:
    case Some{a} Some{d}:
      [Txn{a, d, payee, payee, notes, id}]
    case _ _:
      Nil{}

# The sub-transactions of an entry with several TxDtls, each with its own
# amount, payee and notes.
def Camt.subs(details: List<&2, J.Json>, +is_debit: Bool, +date: Maybe<&2, J.Json>) -> List<&2, Camt.Txn>:
  match details:
    case Nil{}:
      Nil{}
    case Con{+d, rest}:
      List.append(&2, Camt.Txn,
        Camt.keep(
          Camt.signed(is_debit, Maybe.bind(&2, J.Json, N.Num, List.head(&2, J.Json, Camt.find_keys(d, "Amt")),
            amt => Camt.amount(Some{amt}))),
          date, Camt.payee(Some{d}, is_debit), Camt.notes(Some{d}), None{}),
        Camt.subs(rest, is_debit, date))

# `a !== b` for a payee and the additional entry information: two strings
# differ by their text; anything else is the same only when the payee was
# taken from that very value (`same`).
def Camt.differs(info: Maybe<&2, J.Json>, payee: Maybe<&2, J.Json>, same: Bool) -> Bool:
  match info payee:
    case Some{J.JStr{a}} Some{J.JStr{b}}:
      Bool.not(String.eq(a, b))
    case _ _:
      Bool.not(same)

def Camt.has_text(items: List<&2, J.Json>, +text: String) -> Bool:
  match items:
    case Nil{}:
      False{}
    case Con{J.JStr{s}, rest}:
      String.eq(s, text) || Camt.has_text(rest, text)
    case Con{other, rest}:
      Camt.has_text(rest, text)

# `payee_name.includes(notes)`, for a truthy payee and truthy notes: text in
# a string, an element of an array; an object has no `includes`.
def Camt.includes(payee: Maybe<&2, J.Json>, notes: Maybe<&2, J.Json>) -> Result<&2, &2, String, Bool>:
  match payee notes:
    case Some{J.JStr{p}} Some{n}:
      Done{String.contains(p, X.Js.to_string(n))}
    case Some{J.JArr{cells}} Some{J.JStr{n}}:
      Done{Camt.has_text(J.Json.items(J.JArr{cells}), n)}
    case Some{J.JArr{cells}} _:
      Done{False{}}
    case _ _:
      Fail{"payee_name.includes is not a function"}

def Camt.single.fin(
  inc: Result<&2, &2, String, Bool>, amount: Maybe<&2, N.Num>, date: Maybe<&2, J.Json>,
  payee: Maybe<&2, J.Json>, notes: Maybe<&2, J.Json>, id: Maybe<&2, J.Json>
) -> Result<&2, &2, String, List<&2, Camt.Txn>>:
  match inc:
    case Fail{e}:
      Fail{e}
    case Done{inside}:
      Done{Camt.keep(amount, date, payee, Bool.pick(Maybe<&2, J.Json>, inside, None{}, notes), id)}

# An entry with one TxDtls, or none: the payee and the notes fall back on
# the additional entry information and the entry reference.
def Camt.single(
  +entry: J.Json, +details: Maybe<&2, J.Json>, +is_debit: Bool, amount: Maybe<&2, N.Num>, date: Maybe<&2, J.Json>
) -> Result<&2, &2, String, List<&2, Camt.Txn>>:
  +info = X.Js.get(Some{entry}, "AddtlNtryInf")
  +ref = X.Js.get(Some{entry}, "NtryRef")
  +id = X.Js.get(Some{entry}, "AcctSvcrRef")
  +named = Camt.payee(details, is_debit)
  +from_info = Bool.not(X.Js.truthy(named)) && X.Js.truthy(info)
  +payee = Bool.pick(Maybe<&2, J.Json>, from_info, info, named)
  +noted = Camt.notes(details)
  +notes1 = Bool.pick(Maybe<&2, J.Json>,
    Bool.not(X.Js.truthy(noted)) && X.Js.truthy(info) && Camt.differs(info, payee, from_info), info, noted)
  +notes2 = Bool.pick(Maybe<&2, J.Json>,
    Bool.not(X.Js.truthy(payee)) && Bool.not(X.Js.truthy(notes1)) && X.Js.truthy(ref), ref, notes1)
  Camt.single.fin(
    C.If(Result<&2, &2, String, Bool>, X.Js.truthy(payee) && X.Js.truthy(notes2),
      u => Camt.includes(payee, notes2), u => Done{False{}}),
    Camt.signed(is_debit, amount), date, payee, notes2,
    Bool.pick(Maybe<&2, J.Json>, X.Js.truthy(id), id, None{}))

def Camt.is_debit(m: Maybe<&2, J.Json>) -> Bool:
  match m:
    case Some{J.JStr{s}}:
      String.eq(s, "DBIT")
    case other:
      False{}

def Camt.entry.at(+entry: J.Json, date: Result<&2, &2, String, Maybe<&2, J.Json>>) -> Result<&2, &2, String, List<&2, Camt.Txn>>:
  match date:
    case Fail{e}:
      Fail{e}
    case Done{+d}:
      +details = X.Js.get(X.Js.get(Some{entry}, "NtryDtls"), "TxDtls")
      +is_debit = Camt.is_debit(X.Js.get(Some{entry}, "CdtDbtInd"))
      C.If(Result<&2, &2, String, List<&2, Camt.Txn>>, X.Js.is_array(details),
        u => Done{Camt.subs(Maybe.default(&2, List<&2, J.Json>, Maybe.map(&2, J.Json, List<&2, J.Json>, J.Json.items, details), Nil{}), is_debit, d)},
        u => Camt.single(entry, details, is_debit, Camt.amount(X.Js.get(Some{entry}, "Amt")), d))

# The transactions of one Ntry.
def Camt.entry(+entry: J.Json) -> Result<&2, &2, String, List<&2, Camt.Txn>>:
  Camt.entry.at(entry, Camt.dates(Camt.date(X.Js.get(Some{entry}, "ValDt")), entry))

def Camt.entries.join(
  h: Result<&2, &2, String, List<&2, Camt.Txn>>, t: Result<&2, &2, String, List<&2, Camt.Txn>>
) -> Result<&2, &2, String, List<&2, Camt.Txn>>:
  match h t:
    case Fail{e} _:
      Fail{e}
    case Done{xs} Fail{e}:
      Fail{e}
    case Done{xs} Done{ys}:
      Done{List.append(&2, Camt.Txn, xs, ys)}

def Camt.entries(entries: List<&2, J.Json>) -> Result<&2, &2, String, List<&2, Camt.Txn>>:
  match entries:
    case Nil{}:
      Done{Nil{}}
    case Con{h, t}:
      Camt.entries.join(Camt.entry(h), Camt.entries(t))

def Camt.read(parsed: Result<&2, &2, String, Maybe<&2, J.Json>>) -> Result<&2, &2, String, List<&2, Camt.Txn>>:
  match parsed:
    case Fail{e}:
      Fail{e}
    case Done{data}:
      Camt.entries(Camt.find(data, "Ntry"))

# `xmlCAMT2json(text)`: the transactions of every Ntry element that have a
# date and an amount, or the message of the error the promise is rejected
# with.
def Camt.parse(content: String) -> Result<&2, &2, String, List<&2, Camt.Txn>>:
  Camt.read(M.Xml.parse(content, False{}))

# Port of packages/loot-core/src/server/transactions/import/parse-file.ts:
# picks the parser by the file's extension and normalises what it answers
# into transactions with a payee, notes and an amount.
#
# Deviations: the file's content arrives as a String next to its path, so
# reading and decoding it (`fs.readFile`, `decodeCsvBytes` and the `encoding`
# option) stay outside. The `internal` text of an error is the message of
# the underlying error, where the TypeScript gives its stack trace (for CSV
# the two are the same). Amounts are exact (`Num`); an OFX amount with more
# than 14 digits is refused where JS would round it. Fields the TypeScript
# leaves loosely typed are `Json` values, strings in practice; `None` is
# null or undefined, and a missing `transactions` (OFX and CAMT failures) is
# `None` too.
import Base
import ../lib/core.bend as C
import ../lib/num.bend as N
import ../shared/util.bend as F
import ../json/json.bend as J
import ./js.bend as X
import ./qif.bend as Q
import ./csv.bend as V
import ./ofx.bend as O
import ./camt.bend as K

# `ParseFileOptions` without `encoding`. An empty delimiter means the
# default comma, as `options.delimiter || ','`.
type Parse.Options is Data:
  Options{
    has_header_row: Bool, delimiter: String, fallback_missing_payee_to_memo: Bool,
    swap_payee_and_memo: Bool, skip_start_lines: Nat, skip_end_lines: Nat, import_notes: Bool
  }

type Parse.Error is Data:
  Error{message: String, internal: String}

# A transaction: structured (QIF, OFX, CAMT), or a raw CSV record, an array
# of fields or, under a header row, an object.
type Parse.Txn is Data:
  Txn{
    amount: Maybe<&2, N.Num>, date: Maybe<&2, J.Json>, payee_name: Maybe<&2, J.Json>,
    imported_payee: Maybe<&2, J.Json>, notes: Maybe<&2, J.Json>, category: Maybe<&2, J.Json>,
    imported_id: Maybe<&2, J.Json>
  }
  Row{fields: List<&2, String>}
  Record{entries: List<&2, X.Js.Entry<String>>}

type Parse.Result is Data:
  Parsed{errors: List<&2, Parse.Error>, transactions: Maybe<&2, List<&2, Parse.Txn>>}

# `parseFile(path)` with no options.
def Parse.defaults() -> Parse.Options:
  Options{False{}, SNil{}, False{}, False{}, 0n, 0n, False{}}

# `value || null`.
def Parse.or_null(+m: Maybe<&2, J.Json>) -> Maybe<&2, J.Json>:
  Bool.pick(Maybe<&2, J.Json>, X.Js.truthy(m), m, None{})

# `payeeSource || (fallbackUsed ? memoSource : null)`.
def Parse.payee(source: Maybe<&2, J.Json>, fallback: Bool, memo: Maybe<&2, J.Json>) -> Maybe<&2, J.Json>:
  X.Js.or(source, Bool.pick(Maybe<&2, J.Json>, fallback, memo, None{}))

# `options.importNotes && !fallbackUsed ? memoSource || null : null`.
def Parse.notes(import_notes: Bool, fallback: Bool, memo: Maybe<&2, J.Json>) -> Maybe<&2, J.Json>:
  Bool.pick(Maybe<&2, J.Json>, import_notes && Bool.not(fallback), Parse.or_null(memo), None{})

def Parse.failed(message: String, internal: String) -> Parse.Result:
  Parsed{[Error{message, internal}], Some{Nil{}}}

# QIF
# ---

def Parse.qif.keep(
  amount: Maybe<&2, N.Num>, date: Maybe<&2, String>, +payee: Maybe<&2, J.Json>,
  category: Maybe<&2, J.Json>, notes: Maybe<&2, J.Json>
) -> List<&2, Parse.Txn>:
  match amount date:
    case Some{a} Some{d}:
      [Txn{Some{a}, Some{J.JStr{d}}, payee, payee, notes, category, None{}}]
    case _ _:
      Nil{}

# One QIF transaction, kept when it has a date and an amount.
def Parse.qif.one(t: Q.Qif.Txn, +swap: Bool, import_notes: Bool) -> List<&2, Parse.Txn>:
  match t:
    case Q.Txn{date, amount, number, +memo, address, cleared, category, subcategory, +payee, division}:
      +source = X.Js.str(Bool.pick(Maybe<&2, String>, swap, memo, payee))
      +other = X.Js.str(Bool.pick(Maybe<&2, String>, swap, payee, memo))
      +fallback = Bool.not(X.Js.truthy(source)) && swap
      Parse.qif.keep(Maybe.bind(&2, String, N.Num, amount, F.Util.loosely_parse_amount), date,
        Parse.payee(source, fallback, other),
        Parse.or_null(X.Js.or(X.Js.str(subcategory), X.Js.str(category))),
        Parse.notes(import_notes, fallback, other))

def Parse.qif.each(ts: List<&2, Q.Qif.Txn>, +swap: Bool, +import_notes: Bool) -> List<&2, Parse.Txn>:
  match ts:
    case Nil{}:
      Nil{}
    case Con{h, rest}:
      List.append(&2, Parse.Txn, Parse.qif.one(h, swap, import_notes), Parse.qif.each(rest, swap, import_notes))

def Parse.qif.read(r: Result<&2, &2, String, Q.Qif.Data>, options: Parse.Options) -> Parse.Result:
  match r options:
    case Fail{e} _:
      Parse.failed("Failed parsing: doesn't look like a valid QIF file.", e)
    case Done{Q.Parsed{df, kind, txns}} Options{header, delimiter, fallback, swap, start, end, import_notes}:
      Parsed{Nil{}, Some{Parse.qif.each(txns, swap, import_notes)}}

# `parseQIF`.
def Parse.qif(contents: String, options: Parse.Options) -> Parse.Result:
  Parse.qif.read(Q.Qif.parse(contents, None{}), options)

# OFX
# ---

def Parse.ofx.unwrap(+s: String) -> String:
  C.If(String, String.starts_with(s, "(") && String.ends_with(s, ")"),
    u => "-" ++ String.take(String.drop(s, 1n), Nat.sub(String.length(s), 2n)),
    u => s)

def Parse.ofx.has_dot(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{'.', t}:
      True{}
    case SCon{h, t}:
      Parse.ofx.has_dot(t)

# `s.replace(',', '.')`: the first comma only.
def Parse.ofx.comma(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{',', t}:
      SCon{'.', t}
    case SCon{h, t}:
      SCon{h, Parse.ofx.comma(t)}

# Only digits, points and hyphens, and of the points only the first.
def Parse.ofx.clean(s: String, +seen: Bool) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{'.', t}:
      Bool.pick(String, seen, SNil{}, ".") ++ Parse.ofx.clean(t, True{})
    case SCon{'-', t}:
      SCon{'-', Parse.ofx.clean(t, seen)}
    case SCon{Chr{+x}, t}:
      Bool.pick(String, X.Js.is_digit(x), SCon{Chr{x}, SNil{}}, SNil{}) ++ Parse.ofx.clean(t, seen)

def Parse.ofx.float(cleaned: String) -> Maybe<&2, N.Num>:
  match cleaned:
    case SNil{}:
      None{}
    case SCon{'-', SNil{}}:
      None{}
    case SCon{'.', SNil{}}:
      None{}
    case other:
      F.Util.parse_float(other)

def Parse.ofx.decimal(+s: String) -> String:
  Bool.pick(String, Parse.ofx.has_dot(s), s, Parse.ofx.comma(s))

# `parseOfxAmount`: an OFX amount, with parentheses for a negative one, a
# comma for the decimal mark, currency symbols or several points; None
# where it answers null.
def Parse.ofx.amount(amount: Maybe<&2, J.Json>) -> Maybe<&2, N.Num>:
  match amount:
    case Some{J.JStr{text}}:
      Parse.ofx.float(Parse.ofx.clean(Parse.ofx.decimal(Parse.ofx.unwrap(X.Js.trim(text))), False{}))
    case other:
      None{}

# The transactions, and the errors of the amounts that could not be read.
type Parse.Ofx is Data:
  Ofx{errors: List<&2, Parse.Error>, txns: List<&2, Parse.Txn>}

def Parse.ofx.put(error: List<&2, Parse.Error>, txn: Parse.Txn, rest: Parse.Ofx) -> Parse.Ofx:
  match rest:
    case Ofx{errors, txns}:
      Ofx{List.append(&2, Parse.Error, error, errors), Con{txn, txns}}

def Parse.ofx.error(parsed: Maybe<&2, N.Num>, +amount: Maybe<&2, J.Json>) -> List<&2, Parse.Error>:
  match parsed:
    case Some{n}:
      Nil{}
    case None{}:
      [Error{"Invalid amount format: " ++ X.Js.show(amount), "Failed to parse amount: " ++ X.Js.show(amount)}]

def Parse.ofx.one(t: O.Ofx.Txn, +swap: Bool, use_memo: Bool, import_notes: Bool) -> Parse.Txn:
  match t:
    case O.Txn{amount, kind, fit_id, date, +name, +memo}:
      +source = X.Js.str(Bool.pick(Maybe<&2, String>, swap, memo, name))
      +other = X.Js.str(Bool.pick(Maybe<&2, String>, swap, name, memo))
      +fallback = Bool.not(X.Js.truthy(source)) && use_memo
      +payee = Parse.payee(source, fallback, other)
      Txn{Some{Maybe.default(&2, N.Num, Parse.ofx.amount(amount), N.Num.zero())}, Some{J.JStr{date}},
        payee, payee, Parse.notes(import_notes, fallback, other), None{}, fit_id}

def Parse.ofx.amount_of(t: O.Ofx.Txn) -> Maybe<&2, J.Json>:
  match t:
    case O.Txn{amount, kind, fit_id, date, name, memo}:
      amount

def Parse.ofx.each(ts: List<&2, O.Ofx.Txn>, +swap: Bool, +use_memo: Bool, +import_notes: Bool) -> Parse.Ofx:
  match ts:
    case Nil{}:
      Ofx{Nil{}, Nil{}}
    case Con{+h, rest}:
      +amount = Parse.ofx.amount_of(h)
      Parse.ofx.put(Parse.ofx.error(Parse.ofx.amount(amount), amount),
        Parse.ofx.one(h, swap, use_memo, import_notes), Parse.ofx.each(rest, swap, use_memo, import_notes))

def Parse.ofx.done(r: Parse.Ofx) -> Parse.Result:
  match r:
    case Ofx{errors, txns}:
      Parsed{errors, Some{txns}}

def Parse.ofx.read(r: Result<&2, &2, String, O.Ofx.Data>, options: Parse.Options) -> Parse.Result:
  match r options:
    case Fail{e} _:
      Parsed{[Error{"Failed importing file", e}], None{}}
    case Done{O.Parsed{headers, txns}} Options{header, delimiter, fallback, swap, start, end, import_notes}:
      Parse.ofx.done(Parse.ofx.each(txns, swap, fallback, import_notes))

# `parseOFX`.
def Parse.ofx(contents: String, options: Parse.Options) -> Parse.Result:
  Parse.ofx.read(O.Ofx.parse(contents), options)

# CAMT
# ----

def Parse.camt.one(t: K.Camt.Txn, +swap: Bool, import_notes: Bool) -> Parse.Txn:
  match t:
    case K.Txn{amount, date, +payee_name, imported, +notes, id}:
      +source = Bool.pick(Maybe<&2, J.Json>, swap, notes, payee_name)
      +other = Bool.pick(Maybe<&2, J.Json>, swap, payee_name, notes)
      +fallback = Bool.not(X.Js.truthy(source)) && swap
      +payee = Parse.payee(source, fallback, other)
      Txn{Some{amount}, Some{date}, payee, payee, Parse.notes(import_notes, fallback, other), None{}, id}

def Parse.camt.each(ts: List<&2, K.Camt.Txn>, +swap: Bool, +import_notes: Bool) -> List<&2, Parse.Txn>:
  match ts:
    case Nil{}:
      Nil{}
    case Con{h, rest}:
      Con{Parse.camt.one(h, swap, import_notes), Parse.camt.each(rest, swap, import_notes)}

def Parse.camt.read(r: Result<&2, &2, String, List<&2, K.Camt.Txn>>, options: Parse.Options) -> Parse.Result:
  match r options:
    case Fail{e} _:
      Parsed{[Error{"Failed importing file", e}], None{}}
    case Done{txns} Options{header, delimiter, fallback, swap, start, end, import_notes}:
      Parsed{Nil{}, Some{Parse.camt.each(txns, swap, import_notes)}}

# `parseCAMT`.
def Parse.camt(contents: String, options: Parse.Options) -> Parse.Result:
  Parse.camt.read(K.Camt.parse(contents), options)

# CSV
# ---

def Parse.csv.record(r: V.Csv.Record) -> Parse.Txn:
  match r:
    case V.Row{fields}:
      Row{fields}
    case V.Object{entries}:
      Record{entries}

def Parse.csv.read(r: Result<&2, &2, String, List<&2, V.Csv.Record>>) -> Parse.Result:
  match r:
    case Fail{+e}:
      Parse.failed("Failed parsing: " ++ e, e)
    case Done{records}:
      Parsed{Nil{}, Some{X.Js.map(~V.Csv.Record, ~Parse.Txn, ~Parse.csv.record, records)}}

def Parse.csv.parse(contents: String, header: Bool, +delimiter: String) -> Parse.Result:
  Parse.csv.read(V.Csv.parse(contents,
    V.Csv.options(header, Bool.pick(String, String.is_empty(delimiter), ",", delimiter))))

# The lines between the skipped ones, joined again with `\r\n`.
def Parse.csv.skip(+lines: List<&2, String>, +start: Nat, +end: Nat, header: Bool, delimiter: String) -> Parse.Result:
  +count = List.length(&2, String, lines)
  C.If(Parse.Result, Nat.is_ge((start + end : Nat), count),
    u => Parse.failed("Cannot skip more lines than exist in the file",
      "Attempted to skip " ++ Nat.show(start) ++ " start + " ++ Nat.show(end) ++ " end lines from "
        ++ Nat.show(count) ++ " total lines"),
    u => Parse.csv.parse(String.join(
      List.take(&2, String, List.drop(&2, String, lines, start), Nat.sub(Nat.sub(count, end), start)), "\r\n"),
      header, delimiter))

# `parseCSV`: the records of the file, after dropping the lines to skip at
# its start and its end.
def Parse.csv(+contents: String, options: Parse.Options) -> Parse.Result:
  match options:
    case Options{+header, +delimiter, fallback, swap, +start, +end, import_notes}:
      C.If(Parse.Result, Nat.is_gt(start, 0n) || Nat.is_gt(end, 0n),
        u => Parse.csv.skip(X.Js.lines(contents), start, end, header, delimiter),
        u => Parse.csv.parse(contents, header, delimiter))

# Dispatch
# --------

# `/\.[^.]*$/`: the path from its last dot on.
def Parse.extension(path: String) -> Maybe<&2, String>:
  match path:
    case SNil{}:
      None{}
    case SCon{+h, +t}:
      Maybe.or(&2, String, Parse.extension(t),
        Bool.pick(Maybe<&2, String>, Char.is_eq(h, '.'), Some{SCon{h, t}}, None{}))

def Parse.dispatch(ext: Maybe<&2, String>, contents: String, options: Parse.Options) -> Parse.Result:
  match ext:
    case Some{".qif"}:
      Parse.qif(contents, options)
    case Some{".csv"}:
      Parse.csv(contents, options)
    case Some{".tsv"}:
      Parse.csv(contents, options)
    case Some{".ofx"}:
      Parse.ofx(contents, options)
    case Some{".qfx"}:
      Parse.ofx(contents, options)
    case Some{".xml"}:
      Parse.camt(contents, options)
    case other:
      Parse.failed("Invalid file type", "")

# `parseFile(filepath, options)`, given the file's content: the parser is
# chosen by the extension, in any letter case.
def Parse.file(filepath: String, contents: String, options: Parse.Options) -> Parse.Result:
  Parse.dispatch(Maybe.map(&2, String, String, String.to_lower, Parse.extension(filepath)), contents, options)

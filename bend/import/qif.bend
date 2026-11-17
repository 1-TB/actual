# Port of packages/loot-core/src/server/transactions/import/qif2json.ts: reads
# a QIF file into its transactions.
#
# Deviations: the thrown errors become a `Fail` carrying the error's message.
# A division amount is exact (`Num`), read as `parseFloat` reads plain
# decimals; `None` stands for NaN (an exponent is not read). A field the
# TypeScript leaves undefined is `None`.
import Base
import ../lib/core.bend as C
import ../lib/num.bend as N
import ../shared/util.bend as F
import ./js.bend as X

type Qif.Division is Data:
  Division{
    category: Maybe<&2, String>, subcategory: Maybe<&2, String>,
    description: Maybe<&2, String>, amount: Maybe<&2, N.Num>
  }

type Qif.Txn is Data:
  Txn{
    date: Maybe<&2, String>, amount: Maybe<&2, String>, number: Maybe<&2, String>,
    memo: Maybe<&2, String>, address: Maybe<&2, List<&2, String>>,
    cleared_status: Maybe<&2, String>, category: Maybe<&2, String>,
    subcategory: Maybe<&2, String>, payee: Maybe<&2, String>,
    division: Maybe<&2, List<&2, Qif.Division>>
  }

type Qif.Data is Data:
  Parsed{date_format: Maybe<&2, String>, kind: String, transactions: List<&2, Qif.Txn>}

# The parser's state between lines: a failure once one happened, the
# transaction and the division being filled, and the finished transactions,
# newest first.
type Qif.State is Data:
  State{err: Maybe<&2, String>, txn: Qif.Txn, div: Qif.Division, out: List<&2, Qif.Txn>}

def Qif.Txn.new() -> Qif.Txn:
  Txn{None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}}

def Qif.Division.new() -> Qif.Division:
  Division{None{}, None{}, None{}, None{}}

# Whether no field was set: `Object.keys(transaction).length === 0`.
def Qif.Txn.is_empty(t: Qif.Txn) -> Bool:
  match t:
    case Txn{d, a, n, m, ad, c, cat, sub, p, div}:
      Maybe.is_none(&2, String, d) && Maybe.is_none(&2, String, a) && Maybe.is_none(&2, String, n)
        && Maybe.is_none(&2, String, m) && Maybe.is_none(&2, List<&2, String>, ad)
        && Maybe.is_none(&2, String, c) && Maybe.is_none(&2, String, cat)
        && Maybe.is_none(&2, String, sub) && Maybe.is_none(&2, String, p)
        && Maybe.is_none(&2, List<&2, Qif.Division>, div)

# `text.split(':')`, as the first part and, when there is one, the second.
def Qif.parts(ps: List<&2, String>) -> String & Maybe<&2, String>:
  match ps:
    case Nil{}:
      (SNil{}, None{})
    case Con{a, Nil{}}:
      (a, None{})
    case Con{a, Con{b, rest}}:
      (a, Some{b})

# A category line: the subcategory changes only when the line names one.
def Qif.Txn.categorize(t: Qif.Txn, ps: String & Maybe<&2, String>) -> Qif.Txn:
  match t ps:
    case Txn{d, a, n, m, ad, c, cat, sub, p, div} Tuple{first, second}:
      Txn{d, a, n, m, ad, c, Some{first}, Maybe.or(&2, String, second, sub), p, div}

def Qif.Division.categorize(v: Qif.Division, ps: String & Maybe<&2, String>) -> Qif.Division:
  match v ps:
    case Division{cat, sub, desc, amt} Tuple{first, second}:
      Division{Some{first}, Maybe.or(&2, String, second, sub), desc, amt}

def Qif.Division.describe(v: Qif.Division, text: String) -> Qif.Division:
  match v:
    case Division{cat, sub, desc, amt}:
      Division{cat, sub, Some{text}, amt}

def Qif.Division.price(v: Qif.Division, text: String) -> Qif.Division:
  match v:
    case Division{cat, sub, desc, amt}:
      Division{cat, sub, desc, F.Util.parse_float(text)}

# Adds a finished division at the end of the transaction's list.
def Qif.Txn.divide(t: Qif.Txn, v: Qif.Division) -> Qif.Txn:
  match t:
    case Txn{d, a, n, m, ad, c, cat, sub, p, div}:
      Txn{d, a, n, m, ad, c, cat, sub, p,
        Some{List.append(&2, Qif.Division, Maybe.default(&2, List<&2, Qif.Division>, div, Nil{}), [v])}}

# Sets the field a detail code names: D date, T amount, N number, M memo,
# A one more address line, P payee, C cleared status.
def Qif.Txn.set(t: Qif.Txn, code: Char, text: String) -> Qif.Txn:
  match t code:
    case Txn{d, a, n, m, ad, c, cat, sub, p, div} 'D':
      Txn{Some{text}, a, n, m, ad, c, cat, sub, p, div}
    case Txn{d, a, n, m, ad, c, cat, sub, p, div} 'T':
      Txn{d, Some{text}, n, m, ad, c, cat, sub, p, div}
    case Txn{d, a, n, m, ad, c, cat, sub, p, div} 'N':
      Txn{d, a, Some{text}, m, ad, c, cat, sub, p, div}
    case Txn{d, a, n, m, ad, c, cat, sub, p, div} 'M':
      Txn{d, a, n, Some{text}, ad, c, cat, sub, p, div}
    case Txn{d, a, n, m, ad, c, cat, sub, p, div} 'A':
      Txn{d, a, n, m,
        Some{List.append(&2, String, Maybe.default(&2, List<&2, String>, ad, Nil{}), [text])},
        c, cat, sub, p, div}
    case Txn{d, a, n, m, ad, c, cat, sub, p, div} 'P':
      Txn{d, a, n, m, ad, c, cat, sub, Some{X.Js.replace_all(text, "&amp;", "&")}, div}
    case Txn{d, a, n, m, ad, c, cat, sub, p, div} 'C':
      Txn{d, a, n, m, ad, Some{text}, cat, sub, p, div}
    case other _:
      other

def Qif.fail(message: String) -> Qif.State:
  State{Some{message}, Qif.Txn.new(), Qif.Division.new(), Nil{}}

# One trimmed line applied to the state.
def Qif.line(st: Qif.State, line: String) -> Qif.State:
  match st line:
    case State{Some{e}, txn, div, out} _:
      State{Some{e}, txn, div, out}
    case State{None{}, txn, div, out} SCon{'^', SNil{}}:
      State{None{}, Qif.Txn.new(), div, Con{txn, out}}
    case State{None{}, txn, div, out} SCon{'L', text}:
      State{None{}, Qif.Txn.categorize(txn, Qif.parts(String.split(text, ':'))), div, out}
    case State{None{}, txn, div, out} SCon{'S', text}:
      State{None{}, txn, Qif.Division.categorize(div, Qif.parts(String.split(text, ':'))), out}
    case State{None{}, txn, div, out} SCon{'E', text}:
      State{None{}, txn, Qif.Division.describe(div, text), out}
    case State{None{}, txn, div, out} SCon{'$', text}:
      State{None{}, Qif.Txn.divide(txn, Qif.Division.price(div, text)), Qif.Division.new(), out}
    case State{None{}, txn, div, out} SCon{+code, text}:
      C.If(Qif.State, String.contains("DTNMAPC", SCon{code, SNil{}}),
        u => State{None{}, Qif.Txn.set(txn, code, text), div, out},
        u => Qif.fail("Unknown Detail Code: " ++ SCon{code, SNil{}}))
    case State{None{}, txn, div, out} SNil{}:
      Qif.fail("Unknown Detail Code: undefined")

def Qif.lines(lines: List<&2, String>, st: Qif.State) -> Qif.State:
  match lines:
    case Nil{}:
      st
    case Con{SNil{}, rest}:
      Qif.lines(rest, st)
    case Con{line, rest}:
      Qif.lines(rest, Qif.line(st, X.Js.trim(line)))

def Qif.has_dollar(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{'$', t}:
      True{}
    case SCon{h, t}:
      Qif.has_dollar(t)

def Qif.type.pick(here: Maybe<&2, String>, later: Maybe<&2, String>) -> Maybe<&2, String>:
  match here:
    case None{}:
      later
    case Some{+rest}:
      Bool.pick(Maybe<&2, String>, Qif.has_dollar(rest), later, Some{rest})

# The capture of `/!Type:([^$]*)$/`: what follows the first `!Type:` that no
# `$` comes after.
def Qif.type(s: String) -> Maybe<&2, String>:
  match s:
    case SNil{}:
      None{}
    case SCon{+h, +t}:
      Qif.type.pick(X.Js.strip_prefix(SCon{h, t}, "!Type:"), Qif.type(t))

def Qif.finish(date_format: Maybe<&2, String>, kind: String, st: Qif.State) -> Result<&2, &2, String, Qif.Data>:
  match st:
    case State{Some{e}, txn, div, out}:
      Fail{e}
    case State{None{}, +txn, div, +out}:
      Done{Parsed{date_format, kind, List.reverse(&2, Qif.Txn,
        Bool.pick(List<&2, Qif.Txn>, Qif.Txn.is_empty(txn), out, Con{txn, out}))}}

def Qif.begin(
  kind: Maybe<&2, String>, first: String, rest: List<&2, String>, date_format: Maybe<&2, String>
) -> Result<&2, &2, String, Qif.Data>:
  match kind:
    case None{}:
      Fail{"File does not appear to be a valid qif file: " ++ first}
    case Some{t}:
      Qif.finish(date_format, t,
        Qif.lines(rest, State{None{}, Qif.Txn.new(), Qif.Division.new(), Nil{}}))

def Qif.start(lines: List<&2, String>, date_format: Maybe<&2, String>) -> Result<&2, &2, String, Qif.Data>:
  match lines:
    case Nil{}:
      Fail{"Cannot read properties of undefined (reading 'trim')"}
    case Con{+first, rest}:
      Qif.begin(Qif.type(X.Js.trim(first)), first, rest, date_format)

# `qif2json(qif, { dateFormat })`: the file's type and its transactions, or
# the message of the error the TypeScript throws.
def Qif.parse(qif: String, date_format: Maybe<&2, String>) -> Result<&2, &2, String, Qif.Data>:
  Qif.start(List.filter(~String, ~(s => Bool.not(String.is_empty(s))), String.split(qif, '\n')), date_format)

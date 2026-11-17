# A CSV parser: a port of the `csv-parse` library (v7, `csv-parse/sync`) for
# the options packages/loot-core/src/server/transactions/import/parse-file.ts
# passes to it, and a few more: `columns` (a header row), `bom`, `delimiter`
# (any non-empty string), `quote`, `escape`, `ltrim`/`rtrim` (`trim` is
# both), `relax_column_count` and `skip_empty_lines`. The record delimiter is
# discovered as csv-parse discovers it: the first of `\r\n`, `\n` or `\r`
# met outside quotes ends every record.
#
# The library walks UTF-8 bytes and this walks code points, which reads the
# same records; the one place a byte shows is the "Invalid Closing Quote"
# message, which names the first byte of the offending character.
#
# Deviations: the thrown `CsvError` becomes a `Fail` with its message. The
# quote and the escape are single characters.
import Base
import ../lib/core.bend as C
import ../json/json.bend as J
import ./js.bend as X

type Csv.Options is Data:
  Options{
    columns: Bool, bom: Bool, delimiter: String,
    quote: Maybe<&2, Char>, escape: Maybe<&2, Char>,
    ltrim: Bool, rtrim: Bool, relax_column_count: Bool, skip_empty_lines: Bool
  }

# A record: its fields in order, or, under a header row, an object keyed by
# the column names, its entries in the order JS lists an object's keys.
type Csv.Record is Data:
  Row{fields: List<&2, String>}
  Object{entries: List<&2, X.Js.Entry<String>>}

type Csv.Columns is Data:
  NoHeader{}
  Pending{}
  Names{names: List<&2, String>}

# What one character does to the parser.
type Csv.Action is Data:
  DoSkip{}
  DoEscape{}
  DoOpen{}
  DoClose{rd: U32}
  DoBad{message: String}
  DoEmpty{skip: Nat}
  DoEndRecord{skip: Nat}
  DoEndField{skip: Nat}
  DoAppend{}

# The parser between characters. `skip` counts the characters of a matched
# delimiter still to pass over; `rd` is the record delimiter: 0 while not
# discovered, 1 for `\r\n`, 2 for `\n`, 3 for `\r`. The field, the record and
# the output are held newest first.
type Csv.State is Data:
  State{
    err: Maybe<&2, String>, skip: Nat,
    quoting: Bool, was_quoting: Bool, escaping: Bool, was_row_delimiter: Bool,
    lines: Nat, rd: U32, field: String, record: List<&2, String>,
    columns: Csv.Columns, count: Nat, expected: Nat, out: List<&2, Csv.Record>
  }

# The options parse-file.ts passes: `bom: true, quote: '"', trim: true,
# relax_column_count: true, skip_empty_lines: true`, the default escape, and
# the given header flag and delimiter.
def Csv.options(columns: Bool, delimiter: String) -> Csv.Options:
  Options{columns, True{}, delimiter, Some{'"'}, Some{'"'}, True{}, True{}, True{}, True{}}

def Csv.is(m: Maybe<&2, Char>, x: U32) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{Chr{q}}:
      U32.is_eq(q, x)

def Csv.same(a: Maybe<&2, Char>, b: Maybe<&2, Char>) -> Bool:
  match a b:
    case Some{Chr{x}} Some{Chr{y}}:
      U32.is_eq(x, y)
    case _ _:
      False{}

# The code of the first character, 0 at the end of the text.
def Csv.head(s: String) -> U32:
  match s:
    case SNil{}:
      0
    case SCon{Chr{x}, t}:
      x

# The record delimiter s starts with: 1 `\r\n`, 2 `\n`, 3 `\r`, 0 none.
def Csv.discover(s: String) -> U32:
  match s:
    case SCon{'\r', SCon{'\n', t}}:
      1
    case SCon{'\n', t}:
      2
    case SCon{'\r', t}:
      3
    case other:
      0

# The length of the record delimiter `rd` when s starts with it, else 0.
def Csv.rd_len(rd: U32, s: String) -> Nat:
  match rd s:
    case 1 SCon{'\r', SCon{'\n', t}}:
      2n
    case 2 SCon{'\n', t}:
      1n
    case 3 SCon{'\r', t}:
      1n
    case _ other:
      0n

def Csv.delim_len(+delimiter: String, s: String) -> Nat:
  Bool.pick(Nat, String.starts_with(s, delimiter), String.length(delimiter), 0n)

# The first UTF-8 byte of a code point, as the character of that code.
def Csv.first_byte(+x: U32) -> String:
  SCon{Chr{Maybe.default(&2, U32, List.head(&2, U32, [
    Bool.pick(U32, (x < 128 : U32), x,
      Bool.pick(U32, (x < 2048 : U32), (192 .|. (x >> 6n) : U32),
        Bool.pick(U32, (x < 65536 : U32), (224 .|. (x >> 12n) : U32), (240 .|. (x >> 18n) : U32))))]), 0)},
    SNil{}}

# `JSON.stringify(info.column)`: the name of the column the field would
# fill, `null` past the last one, or the field's index without a header.
def Csv.column(columns: Csv.Columns, +index: Nat) -> String:
  match columns:
    case Names{names}:
      Maybe.default(&2, String,
        Maybe.map(&2, String, String, J.Json.quote, List.get(&2, String, names, index)), "null")
    case other:
      Nat.show(index)

def Csv.bad_opening(columns: Csv.Columns, record: List<&2, String>, +lines: Nat, field: String) -> Csv.Action:
  +value = String.reverse(field)
  DoBad{"Invalid Opening Quote: a quote is found on field "
    ++ Csv.column(columns, List.length(&2, String, record)) ++ " at line " ++ Nat.show(lines)
    ++ ", value is " ++ J.Json.quote(value)
    ++ Bool.pick(String, String.eq(value, SCon{Chr{65279}, SNil{}}), " (utf8 bom)", "")}

# The characters that do not open, close or delimit anything: kept in the
# field, or trimmed away, or refused after a closing quote. csv-parse walks
# bytes and, after a closing quote, steps over only the first byte of a
# trimable character unless it is trimming the left of an empty field, so a
# multi-byte space there (a no-break space, say) is refused too.
def Csv.tail(ltrim: Bool, +rtrim: Bool, quoting: Bool, was_quoting: Bool, field_empty: Bool, +x: U32, +lines: Nat) -> Csv.Action:
  +space = X.Js.is_space(x)
  +lappend = Bool.not(ltrim) || quoting || Bool.not(field_empty) || Bool.not(space)
  C.If(Csv.Action, lappend && (Bool.not(rtrim) || Bool.not(was_quoting)),
    u => DoAppend{},
    u => C.If(Csv.Action, (rtrim && Bool.not(space)) || (lappend && (x >= 128 : U32)),
      v => DoBad{"Invalid Closing Quote: found non trimable byte after quote at line " ++ Nat.show(lines)},
      v => DoSkip{}))

# Outside quotes: a record delimiter, a field delimiter, or `Csv.tail`.
def Csv.plain(
  +cfg: Csv.Options, +x: U32, +t: String, +was_quoting: Bool, +rd: U32,
  +field_empty: Bool, record_empty: Bool, +lines: Nat
) -> Csv.Action:
  match cfg:
    case Options{columns, bom, +delimiter, quote, escape, +ltrim, +rtrim, relax, +skip_empty}:
      +n = Csv.rd_len(rd, SCon{Chr{x}, t})
      +m = Csv.delim_len(delimiter, SCon{Chr{x}, t})
      +blank = skip_empty && Bool.not(was_quoting) && record_empty && field_empty
      C.If(Csv.Action, Nat.is_ne(n, 0n),
        u => Bool.pick(Csv.Action, blank, DoEmpty{Nat.sub(n, 1n)}, DoEndRecord{Nat.sub(n, 1n)}),
        u => C.If(Csv.Action, Nat.is_ne(m, 0n),
          v => DoEndField{Nat.sub(m, 1n)},
          v => Csv.tail(ltrim, rtrim, False{}, was_quoting, field_empty, x, lines)))

# A quote character: it closes the quoted field when a delimiter, a record
# delimiter, a trimable character or the end follows, and opens one only at
# the start of a field.
def Csv.quote(
  +cfg: Csv.Options, +t: String, quoting: Bool, +rd: U32,
  +field: String, +record: List<&2, String>, +columns: Csv.Columns, +lines: Nat
) -> Csv.Action:
  match cfg quoting:
    case Options{c, bom, +delimiter, quote, escape, ltrim, +rtrim, relax, skip_empty} True{}:
      +next = Csv.head(t)
      +rd2 = Bool.pick(U32, U32.is_zero(rd), Csv.discover(t), rd)
      C.If(Csv.Action,
        U32.is_zero(next) || Nat.is_ne(Csv.delim_len(delimiter, t), 0n)
          || Nat.is_ne(Csv.rd_len(rd2, t), 0n) || (rtrim && X.Js.is_space(next)),
        u => DoClose{rd2},
        u => DoBad{"Invalid Closing Quote: got \"" ++ Csv.first_byte(next) ++ "\" at line " ++ Nat.show(lines)
          ++ " instead of delimiter, record delimiter, trimable character (if activated) or comment"})
    case other False{}:
      C.If(Csv.Action, String.is_empty(field),
        u => DoOpen{},
        u => Csv.bad_opening(columns, record, lines, field))

# What the character x, followed by t, does.
def Csv.decide(
  +cfg: Csv.Options, +x: U32, +t: String, +quoting: Bool, +was_quoting: Bool, escaping: Bool, +rd: U32,
  +field: String, +record: List<&2, String>, +columns: Csv.Columns, +lines: Nat
) -> Csv.Action:
  match cfg escaping:
    case Options{c, bom, delimiter, quote, escape, +ltrim, +rtrim, relax, skip_empty} True{}:
      Csv.tail(ltrim, rtrim, quoting, was_quoting, String.is_empty(field), x, lines)
    case Options{c, bom, delimiter, +quote, +escape, +ltrim, +rtrim, relax, skip_empty} False{}:
      C.If(Csv.Action,
        quoting && Csv.is(escape, x) && Bool.not(String.is_empty(t))
          && (Bool.not(Csv.same(escape, quote)) || Csv.is(quote, Csv.head(t))),
        u => DoEscape{},
        u => C.If(Csv.Action, Csv.is(quote, x),
          v => Csv.quote(cfg, t, quoting, rd, field, record, columns, lines),
          v => C.If(Csv.Action, quoting,
            w => Csv.tail(ltrim, rtrim, True{}, was_quoting, String.is_empty(field), x, lines),
            w => Csv.plain(cfg, x, t, was_quoting, rd, String.is_empty(field),
              List.is_empty(&2, String, record), lines))))

# The field is finished: trimmed on the right unless it was quoted, and
# added to the record.
def Csv.end_field(rtrim: Bool, st: Csv.State) -> Csv.State:
  match st:
    case State{err, skip, q, +wq, esc, wr, lines, rd, +field, record, columns, count, expected, out}:
      State{err, skip, q, False{}, esc, wr, lines, rd, SNil{},
        Con{String.reverse(Bool.pick(String, rtrim && Bool.not(wq), X.Js.trim_start(field), field)), record},
        columns, count, expected, out}

# The object of a record under a header: each field under its column's name,
# fields past the last column dropped.
def Csv.object(names: List<&2, String>, fields: List<&2, String>, acc: List<&2, X.Js.Entry<String>>) -> List<&2, X.Js.Entry<String>>:
  match names fields:
    case Con{n, nt} Con{f, ft}:
      Csv.object(nt, ft, X.Js.set(String, acc, n, f))
    case _ _:
      acc

def Csv.length_error(named: Bool, +expected: Nat, +got: Nat, +lines: Nat) -> String:
  "Invalid Record Length: " ++ Bool.pick(String, named, "columns length is ", "expect ")
    ++ Nat.show(expected) ++ ", got " ++ Nat.show(got) ++ " on line " ++ Nat.show(lines)

# A record that is not the header: checked against the expected length
# unless that is relaxed, then emitted.
def Csv.emit(
  relax: Bool, named: Bool, +expected: Nat, +fields: List<&2, String>, +lines: Nat, record: Csv.Record
) -> Maybe<&2, String> & Csv.Record:
  (Bool.pick(Maybe<&2, String>,
    relax || Nat.is_eq(List.length(&2, String, fields), expected), None{},
    Some{Csv.length_error(named, expected, List.length(&2, String, fields), lines)}), record)

def Csv.push(st: Csv.State, +expected: Nat, r: Maybe<&2, String> & Csv.Record) -> Csv.State:
  match st r:
    case State{err, skip, q, wq, esc, wr, lines, rd, field, record, columns, count, old, out} Tuple{None{}, rec}:
      State{None{}, skip, q, wq, esc, wr, lines, rd, field, Nil{}, columns, 1n+count, expected, Con{rec, out}}
    case State{err, skip, q, wq, esc, wr, lines, rd, field, record, columns, count, old, out} Tuple{Some{e}, rec}:
      State{Some{e}, skip, q, wq, esc, wr, lines, rd, field, Nil{}, columns, count, expected, out}

# The record is finished: the header row names the columns, any other
# record is emitted.
def Csv.end_record(relax: Bool, st: Csv.State) -> Csv.State:
  match st:
    case State{err, skip, q, wq, esc, wr, lines, rd, field, +record, Pending{}, count, expected, out}:
      State{err, skip, q, wq, esc, wr, lines, rd, field, Nil{},
        Names{List.reverse(&2, String, record)}, count, List.length(&2, String, record), out}
    case State{err, skip, q, wq, esc, wr, +lines, rd, field, record, NoHeader{}, +count, +expected, out}:
      +fields = List.reverse(&2, String, record)
      +want = Bool.pick(Nat, Nat.is_eq(count, 0n), List.length(&2, String, fields), expected)
      Csv.push(State{err, skip, q, wq, esc, wr, lines, rd, field, Nil{}, NoHeader{}, count, expected, out},
        want, Csv.emit(relax, False{}, want, fields, lines, Row{fields}))
    case State{err, skip, q, wq, esc, wr, +lines, rd, field, record, Names{+names}, count, +expected, out}:
      +fields = List.reverse(&2, String, record)
      Csv.push(State{err, skip, q, wq, esc, wr, lines, rd, field, Nil{}, Names{names}, count, expected, out},
        expected, Csv.emit(relax, True{}, expected, fields, lines, Object{Csv.object(names, fields, Nil{})}))

def Csv.skipping(st: Csv.State, n: Nat) -> Csv.State:
  match st:
    case State{err, skip, q, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}:
      State{err, n, q, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}

def Csv.apply(rtrim: Bool, relax: Bool, action: Csv.Action, st: Csv.State, c: Char) -> Csv.State:
  match action st:
    case DoSkip{} other:
      other
    case DoEscape{} State{err, skip, q, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}:
      State{err, skip, q, wq, True{}, wr, lines, rd, field, record, columns, count, expected, out}
    case DoOpen{} State{err, skip, q, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}:
      State{err, skip, True{}, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}
    case DoClose{rd2} State{err, skip, q, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}:
      State{err, skip, False{}, True{}, esc, wr, lines, rd2, field, record, columns, count, expected, out}
    case DoBad{message} State{err, skip, q, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}:
      State{Some{message}, skip, q, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}
    case DoEmpty{n} other:
      Csv.skipping(other, n)
    case DoEndField{n} other:
      Csv.skipping(Csv.end_field(rtrim, other), n)
    case DoEndRecord{n} other:
      Csv.skipping(Csv.end_record(relax, Csv.end_field(rtrim, other)), n)
    case DoAppend{} State{err, skip, q, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}:
      State{err, skip, q, wq, esc, wr, lines, rd, SCon{c, field}, record, columns, count, expected, out}

# One character, followed by t.
def Csv.step(+cfg: Csv.Options, st: Csv.State, +x: U32, +t: String) -> Csv.State:
  match cfg st:
    case _ State{Some{e}, skip, q, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}:
      State{Some{e}, skip, q, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}
    case _ State{None{}, 1n+k, q, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}:
      State{None{}, k, q, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}
    case Options{c, bom, d, qu, es, lt, +rtrim, +relax, se} State{None{}, 0n, +q, +wq, esc, wr, lines, +rd, +field, +record, +columns, count, expected, out}:
      +lines1 = (lines + Bool.pick(Nat, wr, 1n, 0n) : Nat)
      +rd1 = Bool.pick(U32, Bool.not(q) && U32.is_zero(rd), Csv.discover(SCon{Chr{x}, t}), rd)
      Csv.apply(rtrim, relax,
        Csv.decide(cfg, x, t, q, wq, esc, rd1, field, record, columns, lines1),
        State{None{}, 0n, q, wq, False{}, U32.is_eq(x, 13) || U32.is_eq(x, 10), lines1, rd1, field, record,
          columns, count, expected, out},
        Chr{x})

def Csv.run(s: String, +cfg: Csv.Options, st: Csv.State) -> Csv.State:
  match s:
    case SNil{}:
      st
    case SCon{Chr{x}, +t}:
      Csv.run(t, cfg, Csv.step(cfg, st, x, t))

def Csv.result(st: Csv.State) -> Result<&2, &2, String, List<&2, Csv.Record>>:
  match st:
    case State{Some{e}, skip, q, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}:
      Fail{e}
    case State{None{}, skip, q, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}:
      Done{List.reverse(&2, Csv.Record, out)}

# The end of the input: an open quote is an error, and a last line without
# a record delimiter is a record when it holds anything.
def Csv.finish(cfg: Csv.Options, st: Csv.State) -> Result<&2, &2, String, List<&2, Csv.Record>>:
  match cfg st:
    case _ State{Some{e}, skip, q, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}:
      Fail{e}
    case _ State{None{}, skip, True{}, wq, esc, wr, lines, rd, field, record, columns, count, expected, out}:
      Fail{"Quote Not Closed: the parsing is finished with an opening quote at line " ++ Nat.show(lines)}
    case Options{c, bom, d, qu, es, lt, rtrim, relax, se} State{None{}, skip, False{}, +wq, esc, wr, lines, rd, +field, +record, columns, count, expected, out}:
      pending = wq || Bool.not(List.is_empty(&2, String, record)) || Bool.not(String.is_empty(field))
      +st1 = {State{None{}, skip, False{}, wq, esc, wr, lines, rd, field, record, columns, count, expected, out} : Csv.State}
      Csv.result(Bool.pick(Csv.State, pending, Csv.end_record(relax, Csv.end_field(rtrim, st1)), st1))

def Csv.strip_bom(bom: Bool, s: String) -> String:
  match bom s:
    case True{} SCon{Chr{65279}, t}:
      t
    case _ other:
      other

def Csv.start(cfg: Csv.Options) -> Csv.State:
  match cfg:
    case Options{columns, bom, d, qu, es, lt, rt, relax, se}:
      State{None{}, 0n, False{}, False{}, False{}, False{}, 1n, 0, SNil{}, Nil{},
        Bool.pick(Csv.Columns, columns, Pending{}, NoHeader{}), 0n, 0n, Nil{}}

def Csv.bom(cfg: Csv.Options) -> Bool:
  match cfg:
    case Options{columns, bom, d, qu, es, lt, rt, relax, se}:
      bom

# `parse(text, options)` of `csv-parse/sync`: the records, or the message of
# the error it throws.
def Csv.parse(text: String, +cfg: Csv.Options) -> Result<&2, &2, String, List<&2, Csv.Record>>:
  Csv.finish(cfg, Csv.run(Csv.strip_bom(Csv.bom(cfg), text), cfg, Csv.start(cfg)))

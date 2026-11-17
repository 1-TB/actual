# Port of packages/loot-core/src/shared/months.ts: month and day arithmetic on
# `yyyy`, `yyyy-MM` and `yyyy-MM-dd` strings.
#
# Deviations from the TypeScript:
# - A parsed date is a count of days since 1970-01-01 (lib/date.bend), not a
#   JS `Date` at local noon. The original pins every date to 12:00 local time
#   so that calendar maths never crosses a day, which is what a day count is.
#   A caller holding a `Date` passes its local day as `Date.iso_date(days)`,
#   or uses `Months.format_days`.
# - Where date-fns throws (an unparsable string, a format token it rejects) the
#   def answers `None`. Dates before 1970 and past the JS limit (day 10^8)
#   answer `None` too. Comparisons answer False for an invalid date, as JS.
# - `n: number` arguments are `Int` (lib/int.bend); fractions are not modelled.
# - The clock readers (`current_month`, `current_day`, ...) take `now`: the
#   local wall-clock time in milliseconds since 1970 (UTC millis plus the zone
#   offset). The `IS_TESTING` branch of the original, which pins the clock to
#   2017-01-01, is the caller passing that day.
# - `firstDayOfWeekIdx` (a string preference, '0' to '6') is a Nat, 0 = Sunday.
# - `format` knows the English (en-US) names only, and the tokens listed above
#   `Months.format`. `memoizeOne` is dropped: the defs are pure.
# - The `get*Regex` defs answer the source of the RegExp the original builds;
#   `Months.regex_test` runs such a source (see there for the subset).
import Base
import ../lib/core.bend as C
import ../lib/text.bend as T
import ../lib/date.bend as D
import ../lib/int.bend as I

# ---------------------------------------------------------------------------
# Day counts and month indexes

# Some{days} when a JS Date can hold the day.
def Months.valid(+days: Nat) -> Maybe<&2, Nat>:
  Bool.pick(Maybe<&2, Nat>, Nat.is_lt(days, 100000000n), Some{days}, None{})

def Months.to_nat(i: I.Int) -> Maybe<&2, Nat>:
  match i:
    case I.Int{False{}, abs}:
      Some{abs}
    case I.Int{True{}, abs}:
      None{}

def Months.civil.index(c: D.Civil) -> Nat:
  match c:
    case D.Civil{year, month, day}:
      Nat.sub((year * 12n + month : Nat), 1n)

def Months.civil.day(c: D.Civil) -> Nat:
  match c:
    case D.Civil{year, month, day}:
      day

def Months.civil.year(c: D.Civil) -> Nat:
  match c:
    case D.Civil{year, month, day}:
      year

# The month of a day as one number: year * 12 + month - 1.
def Months.index(days: Nat) -> Nat:
  Months.civil.index(D.Date.civil_from_days(days))

def Months.day_of_month(days: Nat) -> Nat:
  Months.civil.day(D.Date.civil_from_days(days))

def Months.year_of(days: Nat) -> Nat:
  Months.civil.year(D.Date.civil_from_days(days))

# The first day of a month index.
def Months.month_start(+mi: Nat) -> Nat:
  D.Date.days_from_civil(Nat.div(mi, 12n), (Nat.mod(mi, 12n) + 1n : Nat), 1n)

def Months.month_length(+mi: Nat) -> Nat:
  D.Date.days_in_month(Nat.div(mi, 12n), (Nat.mod(mi, 12n) + 1n : Nat))

# A day of a month, held back to the month's last day as date-fns `addMonths`.
def Months.at_day(+mi: Nat, day: Nat) -> Nat:
  Nat.sub((Months.month_start(mi) + Nat.min(day, Months.month_length(mi)) : Nat), 1n)

# A day of a month, running over into the next months as JS `setMonth`.
def Months.at_day_js(mi: Nat, day: Nat) -> Nat:
  Nat.sub((Months.month_start(mi) + day : Nat), 1n)

# Some{mi} for a month from January 1970 on.
def Months.epoch_index(+mi: Nat) -> Maybe<&2, Nat>:
  Bool.pick(Maybe<&2, Nat>, Nat.is_ge(mi, 23640n), Some{mi}, None{})

def Months.small(+i: I.Int) -> Maybe<&2, I.Int>:
  Bool.pick(Maybe<&2, I.Int>, Nat.is_le(I.Int.abs(i), 200000000n), Some{i}, None{})

# JS reads the years 0 to 99 as 1900 to 1999.
def Months.js_year(+y: I.Int) -> I.Int:
  Bool.pick(I.Int, Bool.and(Bool.not(I.Int.is_neg(y)), Nat.is_lt(I.Int.abs(y), 100n)),
    I.Int.add(y, I.Int.from_nat(1900n)), y)

# The day of JS `new Date(year, month - 1, day)`: months and days outside
# their range roll over.
def Months.civil(y: I.Int, m: I.Int, d: I.Int) -> Maybe<&2, Nat>:
  do Maybe<&2, Nat>:
    y1 : I.Int <- Months.small(y)
    m1 : I.Int <- Months.small(m)
    d1 : I.Int <- Months.small(d)
    i : Nat <- Months.to_nat(I.Int.add(I.Int.mul(Months.js_year(y1), I.Int.from_nat(12n)),
      I.Int.sub(m1, I.Int.from_nat(1n))))
    mi : Nat <- Months.epoch_index(i)
    days : Nat <- Months.to_nat(I.Int.add(I.Int.from_nat(Months.month_start(mi)),
      I.Int.sub(d1, I.Int.from_nat(1n))))
    Months.valid(days)

# ---------------------------------------------------------------------------
# Parsing

# The leading run of decimal digits.
def Months.digit_run(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{+h, t}:
      C.If(String, Char.is_digit(h), u => SCon{h, Months.digit_run(t)}, u => SNil{})

def Months.read_run(run: String) -> Maybe<&2, Nat>:
  match run:
    case SNil{}:
      None{}
    case other:
      Nat.read(other)

def Months.parse_int.signed(s: String) -> Maybe<&2, I.Int>:
  match s:
    case SCon{'-', t}:
      Maybe.map(&2, Nat, I.Int, I.Int.minus, Months.read_run(Months.digit_run(t)))
    case SCon{'+', t}:
      Maybe.map(&2, Nat, I.Int, I.Int.from_nat, Months.read_run(Months.digit_run(t)))
    case t:
      Maybe.map(&2, Nat, I.Int, I.Int.from_nat, Months.read_run(Months.digit_run(t)))

# JS `parseInt(s)`: leading space, a sign and a run of digits; None for NaN.
def Months.parse_int(s: String) -> Maybe<&2, I.Int>:
  Months.parse_int.signed(String.trim_start(s))

def Months.parse.parts(ps: List<&2, String>) -> Maybe<&2, Nat>:
  match ps:
    case Nil{}:
      None{}
    case Con{y, Nil{}}:
      do Maybe<&2, Nat>:
        yi : I.Int <- Months.parse_int(y)
        Months.civil(yi, I.Int.from_nat(1n), I.Int.from_nat(1n))
    case Con{y, Con{m, Nil{}}}:
      do Maybe<&2, Nat>:
        yi : I.Int <- Months.parse_int(y)
        mi : I.Int <- Months.parse_int(m)
        Months.civil(yi, mi, I.Int.from_nat(1n))
    case Con{y, Con{m, Con{d, rest}}}:
      do Maybe<&2, Nat>:
        yi : I.Int <- Months.parse_int(y)
        mi : I.Int <- Months.parse_int(m)
        di : I.Int <- Months.parse_int(d)
        Months.civil(yi, mi, di)

# `_parse` / `parseDate`: the day of a `yyyy`, `yyyy-MM` or `yyyy-MM-dd`
# string. As the original, each part goes through `parseInt` and a month or a
# day outside its range rolls over ('2020-13' is January 2021).
def Months.parse(value: String) -> Maybe<&2, Nat>:
  Months.parse.parts(String.split(value, '-'))

def Months.parse_date(value: String) -> Maybe<&2, Nat>:
  Months.parse(value)

# ---------------------------------------------------------------------------
# The three fixed formats

# `yyyy`
def Months.fmt_year(days: Nat) -> String:
  T.Text.pad_nat(Months.year_of(days), 4n)

# A month index as `yyyy-MM`.
def Months.fmt_index(+mi: Nat) -> String:
  T.Text.pad_nat(Nat.div(mi, 12n), 4n) ++ "-" ++ T.Text.pad_nat((Nat.mod(mi, 12n) + 1n : Nat), 2n)

# `yyyy-MM`
def Months.fmt_month(days: Nat) -> String:
  Months.fmt_index(Months.index(days))

# `yyyy-MM-dd`
def Months.fmt_day(days: Nat) -> String:
  D.Date.iso_date(days)

# ---------------------------------------------------------------------------
# Arithmetic on day counts

def Months.days.add(days: Nat, n: I.Int) -> Maybe<&2, Nat>:
  do Maybe<&2, Nat>:
    r : Nat <- Months.to_nat(I.Int.add(I.Int.from_nat(days), n))
    Months.valid(r)

# date-fns `addMonths`: the same day of the month, or the month's last day.
def Months.days.add_months(+days: Nat, n: I.Int) -> Maybe<&2, Nat>:
  do Maybe<&2, Nat>:
    i : Nat <- Months.to_nat(I.Int.add(I.Int.from_nat(Months.index(days)), n))
    mi : Nat <- Months.epoch_index(i)
    Months.valid(Months.at_day(mi, Months.day_of_month(days)))

# How many days a day lies after the start of its week.
def Months.days.into_week(days: Nat, first: Nat) -> Nat:
  Nat.mod(Nat.sub((D.Date.weekday(days) + 7n : Nat), Nat.mod(first, 7n)), 7n)

# date-fns `startOfWeek` with `weekStartsOn: first`.
def Months.days.week_start(+days: Nat, first: Nat) -> Maybe<&2, Nat>:
  +back = Months.days.into_week(days, first)
  Bool.pick(Maybe<&2, Nat>, Nat.is_ge(days, back), Some{Nat.sub(days, back)}, None{})

def Months.days.month_first(days: Nat) -> Nat:
  Months.month_start(Months.index(days))

def Months.days.month_last(days: Nat) -> Nat:
  +mi = Months.index(days)
  Nat.sub((Months.month_start(mi) + Months.month_length(mi) : Nat), 1n)

# ---------------------------------------------------------------------------
# Formatting (date-fns `format`, en-US)

type Months.Token is Data:
  MLit{text: String}
  MFmt{char: Char, count: Nat, ordinal: Bool}

def Months.month_names() -> List<&2, String>:
  ["January", "February", "March", "April", "May", "June", "July", "August",
   "September", "October", "November", "December"]

def Months.day_names() -> List<&2, String>:
  ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

# The English name of a month, 1 to 12.
def Months.month_name(month: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, Months.month_names(), Nat.sub(month, 1n)), "")

# The English name of a weekday, 0 = Sunday.
def Months.day_name(dow: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, Months.day_names(), dow), "")

def Months.ordinal.unit(u: Nat) -> String:
  match u:
    case 1n:
      "st"
    case 2n:
      "nd"
    case 3n:
      "rd"
    case other:
      "th"

# 1st, 2nd, 3rd, 4th, 11th, 21st ...
def Months.ordinal(+n: Nat) -> String:
  +r = Nat.mod(n, 100n)
  Nat.show(n) ++ Bool.pick(String, Bool.or(Nat.is_gt(r, 20n), Nat.is_lt(r, 10n)),
    Months.ordinal.unit(Nat.mod(r, 10n)), "th")

# A number zero-padded to the token's length, or as an ordinal.
def Months.fmt.num(ordinal: Bool, +v: Nat, w: Nat) -> String:
  match ordinal:
    case True{}:
      Months.ordinal(v)
    case False{}:
      T.Text.pad_nat(v, w)

def Months.fmt.month.text(w: Nat, +month: Nat) -> String:
  match w:
    case 1n:
      Nat.show(month)
    case 2n:
      T.Text.pad_nat(month, 2n)
    case 3n:
      String.take(Months.month_name(month), 3n)
    case 5n:
      String.take(Months.month_name(month), 1n)
    case other:
      Months.month_name(month)

def Months.fmt.month(ordinal: Bool, w: Nat, month: Nat) -> String:
  match ordinal:
    case True{}:
      Months.ordinal(month)
    case False{}:
      Months.fmt.month.text(w, month)

# E, EE, EEE: Mon; EEEE: Monday; EEEEE: M; EEEEEE: Mo.
def Months.fmt.day.text(w: Nat, +dow: Nat) -> String:
  match w:
    case 1n:
      String.take(Months.day_name(dow), 3n)
    case 2n:
      String.take(Months.day_name(dow), 3n)
    case 3n:
      String.take(Months.day_name(dow), 3n)
    case 5n:
      String.take(Months.day_name(dow), 1n)
    case 6n:
      String.take(Months.day_name(dow), 2n)
    case other:
      Months.day_name(dow)

# e, c, i: the weekday as a number (num) for one or two letters, else as text.
def Months.fmt.day.num.text(w: Nat, +num: Nat, +dow: Nat) -> String:
  match w:
    case 1n:
      Nat.show(num)
    case 2n:
      T.Text.pad_nat(num, 2n)
    case 3n:
      Months.fmt.day.text(3n, dow)
    case 5n:
      Months.fmt.day.text(5n, dow)
    case 6n:
      Months.fmt.day.text(6n, dow)
    case other:
      Months.day_name(dow)

def Months.fmt.day.num(ordinal: Bool, w: Nat, num: Nat, dow: Nat) -> String:
  match ordinal:
    case True{}:
      Months.ordinal(num)
    case False{}:
      Months.fmt.day.num.text(w, num, dow)

def Months.fmt.quarter.text(w: Nat, +q: Nat) -> String:
  match w:
    case 1n:
      Nat.show(q)
    case 2n:
      T.Text.pad_nat(q, 2n)
    case 3n:
      "Q" ++ Nat.show(q)
    case 5n:
      Nat.show(q)
    case other:
      Months.ordinal(q) ++ " quarter"

def Months.fmt.quarter(ordinal: Bool, w: Nat, q: Nat) -> String:
  match ordinal:
    case True{}:
      Months.ordinal(q)
    case False{}:
      Months.fmt.quarter.text(w, q)

# Every date is at noon.
def Months.fmt.am_pm(w: Nat) -> String:
  match w:
    case 1n:
      "PM"
    case 2n:
      "PM"
    case 3n:
      "pm"
    case 5n:
      "p"
    case other:
      "p.m."

def Months.iso_weekday(+dow: Nat) -> Nat:
  Bool.pick(Nat, Nat.is_eq(dow, 0n), 7n, dow)

# A word character that is no token: date-fns throws for a letter and keeps
# the rest as text.
def Months.render.plain(+c: Char, n: Nat) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, Char.is_alpha(c), None{}, Some{String.repeat(SCon{c, SNil{}}, n)})

# One formatting token. None for a letter that is not a supported token.
def Months.render.fmt(
  c: Char, +w: Nat, +o: Bool, +year: Nat, +month: Nat, +day: Nat, +dow: Nat
) -> Maybe<&2, String>:
  match c:
    case 'y':
      Some{Months.fmt.num(o, Bool.pick(Nat, Nat.is_eq(w, 2n), Nat.mod(year, 100n), year), w)}
    case 'M':
      Some{Months.fmt.month(o, w, month)}
    case 'L':
      Some{Months.fmt.month(o, w, month)}
    case 'd':
      Some{Months.fmt.num(o, day, w)}
    case 'E':
      Some{Months.fmt.day.text(w, dow)}
    case 'e':
      Some{Months.fmt.day.num(o, w, (dow + 1n : Nat), dow)}
    case 'c':
      Some{Months.fmt.day.num(o, w, (dow + 1n : Nat), dow)}
    case 'i':
      Some{Months.fmt.day.num(o, w, Months.iso_weekday(dow), dow)}
    case 'Q':
      Some{Months.fmt.quarter(o, w, (Nat.sub(month, 1n) / 3n + 1n : Nat))}
    case 'q':
      Some{Months.fmt.quarter(o, w, (Nat.sub(month, 1n) / 3n + 1n : Nat))}
    case 'a':
      Some{Months.fmt.am_pm(w)}
    case 'H':
      Some{Months.fmt.num(o, 12n, w)}
    case 'h':
      Some{Months.fmt.num(o, 12n, w)}
    case 'm':
      Some{Months.fmt.num(o, 0n, w)}
    case 's':
      Some{Months.fmt.num(o, 0n, w)}
    case other:
      Months.render.plain(other, w)

def Months.render.civil(civil: D.Civil, c: Char, w: Nat, o: Bool, dow: Nat) -> Maybe<&2, String>:
  match civil:
    case D.Civil{year, month, day}:
      Months.render.fmt(c, w, o, year, month, day, dow)

def Months.render(tok: Months.Token, +days: Nat) -> Maybe<&2, String>:
  match tok:
    case MLit{text}:
      Some{text}
    case MFmt{c, w, o}:
      Months.render.civil(D.Date.civil_from_days(days), c, w, o, D.Date.weekday(days))

def Months.is_word(+c: Char) -> Bool:
  Bool.or(Bool.or(Char.is_alpha(c), Char.is_digit(c)), Char.is_eq(c, '_'))

# How many times c repeats at the head of s.
def Months.run_length(s: String, +c: Char) -> Nat:
  match s:
    case SNil{}:
      0n
    case SCon{h, t}:
      C.If(Nat, Char.is_eq(h, c), u => (1n + Months.run_length(t, c) : Nat), u => 0n)

def Months.lex.push(h: Char, p: String & String) -> String & String:
  (text, rest) = p
  (SCon{h, text}, rest)

# After an opening quote: the text up to the closing quote, where '' is a
# quote, and what follows it.
def Months.lex.quoted(s: String) -> String & String:
  match s:
    case SNil{}:
      (SNil{}, SNil{})
    case SCon{'\'', SCon{'\'', t}}:
      Months.lex.push('\'', Months.lex.quoted(t))
    case SCon{'\'', t}:
      (SNil{}, t)
    case SCon{h, t}:
      Months.lex.push(h, Months.lex.quoted(t))

def Months.lex.lit(p: String & String) -> Months.Token & String:
  (text, rest) = p
  (MLit{text}, rest)

def Months.lex.quote(t: String) -> Months.Token & String:
  match t:
    case SNil{}:
      (MLit{SNil{}}, SNil{})
    case SCon{'\'', r}:
      (MLit{"'"}, r)
    case other:
      Months.lex.lit(Months.lex.quoted(other))

def Months.lex.run(h: Char, +n: Nat, t: String) -> Months.Token & String:
  (MFmt{h, (n + 1n : Nat), False{}}, String.drop(t, n))

def Months.lex.word(ordinal: Bool, +h: Char, +t: String) -> Months.Token & String:
  match ordinal:
    case True{}:
      (MFmt{h, 1n, True{}}, String.drop(t, 1n))
    case False{}:
      Months.lex.run(h, Months.run_length(t, h), t)

def Months.lex.kind(quote: Bool, word: Bool, +h: Char, +t: String) -> Months.Token & String:
  match quote word:
    case True{} _:
      Months.lex.quote(t)
    case False{} True{}:
      Months.lex.word(Bool.and(String.contains("yYQqMLwIdDecihHKkms", SCon{h, SNil{}}),
        String.starts_with(t, "o")), h, t)
    case False{} False{}:
      (MLit{SCon{h, SNil{}}}, t)

# The token at the head of a format (h, then t) and the rest, as date-fns'
# /[yYQqMLwIdDecihHKkms]o|(\w)\1*|''|'(''|[^'])+('|$)|./ splits it.
def Months.lex(+h: Char, t: String) -> Months.Token & String:
  Months.lex.kind(Char.is_eq(h, '\''), Months.is_word(h), h, t)

def Months.lex.token(p: Months.Token & String) -> Months.Token:
  (tok, rest) = p
  tok

def Months.lex.rest(p: Months.Token & String) -> String:
  (tok, rest) = p
  rest

def Months.join(a: Maybe<&2, String>, b: Maybe<&2, String>) -> Maybe<&2, String>:
  match a b:
    case Some{x} Some{y}:
      Some{x ++ y}
    case _ _:
      None{}

def Months.prepend(pre: String, m: Maybe<&2, String>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{s}:
      Some{pre ++ s}

# The en-US long date formats: P, PP, PPP, PPPP.
def Months.expand.long(run: Nat) -> String:
  match run:
    case 0n:
      ""
    case 1n:
      "MM/dd/yyyy"
    case 2n:
      "MMM d, y"
    case 3n:
      "MMMM do, y"
    case other:
      "EEEE, MMMM do, y"

# date-fns' first pass: every run of P outside quotes becomes its long format.
# `run` counts the P's read so far. None for the time formats (p).
def Months.expand(s: String, quoted: Bool, +run: Nat) -> Maybe<&2, String>:
  match s quoted:
    case SNil{} _:
      Some{Months.expand.long(run)}
    case SCon{'\'', SCon{'\'', t}} True{}:
      Months.prepend("''", Months.expand(t, True{}, 0n))
    case SCon{'\'', SCon{'\'', t}} False{}:
      Months.prepend(Months.expand.long(run) ++ "''", Months.expand(t, False{}, 0n))
    case SCon{'\'', t} True{}:
      Months.prepend("'", Months.expand(t, False{}, 0n))
    case SCon{'\'', t} False{}:
      Months.prepend(Months.expand.long(run) ++ "'", Months.expand(t, True{}, 0n))
    case SCon{'P', t} False{}:
      Months.expand(t, False{}, (run + 1n : Nat))
    case SCon{'p', t} False{}:
      None{}
    case SCon{h, t} True{}:
      Months.prepend(SCon{h, SNil{}}, Months.expand(t, True{}, 0n))
    case SCon{h, t} False{}:
      Months.prepend(Months.expand.long(run) ++ SCon{h, SNil{}}, Months.expand(t, False{}, 0n))

def Months.format.go(f: Nat, s: String, +days: Nat) -> Maybe<&2, String>:
  match f s:
    case 0n _:
      Some{SNil{}}
    case 1n+g SNil{}:
      Some{SNil{}}
    case 1n+g SCon{+h, +t}:
      Months.join(Months.render(Months.lex.token(Months.lex(h, t)), days),
        Months.format.go(g, Months.lex.rest(Months.lex(h, t)), days))

def Months.format.long(+fmt: String, days: Nat) -> Maybe<&2, String>:
  Months.format.go((String.length(fmt) + 1n : Nat), fmt, days)

# date-fns `format` of a day count (at noon), with the en-US names. Supported
# tokens, each with date-fns' meaning for every length:
#   y yy yyy yyyy.. yo         year
#   M MM MMM MMMM MMMMM Mo     month; L.. the same (stand-alone month)
#   d dd do                    day of the month
#   E..EEEEEE                  weekday name
#   e.. c.. i.. (eo co io)     weekday number, week starting on Sunday / ISO
#   Q.. q.. Qo                 quarter
#   a..aaaaa                   PM (every date is at noon)
#   H HH h hh m mm s ss (+o)   12, 12, 0, 0
#   P PP PPP PPPP              long dates: 01/31/2024, Jan 31, 2024, ...
#   'text' and ''              quoted text and a quote; other non-letters as is
# Any other letter answers None; date-fns throws for most of them (the rest,
# like w, G, D, p, x, z, t, are not ported).
def Months.format_days(days: Nat, fmt: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    long : String <- Months.expand(fmt, False{}, 0n)
    Months.format.long(long, days)

# ---------------------------------------------------------------------------
# The exported functions

def Months.year_from_date(date: String) -> Maybe<&2, String>:
  Maybe.map(&2, Nat, String, Months.fmt_year, Months.parse(date))

def Months.month_from_date(date: String) -> Maybe<&2, String>:
  Maybe.map(&2, Nat, String, Months.fmt_month, Months.parse(date))

def Months.day_from_date(date: String) -> Maybe<&2, String>:
  Maybe.map(&2, Nat, String, Months.fmt_day, Months.parse(date))

# ---------------------------------------------------------------------------
# A matcher for the regular expressions this module builds

type Months.Rx is Data:
  RxDigit{}
  RxOpt{}
  RxAny{}
  RxChr{c: Char}
  RxEnd{}

def Months.rx.digit(c: Char) -> Nat:
  Nat.sub(U32.to_nat(Char.to_u32(c)), 48n)

# \d{lo,hi}: lo digits, then hi - lo optional ones.
def Months.rx.digits(+lo: Nat, hi: Nat, rest: List<&2, Months.Rx>) -> List<&2, Months.Rx>:
  List.append(&2, Months.Rx, List.replicate(Months.Rx, lo, RxDigit{}),
    List.append(&2, Months.Rx, List.replicate(Months.Rx, Nat.sub(hi, lo), RxOpt{}), rest))

def Months.rx.compile(src: String) -> List<&2, Months.Rx>:
  match src:
    case SNil{}:
      Nil{}
    case SCon{'\\', SCon{'d', SCon{'{', SCon{+a, SCon{'}', t}}}}}:
      Months.rx.digits(Months.rx.digit(a), Months.rx.digit(a), Months.rx.compile(t))
    case SCon{'\\', SCon{'d', SCon{'{', SCon{a, SCon{',', SCon{b, SCon{'}', t}}}}}}}:
      Months.rx.digits(Months.rx.digit(a), Months.rx.digit(b), Months.rx.compile(t))
    case SCon{'$', SNil{}}:
      [RxEnd{}]
    case SCon{'.', t}:
      RxAny{} <> Months.rx.compile(t)
    case SCon{c, t}:
      RxChr{c} <> Months.rx.compile(t)

# True when the tokens match a prefix of s.
def Months.rx.at(+toks: List<&2, Months.Rx>, s: String) -> Bool:
  match toks s:
    case Nil{} _:
      True{}
    case Con{RxEnd{}, rest} SNil{}:
      Months.rx.at(rest, SNil{})
    case Con{RxEnd{}, rest} SCon{h, t}:
      False{}
    case Con{RxOpt{}, rest} SNil{}:
      Months.rx.at(rest, SNil{})
    case Con{RxOpt{}, rest} SCon{+h, +t}:
      Bool.or(Months.rx.at(rest, SCon{h, t}), Bool.and(Char.is_digit(h), Months.rx.at(rest, t)))
    case Con{tok, rest} SNil{}:
      False{}
    case Con{RxDigit{}, rest} SCon{h, t}:
      Bool.and(Char.is_digit(h), Months.rx.at(rest, t))
    case Con{RxAny{}, rest} SCon{h, t}:
      Bool.and(Bool.not(Char.is_eq(h, '\n')), Months.rx.at(rest, t))
    case Con{RxChr{c}, rest} SCon{h, t}:
      Bool.and(Char.is_eq(h, c), Months.rx.at(rest, t))

def Months.rx.search(s: String, +toks: List<&2, Months.Rx>) -> Bool:
  match s:
    case SNil{}:
      Months.rx.at(toks, SNil{})
    case SCon{h, t}:
      +rest = t
      Bool.or(Months.rx.at(toks, SCon{h, rest}), Months.rx.search(rest, toks))

# JS `new RegExp(source).test(s)` for the sources this module builds: an
# optional leading `^`, an optional final `$`, `\d{n}` and `\d{n,m}` with
# single-digit counts, `.` for any character, and every other character for
# itself (so a format holding other RegExp operators is not supported).
def Months.regex_test(source: String, s: String) -> Bool:
  match source:
    case SCon{'^', t}:
      Months.rx.at(Months.rx.compile(t), s)
    case other:
      Months.rx.search(s, Months.rx.compile(other))

# ---------------------------------------------------------------------------

def Months.slice(s: String, from: Nat, len: Nat) -> String:
  String.take(String.drop(s, from), len)

# /^(\d{4})-(\d{2})$/ with a month from 1 to 12.
def Months.is_valid_year_month(+value: String) -> Bool:
  +month = Maybe.default(&2, Nat, T.Text.field(value, 5n, 2n), 0n)
  Bool.and(Months.regex_test("^\\d{4}-\\d{2}$", value),
    Bool.and(Nat.is_ge(month, 1n), Nat.is_le(month, 12n)))

# Whether a value is day-shaped (`yyyy-MM-dd`) rather than month-shaped
# (`yyyy-MM`), and names a day its month has.
def Months.is_valid_year_month_day(+value: String) -> Bool:
  +y = Maybe.default(&2, Nat, T.Text.field(value, 0n, 4n), 0n)
  +year = Bool.pick(Nat, Nat.is_lt(y, 100n), (y + 1900n : Nat), y)
  +month = Maybe.default(&2, Nat, T.Text.field(value, 5n, 2n), 0n)
  +day = Maybe.default(&2, Nat, T.Text.field(value, 8n, 2n), 0n)
  Bool.and(Months.regex_test("^\\d{4}-\\d{2}-\\d{2}$", value),
    Bool.and(Bool.and(Nat.is_ge(month, 1n), Nat.is_le(month, 12n)),
    Bool.and(Nat.is_ge(day, 1n), Nat.is_le(day, D.Date.days_in_month(year, month)))))

# The first day of the week of a date, for a week starting on `first`
# (0 = Sunday).
def Months.week_from_date(date: String, first: Nat) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    days : Nat <- Months.parse(date)
    start : Nat <- Months.days.week_start(days, first)
    return Months.fmt_day(start)

def Months.first_day_of_month(date: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    days : Nat <- Months.parse(date)
    return Months.fmt_day(Months.days.month_first(days))

def Months.last_day_of_month(date: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    days : Nat <- Months.parse(date)
    return Months.fmt_day(Months.days.month_last(days))

# The local day count of a local time in milliseconds.
def Months.today(now: Nat) -> Nat:
  Nat.div(now, 86400000n)

def Months.current_month(now: Nat) -> String:
  Months.fmt_month(Months.today(now))

def Months.current_week(now: Nat, first: Nat) -> Maybe<&2, String>:
  Maybe.map(&2, Nat, String, Months.fmt_day, Months.days.week_start(Months.today(now), first))

def Months.current_year(now: Nat) -> String:
  Months.fmt_year(Months.today(now))

# The current date, as a day count.
def Months.current_date(now: Nat) -> Nat:
  Months.today(now)

def Months.current_day(now: Nat) -> String:
  Months.fmt_day(Months.today(now))

def Months.shift_months(month: String, n: I.Int, fmt: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    days : Nat <- Months.parse(month)
    moved : Nat <- Months.days.add_months(days, n)
    Months.format_days(moved, fmt)

def Months.add_months(month: String, n: I.Int) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    days : Nat <- Months.parse(month)
    moved : Nat <- Months.days.add_months(days, n)
    return Months.fmt_month(moved)

def Months.sub_months(month: String, n: I.Int) -> Maybe<&2, String>:
  Months.add_months(month, I.Int.neg(n))

def Months.next_month(month: String) -> Maybe<&2, String>:
  Months.add_months(month, I.Int.from_nat(1n))

def Months.prev_month(month: String) -> Maybe<&2, String>:
  Months.add_months(month, I.Int.minus(1n))

# Twelve months back, in the given format (the original defaults to 'yyyy-MM').
def Months.prev_year(month: String, fmt: String) -> Maybe<&2, String>:
  Months.shift_months(month, I.Int.minus(12n), fmt)

# Three months back, in the given format (the original defaults to 'yyyy-MM').
def Months.prev_quarter(month: String, fmt: String) -> Maybe<&2, String>:
  Months.shift_months(month, I.Int.minus(3n), fmt)

def Months.add_years(year: String, n: I.Int) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    days : Nat <- Months.parse(year)
    moved : Nat <- Months.days.add_months(days, I.Int.mul(n, I.Int.from_nat(12n)))
    return Months.fmt_year(moved)

def Months.sub_years(year: String, n: I.Int) -> Maybe<&2, String>:
  Months.add_years(year, I.Int.neg(n))

def Months.add_days(day: String, n: I.Int) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    days : Nat <- Months.parse(day)
    moved : Nat <- Months.days.add(days, n)
    return Months.fmt_day(moved)

def Months.sub_days(day: String, n: I.Int) -> Maybe<&2, String>:
  Months.add_days(day, I.Int.neg(n))

def Months.add_weeks(date: String, n: I.Int) -> Maybe<&2, String>:
  Months.add_days(date, I.Int.mul(n, I.Int.from_nat(7n)))

def Months.sub_weeks(date: String, n: I.Int) -> Maybe<&2, String>:
  Months.add_weeks(date, I.Int.neg(n))

# The months from month2 to month1; None where JS answers NaN.
def Months.difference_in_calendar_months(month1: String, month2: String) -> Maybe<&2, I.Int>:
  do Maybe<&2, I.Int>:
    a : Nat <- Months.parse(month1)
    b : Nat <- Months.parse(month2)
    return I.Int.diff(Months.index(a), Months.index(b))

# The days from month2 to month1; None where JS answers NaN.
def Months.difference_in_calendar_days(month1: String, month2: String) -> Maybe<&2, I.Int>:
  do Maybe<&2, I.Int>:
    a : Nat <- Months.parse(month1)
    b : Nat <- Months.parse(month2)
    return I.Int.diff(a, b)

def Months.days.before(a: Maybe<&2, Nat>, b: Maybe<&2, Nat>) -> Bool:
  match a b:
    case Some{x} Some{y}:
      Nat.is_lt(x, y)
    case _ _:
      False{}

def Months.is_before(month1: String, month2: String) -> Bool:
  Months.days.before(Months.parse(month1), Months.parse(month2))

def Months.is_after(month1: String, month2: String) -> Bool:
  Months.days.before(Months.parse(month2), Months.parse(month1))

def Months.maybe_is(m: Maybe<&2, String>, s: String) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{x}:
      String.eq(x, s)

def Months.is_current_month(+month: String, now: Nat) -> Bool:
  Bool.and(Bool.or(Months.is_valid_year_month(month), Months.is_valid_year_month_day(month)),
    Months.maybe_is(Months.month_from_date(month), Months.current_month(now)))

def Months.is_current_day(+day: String, now: Nat) -> Bool:
  Bool.and(Months.is_valid_year_month_day(day),
    Months.maybe_is(Months.day_from_date(day), Months.current_day(now)))

def Months.civil.number(c: D.Civil) -> Nat:
  match c:
    case D.Civil{year, month, day}:
      (year * 10000n + month * 100n + day : Nat)

# A day as the number yyyyMMdd.
def Months.day_number(days: Nat) -> Nat:
  Months.civil.number(D.Date.civil_from_days(days))

type Months.Bounds is Data:
  Bounds{start: Nat, end: Nat}

# The first and the last day of a month as yyyyMMdd numbers.
def Months.bounds(month: String) -> Maybe<&2, Months.Bounds>:
  do Maybe<&2, Months.Bounds>:
    days : Nat <- Months.parse(month)
    +d : Nat = days
    return Bounds{Months.day_number(Months.days.month_first(d)), Months.day_number(Months.days.month_last(d))}

# n years from `from`, as `yyyy`.
def Months.seq.years(n: Nat, +from: Nat) -> List<&2, String>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      T.Text.pad_nat(from, 4n) <> Months.seq.years(p, (from + 1n : Nat))

# n month indexes from `from`, as `yyyy-MM`.
def Months.seq.months(n: Nat, +from: Nat) -> List<&2, String>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      Months.fmt_index(from) <> Months.seq.months(p, (from + 1n : Nat))

# n days from `from`, `step` days apart, as `yyyy-MM-dd`.
def Months.seq.days(n: Nat, +from: Nat, +step: Nat) -> List<&2, String>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      Months.fmt_day(from) <> Months.seq.days(p, (from + step : Nat), step)

def Months.count(n: Nat, inclusive: Bool) -> Nat:
  (n + Bool.pick(Nat, inclusive, 1n, 0n) : Nat)

def Months._year_range(start: String, end: String, inclusive: Bool) -> Maybe<&2, List<&2, String>>:
  do Maybe<&2, List<&2, String>>:
    a : Nat <- Months.parse(start)
    b : Nat <- Months.parse(end)
    +from : Nat = Months.year_of(a)
    return Months.seq.years(Months.count(Nat.sub(Months.year_of(b), from), inclusive), from)

def Months.year_range_inclusive(start: String, end: String) -> Maybe<&2, List<&2, String>>:
  Months._year_range(start, end, True{})

def Months._week_range(
  start: String, end: String, inclusive: Bool, +first: Nat
) -> Maybe<&2, List<&2, String>>:
  do Maybe<&2, List<&2, String>>:
    a : Nat <- Months.parse(start)
    from : Nat <- Months.days.week_start(a, first)
    b : Nat <- Months.parse(end)
    to : Nat <- Months.days.week_start(b, first)
    +f : Nat = from
    return Months.seq.days(Months.count(Nat.div(Nat.sub(to, f), 7n), inclusive), f, 7n)

def Months.week_range_inclusive(start: String, end: String, first: Nat) -> Maybe<&2, List<&2, String>>:
  Months._week_range(start, end, True{}, first)

def Months._range(start: String, end: String, inclusive: Bool) -> Maybe<&2, List<&2, String>>:
  do Maybe<&2, List<&2, String>>:
    a : Nat <- Months.parse(start)
    b : Nat <- Months.parse(end)
    +from : Nat = Months.index(a)
    return Months.seq.months(Months.count(Nat.sub(Months.index(b), from), inclusive), from)

# The months from start up to, not including, end.
def Months.range(start: String, end: String) -> Maybe<&2, List<&2, String>>:
  Months._range(start, end, False{})

def Months.range_inclusive(start: String, end: String) -> Maybe<&2, List<&2, String>>:
  Months._range(start, end, True{})

# As the original's loop: an unparsable start gives no days, and throws only
# when the range is inclusive; an unparsable end gives no days before it.
def Months._day_range.of(a: Maybe<&2, Nat>, b: Maybe<&2, Nat>, inclusive: Bool) -> Maybe<&2, List<&2, String>>:
  match a b inclusive:
    case None{} _ True{}:
      None{}
    case None{} _ False{}:
      Some{Nil{}}
    case Some{+from} None{} inc:
      Some{Months.seq.days(Months.count(0n, inc), from, 1n)}
    case Some{+from} Some{to} inc:
      Some{Months.seq.days(Months.count(Nat.sub(to, from), inc), from, 1n)}

def Months._day_range(start: String, end: String, inclusive: Bool) -> Maybe<&2, List<&2, String>>:
  Months._day_range.of(Months.parse(start), Months.parse(end), inclusive)

def Months.day_range(start: String, end: String) -> Maybe<&2, List<&2, String>>:
  Months._day_range(start, end, False{})

def Months.day_range_inclusive(start: String, end: String) -> Maybe<&2, List<&2, String>>:
  Months._day_range(start, end, True{})

def Months.get_month_from_index(year: String, month_index: Nat) -> String:
  year ++ "-" ++ T.Text.pad_nat((month_index + 1n : Nat), 2n)

# `parseInt(month.slice(5, 7)) - 1`; None for NaN.
def Months.get_month_index(month: String) -> Maybe<&2, I.Int>:
  do Maybe<&2, I.Int>:
    m : I.Int <- Months.parse_int(Months.slice(month, 5n, 2n))
    return I.Int.sub(m, I.Int.from_nat(1n))

def Months.get_year(month: String) -> String:
  String.take(month, 4n)

def Months.get_month(day: String) -> String:
  String.take(day, 7n)

# The day of the month.
def Months.get_day(day: String) -> Maybe<&2, Nat>:
  Maybe.map(&2, Nat, Nat, Months.day_of_month, Months.parse(day))

# Weekday names ordered to match `Date.prototype.getDay()` (0 = Sunday).
def Months.weekdays() -> List<&2, String>:
  ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

# How many times a day of the week (0 = Sunday) falls in `month`: 4 or 5.
def Months.count_day_of_week_in_month(month: String, day_of_week: Nat) -> Maybe<&2, Nat>:
  do Maybe<&2, Nat>:
    days : Nat <- Months.parse(month)
    +start : Nat = Months.days.month_first(days)
    +offset : Nat = Nat.mod(Nat.sub((day_of_week + 7n : Nat), D.Date.weekday(start)), 7n)
    return Bool.pick(Nat, Nat.is_lt((offset + 28n : Nat), Months.month_length(Months.index(start))), 5n, 4n)

def Months.get_month_end(day: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    next : String <- Months.next_month(String.take(day, 7n))
    Months.sub_days(next ++ "-01", I.Int.from_nat(1n))

# The last day of the week of a date, for a week starting on `first`.
def Months.get_week_end(date: String, first: Nat) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    days : Nat <- Months.parse(date)
    start : Nat <- Months.days.week_start(days, first)
    end : Nat <- Months.valid((start + 6n : Nat))
    return Months.fmt_day(end)

def Months.get_year_start(month: String) -> String:
  Months.get_year(month) ++ "-01"

def Months.get_year_end(month: String) -> String:
  Months.get_year(month) ++ "-12"

def Months.number.read(s: String) -> Maybe<&2, Nat>:
  match s:
    case SNil{}:
      Some{0n}
    case other:
      Nat.read(other)

# JS `Number(s)` for blank or all-digit text; None stands for NaN. (Signs,
# fractions and exponents are read as NaN here.)
def Months.number(s: String) -> Maybe<&2, Nat>:
  +t = String.trim(s)
  Bool.pick(Maybe<&2, Nat>, String.eq(Months.digit_run(t), t), Months.number.read(t), None{})

def Months.quarter_of(+m: Nat) -> Nat:
  Bool.pick(Nat, Nat.is_eq(m, 0n), 0n, (Nat.sub(m, 1n) / 3n + 1n : Nat))

# The quarter, 1 to 4, of a `yyyy-MM` month; None where JS answers NaN. As
# the original, month 00 is in quarter 0.
def Months.get_quarter(month: String) -> Maybe<&2, Nat>:
  Maybe.map(&2, Nat, Nat, m => Months.quarter_of(m), Months.number(Months.slice(month, 5n, 2n)))

# String((q - 1) * 3 + 1).padStart(2, '0'), which is -2 for quarter 0.
def Months.quarter.first(q: Maybe<&2, Nat>) -> String:
  match q:
    case None{}:
      "NaN"
    case Some{0n}:
      "-2"
    case Some{n}:
      T.Text.pad_nat(Nat.sub((n * 3n : Nat), 2n), 2n)

def Months.quarter.last(q: Maybe<&2, Nat>) -> String:
  match q:
    case None{}:
      "NaN"
    case Some{n}:
      T.Text.pad_nat((n * 3n : Nat), 2n)

def Months.get_quarter_start(+month: String) -> String:
  Months.get_year(month) ++ "-" ++ Months.quarter.first(Months.get_quarter(month))

def Months.get_quarter_end(+month: String) -> String:
  Months.get_year(month) ++ "-" ++ Months.quarter.last(Months.get_quarter(month))

# Quarters are keyed by their first month, e.g. Q2 2024 is '2024-04'.
def Months.quarter_from_date(date: String) -> Maybe<&2, String>:
  Maybe.map(&2, String, String, m => Months.get_quarter_start(m), Months.month_from_date(date))

def Months.current_quarter(now: Nat) -> String:
  Months.get_quarter_start(Months.current_month(now))

def Months.cons(h: String, m: Maybe<&2, List<&2, String>>) -> Maybe<&2, List<&2, String>>:
  match m:
    case None{}:
      None{}
    case Some{t}:
      Some{h <> t}

# The original's loop compares the quarters as text; when that never stops
# (a five-digit year below a four-digit one) it runs until date-fns throws,
# which is the fuel running out here.
def Months.quarters(f: Nat, +mi: Nat, +end: String) -> Maybe<&2, List<&2, String>>:
  match f:
    case 0n:
      None{}
    case 1n+g:
      +q = Months.fmt_index(mi)
      C.If(Maybe<&2, List<&2, String>>, String.is_le(q, end),
        u => Months.cons(q, Months.quarters(g, (mi + 3n : Nat), end)),
        u => Some{Nil{}})

def Months.quarter_index(days: Nat) -> Nat:
  +mi = Months.index(days)
  Nat.sub(mi, Nat.mod(mi, 3n))

def Months.quarter_range_inclusive(start: String, end: String) -> Maybe<&2, List<&2, String>>:
  do Maybe<&2, List<&2, String>>:
    a : Nat <- Months.parse(start)
    b : Nat <- Months.parse(end)
    +from : Nat = Months.quarter_index(a)
    +to : Nat = Months.quarter_index(b)
    Months.quarters((Nat.sub(to, from) / 3n + 2n : Nat), from, Months.fmt_index(to))

def Months.replace_first(s: String, +c: Char, +with: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{+h, +t}:
      C.If(String, Char.is_eq(h, c), u => with ++ t, u => SCon{h, Months.replace_first(t, c, with)})

def Months.sheet_for_month(month: String) -> String:
  "budget" ++ Months.replace_first(month, '-', "")

# date-fns `format` of a `yyyy`, `yyyy-MM` or `yyyy-MM-dd` string; the tokens
# are listed at `Months.format_days`.
def Months.format(month: String, fmt: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    days : Nat <- Months.parse(month)
    Months.format_days(days, fmt)

# January '24
def Months.name_for_month(month: String) -> Maybe<&2, String>:
  Months.format(month, "MMMM ''yy")

# ---------------------------------------------------------------------------
# formatDistance

# date-fns `differenceInMonths(later, earlier)` for later >= earlier: the full
# months between two days.
def Months.days.full_months(+later: Nat, +earlier: Nat) -> Nat:
  +diff = Nat.sub(Months.index(later), Months.index(earlier))
  +dom = Months.day_of_month(later)
  +is_feb = Nat.is_eq(Nat.mod(Months.index(later), 12n), 1n)
  +working = Bool.pick(Nat, Bool.and(is_feb, Nat.is_gt(dom, 27n)),
    Months.at_day_js(Months.index(later), 30n), later)
  +back = Months.at_day_js(Nat.sub(Months.index(working), diff), Months.day_of_month(working))
  +whole = Bool.and(Nat.is_eq(diff, 1n),
    Bool.and(Nat.is_eq(later, Months.days.month_last(later)), Nat.is_gt(later, earlier)))
  +short = Bool.and(Nat.is_lt(back, earlier), Bool.not(whole))
  Bool.pick(Nat, Nat.is_lt(diff, 1n), 0n, Nat.sub(diff, Bool.pick(Nat, short, 1n, 0n)))

def Months.distance.count(prefix: String, +n: Nat, unit: String) -> String:
  prefix ++ Nat.show(n) ++ " " ++ unit ++ Bool.pick(String, Nat.is_eq(n, 1n), "", "s")

def Months.distance.years(+months: Nat) -> String:
  +rest = Nat.mod(months, 12n)
  +years = Nat.div(months, 12n)
  Bool.pick(String, Nat.is_lt(rest, 3n), Months.distance.count("about ", years, "year"),
    Bool.pick(String, Nat.is_lt(rest, 9n), Months.distance.count("over ", years, "year"),
      Months.distance.count("almost ", (years + 1n : Nat), "year")))

# The words for two days n apart, n >= 60.
def Months.distance.far(+n: Nat, +months: Nat) -> String:
  Bool.pick(String, Nat.is_lt(months, 12n),
    Months.distance.count("", ((n + 15n) / 30n : Nat), "month"), Months.distance.years(months))

def Months.distance.words(+later: Nat, +earlier: Nat, seconds: Bool) -> String:
  +n = Nat.sub(later, earlier)
  Bool.pick(String, Nat.is_eq(n, 0n),
    Bool.pick(String, seconds, "less than 5 seconds", "less than a minute"),
    Bool.pick(String, Nat.is_lt(n, 30n), Months.distance.count("", n, "day"),
      Bool.pick(String, Nat.is_lt(n, 60n),
        Months.distance.count("about ", ((n + 15n) / 30n : Nat), "month"),
        Months.distance.far(n, Months.days.full_months(later, earlier)))))

def Months.distance.suffix(words: String, add_suffix: Bool, future: Bool) -> String:
  match add_suffix future:
    case False{} _:
      words
    case True{} True{}:
      "in " ++ words
    case True{} False{}:
      words ++ " ago"

# date-fns `formatDistance` in English between two day counts.
def Months.format_distance_days(+a: Nat, +b: Nat, add_suffix: Bool, include_seconds: Bool) -> String:
  Months.distance.suffix(Months.distance.words(Nat.max(a, b), Nat.min(a, b), include_seconds),
    add_suffix, Nat.is_gt(a, b))

# The distance between two dates in English words: '3 days', 'about 1 month',
# and with add_suffix 'in 3 days' when date1 is after date2, else '3 days ago'.
def Months.format_distance(
  date1: String, date2: String, add_suffix: Bool, include_seconds: Bool
) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    a : Nat <- Months.parse(date1)
    b : Nat <- Months.parse(date2)
    return Months.format_distance_days(a, b, add_suffix, include_seconds)

# ---------------------------------------------------------------------------
# Date format helpers

# JS `s.replace(/c+/g, with)`: every run of c becomes `with`. `prev` tells
# whether the character before s was c.
def Months.replace_runs.go(s: String, +c: Char, +with: String, prev: Bool) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{+h, t}:
      +same = Char.is_eq(h, c)
      +rest = Months.replace_runs.go(t, c, with, same)
      Bool.pick(String, same, Bool.pick(String, prev, rest, with ++ rest), SCon{h, rest})

def Months.replace_runs(s: String, c: Char, with: String) -> String:
  Months.replace_runs.go(s, c, with, False{})

def Months.strip_start(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{+h, +t}:
      Bool.pick(String, Months.is_word(h), SCon{h, t}, t)

# JS `s.replace(/[^\w]$/, '').replace(/^[^\w]/, '')`.
def Months.strip_ends(s: String) -> String:
  Months.strip_start(String.reverse(Months.strip_start(String.reverse(s))))

# JS `s.replace(/cc/, 'c')`: the first doubled c becomes one.
def Months.squeeze_first.go(s: String, +c: Char, prev: Bool) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{+h, +t}:
      +same = Char.is_eq(h, c)
      C.If(String, Bool.and(prev, same), u => t, u => SCon{h, Months.squeeze_first.go(t, c, same)})

def Months.squeeze_first(s: String, c: Char) -> String:
  Months.squeeze_first.go(s, c, False{})

def Months.rx.day_month(s: String) -> String:
  Months.replace_runs(Months.replace_runs(s, 'd', "\\d{1,2}"), 'M', "\\d{1,2}")

# The source of a RegExp finding a date written in `format` (not anchored).
def Months.get_date_format_regex(format: String) -> String:
  Months.replace_runs(Months.rx.day_month(format), 'y', "\\d{4}")

# 'MM/dd/yyyy' -> 'MM/dd'
def Months.get_day_month_format(format: String) -> String:
  Months.strip_ends(Months.replace_runs(format, 'y', ""))

def Months.get_day_month_regex(format: String) -> String:
  "^" ++ Months.rx.day_month(Months.get_day_month_format(format)) ++ "$"

def Months.month_year.strip(format: String) -> String:
  Months.squeeze_first(Months.strip_ends(Months.replace_runs(format, 'd', "")), '/')

# 'MM/dd/yyyy' -> 'MM/yyyy'
def Months.get_month_year_format(format: String) -> String:
  Months.squeeze_first(Months.squeeze_first(Months.month_year.strip(format), '.'), '-')

def Months.get_month_year_regex(format: String) -> String:
  "^" ++ Months.replace_runs(Months.replace_runs(Months.month_year.strip(format),
    'M', "\\d{1,2}"), 'y', "\\d{2,4}") ++ "$"

# 'MM/dd/yyyy' -> 'MM/dd/yy'
def Months.get_short_year_format(format: String) -> String:
  Months.replace_runs(format, 'y', "yy")

def Months.get_short_year_regex(format: String) -> String:
  "^" ++ Months.replace_runs(Months.rx.day_month(Months.strip_ends(format)), 'y', "\\d{2}") ++ "$"

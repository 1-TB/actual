# Number formats and money amounts: a port of the amount half of
# packages/loot-core/src/shared/util.ts (`getNumberFormat`,
# `integerToCurrency`, `currencyToAmount`, `currencyToInteger`,
# `amountToInteger`, `integerToAmount`, `stringToInteger`,
# `looselyParseAmount`, `toRelaxedNumber`, `titleFirst`).
#
# Deviations from the TypeScript:
# - The number format is an argument; the TS keeps it in a module variable
#   set by `setNumberFormat`.
# - An amount (a JS `number` there) is an exact rational, `N.Num`, and an
#   integer amount a signed integer, `I.Int`. Texts with more than 14 digits
#   and exponents (`1e3`) are refused rather than read as floats. Rounding to
#   cents is exact: "1.005" is 101 cents, where the TS float product
#   1.005 * 100 = 100.49999999999999 rounds to 100.
# - `Intl.NumberFormat` is replaced by `Util.format`, which groups digits the
#   way the five locales the TS picks do.
# - The object and array helpers of util.ts (`getChangedValues`, `groupBy`,
#   `setIn`, ...) work on untyped JS records and are not ported here.
import Base
import ../lib/core.bend as C
import ../lib/int.bend as I
import ../lib/num.bend as N
import ../lib/text.bend as T

type NumberFormat is Data:
  # 1,000.33 (en-US)
  CommaDot{}
  # 1.000,33 (de-DE)
  DotComma{}
  # 1 000,33 with a narrow no-break space (fr-FR)
  SpaceComma{}
  # 1’000.33 (de-CH)
  ApostropheDot{}
  # 1,00,000.33 (en-IN)
  CommaDotIn{}

# The format of a stored preference; anything unknown is comma-dot.
def Util.parse_number_format(name: String) -> NumberFormat:
  match name:
    case "dot-comma":
      DotComma{}
    case "space-comma":
      SpaceComma{}
    case "apostrophe-dot":
      ApostropheDot{}
    case "comma-dot-in":
      CommaDotIn{}
    case other:
      CommaDot{}

def Util.number_format_name(f: NumberFormat) -> String:
  match f:
    case CommaDot{}:
      "comma-dot"
    case DotComma{}:
      "dot-comma"
    case SpaceComma{}:
      "space-comma"
    case ApostropheDot{}:
      "apostrophe-dot"
    case CommaDotIn{}:
      "comma-dot-in"

def Util.thousands_separator(f: NumberFormat) -> Char:
  match f:
    case CommaDot{}:
      ','
    case DotComma{}:
      '.'
    case SpaceComma{}:
      Chr{8239}
    case ApostropheDot{}:
      Chr{8217}
    case CommaDotIn{}:
      ','

def Util.decimal_separator(f: NumberFormat) -> Char:
  match f:
    case DotComma{}:
      ','
    case SpaceComma{}:
      ','
    case other:
      '.'

# Formatting
# ----------

# Puts `sep` between groups of `size` digits of a reversed digit string.
def Util.group.go(rev: String, +size: Nat, +left: Nat, +sep: Char) -> String:
  match rev left:
    case SNil{} _:
      SNil{}
    case SCon{h, t} 0n:
      SCon{sep, SCon{h, Util.group.go(t, size, Nat.sub(size, 1n), sep)}}
    case SCon{h, t} 1n+p:
      SCon{h, Util.group.go(t, size, p, sep)}

# The digits of a natural with the format's thousands separators: groups of
# three, or for comma-dot-in a last group of three and groups of two before.
def Util.group(digits: String, f: NumberFormat) -> String:
  match f:
    case CommaDotIn{}:
      String.reverse(Util.group.go(String.reverse(digits), 2n, 3n, ','))
    case other:
      String.reverse(Util.group.go(String.reverse(digits), 3n, 3n, Util.thousands_separator(other)))

# `-0` is written `0`, as the TS formatter does.
def Util.format.zero(s: String) -> String:
  match s:
    case SCon{'-', SCon{'0', SNil{}}}:
      "0"
    case other:
      other

def Util.format.join(neg: Bool, whole: String, +frac: String, +f: NumberFormat) -> String:
  Util.format.zero(Bool.pick(String, neg, "-", "") ++ Util.group(whole, f) ++
    Bool.pick(String, String.is_empty(frac), "", SCon{Util.decimal_separator(f), frac}))

def Util.format.digits(neg: Bool, scaled: Maybe<&2, Nat>, +places: Nat, f: NumberFormat) -> String:
  match scaled:
    case None{}:
      "NaN"
    case Some{n}:
      +digits = T.Text.pad_left(Nat.show(n), 1n+places, '0')
      +cut = Nat.sub(String.length(digits), places)
      Util.format.join(neg, String.take(digits, cut), String.drop(digits, cut), f)

# |num/den| * 10^places rounded to the nearest natural, a half going away
# from zero, which is how `Intl.NumberFormat` rounds.
def Util.format.scale(num: Nat, +den: Nat, places: Nat) -> Maybe<&2, Nat>:
  Maybe.bind(&2, Nat, Nat, N.Num.pow10(places), p =>
    Maybe.bind(&2, Nat, Nat, N.Num.times(num, (p * 2n : Nat)), n =>
      Maybe.map(&2, Nat, Nat, m => Nat.div(m, (den * 2n : Nat)), N.Num.plus(n, den))))

# An amount with `places` fraction digits and the format's separators: what
# `getNumberFormat({format, decimalPlaces}).formatter.format(amount)` writes.
# A negative amount that rounds to zero keeps its sign ("-0.00") unless
# nothing but "-0" is left, as with `Intl.NumberFormat`.
def Util.format(a: N.Num, f: NumberFormat, +places: Nat) -> String:
  match a:
    case N.Num{neg, num, den}:
      Util.format.digits(neg, Util.format.scale(num, den, places), places, f)

# The fraction digits of the default formatter: none when fractions are
# hidden, two otherwise.
def Util.places(hide_fraction: Bool) -> Nat:
  match hide_fraction:
    case True{}:
      0n
    case False{}:
      2n

# An amount in the format: `amountToCurrency`.
def Util.amount_to_currency(a: N.Num, f: NumberFormat, hide_fraction: Bool) -> String:
  Util.format(a, f, Util.places(hide_fraction))

# An amount in the format without decimals: `amountToCurrencyNoDecimal`.
def Util.amount_to_currency_no_decimal(a: N.Num, f: NumberFormat) -> String:
  Util.format(a, f, 0n)

# An integer amount as the amount it stands for: 12345 with 2 places is
# 123.45. `integerToAmount`.
def Util.integer_to_amount(i: I.Int, places: Nat) -> N.Num:
  Maybe.default(&2, N.Num, N.Num.from_scaled(i, places), N.Num.zero())

# An amount as an integer amount: `Math.round(amount * 10^places)`.
# `amountToInteger`.
def Util.amount_to_integer(a: N.Num, places: Nat) -> Maybe<&2, I.Int>:
  N.Num.round(a, places)

# An integer amount (cents) in the format: `integerToCurrency`.
def Util.integer_to_currency(i: I.Int, f: NumberFormat, hide_fraction: Bool) -> String:
  Util.format(Util.integer_to_amount(i, 2n), f, Util.places(hide_fraction))

# An integer amount in the format, with its decimals whenever it has cents
# even if fractions are hidden: `integerToCurrencyWithDecimal` without a
# currency code.
def Util.integer_to_currency_with_decimal(+i: I.Int, f: NumberFormat, hide_fraction: Bool) -> String:
  Util.integer_to_currency(i, f,
    Bool.and(hide_fraction, I.Int.is_zero(I.Int.mod(i, I.Int.from_nat(100n)))))

# Parsing
# -------

def Util.is_digit(+x: U32) -> Bool:
  Bool.and((x >= 48 : U32), (x <= 57 : U32))

# U+2212 MINUS SIGN becomes the ASCII hyphen.
def Util.ascii_minus(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{8722}, t}:
      SCon{'-', Util.ascii_minus(t)}
    case SCon{h, t}:
      SCon{h, Util.ascii_minus(t)}

# Only the digits and hyphens of s: `s.replace(/[^\d-]/g, '')`.
def Util.numbers(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+x}, t}:
      Bool.pick(String, Bool.or(Util.is_digit(x), U32.is_eq(x, 45)), SCon{Chr{x}, SNil{}}, SNil{}) ++
        Util.numbers(t)

def Util.span.put(c: Char, r: String & String) -> String & String:
  (ds, rest) = r
  (SCon{c, ds}, rest)

# The digits at the head of s, and what follows.
def Util.span(s: String) -> String & String:
  match s:
    case SNil{}:
      (SNil{}, SNil{})
    case SCon{Chr{+x}, +t}:
      C.If(String & String, Util.is_digit(x),
        u => Util.span.put(Chr{x}, Util.span(t)),
        u => (SNil{}, SCon{Chr{x}, t}))

def Util.parse_float.frac(rest: String) -> String:
  match rest:
    case SCon{'.', t}:
      Pair.fst(String, String, Util.span(t))
    case other:
      SNil{}

def Util.parse_float.make(neg: Bool, +whole: String, +frac: String) -> Maybe<&2, N.Num>:
  +digits = whole ++ frac
  C.If(Maybe<&2, N.Num>,
    Bool.and(Bool.not(String.is_empty(digits)), Nat.is_le(String.length(digits), 14n)),
    u => Maybe.map(&2, Nat, N.Num,
      d => N.Num.make(neg, Maybe.default(&2, Nat, Nat.read(digits), 0n), d),
      N.Num.pow10(String.length(frac))),
    u => None{})

def Util.parse_float.body(neg: Bool, r: String & String) -> Maybe<&2, N.Num>:
  (whole, rest) = r
  Util.parse_float.make(neg, whole, Util.parse_float.frac(rest))

def Util.parse_float.sign(s: String) -> Maybe<&2, N.Num>:
  match s:
    case SCon{'-', t}:
      Util.parse_float.body(True{}, Util.span(t))
    case SCon{'+', t}:
      Util.parse_float.body(False{}, Util.span(t))
    case other:
      Util.parse_float.body(False{}, Util.span(other))

# JS `parseFloat` for plain decimals: leading spaces, a sign, digits, a point
# and digits, stopping at the first character that does not fit. None where
# JS answers NaN. Exponents are not read.
def Util.parse_float(s: String) -> Maybe<&2, N.Num>:
  Util.parse_float.sign(String.trim_start(s))

def Util.split_last.put(c: Char, r: Maybe<&1, (String & Char) & String>) -> Maybe<&1, (String & Char) & String>:
  match r:
    case None{}:
      None{}
    case Some{Tuple{Tuple{after, sep}, before}}:
      Some{((SCon{c, after}, sep), before)}

# Scans a reversed string for its first dot or comma: the reversed text
# before it, the separator, and the reversed text after it.
def Util.split_last.go(rev: String) -> Maybe<&1, (String & Char) & String>:
  match rev:
    case SNil{}:
      None{}
    case SCon{'.', t}:
      Some{((SNil{}, '.'), t)}
    case SCon{',', t}:
      Some{((SNil{}, ','), t)}
    case SCon{h, t}:
      Util.split_last.put(h, Util.split_last.go(t))

type Util.Split is Data:
  # no dot or comma
  Whole{}
  # the text before the last dot or comma, that separator, the text after
  Split{before: String, sep: Char, after: String}

def Util.split_last.fin(r: Maybe<&1, (String & Char) & String>) -> Util.Split:
  match r:
    case None{}:
      Whole{}
    case Some{Tuple{Tuple{after, sep}, before}}:
      Split{String.reverse(before), sep, String.reverse(after)}

# Splits s at its last dot or comma: `/[,.](?=[^.,]*$)/`.
def Util.split_last(s: String) -> Util.Split:
  Util.split_last.fin(Util.split_last.go(String.reverse(s)))

def Util.currency_to_amount.at(+text: String, split: Util.Split, f: NumberFormat) -> Maybe<&2, N.Num>:
  match split:
    case Whole{}:
      Util.parse_float(Util.numbers(text) ++ ".")
    case Split{+before, +sep, +after}:
      # a thousands separator followed by three or more characters is not a
      # decimal point
      C.If(Maybe<&2, N.Num>,
        Bool.and(Char.is_eq(sep, Util.thousands_separator(f)), Nat.is_ge(String.length(after), 3n)),
        u => Util.parse_float(Util.numbers(text) ++ "."),
        u => Util.parse_float(Util.numbers(before) ++ "." ++ after))

# Reads an amount the user typed in the format: `currencyToAmount`. None
# where the TS answers null.
def Util.currency_to_amount(text: String, f: NumberFormat) -> Maybe<&2, N.Num>:
  +clean = Util.ascii_minus(text)
  Util.currency_to_amount.at(clean, Util.split_last(clean), f)

# Reads a typed amount as an integer amount: `currencyToInteger`.
def Util.currency_to_integer(text: String, f: NumberFormat) -> Maybe<&2, I.Int>:
  Maybe.bind(&2, N.Num, I.Int, Util.currency_to_amount(text, f), a => N.Num.round(a, 2n))

# `integerToAmount(currencyToInteger(text) || 0)`: `toRelaxedNumber`.
def Util.to_relaxed_number(text: String, f: NumberFormat) -> N.Num:
  Util.integer_to_amount(Maybe.default(&2, I.Int, Util.currency_to_integer(text, f), I.Int.zero()), 2n)

# Only the characters `-0123456789.,` of s.
def Util.amount_chars(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+x}, t}:
      Bool.pick(String, Bool.or(Util.is_digit(x), Bool.or(U32.is_eq(x, 45), Bool.or(U32.is_eq(x, 46), U32.is_eq(x, 44)))),
        SCon{Chr{x}, SNil{}}, SNil{}) ++ Util.amount_chars(t)

def Util.parse_int.digits(neg: Bool, r: String & String) -> Maybe<&2, I.Int>:
  (+ds, rest) = r
  C.If(Maybe<&2, I.Int>, Bool.and(Bool.not(String.is_empty(ds)), Nat.is_le(String.length(ds), 14n)),
    u => Some{I.Int.make(neg, Maybe.default(&2, Nat, Nat.read(ds), 0n))},
    u => None{})

# JS `parseInt(s)` in base 10: a sign and the digits after it.
def Util.parse_int(s: String) -> Maybe<&2, I.Int>:
  match s:
    case SCon{'-', t}:
      Util.parse_int.digits(True{}, Util.span(t))
    case SCon{'+', t}:
      Util.parse_int.digits(False{}, Util.span(t))
    case other:
      Util.parse_int.digits(False{}, Util.span(other))

# The integer at the head of a text once everything but digits, signs and
# separators is dropped: `stringToInteger`.
def Util.string_to_integer(s: String) -> Maybe<&2, I.Int>:
  Util.parse_int(Util.amount_chars(Util.ascii_minus(s)))

# s without its U+2212 minus signs.
def Util.drop_minus(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{8722}, t}:
      Util.drop_minus(t)
    case SCon{h, t}:
      SCon{h, Util.drop_minus(t)}

# s without the first occurrence of c.
def Util.drop_first(s: String, +c: Char) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{+h, +t}:
      C.If(String, Char.is_eq(h, c), u => t, u => SCon{h, Util.drop_first(t, c)})

def Util.has_digit(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{x}, t}:
      Bool.or(Util.is_digit(x), Util.has_digit(t))

# An amount in parentheses is negative: "(1,234.56)" reads as "-1,234.56".
def Util.loose.sign(+s: String) -> String:
  C.If(String, Bool.and(String.starts_with(s, "("), String.ends_with(s, ")")),
    u => "-" ++ Util.drop_first(String.drop(Util.drop_minus(s), 1n), ')'),
    u => Util.ascii_minus(s))

# Whether the text after the last separator is a decimal part: one or two,
# or four to nine digits, then no further digit.
def Util.loose.is_decimal(r: String & String) -> Bool:
  (+ds, rest) = r
  Bool.and(Bool.not(Util.has_digit(rest)),
    Bool.or(Bool.and(Nat.is_ge(String.length(ds), 1n), Nat.is_le(String.length(ds), 2n)),
      Bool.and(Nat.is_ge(String.length(ds), 4n), Nat.is_le(String.length(ds), 9n))))

def Util.loose.at(+text: String, split: Util.Split) -> Maybe<&2, N.Num>:
  match split:
    case Whole{}:
      Util.parse_float(Util.numbers(text))
    case Split{+before, sep, +after}:
      C.If(Maybe<&2, N.Num>, Util.loose.is_decimal(Util.span(after)),
        u => Util.parse_float(Util.numbers(before) ++ "." ++ Util.numbers(after)),
        u => Util.parse_float(Util.numbers(text)))

# Reads an amount from a financial file, whatever its number format, by
# looking for a decimal marker followed by one or two, or four to nine,
# digits; three could be a thousands group. `looselyParseAmount`.
def Util.loosely_parse_amount(amount: String) -> Maybe<&2, N.Num>:
  +text = Util.loose.sign(String.trim(amount))
  Util.loose.at(text, Util.split_last(text))

# Text
# ----

# Upper case for ASCII and Latin-1 letters; other scripts are left as they
# are, where JS `toUpperCase` knows all of Unicode.
def Util.upper(c: Char) -> Char:
  match c:
    case Chr{+x}:
      Bool.pick(Char, Bool.and(Bool.and((x >= 224 : U32), (x <= 254 : U32)), U32.is_ne(x, 247)),
        Chr{(x - 32 : U32)}, Char.to_upper(Chr{x}))

# The text with its first character in upper case: `titleFirst`.
def Util.title_first(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{h, t}:
      SCon{Util.upper(h), t}

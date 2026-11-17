# Calendar arithmetic on the proleptic Gregorian calendar, in UTC, from the
# Unix epoch on. A date is a count of days since 1970-01-01 and a time is a
# count of milliseconds since then, both naturals. The algorithms are Howard
# Hinnant's `days_from_civil` and `civil_from_days`.
import Base
import ./text.bend as T

type Civil is Data:
  Civil{year: Nat, month: Nat, day: Nat}

# Days since 1970-01-01 of a civil date; 0 for dates before the epoch.
def Date.days_from_civil(year: Nat, +month: Nat, day: Nat) -> Nat:
  +y = Nat.sub(year, Bool.pick(Nat, Nat.is_le(month, 2n), 1n, 0n))
  +era = Nat.div(y, 400n)
  +yoe = Nat.sub(y, (era * 400n : Nat))
  mp = Bool.pick(Nat, Nat.is_gt(month, 2n), Nat.sub(month, 3n), (month + 9n : Nat))
  doy = Nat.sub((((153n * mp + 2n : Nat) / 5n) + day : Nat), 1n)
  doe = Nat.sub((yoe * 365n + (yoe / 4n) + doy : Nat), (yoe / 100n : Nat))
  Nat.sub((era * 146097n + doe : Nat), 719468n)

# The civil date of a count of days since 1970-01-01.
def Date.civil_from_days(days: Nat) -> Civil:
  +z = (days + 719468n : Nat)
  +era = Nat.div(z, 146097n)
  +doe = Nat.sub(z, (era * 146097n : Nat))
  +yoe = Nat.div(Nat.sub(Nat.sub((doe + (doe / 36524n) : Nat), (doe / 1460n : Nat)),
    (doe / 146096n : Nat)), 365n)
  +doy = Nat.sub((doe + (yoe / 100n) : Nat), (365n * yoe + (yoe / 4n) : Nat))
  +mp = Nat.div((5n * doy + 2n : Nat), 153n)
  day = Nat.sub((doy + 1n : Nat), ((153n * mp + 2n : Nat) / 5n : Nat))
  +month = Bool.pick(Nat, Nat.is_lt(mp, 10n), (mp + 3n : Nat), Nat.sub(mp, 9n))
  year = (yoe + era * 400n + Bool.pick(Nat, Nat.is_le(month, 2n), 1n, 0n) : Nat)
  Civil{year, month, day}

def Date.is_leap(+year: Nat) -> Bool:
  Bool.and(Nat.is_eq(Nat.mod(year, 4n), 0n),
    Bool.or(Nat.is_ne(Nat.mod(year, 100n), 0n), Nat.is_eq(Nat.mod(year, 400n), 0n)))

# The number of days in a month, 1 to 12.
def Date.days_in_month(year: Nat, month: Nat) -> Nat:
  match month:
    case 2n:
      Bool.pick(Nat, Date.is_leap(year), 29n, 28n)
    case 4n:
      30n
    case 6n:
      30n
    case 9n:
      30n
    case 11n:
      30n
    case other:
      31n

# The day of the week of a count of days since the epoch: 0 is Sunday.
def Date.weekday(days: Nat) -> Nat:
  Nat.mod((days + 4n : Nat), 7n)

def Date.iso_date.of(c: Civil) -> String:
  match c:
    case Civil{year, month, day}:
      T.Text.pad_nat(year, 4n) ++ "-" ++ T.Text.pad_nat(month, 2n) ++ "-" ++ T.Text.pad_nat(day, 2n)

# A day count as `YYYY-MM-DD`.
def Date.iso_date(days: Nat) -> String:
  Date.iso_date.of(Date.civil_from_days(days))

# Milliseconds since the epoch as `YYYY-MM-DDTHH:MM:SS.mmmZ`, which is what JS
# `new Date(ms).toISOString()` answers for years up to 9999.
def Date.iso_from_millis(+ms: Nat) -> String:
  +rest = Nat.mod(ms, 86400000n)
  Date.iso_date(Nat.div(ms, 86400000n)) ++ "T" ++
    T.Text.pad_nat(Nat.div(rest, 3600000n), 2n) ++ ":" ++
    T.Text.pad_nat(Nat.mod(Nat.div(rest, 60000n), 60n), 2n) ++ ":" ++
    T.Text.pad_nat(Nat.mod(Nat.div(rest, 1000n), 60n), 2n) ++ "." ++
    T.Text.pad_nat(Nat.mod(rest, 1000n), 3n) ++ "Z"

# Reads `YYYY-MM-DD` at the head of s as a day count. As V8 does, a day up to
# 31 is accepted in any month and rolls over. None before 1970.
def Date.days_from_iso(+s: String) -> Maybe<&2, Nat>:
  do Maybe<&2, Nat>:
    year : Nat <- T.Text.field(s, 0n, 4n)
    month : Nat <- T.Text.field(s, 5n, 2n)
    day : Nat <- T.Text.field(s, 8n, 2n)
    +y : Nat = year
    +m : Nat = month
    +d : Nat = day
    ok : Unit <- T.Text.guard(
      Bool.and(Bool.and(T.Text.at(s, 4n, '-'), T.Text.at(s, 7n, '-')),
      Bool.and(Bool.and(Nat.is_ge(y, 1970n), Nat.is_ge(m, 1n)),
      Bool.and(Nat.is_le(m, 12n), Bool.and(Nat.is_ge(d, 1n), Nat.is_le(d, 31n))))))
    return Date.days_from_civil(y, m, d)

# Reads exactly `YYYY-MM-DDTHH:MM:SS.mmmZ` as milliseconds since the epoch.
def Date.millis_from_iso(+s: String) -> Maybe<&2, Nat>:
  do Maybe<&2, Nat>:
    days : Nat <- Date.days_from_iso(s)
    hour : Nat <- T.Text.field(s, 11n, 2n)
    min : Nat <- T.Text.field(s, 14n, 2n)
    sec : Nat <- T.Text.field(s, 17n, 2n)
    ms : Nat <- T.Text.field(s, 20n, 3n)
    +h : Nat = hour
    +mi : Nat = min
    +se : Nat = sec
    ok : Unit <- T.Text.guard(
      Bool.and(Bool.and(Nat.is_eq(String.length(s), 24n), T.Text.at(s, 10n, 'T')),
      Bool.and(Bool.and(T.Text.at(s, 13n, ':'), T.Text.at(s, 16n, ':')),
      Bool.and(Bool.and(T.Text.at(s, 19n, '.'), T.Text.at(s, 23n, 'Z')),
      Bool.and(Nat.is_lt(h, 24n), Bool.and(Nat.is_lt(mi, 60n), Nat.is_lt(se, 60n)))))))
    return (days * 86400000n + h * 3600000n + mi * 60000n + se * 1000n + ms : Nat)

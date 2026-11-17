# The currencies a budget can be shown in: a port of
# packages/loot-core/src/shared/currencies.ts, plus the currency-code branch
# of `integerToCurrencyWithDecimal` from util.ts.
import Base
import ../lib/int.bend as I
import ./util.bend as F

type Currency is Data:
  Currency{code: String, symbol: String, name: String, decimal_places: Nat,
    number_format: F.NumberFormat, symbol_first: Bool}

# Number formats and symbol placement follow CLDR locale conventions. The
# first entry, with an empty code, is "no currency".
def Currencies.all() -> List<&2, Currency>:
  [
    Currency{"", "", "None", 2n, F.CommaDot{}, True{}},
    Currency{"AED", "د.إ", "UAE Dirham", 2n, F.CommaDot{}, False{}},
    Currency{"ARS", "Arg$", "Argentinian Peso", 2n, F.DotComma{}, True{}},
    Currency{"AUD", "A$", "Australian Dollar", 2n, F.CommaDot{}, True{}},
    Currency{"BDT", "৳", "Bangladeshi Taka", 2n, F.CommaDotIn{}, True{}},
    Currency{"BRL", "R$", "Brazilian Real", 2n, F.DotComma{}, True{}},
    Currency{"BYN", "Br", "Belarusian Ruble", 2n, F.SpaceComma{}, False{}},
    Currency{"CAD", "CA$", "Canadian Dollar", 2n, F.CommaDot{}, True{}},
    Currency{"CHF", "CHF", "Swiss Franc", 2n, F.ApostropheDot{}, True{}},
    Currency{"CLP", "CLP$", "Chilean Peso", 2n, F.DotComma{}, True{}},
    Currency{"CNY", "¥", "Yuan Renminbi", 2n, F.CommaDot{}, True{}},
    Currency{"COP", "Col$", "Colombian Peso", 2n, F.DotComma{}, True{}},
    Currency{"CRC", "₡", "Costa Rican Colón", 2n, F.SpaceComma{}, True{}},
    Currency{"CZK", "Kč", "Czech Koruna", 2n, F.SpaceComma{}, False{}},
    Currency{"DKK", "kr", "Danish Krone", 2n, F.DotComma{}, False{}},
    Currency{"DOP", "RD$", "Dominican Peso", 2n, F.CommaDot{}, True{}},
    Currency{"EGP", "ج.م", "Egyptian Pound", 2n, F.CommaDot{}, False{}},
    Currency{"EUR", "€", "Euro", 2n, F.DotComma{}, False{}},
    Currency{"GBP", "£", "Pound Sterling", 2n, F.CommaDot{}, True{}},
    Currency{"GTQ", "Q", "Guatemalan Quetzal", 2n, F.CommaDot{}, True{}},
    Currency{"HKD", "HK$", "Hong Kong Dollar", 2n, F.CommaDot{}, True{}},
    Currency{"HUF", "Ft", "Hungarian Forint", 2n, F.SpaceComma{}, False{}},
    Currency{"IDR", "Rp", "Indonesian Rupiah", 2n, F.DotComma{}, True{}},
    Currency{"ILS", "₪", "Israeli New Shekel", 2n, F.CommaDot{}, True{}},
    Currency{"INR", "₹", "Indian Rupee", 2n, F.CommaDotIn{}, True{}},
    Currency{"IRR", "﷼", "Iranian Rial", 0n, F.CommaDot{}, False{}},
    Currency{"JMD", "J$", "Jamaican Dollar", 2n, F.CommaDot{}, True{}},
    Currency{"JPY", "¥", "Japanese Yen", 0n, F.CommaDot{}, True{}},
    Currency{"KRW", "₩", "South Korean Won", 0n, F.CommaDot{}, True{}},
    Currency{"LKR", "Rs.", "Sri Lankan Rupee", 2n, F.CommaDot{}, True{}},
    Currency{"MDL", "L", "Moldovan Leu", 2n, F.DotComma{}, False{}},
    Currency{"MKD", "ден", "Macedonian Denar", 2n, F.DotComma{}, False{}},
    Currency{"MXN", "$", "Mexican Peso", 2n, F.CommaDot{}, True{}},
    Currency{"MYR", "RM", "Malaysian Ringgit", 2n, F.CommaDot{}, True{}},
    Currency{"NOK", "kr", "Norwegian Krone", 2n, F.SpaceComma{}, False{}},
    Currency{"PEN", "S/", "Peruvian Sol", 2n, F.CommaDot{}, True{}},
    Currency{"PHP", "₱", "Philippine Peso", 2n, F.CommaDot{}, True{}},
    Currency{"PKR", "Rs.", "Pakistani Rupee", 2n, F.CommaDot{}, True{}},
    Currency{"PLN", "zł", "Polish Złoty", 2n, F.SpaceComma{}, False{}},
    Currency{"QAR", "ر.ق", "Qatari Riyal", 2n, F.CommaDot{}, False{}},
    Currency{"RON", "lei", "Romanian Leu", 2n, F.DotComma{}, False{}},
    Currency{"RSD", "дин", "Serbian Dinar", 2n, F.DotComma{}, False{}},
    Currency{"RUB", "₽", "Russian Ruble", 2n, F.SpaceComma{}, False{}},
    Currency{"SAR", "ر.س", "Saudi Riyal", 2n, F.CommaDot{}, False{}},
    Currency{"SEK", "kr", "Swedish Krona", 2n, F.SpaceComma{}, False{}},
    Currency{"SGD", "S$", "Singapore Dollar", 2n, F.CommaDot{}, True{}},
    Currency{"THB", "฿", "Thai Baht", 2n, F.CommaDot{}, True{}},
    Currency{"TRY", "₺", "Turkish Lira", 2n, F.DotComma{}, True{}},
    Currency{"TWD", "NT$", "New Taiwan Dollar", 2n, F.CommaDot{}, True{}},
    Currency{"TZS", "TSh", "Tanzanian Shilling", 2n, F.CommaDot{}, True{}},
    Currency{"UAH", "₴", "Ukrainian Hryvnia", 2n, F.SpaceComma{}, False{}},
    Currency{"USD", "$", "US Dollar", 2n, F.CommaDot{}, True{}},
    Currency{"UYU", "$U", "Uruguayan Peso", 2n, F.DotComma{}, True{}},
    Currency{"UZS", "UZS", "Uzbek Soum", 2n, F.SpaceComma{}, False{}},
    Currency{"ZAR", "R", "South African Rand", 2n, F.SpaceComma{}, True{}} ]

def Currencies.none() -> Currency:
  Currency{"", "", "None", 2n, F.CommaDot{}, True{}}

def Currencies.find(cs: List<&2, Currency>, +code: String) -> Currency:
  match cs:
    case Nil{}:
      Currencies.none()
    case Con{Currency{+c, symbol, name, places, format, first}, t}:
      Bool.pick(Currency, String.eq(c, code), Currency{c, symbol, name, places, format, first},
        Currencies.find(t, code))

# The currency with a code, or "no currency" when there is none.
# `getCurrency`.
def Currencies.get(code: String) -> Currency:
  Currencies.find(Currencies.all(), code)

def Currencies.places(c: Currency) -> Nat:
  match c:
    case Currency{code, symbol, name, places, format, first}:
      places

# The number of decimals a currency is shown with. `getDecimalPlaces`.
def Currencies.decimal_places(code: String) -> Nat:
  Currencies.places(Currencies.get(code))

# An integer amount (cents) in a number format, with the decimals of a
# currency: `integerToCurrencyWithDecimal(integerAmount, currencyCode)`.
def Currencies.integer_to_currency(i: I.Int, f: F.NumberFormat, code: String) -> String:
  F.Util.format(F.Util.integer_to_amount(i, 2n), f, Currencies.decimal_places(code))

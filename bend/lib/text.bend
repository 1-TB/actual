# Text helpers shared by the ports: UTF-8 encoding, padding, digits.
import Base
import ./core.bend as C

def Text.utf8.pick(+x: U32, one: Bool, two: Bool, three: Bool) -> List<&2, U32>:
  match one two three:
    case True{} _ _:
      [x]
    case False{} True{} _:
      [(192 .|. (x >> 6n) : U32), (128 .|. (x .&. 63) : U32)]
    case False{} False{} True{}:
      [(224 .|. (x >> 12n) : U32), (128 .|. ((x >> 6n) .&. 63) : U32),
       (128 .|. (x .&. 63) : U32)]
    case False{} False{} False{}:
      [(240 .|. (x >> 18n) : U32), (128 .|. ((x >> 12n) .&. 63) : U32),
       (128 .|. ((x >> 6n) .&. 63) : U32), (128 .|. (x .&. 63) : U32)]

# The UTF-8 bytes of one code point.
def Text.utf8.chr(+x: U32) -> List<&2, U32>:
  Text.utf8.pick(x, (x < 128 : U32), (x < 2048 : U32), (x < 65536 : U32))

# The UTF-8 bytes of a string.
def Text.utf8(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{Chr{x}, t}:
      List.append(&2, U32, Text.utf8.chr(x), Text.utf8(t))

# The last n characters of s, as JS `s.slice(-n)` answers for n > 0.
def Text.last(+s: String, n: Nat) -> String:
  String.drop(s, Nat.sub(String.length(s), n))

# s padded on the left with c up to n characters; longer strings are kept.
def Text.pad_left(+s: String, n: Nat, +c: Char) -> String:
  String.append(String.repeat(SCon{c, SNil{}}, Nat.sub(n, String.length(s))), s)

# n in decimal, zero-padded to w digits.
def Text.pad_nat(n: Nat, w: Nat) -> String:
  Text.pad_left(Nat.show(n), w, '0')

# One hexadecimal digit, uppercase.
def Text.hex_digit(+d: U32) -> Char:
  Chr{(d + 48 + Bool.to_u32((d > 9 : U32)) * 7 : U32)}

def Text.hex_upper.go(f: Nat, +n: U32, acc: String, z: Bool) -> String:
  match f z:
    case 0n _:
      acc
    case 1n+g True{}:
      acc
    case 1n+g False{}:
      +m = (n >> 4n : U32)
      Text.hex_upper.go(g, m, SCon{Text.hex_digit((n .&. 15 : U32)), acc}, U32.is_zero(m))

def Text.hex_upper.if(n: U32, z: Bool) -> String:
  match z:
    case True{}:
      "0"
    case False{}:
      Text.hex_upper.go(8n, n, SNil{}, False{})

# n in uppercase hexadecimal, "0" for zero, as JS `n.toString(16).toUpperCase()`.
def Text.hex_upper(+n: U32) -> String:
  Text.hex_upper.if(n, U32.is_zero(n))

# Some{Unit} when c holds: a guard for `do Maybe` blocks.
def Text.guard(c: Bool) -> Maybe<&2, Unit>:
  match c:
    case True{}:
      Some{Unit{}}
    case False{}:
      None{}

# The characters [from, from+len) of s, read as a decimal natural. None when
# the slice is short or holds a non-digit.
def Text.field(s: String, from: Nat, +len: Nat) -> Maybe<&2, Nat>:
  +part = String.take(String.drop(s, from), len)
  do Maybe<&2, Nat>:
    ok : Unit <- Text.guard(Nat.is_eq(String.length(part), len))
    Nat.read(part)

# True when the character at index i of s is c.
def Text.at(s: String, i: Nat, c: Char) -> Bool:
  Char.is_eq(Maybe.default(&2, Char, String.get(s, i), Chr{0}), c)

def Text.within(+x: U32, lo: U32, hi: U32) -> Bool:
  Bool.and(U32.is_ge(x, lo), U32.is_le(x, hi))

# Whether a code point is whitespace to a JS regular expression's `\s`.
def Text.is_js_space(+x: U32) -> Bool:
  Text.within(x, 9, 13) || U32.is_eq(x, 32) || U32.is_eq(x, 160) || U32.is_eq(x, 5760) ||
    Text.within(x, 8192, 8202) || U32.is_eq(x, 8232) || U32.is_eq(x, 8233) ||
    U32.is_eq(x, 8239) || U32.is_eq(x, 8287) || U32.is_eq(x, 12288) || U32.is_eq(x, 65279)

# What a byte starts when no sequence is open: the character it is by
# itself, or nothing for a lead byte; a stray byte is U+FFFD.
def Text.from_utf8.emit(+b: U32) -> String:
  Bool.pick(String, (b < 128 : U32), SCon{Chr{b}, SNil{}},
    Bool.pick(String, Text.within(b, 194, 244), SNil{}, SCon{Chr{65533}, SNil{}}))

# The payload bits of a lead byte.
def Text.from_utf8.bits(+b: U32) -> U32:
  Bool.pick(U32, (b < 224 : U32), (b .&. 31 : U32),
    Bool.pick(U32, (b < 240 : U32), (b .&. 15 : U32), (b .&. 7 : U32)))

# The number of continuation bytes a lead byte announces; 0 otherwise.
def Text.from_utf8.need(+b: U32) -> Nat:
  Bool.pick(Nat, Text.within(b, 194, 223), 1n,
    Bool.pick(Nat, Text.within(b, 224, 239), 2n,
      Bool.pick(Nat, Text.within(b, 240, 244), 3n, 0n)))

# Decodes byte by byte: `code` holds the bits read of an open sequence and
# `need` the continuation bytes it still wants.
def Text.from_utf8.go(bytes: List<&2, U32>, +code: U32, +need: Nat) -> String:
  match bytes need:
    case Nil{} 0n:
      SNil{}
    case Nil{} 1n+p:
      SCon{Chr{65533}, SNil{}}
    case Con{+b, t} 0n:
      Text.from_utf8.emit(b) ++ Text.from_utf8.go(t, Text.from_utf8.bits(b), Text.from_utf8.need(b))
    case Con{+b, +t} 1n+ +p:
      C.If(String, Text.within(b, 128, 191),
        u => Bool.pick(String, Nat.is_eq(p, 0n),
            SCon{Chr{((code << 6n) .|. (b .&. 63) : U32)}, SNil{}}, SNil{}) ++
          Text.from_utf8.go(t, ((code << 6n) .|. (b .&. 63) : U32), p),
        u => SCon{Chr{65533}, Text.from_utf8.emit(b)} ++
          Text.from_utf8.go(t, Text.from_utf8.bits(b), Text.from_utf8.need(b)))

# The text of UTF-8 bytes; a malformed sequence becomes U+FFFD, as a JS
# `TextDecoder` does.
def Text.from_utf8(bytes: List<&2, U32>) -> String:
  Text.from_utf8.go(bytes, 0, 0n)

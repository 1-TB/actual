# MurmurHash3 (x86, 32-bit), as `murmurhash.v3` computes it in the TypeScript
# code: over the UTF-8 bytes of the key, with seed 0 unless one is given.
import Base
import ../lib/text.bend as T

def Murmur.rotl(+x: U32, +r: Nat) -> U32:
  ((x << r) .|. (x >> Nat.sub(32n, r)) : U32)

def Murmur.mix_k(k: U32) -> U32:
  (Murmur.rotl((k * 3432918353 : U32), 15n) * 461845907 : U32)

def Murmur.mix_h(h: U32, k: U32) -> U32:
  (Murmur.rotl((h .^. Murmur.mix_k(k) : U32), 13n) * 5 + 3864292196 : U32)

def Murmur.fmix(+h: U32) -> U32:
  +a = (h .^. (h >> 16n) : U32)
  +b = (a * 2246822507 : U32)
  +c = (b .^. (b >> 13n) : U32)
  +d = (c * 3266489909 : U32)
  (d .^. (d >> 16n) : U32)

def Murmur.word(a: U32, b: U32, c: U32, d: U32) -> U32:
  (a .|. (b << 8n) .|. (c << 16n) .|. (d << 24n) : U32)

# Folds the bytes four at a time; `len` counts every byte consumed.
def Murmur.go(bytes: List<&2, U32>, h: U32, len: U32) -> U32:
  match bytes:
    case Nil{}:
      Murmur.fmix((h .^. len : U32))
    case Con{a, Nil{}}:
      Murmur.fmix((h .^. Murmur.mix_k(a) .^. (len + 1) : U32))
    case Con{a, Con{b, Nil{}}}:
      Murmur.fmix((h .^. Murmur.mix_k(Murmur.word(a, b, 0, 0)) .^. (len + 2) : U32))
    case Con{a, Con{b, Con{c, Nil{}}}}:
      Murmur.fmix((h .^. Murmur.mix_k(Murmur.word(a, b, c, 0)) .^. (len + 3) : U32))
    case Con{a, Con{b, Con{c, Con{d, t}}}}:
      Murmur.go(t, Murmur.mix_h(h, Murmur.word(a, b, c, d)), (len + 4 : U32))

def Murmur.bytes(bytes: List<&2, U32>, seed: U32) -> U32:
  Murmur.go(bytes, seed, 0)

# The hash of a string's UTF-8 bytes with seed 0: `murmurhash.v3(key)`.
def Murmur.v3(key: String) -> U32:
  Murmur.bytes(T.Text.utf8(key), 0)

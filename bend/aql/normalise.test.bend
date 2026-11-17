# Cases for normalise.bend; expected values come from the JS function
# (scratchpad aql/normgen.mjs).
import Base
import ../lib/test.bend as T
import ./normalise.bend as N

# The text of the code points from..from+n-1.
def range(n: Nat, +from: U32) -> String:
  match n:
    case 0n:
      SNil{}
    case 1n+p:
      SCon{Chr{from}, range(p, (from + 1 : U32))}

# A rolling hash of a text: h * 31 + code point, modulo 2^32.
def hash(s: String, +h: U32) -> U32:
  match s:
    case SNil{}:
      h
    case SCon{Chr{x}, t}:
      hash(t, (h * 31 + x : U32))

def main() -> IO(Unit):
  T.Test.run([
    T.Check{"norm %TEST%", N.Norm.string("%TEST%"), "%test%"},
    T.Check{"norm Ünïcödé ŁØSSŒ", N.Norm.string("Ünïcödé ŁØSSŒ"), "unicode lossoe"},
    T.Check{"norm ÀÉÎõü ñ ç Å", N.Norm.string("ÀÉÎõü ñ ç Å"), "aeiou n c a"},
    T.Check{"norm straße ẞ", N.Norm.string("straße ẞ"), "strasse ss"},
    T.Check{"norm Ελληνικά ΆΈ", N.Norm.string("Ελληνικά ΆΈ"), "ελληνικα αε"},
    T.Check{"norm Привет Ёж й", N.Norm.string("Привет Ёж й"), "привет еж и"},
    T.Check{"norm Ǆ ǅ İstanbul I", N.Norm.string("Ǆ ǅ İstanbul I"), "ǆ ǆ istanbul i"},
    T.Check{"norm é ạ̈", N.Norm.string("é ạ̈"), "e a"},
    T.Check{"norm it's 100% _ok_", N.Norm.string("it's 100% _ok_"), "it's 100% _ok_"},
    T.Check{"norm Żółć gęślą jaźń", N.Norm.string("Żółć gęślą jaźń"), "zolc gesla jazn"},
    T.Check{"norm Ạ ệ Ổ ự", N.Norm.string("Ạ ệ Ổ ự"), "a e o u"},
    T.Check{"norm ճամփա Ա", N.Norm.string("ճամփա Ա"), "ճամփա ա"},
    T.Check{"norm ", N.Norm.string(""), ""},
    T.Test.u32("every code point below U+2000, hashed", hash(N.Norm.string(range(8192n, 0)), 0), 1464438715)
  ])

# The XML parser packages/loot-core/src/server/transactions/import needs: a
# port of what `parseStringPromise(text, { explicitArray: false, trim })` of
# the `xml2js` library (v0.6) answers, on top of a port of the strict-mode
# tokenizer of the `sax` library (v1.5) that xml2js drives.
#
# The result is the value xml2js builds, as a `Json` (bend/json/json.bend):
# an element with only text is a string; one with attributes or children is
# an object with the text under `_` (when not blank), the attributes under
# `$` and each child under its name, children of one name gathered in an
# array; an empty element is its own, blank, text. The root is wrapped in an
# object under its name. A blank document answers no value (JS `null`).
#
# As in xml2js, the answer is settled the moment the root element closes:
# whatever follows it is not looked at, and any error before it fails the
# whole parse.
#
# Deviations: a failure carries sax's message without the line, column and
# character it appends. sax walks UTF-16 units and this walks code points;
# both refuse a character outside the Basic Multilingual Plane in a name.
# Two accidents of the JS objects are not reproduced: a child element named
# `cdata` beside a CDATA section, and the entity names `Object.prototype`
# happens to define (`&constructor;`).
import Base
import ../lib/core.bend as C
import ../json/json.bend as J
import ./js.bend as X
import ./entities.bend as E

# The children of one name, newest first.
type Xml.Kid is Data:
  Kid{name: String, values: List<&2, J.Json>}

# An open element: its text so far (reversed), whether a CDATA section
# added to it, its attributes and its children. xml2js keeps the text under
# the key `_` of the object it is building, so a child element named `_`
# lands on it: the text becomes an array, which reads as its parts joined by
# commas once more text comes, and breaks the parse (`broken`) if the element
# closes first.
type Xml.Frame is Data:
  Frame{
    name: String, text: String, cdata: Bool, broken: Bool,
    attrs: List<&2, J.Json.Member>, kids: List<&2, Xml.Kid>
  }

type Xml.Status is Data:
  Going{}
  Failed{message: String}
  Finished{value: J.Json}

# The tokenizer between characters. `s` is sax's state (see `Xml.dispatch`).
# The buffers hold their characters newest first: `text` and `cd` are the
# text not yet given to the innermost open element and whether CDATA is part
# of it; `name` is the tag name, `attr` and `value` the attribute being
# read, `entity` the entity being read, `q` the open quote, `decl` the
# text after `<!` in upper case, `cdata` the CDATA section, `doctype` what
# sax's `parser.doctype` holds (0 nothing, 1 an open declaration, 2 a closed
# one), `attrs` the attributes of the tag being read (newest first) and
# `stack` the open elements, innermost first.
type Xml.State is Data:
  State{
    status: Xml.Status, s: U32, text: String, cd: Bool, name: String, attr: String, value: String,
    entity: String, q: U32, decl: String, cdata: String, doctype: U32,
    attrs: List<&2, J.Json.Member>, stack: List<&2, Xml.Frame>
  }

type Xml.Popped is Data:
  PopFail{message: String}
  PopDone{value: J.Json}
  PopStack{stack: List<&2, Xml.Frame>}

# Character classes
# -----------------

# sax's `isWhitespace`.
def Xml.is_ws(+x: U32) -> Bool:
  U32.is_eq(x, 32) || U32.is_eq(x, 10) || U32.is_eq(x, 13) || U32.is_eq(x, 9)

def Xml.is_quote(+x: U32) -> Bool:
  U32.is_eq(x, 34) || U32.is_eq(x, 39)

def Xml.in(+x: U32, lo: U32, hi: U32) -> Bool:
  (x >= lo : U32) && (x <= hi : U32)

# sax's `nameStart`.
def Xml.name_start(+x: U32) -> Bool:
  U32.is_eq(x, 58) || U32.is_eq(x, 95) || Xml.in(x, 65, 90) || Xml.in(x, 97, 122)
    || Xml.in(x, 192, 214) || Xml.in(x, 216, 246) || Xml.in(x, 248, 767) || Xml.in(x, 880, 893)
    || Xml.in(x, 895, 8191) || Xml.in(x, 8204, 8205) || Xml.in(x, 8304, 8591)
    || Xml.in(x, 11264, 12271) || Xml.in(x, 12289, 55295) || Xml.in(x, 63744, 64975)
    || Xml.in(x, 65008, 65533)

# sax's `nameBody`.
def Xml.name_body(+x: U32) -> Bool:
  Xml.name_start(x) || U32.is_eq(x, 183) || Xml.in(x, 768, 879) || Xml.in(x, 8255, 8256)
    || U32.is_eq(x, 46) || Xml.in(x, 48, 57) || U32.is_eq(x, 45)

def Xml.upper(+x: U32) -> U32:
  Bool.pick(U32, Xml.in(x, 97, 122), (x - 32 : U32), x)

def Xml.lower(+x: U32) -> U32:
  Bool.pick(U32, Xml.in(x, 65, 90), (x + 32 : U32), x)

def Xml.lower_all(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{x}, t}:
      SCon{Chr{Xml.lower(x)}, Xml.lower_all(t)}

# Entities
# --------

def Xml.digit(+x: U32, hex: Bool) -> Maybe<&2, U32>:
  C.If(Maybe<&2, U32>, Xml.in(x, 48, 57),
    u => Some{(x - 48 : U32)},
    u => Bool.pick(Maybe<&2, U32>, hex && Xml.in(x, 97, 102), Some{(x - 87 : U32)}, None{}))

def Xml.code.go(s: String, +hex: Bool, +acc: U32) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      Some{acc}
    case SCon{Chr{x}, t}:
      Maybe.bind(&2, U32, U32, Xml.digit(x, hex), d =>
        Xml.code.go(t, hex, (acc * Bool.pick(U32, hex, 16, 10) + d : U32)))

# The code point a numeric character reference names: digits without the
# leading zeros, at most 0x10FFFF.
def Xml.code(digits: String, hex: Bool) -> Maybe<&2, U32>:
  +ds = X.Js.zeros(digits)
  C.If(Maybe<&2, U32>, Bool.not(String.is_empty(ds)) && Nat.is_le(String.length(ds), 7n),
    u => Maybe.bind(&2, U32, U32, Xml.code.go(ds, hex, 0), +n =>
      Bool.pick(Maybe<&2, U32>, (n <= 1114111 : U32), Some{n}, None{})),
    u => None{})

def Xml.entity.numeric(name: String) -> Maybe<&2, U32>:
  match name:
    case SCon{'#', SCon{'x', digits}}:
      Xml.code(digits, True{})
    case SCon{'#', digits}:
      Xml.code(digits, False{})
    case other:
      None{}

# sax's `parseEntity`: a named entity, by its exact name or else in lower
# case, or a decimal or hexadecimal character reference. None is "Invalid
# character entity".
def Xml.entity(+name: String) -> Maybe<&2, U32>:
  Maybe.or(&2, U32, E.Entities.find(name),
    Maybe.or(&2, U32, E.Entities.find(Xml.lower_all(name)), Xml.entity.numeric(Xml.lower_all(name))))

# Building values
# ---------------

def Xml.kid(k: Xml.Kid) -> J.Json.Member:
  match k:
    case Kid{name, Con{only, Nil{}}}:
      J.Member{name, only}
    case Kid{name, values}:
      J.Member{name, J.Json.array(List.reverse(&2, J.Json, values))}

# The value xml2js gives an element when it closes.
def Xml.value(trim: Bool, +text: String, cdata: Bool, +attrs: List<&2, J.Json.Member>, +kids: List<&2, Xml.Kid>) -> J.Json:
  +blank = X.Js.is_blank(text) && Bool.not(cdata)
  +shown = Bool.pick(String, trim, X.Js.trim(text), text)
  C.If(J.Json, List.is_empty(&2, J.Json.Member, attrs) && List.is_empty(&2, Xml.Kid, kids),
    u => J.JStr{Bool.pick(String, blank, text, shown)},
    u => J.Json.object(List.concat(&2, J.Json.Member, [
      Bool.pick(List<&2, J.Json.Member>, blank, Nil{}, [J.Member{"_", J.JStr{shown}}]),
      Bool.pick(List<&2, J.Json.Member>, List.is_empty(&2, J.Json.Member, attrs), Nil{},
        [J.Member{"$", J.Json.object(List.reverse(&2, J.Json.Member, attrs))}]),
      X.Js.map(~Xml.Kid, ~J.Json.Member, ~Xml.kid, kids)])))

# xml2js's `assignOrPush`: a child joins the others of its name.
def Xml.adopt.kids(kids: List<&2, Xml.Kid>, +name: String, +value: J.Json) -> List<&2, Xml.Kid>:
  match kids:
    case Nil{}:
      [Kid{name, [value]}]
    case Con{Kid{+k, +values}, +t}:
      C.If(List<&2, Xml.Kid>, String.eq(k, name),
        u => Con{Kid{k, Con{value, values}}, t},
        u => Con{Kid{k, values}, Xml.adopt.kids(t, name, value)})

def Xml.adopt(parent: Xml.Frame, +name: String, +value: J.Json) -> Xml.Frame:
  match parent:
    case Frame{+pname, +text, +cdata, +broken, +attrs, +kids}:
      Bool.pick(Xml.Frame, String.eq(name, "_"),
        Frame{pname, String.reverse("," ++ X.Js.to_string(value)) ++ text, cdata, True{}, attrs, kids},
        Frame{pname, text, cdata, broken, attrs, Xml.adopt.kids(kids, name, value)})

def Xml.pop.give(name: String, value: J.Json, rest: List<&2, Xml.Frame>) -> Xml.Popped:
  match rest:
    case Nil{}:
      PopDone{J.Json.object([J.Member{name, value}])}
    case Con{parent, more}:
      PopStack{Con{Xml.adopt(parent, name, value), more}}

# sax's `closeTag` in strict mode with xml2js's `onclosetag`: the closing
# tag must name the innermost open element, which then becomes a value.
def Xml.pop(trim: Bool, +tag: String, +text: String, cd: Bool, stack: List<&2, Xml.Frame>) -> Xml.Popped:
  match stack:
    case Nil{}:
      PopFail{"Unmatched closing tag: " ++ tag}
    case Con{Frame{+name, +ftext, +fcd, +broken, +attrs, +kids}, +rest}:
      C.If(Xml.Popped, String.eq(name, tag),
        u => C.If(Xml.Popped, broken && String.is_empty(text),
          v => PopFail{"obj[charkey].match is not a function"},
          v => Xml.pop.give(name, Xml.value(trim, String.reverse(text ++ ftext), fcd || cd, attrs, kids), rest)),
        u => PopFail{"Unexpected close tag"})

# The pending text given to the innermost open element.
def Xml.flush(stack: List<&2, Xml.Frame>, +text: String, cd: Bool) -> List<&2, Xml.Frame>:
  match stack:
    case Nil{}:
      Nil{}
    case Con{Frame{name, ftext, fcd, broken, attrs, kids}, rest}:
      Con{Frame{name, text ++ ftext, fcd || cd, broken && String.is_empty(text), attrs, kids}, rest}

def Xml.has_attr(attrs: List<&2, J.Json.Member>, +name: String) -> Bool:
  match attrs:
    case Nil{}:
      False{}
    case Con{J.Member{k, v}, t}:
      String.eq(k, name) || Xml.has_attr(t, name)

# State changes
# -------------

def Xml.to(st: Xml.State, n: U32) -> Xml.State:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      State{status, n, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}

def Xml.fail(st: Xml.State, message: String) -> Xml.State:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      State{Failed{message}, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}

def Xml.text_push(st: Xml.State, x: U32) -> Xml.State:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      State{status, s, SCon{Chr{x}, text}, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}

# A new tag name; the tag's attributes start empty.
def Xml.name_set(st: Xml.State, fresh: String) -> Xml.State:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      State{status, s, text, cd, fresh, attr, value, entity, q, decl, cdata, doctype, Nil{}, stack}

def Xml.name_push(st: Xml.State, x: U32) -> Xml.State:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      State{status, s, text, cd, SCon{Chr{x}, name}, attr, value, entity, q, decl, cdata, doctype, attrs, stack}

def Xml.attr_set(st: Xml.State, x: U32) -> Xml.State:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      State{status, s, text, cd, name, SCon{Chr{x}, SNil{}}, SNil{}, entity, q, decl, cdata, doctype, attrs, stack}

def Xml.attr_push(st: Xml.State, x: U32) -> Xml.State:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      State{status, s, text, cd, name, SCon{Chr{x}, attr}, value, entity, q, decl, cdata, doctype, attrs, stack}

def Xml.value_push(st: Xml.State, x: U32) -> Xml.State:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      State{status, s, text, cd, name, attr, SCon{Chr{x}, value}, entity, q, decl, cdata, doctype, attrs, stack}

def Xml.entity_set(st: Xml.State, fresh: String) -> Xml.State:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      State{status, s, text, cd, name, attr, value, fresh, q, decl, cdata, doctype, attrs, stack}

def Xml.q_set(st: Xml.State, x: U32) -> Xml.State:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      State{status, s, text, cd, name, attr, value, entity, x, decl, cdata, doctype, attrs, stack}

def Xml.decl_set(st: Xml.State, fresh: String) -> Xml.State:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      State{status, s, text, cd, name, attr, value, entity, q, fresh, cdata, doctype, attrs, stack}

def Xml.cdata_set(st: Xml.State, fresh: String) -> Xml.State:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      State{status, s, text, cd, name, attr, value, entity, q, decl, fresh, doctype, attrs, stack}

def Xml.doctype_set(st: Xml.State, d: U32) -> Xml.State:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, d, attrs, stack}

def Xml.name(st: Xml.State) -> String:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      name

def Xml.get_entity(st: Xml.State) -> String:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      entity

def Xml.q(st: Xml.State) -> U32:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      q

def Xml.decl(st: Xml.State) -> String:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      decl

def Xml.get_cdata(st: Xml.State) -> String:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      cdata

def Xml.doctype(st: Xml.State) -> U32:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      doctype

# Whether an element is open: sax's `sawRoot && !closedRoot`.
def Xml.inside(st: Xml.State) -> Bool:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      Bool.not(List.is_empty(&2, Xml.Frame, stack))

# sax's `attrib`: the attribute read joins the tag's, unless its name is
# already there.
def Xml.attr_done(st: Xml.State) -> Xml.State:
  match st:
    case State{status, s, text, cd, name, +attr, value, entity, q, decl, cdata, doctype, +attrs, stack}:
      +key = String.reverse(attr)
      State{status, s, text, cd, name, attr, SNil{}, entity, 0, decl, cdata, doctype,
        Bool.pick(List<&2, J.Json.Member>, Xml.has_attr(attrs, key), attrs,
          Con{J.Member{key, J.JStr{String.reverse(value)}}, attrs}),
        stack}

# The finished CDATA section joins the text of the open element, if any.
def Xml.cdata_done(st: Xml.State) -> Xml.State:
  match st:
    case State{status, s, +text, cd, name, attr, value, entity, q, decl, +cdata, doctype, attrs, +stack}:
      +keep = Bool.not(String.is_empty(cdata)) && Bool.not(List.is_empty(&2, Xml.Frame, stack))
      State{status, 2, Bool.pick(String, keep, cdata ++ text, text), cd || keep, name, attr, value, entity, q,
        decl, SNil{}, doctype, attrs, stack}

# sax's `openTag` with xml2js's `onopentag`: a new innermost element.
def Xml.open(st: Xml.State) -> Xml.State:
  match st:
    case State{status, s, text, cd, +name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      State{status, 2, SNil{}, False{}, name, attr, value, entity, q, decl, cdata, doctype, Nil{},
        Con{Frame{String.reverse(name), SNil{}, False{}, False{}, attrs, Nil{}}, Xml.flush(stack, text, cd)}}

def Xml.close.to(st: Xml.State, p: Xml.Popped) -> Xml.State:
  match st p:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack} PopFail{m}:
      State{Failed{m}, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack} PopDone{v}:
      State{Finished{v}, 2, SNil{}, False{}, name, attr, value, entity, q, decl, cdata, doctype, attrs, Nil{}}
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack} PopStack{rest}:
      State{status, 2, SNil{}, False{}, name, attr, value, entity, q, decl, cdata, doctype, attrs, rest}

def Xml.close(trim: Bool, +st: Xml.State) -> Xml.State:
  match st:
    case State{status, s, text, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      Xml.close.to(st, Xml.pop(trim, String.reverse(name), text, cd, stack))

# The tokenizer
# -------------

def Xml.on_entity.end(+st: Xml.State, code: Maybe<&2, U32>, +back: U32) -> Xml.State:
  match code:
    case None{}:
      Xml.fail(st, "Invalid character entity")
    case Some{+c}:
      Xml.to(Bool.pick(Xml.State, U32.is_eq(back, 2), Xml.text_push(st, c), Xml.value_push(st, c)), back)

# An entity being read, in text (`back` 2) or in a quoted attribute value
# (`back` 25): `;` ends it, a name character extends it.
def Xml.on_entity(+st: Xml.State, +x: U32, +back: U32) -> Xml.State:
  +name = Xml.get_entity(st)
  C.If(Xml.State, U32.is_eq(x, 59),
    u => Xml.on_entity.end(st, Xml.entity(String.reverse(name)), back),
    u => C.If(Xml.State,
      U32.is_eq(x, 35) || Bool.pick(Bool, String.is_empty(name), Xml.name_start(x), Xml.name_body(x)),
      v => Xml.entity_set(st, SCon{Chr{x}, name}),
      v => Xml.fail(st, "Invalid character in entity name")))

# Before the first tag: only whitespace may come.
def Xml.on_begin(+st: Xml.State, +x: U32) -> Xml.State:
  C.If(Xml.State, U32.is_eq(x, 60),
    u => Xml.to(st, 4),
    u => Bool.pick(Xml.State, Xml.is_ws(x), st, Xml.fail(st, "Non-whitespace before first tag.")))

def Xml.on_text(+st: Xml.State, +x: U32) -> Xml.State:
  C.If(Xml.State, U32.is_eq(x, 60),
    u => Xml.to(st, 4),
    u => C.If(Xml.State, Xml.inside(st),
      v => Bool.pick(Xml.State, U32.is_eq(x, 38), Xml.to(Xml.entity_set(st, SNil{}), 3), Xml.text_push(st, x)),
      v => Bool.pick(Xml.State, Xml.is_ws(x), st, Xml.fail(st, "Text data outside of root node."))))

# After `<`.
def Xml.on_waka(+st: Xml.State, +x: U32) -> Xml.State:
  C.If(Xml.State, U32.is_eq(x, 33),
    u => Xml.to(Xml.decl_set(st, SNil{}), 5),
    u => C.If(Xml.State, Xml.is_ws(x),
      v => st,
      v => C.If(Xml.State, Xml.name_start(x),
        w => Xml.to(Xml.name_set(st, SCon{Chr{x}, SNil{}}), 19),
        w => C.If(Xml.State, U32.is_eq(x, 47),
          y => Xml.to(Xml.name_set(st, SNil{}), 28),
          y => Bool.pick(Xml.State, U32.is_eq(x, 63), Xml.to(st, 17), Xml.fail(st, "Unencoded <"))))))

# After `<!`: a comment, a CDATA section, a DOCTYPE, or a declaration that
# runs to `>`. A quote in one never ends in sax (it compares with a quote it
# did not record), so the parse fails as it would at the end of the input.
def Xml.on_decl(+st: Xml.State, +x: U32) -> Xml.State:
  +decl = Xml.decl(st)
  +d = {SCon{Chr{Xml.upper(x)}, decl} : String}
  C.If(Xml.State, String.eq(decl, "-") && U32.is_eq(x, 45),
    u => Xml.to(st, 11),
    u => C.If(Xml.State, U32.is_eq(Xml.doctype(st), 1) && Bool.not(String.is_empty(decl)),
      v => Xml.to(st, 9),
      v => C.If(Xml.State, String.eq(d, "[ATADC["),
        w => Xml.to(Xml.cdata_set(st, SNil{}), 14),
        w => C.If(Xml.State, String.eq(d, "EPYTCOD"),
          y => Bool.pick(Xml.State, Bool.not(U32.is_zero(Xml.doctype(st))) || Xml.inside(st),
            Xml.fail(st, "Inappropriately located doctype declaration"), Xml.to(st, 7)),
          y => C.If(Xml.State, U32.is_eq(x, 62),
            z => Xml.to(st, 2),
            z => Bool.pick(Xml.State, Xml.is_quote(x),
              Xml.fail(st, Bool.pick(String, Xml.inside(st), "Unclosed root tag", "Unexpected end")),
              Xml.decl_set(st, d)))))))

def Xml.on_doctype(st: Xml.State, +x: U32) -> Xml.State:
  +open = Xml.doctype_set(st, 1)
  C.If(Xml.State, U32.is_eq(x, 62),
    u => Xml.to(Xml.doctype_set(open, 2), 2),
    u => C.If(Xml.State, U32.is_eq(x, 91),
      v => Xml.to(open, 9),
      v => Bool.pick(Xml.State, Xml.is_quote(x), Xml.to(Xml.q_set(open, x), 8), open)))

def Xml.on_dtd(+st: Xml.State, +x: U32) -> Xml.State:
  C.If(Xml.State, U32.is_eq(x, 93),
    u => Xml.to(st, 7),
    u => C.If(Xml.State, U32.is_eq(x, 60),
      v => Xml.to(st, 4),
      v => Bool.pick(Xml.State, Xml.is_quote(x), Xml.to(Xml.q_set(st, x), 10), st)))

# A quoted stretch of a DOCTYPE: the matching quote goes back to `back`.
def Xml.on_quoted(+st: Xml.State, x: U32, back: U32) -> Xml.State:
  Bool.pick(Xml.State, U32.is_eq(x, Xml.q(st)), Xml.to(Xml.q_set(st, 0), back), st)

def Xml.on_comment_end(+st: Xml.State, x: U32) -> Xml.State:
  C.If(Xml.State, U32.is_eq(x, 62),
    u => Xml.to(st, Bool.pick(U32, U32.is_eq(Xml.doctype(st), 1), 9, 2)),
    u => Xml.fail(st, "Malformed comment"))

def Xml.on_cdata(s: U32, +st: Xml.State, +x: U32) -> Xml.State:
  match s:
    case 14:
      Bool.pick(Xml.State, U32.is_eq(x, 93), Xml.to(st, 15),
        Xml.cdata_set(st, SCon{Chr{x}, Xml.get_cdata(st)}))
    case 15:
      Bool.pick(Xml.State, U32.is_eq(x, 93), Xml.to(st, 16),
        Xml.to(Xml.cdata_set(st, SCon{Chr{x}, SCon{']', Xml.get_cdata(st)}}), 14))
    case other:
      C.If(Xml.State, U32.is_eq(x, 62),
        u => Xml.cdata_done(st),
        u => Bool.pick(Xml.State, U32.is_eq(x, 93), Xml.cdata_set(st, SCon{']', Xml.get_cdata(st)}),
          Xml.to(Xml.cdata_set(st, SCon{Chr{x}, SCon{']', SCon{']', Xml.get_cdata(st)}}}), 14)))

def Xml.on_open_tag(+st: Xml.State, +x: U32) -> Xml.State:
  C.If(Xml.State, Xml.name_body(x),
    u => Xml.name_push(st, x),
    u => C.If(Xml.State, U32.is_eq(x, 62),
      v => Xml.open(st),
      v => C.If(Xml.State, U32.is_eq(x, 47),
        w => Xml.to(st, 20),
        w => Bool.pick(Xml.State, Xml.is_ws(x), Xml.to(st, 21), Xml.fail(st, "Invalid character in tag name")))))

def Xml.on_attrib(+st: Xml.State, +x: U32) -> Xml.State:
  C.If(Xml.State, Xml.is_ws(x),
    u => st,
    u => C.If(Xml.State, U32.is_eq(x, 62),
      v => Xml.open(st),
      v => C.If(Xml.State, U32.is_eq(x, 47),
        w => Xml.to(st, 20),
        w => Bool.pick(Xml.State, Xml.name_start(x), Xml.to(Xml.attr_set(st, x), 22),
          Xml.fail(st, "Invalid attribute name")))))

def Xml.on_attrib_name(+st: Xml.State, +x: U32) -> Xml.State:
  C.If(Xml.State, U32.is_eq(x, 61),
    u => Xml.to(st, 24),
    u => C.If(Xml.State, U32.is_eq(x, 62),
      v => Xml.fail(st, "Attribute without value"),
      v => C.If(Xml.State, Xml.is_ws(x),
        w => Xml.to(st, 23),
        w => Bool.pick(Xml.State, Xml.name_body(x), Xml.attr_push(st, x), Xml.fail(st, "Invalid attribute name")))))

def Xml.on_attrib_value(+st: Xml.State, +x: U32) -> Xml.State:
  C.If(Xml.State, U32.is_eq(x, Xml.q(st)),
    u => Xml.to(Xml.attr_done(st), 26),
    u => Bool.pick(Xml.State, U32.is_eq(x, 38), Xml.to(Xml.entity_set(st, SNil{}), 27), Xml.value_push(st, x)))

def Xml.on_attrib_closed(+st: Xml.State, +x: U32) -> Xml.State:
  C.If(Xml.State, Xml.is_ws(x),
    u => Xml.to(st, 21),
    u => C.If(Xml.State, U32.is_eq(x, 62),
      v => Xml.open(st),
      v => C.If(Xml.State, U32.is_eq(x, 47),
        w => Xml.to(st, 20),
        w => Xml.fail(st, Bool.pick(String, Xml.name_start(x), "No whitespace between attributes",
          "Invalid attribute name")))))

def Xml.on_close_tag(+trim: Bool, +st: Xml.State, +x: U32) -> Xml.State:
  C.If(Xml.State, String.is_empty(Xml.name(st)),
    u => C.If(Xml.State, Xml.is_ws(x),
      v => st,
      v => Bool.pick(Xml.State, Xml.name_start(x), Xml.name_push(st, x),
        Xml.fail(st, "Invalid tagname in closing tag."))),
    u => C.If(Xml.State, U32.is_eq(x, 62),
      v => Xml.close(trim, st),
      v => C.If(Xml.State, Xml.name_body(x),
        w => Xml.name_push(st, x),
        w => Bool.pick(Xml.State, Xml.is_ws(x), Xml.to(st, 29), Xml.fail(st, "Invalid tagname in closing tag")))))

# One character in sax state `s`:
#   0 BEGIN, 1 BEGIN_WHITESPACE, 2 TEXT, 3 TEXT_ENTITY, 4 OPEN_WAKA,
#   5 SGML_DECL, 7 DOCTYPE, 8 DOCTYPE_QUOTED, 9 DOCTYPE_DTD,
#   10 DOCTYPE_DTD_QUOTED, 11 COMMENT, 12 COMMENT_ENDING, 13 COMMENT_ENDED,
#   14 CDATA, 15 CDATA_ENDING, 16 CDATA_ENDING_2, 17 PROC_INST and
#   PROC_INST_BODY, 18 PROC_INST_ENDING, 19 OPEN_TAG, 20 OPEN_TAG_SLASH,
#   21 ATTRIB, 22 ATTRIB_NAME, 23 ATTRIB_NAME_SAW_WHITE, 24 ATTRIB_VALUE,
#   25 ATTRIB_VALUE_QUOTED, 26 ATTRIB_VALUE_CLOSED, 27 ATTRIB_VALUE_ENTITY_Q,
#   28 CLOSE_TAG, 29 CLOSE_TAG_SAW_WHITE.
def Xml.dispatch(+trim: Bool, s: U32, +st: Xml.State, +x: U32) -> Xml.State:
  match s:
    case 0:
      Bool.pick(Xml.State, U32.is_eq(x, 65279), Xml.to(st, 1), Xml.on_begin(Xml.to(st, 1), x))
    case 1:
      Xml.on_begin(st, x)
    case 2:
      Xml.on_text(st, x)
    case 3:
      Xml.on_entity(st, x, 2)
    case 4:
      Xml.on_waka(st, x)
    case 5:
      Xml.on_decl(st, x)
    case 7:
      Xml.on_doctype(st, x)
    case 8:
      Xml.on_quoted(st, x, 7)
    case 9:
      Xml.on_dtd(st, x)
    case 10:
      Xml.on_quoted(st, x, 9)
    case 11:
      Bool.pick(Xml.State, U32.is_eq(x, 45), Xml.to(st, 12), st)
    case 12:
      Xml.to(st, Bool.pick(U32, U32.is_eq(x, 45), 13, 11))
    case 13:
      Xml.on_comment_end(st, x)
    case 14:
      Xml.on_cdata(14, st, x)
    case 15:
      Xml.on_cdata(15, st, x)
    case 16:
      Xml.on_cdata(16, st, x)
    case 17:
      Bool.pick(Xml.State, U32.is_eq(x, 63), Xml.to(st, 18), st)
    case 18:
      Xml.to(st, Bool.pick(U32, U32.is_eq(x, 62), 2, 17))
    case 19:
      Xml.on_open_tag(st, x)
    case 20:
      C.If(Xml.State, U32.is_eq(x, 62),
        u => Xml.close(trim, Xml.open(st)),
        u => Xml.fail(st, "Forward-slash in opening tag not followed by >"))
    case 21:
      Xml.on_attrib(st, x)
    case 22:
      Xml.on_attrib_name(st, x)
    case 23:
      Bool.pick(Xml.State, U32.is_eq(x, 61), Xml.to(st, 24),
        Bool.pick(Xml.State, Xml.is_ws(x), st, Xml.fail(st, "Attribute without value")))
    case 24:
      Bool.pick(Xml.State, Xml.is_ws(x), st,
        Bool.pick(Xml.State, Xml.is_quote(x), Xml.to(Xml.q_set(st, x), 25), Xml.fail(st, "Unquoted attribute value")))
    case 25:
      Xml.on_attrib_value(st, x)
    case 26:
      Xml.on_attrib_closed(st, x)
    case 27:
      Xml.on_entity(st, x, 25)
    case 28:
      Xml.on_close_tag(trim, st, x)
    case 29:
      C.If(Xml.State, Xml.is_ws(x),
        u => st,
        u => C.If(Xml.State, U32.is_eq(x, 62),
          v => Xml.close(trim, st),
          v => Xml.fail(st, "Invalid characters in closing tag")))
    case other:
      st

# Feeds the text to the tokenizer until it ends, fails, or the root closes.
def Xml.run(text: String, +trim: Bool, st: Xml.State) -> Xml.State:
  match text st:
    case SCon{Chr{x}, t} State{Going{}, +s, tx, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      Xml.run(t, trim, Xml.dispatch(trim, s,
        State{Going{}, s, tx, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}, x))
    case _ other:
      other

# sax's `end`: an element still open, or anything but text in progress, is
# an error; a document without a root has no value.
def Xml.finish(st: Xml.State) -> Result<&2, &2, String, Maybe<&2, J.Json>>:
  match st:
    case State{Failed{m}, s, tx, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      Fail{m}
    case State{Finished{v}, s, tx, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      Done{Some{v}}
    case State{Going{}, s, tx, cd, name, attr, value, entity, q, decl, cdata, doctype, attrs, stack}:
      Bool.pick(Result<&2, &2, String, Maybe<&2, J.Json>>, Bool.not(List.is_empty(&2, Xml.Frame, stack)),
        Fail{"Unclosed root tag"},
        Bool.pick(Result<&2, &2, String, Maybe<&2, J.Json>>, (s <= 2 : U32), Done{None{}}, Fail{"Unexpected end"}))

def Xml.strip_bom(s: String) -> String:
  match s:
    case SCon{Chr{65279}, t}:
      t
    case other:
      other

def Xml.start() -> Xml.State:
  State{Going{}, 0, SNil{}, False{}, SNil{}, SNil{}, SNil{}, SNil{}, 0, SNil{}, SNil{}, 0, Nil{}, Nil{}}

# `parseStringPromise(text, { explicitArray: false, trim })`: the value of
# the document (None for a blank one), or the message of the error.
def Xml.parse(+text: String, trim: Bool) -> Result<&2, &2, String, Maybe<&2, J.Json>>:
  C.If(Result<&2, &2, String, Maybe<&2, J.Json>>, X.Js.is_blank(text),
    u => Done{None{}},
    u => Xml.finish(Xml.run(Xml.strip_bom(text), trim, Xml.start())))

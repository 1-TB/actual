# Tags in transaction notes (`#groceries`): a port of
# packages/loot-core/src/shared/tags.ts. The TS uses regular expressions with
# lookbehind; here each is a scan over the characters.
import Base
import ../lib/core.bend as C
import ../lib/text.bend as T
import ../json/json.bend as J

# xs with x at the end unless it is already there.
def Tags.add(xs: List<&2, String>, +x: String) -> List<&2, String>:
  match xs:
    case Nil{}:
      [x]
    case Con{+h, +t}:
      C.If(List<&2, String>, String.eq(h, x), u => Con{h, t}, u => Con{h, Tags.add(t, x)})

# Pushes the word collected so far (reversed), if any, as a tag.
def Tags.push(+tags: List<&2, String>, +rev: String, +prefix: String) -> List<&2, String>:
  C.If(List<&2, String>, String.is_empty(rev),
    u => tags,
    u => Tags.add(tags, prefix ++ String.reverse(rev)))

def Tags.filter.go(s: String, +rev: String, +tags: List<&2, String>) -> List<&2, String>:
  match s:
    case SNil{}:
      Tags.push(tags, rev, "#")
    case SCon{Chr{+x}, +t}:
      C.If(List<&2, String>, Bool.or(U32.is_eq(x, 35), T.Text.is_js_space(x)),
        u => Tags.filter.go(t, SNil{}, Tags.push(tags, rev, "#")),
        u => Tags.filter.go(t, SCon{Chr{x}, rev}, tags))

# The unique words of a text, each with a single `#` in front, whatever
# number of `#` they had: "one #one ##one ##two three" gives
# ["#one", "#two", "#three"]. `extractTagsForFilter`.
def Tags.extract_for_filter(value: String) -> List<&2, String>:
  Tags.filter.go(value, SNil{}, Nil{})

# Scans for `#word` where the `#` does not follow another `#`. `after_hash`
# says the previous character was a `#`; `in_tag` that a tag is being read,
# its characters so far reversed in `rev`.
def Tags.text.go(
  s: String, +after_hash: Bool, +in_tag: Bool, +rev: String, +tags: List<&2, String>
) -> List<&2, String>:
  match s:
    case SNil{}:
      Bool.pick(List<&2, String>, in_tag, Tags.push(tags, rev, ""), tags)
    case SCon{Chr{+x}, +t}:
      C.If(List<&2, String>, U32.is_eq(x, 35),
        # a `#` ends the tag being read and starts another, unless it follows
        # a `#`
        u => Tags.text.go(t, True{}, Bool.not(after_hash), SNil{},
          Bool.pick(List<&2, String>, in_tag, Tags.push(tags, rev, ""), tags)),
        u => C.If(List<&2, String>, T.Text.is_js_space(x),
          v => Tags.text.go(t, False{}, False{}, SNil{},
            Bool.pick(List<&2, String>, in_tag, Tags.push(tags, rev, ""), tags)),
          v => Tags.text.go(t, False{}, in_tag,
            Bool.pick(String, in_tag, SCon{Chr{x}, rev}, SNil{}), tags)))

# The unique tags of a text, without their `#`; a doubled `#` escapes a tag.
# `extractTagsFromText`.
def Tags.extract_from_text(value: String) -> List<&2, String>:
  Tags.text.go(value, False{}, False{}, SNil{}, Nil{})

# Whether the text at s ends a tag: the end, whitespace, or a `#`.
def Tags.at_boundary(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+x}, t}:
      Bool.or(U32.is_eq(x, 35), T.Text.is_js_space(x))

# Copies s, writing `to` over each `from` that does not follow a `#` and is
# followed by a tag boundary. `skip` counts the characters of a match still
# to drop.
def Tags.rename.go(s: String, +after_hash: Bool, skip: Nat, +from: String, +to: String) -> String:
  match s skip:
    case SNil{} _:
      SNil{}
    case SCon{Chr{+x}, t} 1n+p:
      Tags.rename.go(t, U32.is_eq(x, 35), p, from, to)
    case SCon{Chr{+x}, +t} 0n:
      C.If(String,
        Bool.and(Bool.not(after_hash), Bool.and(String.starts_with(SCon{Chr{x}, t}, from),
          Tags.at_boundary(String.drop(SCon{Chr{x}, t}, String.length(from))))),
        u => to ++ Tags.rename.go(t, U32.is_eq(x, 35), Nat.sub(String.length(from), 1n), from, to),
        u => SCon{Chr{x}, Tags.rename.go(t, U32.is_eq(x, 35), 0n, from, to)})

# Renames a tag wherever it stands as a whole tag in the notes; matching is
# case sensitive. `renameTagInNotes`.
def Tags.rename_in_notes(notes: String, old_tag: String, new_tag: String) -> String:
  Tags.rename.go(notes, False{}, 0n, "#" ++ old_tag, "#" ++ new_tag)

def Tags.escape.chr(+x: U32) -> String:
  match x:
    case 36:
      "[$]"
    case other:
      Bool.pick(String,
        U32.is_eq(x, 46) || U32.is_eq(x, 42) || U32.is_eq(x, 43) || U32.is_eq(x, 63) ||
          U32.is_eq(x, 94) || U32.is_eq(x, 123) || U32.is_eq(x, 125) || U32.is_eq(x, 40) ||
          U32.is_eq(x, 41) || U32.is_eq(x, 124) || U32.is_eq(x, 91) || U32.is_eq(x, 93) ||
          U32.is_eq(x, 92),
        SCon{'\\', SCon{Chr{x}, SNil{}}}, SCon{Chr{x}, SNil{}})

# Escapes the characters special to a regular expression; `$` becomes `[$]`
# because AQL unescapes `\$`.
def Tags.escape(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{x}, t}:
      Tags.escape.chr(x) ++ Tags.escape(t)

def Tags.with_hash(tag: String) -> String:
  match tag:
    case SCon{'#', t}:
      SCon{'#', t}
    case other:
      SCon{'#', other}

# The regular expression AQL uses to find a tag in notes. `makeTagAqlRegex`.
def Tags.aql_regex(tag: String) -> String:
  "(^|[^#])" ++ Tags.escape(Tags.with_hash(tag)) ++ "([\\s#]|$)"

def Tags.has(xs: List<&2, String>, +x: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{h, t}:
      Bool.or(String.eq(h, x), Tags.has(t, x))

def Tags.clause(op: String, tag: String) -> J.Json:
  J.Json.object([J.Member{"notes", J.Json.object([J.Member{op, J.JStr{Tags.aql_regex(tag)}}])}])

def Tags.included(tags: List<&2, String>) -> List<&2, J.Json>:
  match tags:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{Tags.clause("$regexp", h), Tags.included(t)}

def Tags.excluded(scope: List<&2, String>, +bucket: List<&2, String>) -> List<&2, J.Json>:
  match scope:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      List.append(&2, J.Json,
        Bool.pick(List<&2, J.Json>, Tags.has(bucket, h), Nil{}, [Tags.clause("$notregexp", h)]),
        Tags.excluded(t, bucket))

# The AQL filter for transactions whose notes carry every tag of the bucket
# and none of the other tags in scope. `makeExactTagSetQueryFilter`.
def Tags.exact_set_filter(+bucket: List<&2, String>, scope: List<&2, String>) -> J.Json:
  J.Json.object([J.Member{"$and", J.Json.array(
    List.append(&2, J.Json, Tags.included(bucket), Tags.excluded(scope, bucket)))}])

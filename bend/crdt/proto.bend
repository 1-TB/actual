# The protocol buffer messages clients and the sync server exchange: a port of
# packages/crdt/src/proto/sync.proto and of the generated sync_pb.ts, with the
# wire-format encoder and decoder that protobuf-es supplies in TypeScript.
#
# Bytes are a list of U32, one byte each. Encoding writes fields in field
# number order and leaves out proto3 defaults (empty strings and bytes,
# false), so the bytes equal protobuf-es's. Decoding accepts fields in any
# order, keeps the last value of a repeated scalar field, and skips unknown
# fields. Varints past 2^42 and the deprecated group wire types are refused.
import Base
import ../lib/core.bend as C
import ../lib/text.bend as T

def Bytes() -> Data:
  List<&2, U32>

type EncryptedData is Data:
  EncryptedData{iv: Bytes(), auth_tag: Bytes(), data: Bytes()}

type Message is Data:
  Message{dataset: String, row: String, column: String, value: String}

type MessageEnvelope is Data:
  MessageEnvelope{timestamp: String, is_encrypted: Bool, content: Bytes()}

type SyncRequest is Data:
  SyncRequest{messages: List<&2, MessageEnvelope>, file_id: String, group_id: String,
    key_id: String, since: String}

type SyncResponse is Data:
  SyncResponse{messages: List<&2, MessageEnvelope>, merkle: String}

# Writing
# -------

# A base-128 varint, least significant group first.
def Proto.varint.go(fuel: Nat, +n: Nat) -> Bytes():
  match fuel:
    case 0n:
      Nil{}
    case 1n+f:
      C.If(Bytes(), Nat.is_lt(n, 128n),
        u => [U32.from_nat(n)],
        u => Con{U32.from_nat((Nat.mod(n, 128n) + 128n : Nat)), Proto.varint.go(f, Nat.div(n, 128n))})

def Proto.varint(n: Nat) -> Bytes():
  Proto.varint.go(8n, n)

# A field's key: its number and wire type.
def Proto.key(field: Nat, wire: Nat) -> Bytes():
  Proto.varint((field * 8n + wire : Nat))

# A length-delimited field; nothing when the payload is empty.
def Proto.bytes_field(field: Nat, +payload: Bytes()) -> Bytes():
  match payload:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      List.append(&2, U32, Proto.key(field, 2n),
        List.append(&2, U32, Proto.varint(List.length(&2, U32, payload)), payload))

# A length-delimited field that is written even when empty: an embedded
# message is present whatever it holds.
def Proto.message_field(field: Nat, +payload: Bytes()) -> Bytes():
  List.append(&2, U32, Proto.key(field, 2n),
    List.append(&2, U32, Proto.varint(List.length(&2, U32, payload)), payload))

def Proto.string_field(field: Nat, s: String) -> Bytes():
  Proto.bytes_field(field, T.Text.utf8(s))

def Proto.bool_field(field: Nat, b: Bool) -> Bytes():
  match b:
    case False{}:
      Nil{}
    case True{}:
      List.append(&2, U32, Proto.key(field, 0n), [1])

def EncryptedData.encode(m: EncryptedData) -> Bytes():
  match m:
    case EncryptedData{iv, auth_tag, data}:
      List.concat(&2, U32, [Proto.bytes_field(1n, iv), Proto.bytes_field(2n, auth_tag),
        Proto.bytes_field(3n, data)])

def Message.encode(m: Message) -> Bytes():
  match m:
    case Message{dataset, row, column, value}:
      List.concat(&2, U32, [Proto.string_field(1n, dataset), Proto.string_field(2n, row),
        Proto.string_field(3n, column), Proto.string_field(4n, value)])

def MessageEnvelope.encode(m: MessageEnvelope) -> Bytes():
  match m:
    case MessageEnvelope{timestamp, is_encrypted, content}:
      List.concat(&2, U32, [Proto.string_field(1n, timestamp), Proto.bool_field(2n, is_encrypted),
        Proto.bytes_field(3n, content)])

def Proto.envelopes(ms: List<&2, MessageEnvelope>) -> Bytes():
  match ms:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      List.append(&2, U32, Proto.message_field(1n, MessageEnvelope.encode(h)), Proto.envelopes(t))

def SyncRequest.encode(m: SyncRequest) -> Bytes():
  match m:
    case SyncRequest{messages, file_id, group_id, key_id, since}:
      List.concat(&2, U32, [Proto.envelopes(messages), Proto.string_field(2n, file_id),
        Proto.string_field(3n, group_id), Proto.string_field(5n, key_id),
        Proto.string_field(6n, since)])

def SyncResponse.encode(m: SyncResponse) -> Bytes():
  match m:
    case SyncResponse{messages, merkle}:
      List.append(&2, U32, Proto.envelopes(messages), Proto.string_field(2n, merkle))

# Reading
# -------

# A value read from the head of some bytes, and the bytes after it.
type Proto.Read is Data:
  Read{value: Nat, rest: Bytes()}

# One field of a message: its number, its wire type, and either its varint
# value or its payload bytes.
type Proto.Field is Data:
  Field{number: Nat, wire: Nat, value: Nat, payload: Bytes()}

def Proto.read_varint.put(low: Nat, r: Maybe<&2, Proto.Read>) -> Maybe<&2, Proto.Read>:
  match r:
    case None{}:
      None{}
    case Some{Read{high, rest}}:
      Some{Read{(high * 128n + low : Nat), rest}}

# Reads a varint of at most six groups (42 bits).
def Proto.read_varint.go(fuel: Nat, bytes: Bytes()) -> Maybe<&2, Proto.Read>:
  match fuel bytes:
    case 0n _:
      None{}
    case 1n+f Nil{}:
      None{}
    case 1n+f Con{+b, +t}:
      C.If(Maybe<&2, Proto.Read>, (b < 128 : U32),
        u => Some{Read{U32.to_nat(b), t}},
        u => Proto.read_varint.put(U32.to_nat((b .&. 127 : U32)), Proto.read_varint.go(f, t)))

def Proto.read_varint(bytes: Bytes()) -> Maybe<&2, Proto.Read>:
  Proto.read_varint.go(6n, bytes)

# A field read from the head of some bytes, and the bytes after it.
type Proto.Step is Data:
  Step{field: Proto.Field, rest: Bytes()}

# Takes n bytes as the payload of a field.
def Proto.take(+number: Nat, +wire: Nat, +n: Nat, +bytes: Bytes()) -> Maybe<&2, Proto.Step>:
  C.If(Maybe<&2, Proto.Step>, Nat.is_le(n, List.length(&2, U32, bytes)),
    u => Some{Step{Field{number, wire, 0n, List.take(&2, U32, bytes, n)}, List.drop(&2, U32, bytes, n)}},
    u => None{})

def Proto.field.varint(number: Nat, r: Maybe<&2, Proto.Read>) -> Maybe<&2, Proto.Step>:
  match r:
    case None{}:
      None{}
    case Some{Read{value, rest}}:
      Some{Step{Field{number, 0n, value, Nil{}}, rest}}

def Proto.field.sized(number: Nat, r: Maybe<&2, Proto.Read>) -> Maybe<&2, Proto.Step>:
  match r:
    case None{}:
      None{}
    case Some{Read{size, rest}}:
      Proto.take(number, 2n, size, rest)

# Reads the value of a field by its wire type: 0 a varint, 1 eight bytes,
# 2 a length and that many bytes, 5 four bytes.
def Proto.field.body(number: Nat, wire: Nat, rest: Bytes()) -> Maybe<&2, Proto.Step>:
  match wire:
    case 0n:
      Proto.field.varint(number, Proto.read_varint(rest))
    case 1n:
      Proto.take(number, 1n, 8n, rest)
    case 2n:
      Proto.field.sized(number, Proto.read_varint(rest))
    case 5n:
      Proto.take(number, 5n, 4n, rest)
    case other:
      None{}

def Proto.field.key(r: Maybe<&2, Proto.Read>) -> Maybe<&2, Proto.Step>:
  match r:
    case None{}:
      None{}
    case Some{Read{+key, rest}}:
      Proto.field.body(Nat.div(key, 8n), Nat.mod(key, 8n), rest)

# Reads one field from the head of some bytes.
def Proto.field(bytes: Bytes()) -> Maybe<&2, Proto.Step>:
  Proto.field.key(Proto.read_varint(bytes))

def Proto.fields.put(f: Proto.Field, r: Maybe<&2, List<&2, Proto.Field>>) -> Maybe<&2, List<&2, Proto.Field>>:
  match r:
    case None{}:
      None{}
    case Some{fs}:
      Some{Con{f, fs}}

def Proto.fields.then(
  step: Maybe<&2, Proto.Step>, more: Bytes() -> Maybe<&2, List<&2, Proto.Field>>
) -> Maybe<&2, List<&2, Proto.Field>>:
  match step:
    case None{}:
      None{}
    case Some{Step{f, rest}}:
      Proto.fields.put(f, more(rest))

def Proto.fields.go(+fuel: Nat, bytes: Bytes()) -> Maybe<&2, List<&2, Proto.Field>>:
  match fuel bytes:
    case _ Nil{}:
      Some{Nil{}}
    case 0n other:
      None{}
    case 1n+f Con{h, t}:
      Proto.fields.then(Proto.field(Con{h, t}), rest => Proto.fields.go(f, rest))

# The fields of an encoded message, in order; None when the bytes are not a
# well-formed message.
def Proto.fields(+bytes: Bytes()) -> Maybe<&2, List<&2, Proto.Field>>:
  Proto.fields.go(List.length(&2, U32, bytes), bytes)

def EncryptedData.read(fs: List<&2, Proto.Field>, m: EncryptedData) -> EncryptedData:
  match fs m:
    case Nil{} acc:
      acc
    case Con{Field{1n, 2n, v, p}, t} EncryptedData{iv, auth_tag, data}:
      EncryptedData.read(t, EncryptedData{p, auth_tag, data})
    case Con{Field{2n, 2n, v, p}, t} EncryptedData{iv, auth_tag, data}:
      EncryptedData.read(t, EncryptedData{iv, p, data})
    case Con{Field{3n, 2n, v, p}, t} EncryptedData{iv, auth_tag, data}:
      EncryptedData.read(t, EncryptedData{iv, auth_tag, p})
    case Con{other, t} acc:
      EncryptedData.read(t, acc)

def EncryptedData.decode(bytes: Bytes()) -> Maybe<&2, EncryptedData>:
  Maybe.map(&2, List<&2, Proto.Field>, EncryptedData,
    fs => EncryptedData.read(fs, EncryptedData{Nil{}, Nil{}, Nil{}}), Proto.fields(bytes))

def Message.read(fs: List<&2, Proto.Field>, m: Message) -> Message:
  match fs m:
    case Nil{} acc:
      acc
    case Con{Field{1n, 2n, v, p}, t} Message{dataset, row, column, value}:
      Message.read(t, Message{T.Text.from_utf8(p), row, column, value})
    case Con{Field{2n, 2n, v, p}, t} Message{dataset, row, column, value}:
      Message.read(t, Message{dataset, T.Text.from_utf8(p), column, value})
    case Con{Field{3n, 2n, v, p}, t} Message{dataset, row, column, value}:
      Message.read(t, Message{dataset, row, T.Text.from_utf8(p), value})
    case Con{Field{4n, 2n, v, p}, t} Message{dataset, row, column, value}:
      Message.read(t, Message{dataset, row, column, T.Text.from_utf8(p)})
    case Con{other, t} acc:
      Message.read(t, acc)

def Message.decode(bytes: Bytes()) -> Maybe<&2, Message>:
  Maybe.map(&2, List<&2, Proto.Field>, Message,
    fs => Message.read(fs, Message{"", "", "", ""}), Proto.fields(bytes))

def MessageEnvelope.read(fs: List<&2, Proto.Field>, m: MessageEnvelope) -> MessageEnvelope:
  match fs m:
    case Nil{} acc:
      acc
    case Con{Field{1n, 2n, v, p}, t} MessageEnvelope{timestamp, is_encrypted, content}:
      MessageEnvelope.read(t, MessageEnvelope{T.Text.from_utf8(p), is_encrypted, content})
    case Con{Field{2n, 0n, v, p}, t} MessageEnvelope{timestamp, is_encrypted, content}:
      MessageEnvelope.read(t, MessageEnvelope{timestamp, Nat.is_ne(v, 0n), content})
    case Con{Field{3n, 2n, v, p}, t} MessageEnvelope{timestamp, is_encrypted, content}:
      MessageEnvelope.read(t, MessageEnvelope{timestamp, is_encrypted, p})
    case Con{other, t} acc:
      MessageEnvelope.read(t, acc)

def MessageEnvelope.decode(bytes: Bytes()) -> Maybe<&2, MessageEnvelope>:
  Maybe.map(&2, List<&2, Proto.Field>, MessageEnvelope,
    fs => MessageEnvelope.read(fs, MessageEnvelope{"", False{}, Nil{}}), Proto.fields(bytes))

def Proto.envelope.put(
  m: Maybe<&2, MessageEnvelope>, r: Maybe<&2, List<&2, MessageEnvelope>>
) -> Maybe<&2, List<&2, MessageEnvelope>>:
  match m r:
    case Some{e} Some{es}:
      Some{Con{e, es}}
    case a b:
      None{}

# The envelopes in field 1 of a message, in order; None when one of them is
# malformed.
def Proto.read_envelopes(fs: List<&2, Proto.Field>) -> Maybe<&2, List<&2, MessageEnvelope>>:
  match fs:
    case Nil{}:
      Some{Nil{}}
    case Con{Field{1n, 2n, v, p}, t}:
      Proto.envelope.put(MessageEnvelope.decode(p), Proto.read_envelopes(t))
    case Con{other, t}:
      Proto.read_envelopes(t)

def SyncRequest.read(fs: List<&2, Proto.Field>, m: SyncRequest) -> SyncRequest:
  match fs m:
    case Nil{} acc:
      acc
    case Con{Field{2n, 2n, v, p}, t} SyncRequest{messages, file_id, group_id, key_id, since}:
      SyncRequest.read(t, SyncRequest{messages, T.Text.from_utf8(p), group_id, key_id, since})
    case Con{Field{3n, 2n, v, p}, t} SyncRequest{messages, file_id, group_id, key_id, since}:
      SyncRequest.read(t, SyncRequest{messages, file_id, T.Text.from_utf8(p), key_id, since})
    case Con{Field{5n, 2n, v, p}, t} SyncRequest{messages, file_id, group_id, key_id, since}:
      SyncRequest.read(t, SyncRequest{messages, file_id, group_id, T.Text.from_utf8(p), since})
    case Con{Field{6n, 2n, v, p}, t} SyncRequest{messages, file_id, group_id, key_id, since}:
      SyncRequest.read(t, SyncRequest{messages, file_id, group_id, key_id, T.Text.from_utf8(p)})
    case Con{other, t} acc:
      SyncRequest.read(t, acc)

def SyncRequest.decode.with(+fs: List<&2, Proto.Field>) -> Maybe<&2, SyncRequest>:
  Maybe.map(&2, List<&2, MessageEnvelope>, SyncRequest,
    ms => SyncRequest.read(fs, SyncRequest{ms, "", "", "", ""}), Proto.read_envelopes(fs))

def SyncRequest.decode(bytes: Bytes()) -> Maybe<&2, SyncRequest>:
  Maybe.bind(&2, List<&2, Proto.Field>, SyncRequest, Proto.fields(bytes), fs => SyncRequest.decode.with(fs))

def SyncResponse.read(fs: List<&2, Proto.Field>, m: SyncResponse) -> SyncResponse:
  match fs m:
    case Nil{} acc:
      acc
    case Con{Field{2n, 2n, v, p}, t} SyncResponse{messages, merkle}:
      SyncResponse.read(t, SyncResponse{messages, T.Text.from_utf8(p)})
    case Con{other, t} acc:
      SyncResponse.read(t, acc)

def SyncResponse.decode.with(+fs: List<&2, Proto.Field>) -> Maybe<&2, SyncResponse>:
  Maybe.map(&2, List<&2, MessageEnvelope>, SyncResponse,
    ms => SyncResponse.read(fs, SyncResponse{ms, ""}), Proto.read_envelopes(fs))

def SyncResponse.decode(bytes: Bytes()) -> Maybe<&2, SyncResponse>:
  Maybe.bind(&2, List<&2, Proto.Field>, SyncResponse, Proto.fields(bytes), fs => SyncResponse.decode.with(fs))

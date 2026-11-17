# Tests for proto.bend. The expected bytes, in hexadecimal, are what
# protobuf-es writes for the same message (`toBinary`); each "decodes" check
# reads those bytes back and encodes the result again.
import Base
import ../lib/test.bend as T
import ./proto.bend as P

def digit(+d: U32) -> Char:
  Chr{(d + 48 + Bool.to_u32((d > 9 : U32)) * 39 : U32)}

def to_hex(bytes: List<&2, U32>) -> String:
  match bytes:
    case Nil{}:
      SNil{}
    case Con{+b, t}:
      SCon{digit((b >> 4n : U32)), SCon{digit((b .&. 15 : U32)), to_hex(t)}}

def value(+x: U32) -> U32:
  Bool.pick(U32, (x <= 57 : U32), (x - 48 : U32), (x - 87 : U32))

def hex(s: String) -> List<&2, U32>:
  match s:
    case SCon{Chr{a}, SCon{Chr{b}, t}}:
      Con{(value(a) * 16 + value(b) : U32), hex(t)}
    case other:
      Nil{}

def message(m: Maybe<&2, P.Message>) -> String:
  match m:
    case None{}:
      "invalid"
    case Some{v}:
      to_hex(P.Message.encode(v))

def encrypted(m: Maybe<&2, P.EncryptedData>) -> String:
  match m:
    case None{}:
      "invalid"
    case Some{v}:
      to_hex(P.EncryptedData.encode(v))

def envelope(m: Maybe<&2, P.MessageEnvelope>) -> String:
  match m:
    case None{}:
      "invalid"
    case Some{v}:
      to_hex(P.MessageEnvelope.encode(v))

def request(m: Maybe<&2, P.SyncRequest>) -> String:
  match m:
    case None{}:
      "invalid"
    case Some{v}:
      to_hex(P.SyncRequest.encode(v))

def response(m: Maybe<&2, P.SyncResponse>) -> String:
  match m:
    case None{}:
      "invalid"
    case Some{v}:
      to_hex(P.SyncResponse.encode(v))

def main() -> IO(Unit):
  T.Test.run([
    T.Check{"Message 0 encodes", to_hex(P.Message.encode(P.Message{"transactions", "abc-123", "amount", "N:1250"})), "0a0c7472616e73616374696f6e7312076162632d3132331a06616d6f756e7422064e3a31323530"},
    T.Check{"Message 0 decodes", message(P.Message.decode(hex("0a0c7472616e73616374696f6e7312076162632d3132331a06616d6f756e7422064e3a31323530"))), to_hex(P.Message.encode(P.Message{"transactions", "abc-123", "amount", "N:1250"}))},
    T.Check{"Message 1 encodes", to_hex(P.Message.encode(P.Message{"", "", "", ""})), ""},
    T.Check{"Message 1 decodes", message(P.Message.decode(hex(""))), to_hex(P.Message.encode(P.Message{"", "", "", ""}))},
    T.Check{"Message 2 encodes", to_hex(P.Message.encode(P.Message{"payees", "r", "name", "S:Café €5 😀"})), "0a067061796565731201721a046e616d652211533a436166c3a920e282ac3520f09f9880"},
    T.Check{"Message 2 decodes", message(P.Message.decode(hex("0a067061796565731201721a046e616d652211533a436166c3a920e282ac3520f09f9880"))), to_hex(P.Message.encode(P.Message{"payees", "r", "name", "S:Café €5 😀"}))},
    T.Check{"Message 3 encodes", to_hex(P.Message.encode(P.Message{"d", "", "c", "0:"})), "0a01641a01632202303a"},
    T.Check{"Message 3 decodes", message(P.Message.decode(hex("0a01641a01632202303a"))), to_hex(P.Message.encode(P.Message{"d", "", "c", "0:"}))},
    T.Check{"EncryptedData 0 encodes", to_hex(P.EncryptedData.encode(P.EncryptedData{hex("000102"), hex("ffee"), hex("deadbeef")})), "0a030001021202ffee1a04deadbeef"},
    T.Check{"EncryptedData 0 decodes", encrypted(P.EncryptedData.decode(hex("0a030001021202ffee1a04deadbeef"))), "0a030001021202ffee1a04deadbeef"},
    T.Check{"EncryptedData 1 encodes", to_hex(P.EncryptedData.encode(P.EncryptedData{hex(""), hex(""), hex("")})), ""},
    T.Check{"EncryptedData 1 decodes", encrypted(P.EncryptedData.decode(hex(""))), ""},
    T.Check{"EncryptedData 2 encodes", to_hex(P.EncryptedData.encode(P.EncryptedData{hex("aaaaaaaaaaaaaaaaaaaaaaaa"), hex("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"), hex("cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc")})), "0a0caaaaaaaaaaaaaaaaaaaaaaaa1210bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1ac801cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"},
    T.Check{"EncryptedData 2 decodes", encrypted(P.EncryptedData.decode(hex("0a0caaaaaaaaaaaaaaaaaaaaaaaa1210bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1ac801cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"))), "0a0caaaaaaaaaaaaaaaaaaaaaaaa1210bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1ac801cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"},
    T.Check{"MessageEnvelope 0 encodes", to_hex(P.MessageEnvelope.encode(P.MessageEnvelope{"2015-04-24T22:23:42.123Z-1000-0123456789ABCDEF", False{}, hex("0a0c7472616e73616374696f6e7312076162632d3132331a06616d6f756e7422064e3a31323530")})), "0a2e323031352d30342d32345432323a32333a34322e3132335a2d313030302d303132333435363738394142434445461a270a0c7472616e73616374696f6e7312076162632d3132331a06616d6f756e7422064e3a31323530"},
    T.Check{"MessageEnvelope 0 decodes", envelope(P.MessageEnvelope.decode(hex("0a2e323031352d30342d32345432323a32333a34322e3132335a2d313030302d303132333435363738394142434445461a270a0c7472616e73616374696f6e7312076162632d3132331a06616d6f756e7422064e3a31323530"))), "0a2e323031352d30342d32345432323a32333a34322e3132335a2d313030302d303132333435363738394142434445461a270a0c7472616e73616374696f6e7312076162632d3132331a06616d6f756e7422064e3a31323530"},
    T.Check{"MessageEnvelope 1 encodes", to_hex(P.MessageEnvelope.encode(P.MessageEnvelope{"", True{}, hex("00ff10")})), "10011a0300ff10"},
    T.Check{"MessageEnvelope 1 decodes", envelope(P.MessageEnvelope.decode(hex("10011a0300ff10"))), "10011a0300ff10"},
    T.Check{"MessageEnvelope 2 encodes", to_hex(P.MessageEnvelope.encode(P.MessageEnvelope{"t", False{}, hex("")})), "0a0174"},
    T.Check{"MessageEnvelope 2 decodes", envelope(P.MessageEnvelope.decode(hex("0a0174"))), "0a0174"},
    T.Check{"SyncRequest 0 encodes", to_hex(P.SyncRequest.encode(P.SyncRequest{[P.MessageEnvelope{"2015-04-24T22:23:42.123Z-1000-0123456789ABCDEF", False{}, hex("0a0c7472616e73616374696f6e7312076162632d3132331a06616d6f756e7422064e3a31323530")}, P.MessageEnvelope{"", True{}, hex("00ff10")}, P.MessageEnvelope{"t", False{}, hex("")}], "file-1", "group-1", "key", "2015-04-24T22:23:42.123Z-0000-0000000000000000"})), "0a590a2e323031352d30342d32345432323a32333a34322e3132335a2d313030302d303132333435363738394142434445461a270a0c7472616e73616374696f6e7312076162632d3132331a06616d6f756e7422064e3a313235300a0710011a0300ff100a030a0174120666696c652d311a0767726f75702d312a036b6579322e323031352d30342d32345432323a32333a34322e3132335a2d303030302d30303030303030303030303030303030"},
    T.Check{"SyncRequest 0 decodes", request(P.SyncRequest.decode(hex("0a590a2e323031352d30342d32345432323a32333a34322e3132335a2d313030302d303132333435363738394142434445461a270a0c7472616e73616374696f6e7312076162632d3132331a06616d6f756e7422064e3a313235300a0710011a0300ff100a030a0174120666696c652d311a0767726f75702d312a036b6579322e323031352d30342d32345432323a32333a34322e3132335a2d303030302d30303030303030303030303030303030"))), "0a590a2e323031352d30342d32345432323a32333a34322e3132335a2d313030302d303132333435363738394142434445461a270a0c7472616e73616374696f6e7312076162632d3132331a06616d6f756e7422064e3a313235300a0710011a0300ff100a030a0174120666696c652d311a0767726f75702d312a036b6579322e323031352d30342d32345432323a32333a34322e3132335a2d303030302d30303030303030303030303030303030"},
    T.Check{"SyncRequest 1 encodes", to_hex(P.SyncRequest.encode(P.SyncRequest{[], "", "", "", ""})), ""},
    T.Check{"SyncRequest 1 decodes", request(P.SyncRequest.decode(hex(""))), ""},
    T.Check{"SyncRequest 2 encodes", to_hex(P.SyncRequest.encode(P.SyncRequest{[P.MessageEnvelope{"t", False{}, hex("")}, P.MessageEnvelope{"t", False{}, hex("")}], "f", "", "", "s"})), "0a030a01740a030a0174120166320173"},
    T.Check{"SyncRequest 2 decodes", request(P.SyncRequest.decode(hex("0a030a01740a030a0174120166320173"))), "0a030a01740a030a0174120166320173"},
    T.Check{"SyncResponse 0 encodes", to_hex(P.SyncResponse.encode(P.SyncResponse{[P.MessageEnvelope{"2015-04-24T22:23:42.123Z-1000-0123456789ABCDEF", False{}, hex("0a0c7472616e73616374696f6e7312076162632d3132331a06616d6f756e7422064e3a31323530")}, P.MessageEnvelope{"", True{}, hex("00ff10")}, P.MessageEnvelope{"t", False{}, hex("")}], "{\"hash\":123}"})), "0a590a2e323031352d30342d32345432323a32333a34322e3132335a2d313030302d303132333435363738394142434445461a270a0c7472616e73616374696f6e7312076162632d3132331a06616d6f756e7422064e3a313235300a0710011a0300ff100a030a0174120c7b2268617368223a3132337d"},
    T.Check{"SyncResponse 0 decodes", response(P.SyncResponse.decode(hex("0a590a2e323031352d30342d32345432323a32333a34322e3132335a2d313030302d303132333435363738394142434445461a270a0c7472616e73616374696f6e7312076162632d3132331a06616d6f756e7422064e3a313235300a0710011a0300ff100a030a0174120c7b2268617368223a3132337d"))), "0a590a2e323031352d30342d32345432323a32333a34322e3132335a2d313030302d303132333435363738394142434445461a270a0c7472616e73616374696f6e7312076162632d3132331a06616d6f756e7422064e3a313235300a0710011a0300ff100a030a0174120c7b2268617368223a3132337d"},
    T.Check{"SyncResponse 1 encodes", to_hex(P.SyncResponse.encode(P.SyncResponse{[], ""})), ""},
    T.Check{"SyncResponse 1 decodes", response(P.SyncResponse.decode(hex(""))), ""},
    T.Check{"unknown varint field", message(P.Message.decode(hex("0a01613805120162"))), "0a0161120162"},
    T.Check{"unknown bytes, fixed32 and fixed64 fields", message(P.Message.decode(hex("4a030102035d01020304610102030405060708220176"))), "220176"},
    T.Check{"fields out of order", message(P.Message.decode(hex("2201760a0164"))), "0a0164220176"},
    T.Check{"repeated scalar: last wins", message(P.Message.decode(hex("0a01610a0162"))), "0a0162"},
    T.Check{"malformed: truncated length", message(P.Message.decode(hex("0a056162"))), "invalid"},
    T.Check{"malformed: truncated varint", message(P.Message.decode(hex("0a"))), "invalid"},
    T.Check{"malformed: group wire type", message(P.Message.decode(hex("0b"))), "invalid"},
    T.Check{"malformed: key only", message(P.Message.decode(hex("08"))), "invalid"} ])

# The datatypes that stand for the classes of
# packages/loot-core/src/server/rules/: `RuleError` (server/errors.ts),
# `Condition` (condition.ts), `Action` (action.ts) and `Rule` (rule.ts). They
# sit in one file because the TS modules import each other in a cycle
# (rule-utils.ts needs `Rule`, condition.ts needs rule-utils.ts), which Bend
# imports cannot do. The functions over them are in the files named after the
# TS modules.
import Base
import ../lib/num.bend as N
import ./value.bend as V

# `new RuleError(kind, message)`; `kind` is the TS field `type`. The JS
# `Error.message` is "RuleError: " followed by `message`.
type RuleError is Data:
  RuleError{kind: String, message: String}

# The parsed value of a condition (`Condition.value`).
type Parsed is Data:
  # { type: 'date' | 'month' | 'year', date }
  PDate{kind: String, date: String}
  # { type: 'literal', value }
  PLiteral{value: N.Num}
  # { type: 'between', num1, num2 }
  PBetween{num1: N.Num, num2: N.Num}
  # a string, an id, a boolean or an array, as it is
  PValue{value: V.Value}

# `kind` is the TS field `type`, `raw` is `rawValue`, `unparsed` is
# `unparsedValue`.
type Condition is Data:
  Cond{op: String, field: String, value: Parsed, raw: V.Value, unparsed: V.Value, options: V.Value, kind: String}

# `field` and `kind` (the TS `type`) are values because the TS leaves them
# null or undefined for some operations.
type Action is Data:
  Act{op: String, field: V.Value, value: V.Value, raw: V.Value, options: V.Value, kind: V.Value}

type Rule is Data:
  Rule{id: V.Value, stage: V.Value, conditions_op: V.Value, conditions: List<&2, Condition>, actions: List<&2, Action>}

def RuleError.message(e: RuleError) -> String:
  match e:
    case RuleError{kind, message}:
      "RuleError: " ++ message

# The error's type, then its JS message.
def RuleError.show(e: RuleError) -> String:
  match e:
    case RuleError{kind, message}:
      kind ++ ": RuleError: " ++ message

# `Condition.getValue()` as the JS object it is.
def Parsed.to_value(p: Parsed) -> V.Value:
  match p:
    case PDate{kind, date}:
      V.Value.object([V.Field{"type", V.VStr{kind}}, V.Field{"date", V.VStr{date}}])
    case PLiteral{value}:
      V.Value.object([V.Field{"type", V.VStr{"literal"}}, V.Field{"value", V.VNum{value}}])
    case PBetween{num1, num2}:
      V.Value.object([V.Field{"type", V.VStr{"between"}}, V.Field{"num1", V.VNum{num1}}, V.Field{"num2", V.VNum{num2}}])
    case PValue{value}:
      value

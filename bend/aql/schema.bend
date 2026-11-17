# The table schema and the schema config of Actual:
# packages/loot-core/src/server/aql/schema/index.ts.
#
# Deviations: `schemaConfig`'s functions are defs here (`Actual.table_view`
# is `tableViews`, `Actual.customize_query` is `customizeQuery`) and the
# config value only says to use them. Each view function of
# `schemaConfig.views` is the SQL before and after its field list plus the
# overrides it passes (see types.bend). The tables and views below are
# generated from the TS module (scratchpad aql/gen_schema.ts).
import Base
import ../json/json.bend as J
import ../lib/core.bend as C
import ./js.bend as V
import ./types.bend as S
import ./query.bend as Q

# `f(type)` for the field `name`.
def f(+name: String, +kind: String) -> S.Field:
  S.Field.of(name, kind)

def ref(+field: S.Field, +table: String) -> S.Field:
  S.Field.ref(field, table)

def req(+field: S.Field) -> S.Field:
  S.Field.required(field)

def dflt(+field: S.Field, +value: J.Json) -> S.Field:
  S.Field.default(field, S.Value{value})

# `default: () => Date.now()`.
def now(+field: S.Field) -> S.Field:
  S.Field.default(field, S.Now{})

def Actual.transactions() -> S.Table:
  S.Table{"transactions", [
    f("id", "id"),
    f("is_parent", "boolean"),
    f("is_child", "boolean"),
    f("parent_id", "id"),
    req(ref(f("account", "id"), "accounts")),
    ref(f("category", "id"), "categories"),
    req(dflt(f("amount", "integer"), J.Json.nat(0n))),
    ref(f("payee", "id"), "payees"),
    f("notes", "string"),
    req(f("date", "date")),
    f("imported_id", "string"),
    f("error", "json"),
    f("imported_payee", "string"),
    f("starting_balance_flag", "boolean"),
    f("transfer_id", "id"),
    now(f("sort_order", "float")),
    dflt(f("cleared", "boolean"), J.JBool{True{}}),
    dflt(f("reconciled", "boolean"), J.JBool{False{}}),
    f("tombstone", "boolean"),
    ref(f("schedule", "id"), "schedules"),
    f("raw_synced_data", "string")
  ]}

def Actual.payees() -> S.Table:
  S.Table{"payees", [
    f("id", "id"),
    req(f("name", "string")),
    ref(f("transfer_acct", "id"), "accounts"),
    f("tombstone", "boolean"),
    f("favorite", "boolean"),
    f("learn_categories", "boolean")
  ]}

def Actual.accounts() -> S.Table:
  S.Table{"accounts", [
    f("id", "id"),
    req(f("name", "string")),
    f("offbudget", "boolean"),
    f("closed", "boolean"),
    f("sort_order", "float"),
    f("tombstone", "boolean"),
    f("account_id", "string"),
    f("official_name", "string"),
    f("account_sync_source", "string"),
    f("last_reconciled", "string"),
    f("last_sync", "string"),
    f("bank_sync_status", "string"),
    ref(f("account_group_id", "id"), "account_groups")
  ]}

def Actual.account_groups() -> S.Table:
  S.Table{"account_groups", [
    f("id", "id"),
    f("name", "string"),
    f("sort_order", "float"),
    f("tombstone", "boolean")
  ]}

def Actual.categories() -> S.Table:
  S.Table{"categories", [
    f("id", "id"),
    f("name", "string"),
    f("is_income", "boolean"),
    f("hidden", "boolean"),
    ref(f("group", "id"), "category_groups"),
    f("goal_def", "string"),
    f("cleanup_def", "string"),
    dflt(f("template_settings", "json"), J.Json.object([J.Member{"source", J.JStr{"notes"}}])),
    f("sort_order", "float"),
    f("tombstone", "boolean")
  ]}

def Actual.category_groups() -> S.Table:
  S.Table{"category_groups", [
    f("id", "id"),
    f("name", "string"),
    f("is_income", "boolean"),
    f("hidden", "boolean"),
    f("sort_order", "float"),
    f("tombstone", "boolean")
  ]}

def Actual.cleanup_groups() -> S.Table:
  S.Table{"cleanup_groups", [
    f("id", "id"),
    f("name", "string"),
    f("tombstone", "boolean")
  ]}

def Actual.schedules() -> S.Table:
  S.Table{"schedules", [
    f("id", "id"),
    f("name", "string"),
    req(ref(f("rule", "id"), "rules")),
    f("next_date", "date"),
    f("completed", "boolean"),
    f("posts_transaction", "boolean"),
    f("custom_upcoming_length", "string"),
    f("tombstone", "boolean"),
    f("sort_order", "float"),
    ref(f("_payee", "id"), "payees"),
    ref(f("_account", "id"), "accounts"),
    f("_amount", "json/fallback"),
    f("_amountOp", "string"),
    f("_date", "json/fallback"),
    f("_conditions", "json"),
    f("_actions", "json"),
    f("_has_splits", "boolean")
  ]}

def Actual.rules() -> S.Table:
  S.Table{"rules", [
    f("id", "id"),
    f("stage", "string"),
    f("conditions_op", "string"),
    f("conditions", "json"),
    f("actions", "json"),
    f("tombstone", "boolean")
  ]}

def Actual.notes() -> S.Table:
  S.Table{"notes", [
    f("id", "id"),
    f("note", "string")
  ]}

def Actual.preferences() -> S.Table:
  S.Table{"preferences", [
    f("id", "id"),
    f("value", "string")
  ]}

def Actual.transaction_filters() -> S.Table:
  S.Table{"transaction_filters", [
    f("id", "id"),
    f("name", "string"),
    f("conditions_op", "string"),
    f("conditions", "json"),
    f("tombstone", "boolean")
  ]}

def Actual.custom_reports() -> S.Table:
  S.Table{"custom_reports", [
    f("id", "id"),
    f("name", "string"),
    dflt(f("start_date", "string"), J.JStr{"2023-06"}),
    dflt(f("end_date", "string"), J.JStr{"2023-09"}),
    dflt(f("date_static", "integer"), J.Json.nat(0n)),
    f("date_range", "string"),
    dflt(f("mode", "string"), J.JStr{"total"}),
    dflt(f("group_by", "string"), J.JStr{"Category"}),
    dflt(f("sort_by", "string"), J.JStr{"desc"}),
    dflt(f("balance_type", "string"), J.JStr{"Expense"}),
    dflt(f("show_empty", "integer"), J.Json.nat(0n)),
    dflt(f("show_offbudget", "integer"), J.Json.nat(0n)),
    dflt(f("show_hidden", "integer"), J.Json.nat(0n)),
    dflt(f("show_uncategorized", "integer"), J.Json.nat(0n)),
    dflt(f("trim_intervals", "integer"), J.Json.nat(0n)),
    dflt(f("show_trend_lines", "integer"), J.Json.nat(0n)),
    dflt(f("include_current", "integer"), J.Json.nat(0n)),
    dflt(f("graph_type", "string"), J.JStr{"BarGraph"}),
    f("conditions", "json"),
    f("conditions_op", "string"),
    f("metadata", "json"),
    dflt(f("interval", "string"), J.JStr{"Monthly"}),
    f("color_scheme", "json"),
    f("tombstone", "boolean")
  ]}

def Actual.reflect_budgets() -> S.Table:
  S.Table{"reflect_budgets", [
    f("id", "id"),
    f("month", "integer"),
    f("category", "string"),
    f("amount", "integer"),
    f("carryover", "integer"),
    f("goal", "integer"),
    f("long_goal", "integer")
  ]}

def Actual.zero_budgets() -> S.Table:
  S.Table{"zero_budgets", [
    f("id", "id"),
    f("month", "integer"),
    ref(f("category", "string"), "categories"),
    f("amount", "integer"),
    f("carryover", "integer"),
    f("goal", "integer"),
    f("long_goal", "integer")
  ]}

def Actual.dashboard_pages() -> S.Table:
  S.Table{"dashboard_pages", [
    f("id", "id"),
    f("name", "string"),
    f("sort_order", "float"),
    f("tombstone", "boolean")
  ]}

def Actual.dashboard() -> S.Table:
  S.Table{"dashboard", [
    f("id", "id"),
    ref(f("dashboard_page_id", "id"), "dashboard_pages"),
    req(f("type", "string")),
    req(f("width", "integer")),
    req(f("height", "integer")),
    req(f("x", "integer")),
    req(f("y", "integer")),
    f("meta", "json"),
    f("tombstone", "boolean")
  ]}

def Actual.payee_locations() -> S.Table:
  S.Table{"payee_locations", [
    f("id", "id"),
    req(ref(f("payee_id", "id"), "payees")),
    req(f("latitude", "float")),
    req(f("longitude", "float")),
    req(f("created_at", "integer")),
    f("tombstone", "boolean")
  ]}

# `schema`.
def Actual.schema() -> S.Schema:
  S.Schema{[
    Actual.transactions(),
    Actual.payees(),
    Actual.accounts(),
    Actual.account_groups(),
    Actual.categories(),
    Actual.category_groups(),
    Actual.cleanup_groups(),
    Actual.schedules(),
    Actual.rules(),
    Actual.notes(),
    Actual.preferences(),
    Actual.transaction_filters(),
    Actual.custom_reports(),
    Actual.reflect_budgets(),
    Actual.zero_budgets(),
    Actual.dashboard_pages(),
    Actual.dashboard(),
    Actual.payee_locations()
  ]}

def Actual.views.payees() -> S.TableViews:
  S.TableViews{"payees", [], [
    S.View{"v_payees", 1, [
      S.Rename{"name", "COALESCE(__accounts.name, _.name)"}],
      "\n          SELECT ",
      " FROM payees _\n          LEFT JOIN accounts __accounts ON (_.transfer_acct = __accounts.id AND __accounts.tombstone = 0)\n          -- We never want to show transfer payees that are pointing to deleted accounts.\n          -- Either this is not a transfer payee, if the account exists\n          WHERE _.transfer_acct IS NULL OR __accounts.id IS NOT NULL\n        "}
  ]}

def Actual.views.categories() -> S.TableViews:
  S.TableViews{"categories", [
      S.Rename{"group", "cat_group"}], [
    S.View{"v_categories", 1, [
      S.Rename{"group", "cat_group"}],
      "SELECT ",
      " FROM categories _"}
  ]}

def Actual.views.schedules() -> S.TableViews:
  S.TableViews{"schedules", [], [
    S.View{"v_schedules", 1, [
      S.Rename{"next_date", "\n            CASE\n              WHEN _nd.local_next_date_ts = _nd.base_next_date_ts THEN _nd.local_next_date\n              ELSE _nd.base_next_date\n            END\n          "},
      S.Rename{"_payee", "pm.targetId"},
      S.Rename{"_account", "json_extract(_rules.conditions, _paths.account || '.value')"},
      S.Rename{"_amount", "json_extract(_rules.conditions, _paths.amount || '.value')"},
      S.Rename{"_amountOp", "json_extract(_rules.conditions, _paths.amount || '.op')"},
      S.Rename{"_date", "json_extract(_rules.conditions, _paths.date || '.value')"},
      S.Rename{"_conditions", "_rules.conditions"},
      S.Rename{"_actions", "_rules.actions"},
      S.Rename{"_has_splits", "EXISTS (\n            SELECT 1\n            FROM json_each(_rules.actions) action\n            WHERE json_extract(action.value, '$.options.splitIndex') > 0\n          )"}],
      "\n        SELECT ",
      " FROM schedules _\n        LEFT JOIN schedules_next_date _nd ON _nd.schedule_id = _.id\n        LEFT JOIN schedules_json_paths _paths ON _paths.schedule_id = _.id\n        LEFT JOIN rules _rules ON _rules.id = _.rule\n        LEFT JOIN payee_mapping pm ON pm.id = json_extract(_rules.conditions, _paths.payee || '.value')\n        "}
  ]}

def Actual.views.transactions() -> S.TableViews:
  S.TableViews{"transactions", [
      S.Rename{"is_parent", "isParent"},
      S.Rename{"is_child", "isChild"},
      S.Rename{"account", "acct"},
      S.Rename{"imported_id", "financial_id"},
      S.Rename{"imported_payee", "imported_description"},
      S.Rename{"transfer_id", "transferred_id"},
      S.Rename{"payee", "description"}], [
    S.View{"v_transactions_internal", 1, [
      S.Rename{"payee", "pm.targetId"},
      S.Rename{"category", "CASE WHEN _.isParent = 1 THEN NULL ELSE cm.transferId END"},
      S.Rename{"amount", "IFNULL(_.amount, 0)"},
      S.Rename{"parent_id", "CASE WHEN _.isChild = 0 THEN NULL ELSE _.parent_id END"}],
      "\n          SELECT ",
      " FROM transactions _\n          LEFT JOIN category_mapping cm ON cm.id = _.category\n          LEFT JOIN payee_mapping pm ON pm.id = _.description\n          WHERE\n           _.date IS NOT NULL AND\n           _.acct IS NOT NULL AND\n           (_.isChild = 0 OR _.parent_id IS NOT NULL)\n        "},
    S.View{"v_transactions_internal_alive", 0, [], "\n        SELECT _.* FROM v_transactions_internal _\n        LEFT JOIN transactions t2 ON (_.is_child = 1 AND t2.id = _.parent_id)\n        WHERE IFNULL(_.tombstone, 0) = 0 AND (_.is_child = 0 OR t2.tombstone = 0)\n      ", ""},
    S.View{"v_transactions", 2, [
      S.Rename{"payee", "p.id"},
      S.Rename{"category", "c.id"},
      S.Rename{"account", "a.id"}],
      "\n          SELECT ",
      " FROM v_transactions_internal_alive _\n          LEFT JOIN payees p ON (p.id = _.payee AND p.tombstone = 0)\n          LEFT JOIN categories c ON (c.id = _.category AND c.tombstone = 0)\n          LEFT JOIN accounts a ON (a.id = _.account AND a.tombstone = 0)\n          ORDER BY _.date desc, _.starting_balance_flag, _.sort_order desc, _.id;\n        "}
  ]}

# `schemaConfig.views`.
def Actual.views() -> List<&2, S.TableViews>:
  [Actual.views.payees(), Actual.views.categories(), Actual.views.schedules(), Actual.views.transactions()]

# `tableOptions.splits || 'inline'` is `inline` or `none`.
def Actual.inline_splits(+options: J.Json) -> Bool:
  match options:
    case J.JStr{"inline"}:
      True{}
    case J.JStr{"none"}:
      True{}
    case other:
      Bool.not(V.Js.truthy(other))

def Actual.transactions_view(+with_dead: Bool, +is_join: Bool, +options: J.Json) -> String:
  Bool.pick(String,
    Bool.or(is_join, Bool.and(Bool.not(with_dead),
      Actual.inline_splits(Maybe.default(&2, J.Json, J.Json.get(options, "splits"), J.JNull{})))),
    "v_transactions_internal_alive", "v_transactions_internal")

# `schemaConfig.tableViews(name, {isJoin, withDead, tableOptions})`.
def Actual.table_view(+name: String, +with_dead: Bool, +is_join: Bool, +options: J.Json) -> String:
  match name:
    case "transactions":
      Actual.transactions_view(with_dead, is_join, options)
    case "schedules":
      "v_schedules"
    case "categories":
      "v_categories"
    case "payees":
      "v_payees"
    case other:
      other

def Actual.desc(+field: String) -> J.Json:
  V.Js.single(field, J.JStr{"desc"})

def Actual.strs(+names: List<&2, String>) -> List<&2, J.Json>:
  match names:
    case Nil{}:
      Nil{}
    case Con{n, rest}:
      J.JStr{n} <> Actual.strs(rest)

# The default orders of a table.
def Actual.default_orders(+table: String) -> List<&2, J.Json>:
  match table:
    case "transactions":
      [Actual.desc("date"), J.JStr{"starting_balance_flag"}, Actual.desc("sort_order"), J.JStr{"id"}]
    case "category_groups":
      Actual.strs(["is_income", "sort_order", "id"])
    case "categories":
      Actual.strs(["sort_order", "id"])
    case "payees":
      [J.Json.object([
          J.Member{"$condition", V.Js.single("transfer_acct", J.JNull{})},
          J.Member{"$dir", J.JStr{"desc"}}]),
        V.Js.single("$nocase", J.JStr{"$name"})]
    case "accounts":
      Actual.strs(["sort_order", "name"])
    case "account_groups":
      Actual.strs(["sort_order", "id"])
    case "dashboard_pages":
      Actual.strs(["sort_order", "id"])
    case "schedules":
      [V.Js.single("$condition", V.Js.single("completed", J.JBool{True{}})), J.JStr{"next_date"}]
    case other:
      Nil{}

# `orderBy(orders)`: `id` is always the last sort; with no order, the
# table's default.
def Actual.orders(+table: String, +orders: List<&2, J.Json>) -> List<&2, J.Json>:
  match orders:
    case Nil{}:
      Actual.default_orders(table)
    case other:
      List.append(&2, J.Json, other, [J.JStr{"id"}])

# `schemaConfig.customizeQuery(queryState)`.
def Actual.customize_query(+q: Q.QueryState) -> Q.QueryState:
  Q.Query.set_orders(q, Actual.orders(Q.Query.table(q), Q.Query.order_expressions(q)))

# `schemaConfig`.
def Actual.config() -> S.Config:
  S.Config{J.JObj{J.JEnd{}}, True{}, J.JObj{J.JEnd{}}, True{}, Actual.views()}

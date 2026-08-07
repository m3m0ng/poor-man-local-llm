# AI Agent prompt — bank statement → Data Table

Prompt + wiring for the form-upload pipeline:

```
Form Trigger (file upload)
  → Extract from File (PDF → text)
    → AI Agent  (+ Ollama Chat Model, + Structured Output Parser)
      → Split Out (transactions)
        → Code (normalise types)
          → Data Table (insert row)
```

The whole design goal is that the agent's output drops straight into a Data
Table row with no hand-editing: every field is a scalar, types match the
column types, and one transaction = one row.

---

## 1. Create the Data Table columns first

The prompt below is written against these exact columns. Create them in the
Data Table **before** wiring the node, or the mapping will have nothing to
bind to.

| Column | Type | Notes |
|---|---|---|
| `txn_date` | String | `YYYY-MM-DD`. Kept as String on purpose — see [gotcha 4](#4-dates-as-string-not-date). |
| `description` | String | Cleaned merchant / counterparty text |
| `amount` | Number | **Signed**: money out is negative, money in is positive |
| `direction` | String | `debit` or `credit` — redundant with the sign, but makes filtering trivial |
| `currency` | String | ISO-4217, e.g. `EUR` |
| `balance_after` | Number | Running balance if the statement prints one, else empty |
| `category` | String | One of the fixed set in the prompt |
| `account_last4` | String | Last 4 digits/chars of the account number |
| `statement_start` | String | `YYYY-MM-DD` |
| `statement_end` | String | `YYYY-MM-DD` |
| `source_file` | String | Original upload filename — your audit trail |

One signed `amount` column beats separate debit/credit columns: `SUM(amount)`
is then just the net movement, and it can't disagree with itself.

---

## 2. System Message

Paste this into the AI Agent node → **Options → Add Option → System Message**.

```text
You are a bank statement extraction engine. You convert the plain text of one
bank statement into structured data. You do not chat, explain, or comment.

OUTPUT
- Return one JSON object matching the required schema. Nothing else.
- No markdown, no code fences, no preamble, no trailing notes.
- Every field in the schema must be present. Use null when the statement does
  not contain the value.

WHAT COUNTS AS A TRANSACTION
- Include only real money movements: card payments, transfers, direct debits,
  standing orders, ATM withdrawals, deposits, salary, interest, bank fees.
- Exclude summary lines: "opening balance", "closing balance", "total debits",
  "total credits", subtotals, carried-forward rows, page headers and footers.
  The opening and closing balances go in the statement-level fields instead.
- Keep the transactions in the order they appear on the statement.
- Extract every transaction on the statement. Do not stop early, do not
  summarise, do not collapse repeated merchants into one row.

FIELD RULES
- date: ISO format YYYY-MM-DD. Statements often print DD/MM or MM/DD with no
  year — take the year from the statement period. If the statement period
  spans a year boundary, pick the year that keeps the transactions in
  chronological order.
- description: the merchant or counterparty as printed, trimmed. Strip
  padding, reference noise, and card-number fragments. Do not translate,
  expand abbreviations, or invent a nicer name.
- amount: a JSON number, always signed. Money leaving the account is
  negative, money arriving is positive. Strip currency symbols, thousands
  separators, and trailing DR/CR markers. Parentheses around a figure mean
  negative. A separate "debit" column means negative, a "credit" column means
  positive.
- direction: "debit" if amount is negative, "credit" if amount is positive.
- balance_after: the running balance printed on that line, as a number. null
  if the statement does not print one.
- category: exactly one of groceries, dining, transport, utilities, housing,
  health, shopping, entertainment, income, transfer, fees, cash, other.
  Use "other" when unsure. Never invent a new category value.

ACCURACY
- Copy values from the text. Never estimate, never fill a gap with a plausible
  guess, never carry a value over from a neighbouring line.
- If a line is too garbled to read, still emit the row with the fields you can
  read and null for the rest.
- Do not do arithmetic. Do not recompute or "fix" a balance that looks wrong.
```

## 3. User Message

Set the AI Agent's **Source for Prompt** to *Define below*, then:

```text
Extract the statement below.

Filename: {{ $('On form submission').item.json['Bank statement'].filename }}

--- STATEMENT TEXT START ---
{{ $json.text }}
--- STATEMENT TEXT END ---
```

`$json.text` is what **Extract from File** (PDF operation) emits. Adjust the
form-field name `Bank statement` to whatever you called the upload field.

---

## 4. Structured Output Parser schema

Enable **Require Specific Output Format** on the AI Agent, attach a
**Structured Output Parser**, choose *Define using JSON Schema*, and paste:

```json
{
  "type": "object",
  "required": ["account_last4", "currency", "statement_start", "statement_end", "opening_balance", "closing_balance", "transactions"],
  "properties": {
    "account_last4":    { "type": ["string", "null"] },
    "currency":         { "type": ["string", "null"], "description": "ISO-4217 code" },
    "statement_start":  { "type": ["string", "null"], "description": "YYYY-MM-DD" },
    "statement_end":    { "type": ["string", "null"], "description": "YYYY-MM-DD" },
    "opening_balance":  { "type": ["number", "null"] },
    "closing_balance":  { "type": ["number", "null"] },
    "transactions": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["date", "description", "amount", "direction", "category"],
        "properties": {
          "date":          { "type": "string", "description": "YYYY-MM-DD" },
          "description":   { "type": "string" },
          "amount":        { "type": "number", "description": "signed; debits negative" },
          "direction":     { "type": "string", "enum": ["debit", "credit"] },
          "balance_after": { "type": ["number", "null"] },
          "category": {
            "type": "string",
            "enum": ["groceries", "dining", "transport", "utilities", "housing", "health", "shopping", "entertainment", "income", "transfer", "fees", "cash", "other"]
          }
        }
      }
    }
  }
}
```

With the parser attached, the agent emits `$json.output` as a real object, not
a string. That is the thing that makes the rest of the chain transferable.

---

## 5. Split Out — one item per row

The Data Table node inserts **one row per incoming item**, so the array has to
be exploded first.

- Node: **Split Out**
- Field to Split Out: `output.transactions`
- Options → **Include: All Other Fields**

`Include: All Other Fields` is what carries `account_last4`, `currency` and the
statement dates down onto every transaction item — without it you lose them.

## 6. Normalise before insert

Data Table columns are typed. A Number column will reject `"1.234,56"`, and E4B
is documented in [`RESULTS.md`](../RESULTS.md) as occasionally wrapping or
fumbling format. One Code node ahead of the insert makes the failure loud
instead of silent:

```js
// Code node — "Normalise for Data Table" (Run Once for All Items)
const rows = [];

const num = (v) => {
  if (v === null || v === undefined || v === '') return null;
  if (typeof v === 'number') return Number.isFinite(v) ? v : null;
  // "1.234,56" / "(45.00)" / "€ 1,234.56 DR"
  let s = String(v).trim();
  const paren = /^\(.*\)$/.test(s);
  s = s.replace(/[()]/g, '').replace(/[^0-9.,\-]/g, '');
  if (/,\d{2}$/.test(s)) s = s.replace(/\./g, '').replace(',', '.');
  else s = s.replace(/,/g, '');
  const n = parseFloat(s);
  if (!Number.isFinite(n)) return null;
  return paren ? -Math.abs(n) : n;
};

const isDate = (v) => typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v);

for (const item of $input.all()) {
  const j = item.json;
  const t = j.output ?? j;              // Split Out flattens into `output`
  const s = j.output ?? j;              // statement-level fields ride along

  let amount = num(t.amount);
  const direction = amount === null ? null : (amount < 0 ? 'debit' : 'credit');

  const problems = [];
  if (!isDate(t.date)) problems.push(`bad date: ${t.date}`);
  if (amount === null) problems.push(`bad amount: ${t.amount}`);
  if (!t.description) problems.push('missing description');

  if (problems.length) {
    throw new Error(`Row rejected (${problems.join('; ')}) — raw: ${JSON.stringify(t)}`);
  }

  rows.push({
    json: {
      txn_date:        t.date,
      description:     String(t.description).trim().slice(0, 200),
      amount,
      direction,
      currency:        s.currency ?? null,
      balance_after:   num(t.balance_after),
      category:        t.category ?? 'other',
      account_last4:   s.account_last4 ?? null,
      statement_start: isDate(s.statement_start) ? s.statement_start : null,
      statement_end:   isDate(s.statement_end) ? s.statement_end : null,
      source_file:     $('On form submission').first().json['Bank statement']?.filename ?? null,
    },
  });
}

return rows;
```

Swap the `throw` for a routed "quarantine" branch if you would rather keep the
good rows and inspect the bad ones separately.

## 7. Data Table node

- Operation: **Insert row**
- Mapping: **Map Each Column Manually**, or **Map Automatically** — the Code
  node above already emits keys that match the column names exactly.

---

## Variant: `output` comes back as a JSON string

If you run the agent **without** the Structured Output Parser attached, the
node emits a single item whose `output` is a *string* of JSON, and the array is
bare — no statement-level wrapper:

```json
[ { "output": "[\n  {\n    \"date\": \"2026-06-01\", ... } \n]" } ]
```

Split Out cannot work on that: there is no `output.transactions` to point at,
only text. Replace **both** the Split Out and the normalise node with this one
Code node, which parses, explodes and type-checks in a single pass.

```js
// Code node — "Parse + Flatten for Data Table"  (Run Once for All Items)

// Statement-level fields aren't in the model output in this variant.
// Set them here, or extract them in a second small call.
const CURRENCY      = 'MYR';
const ACCOUNT_LAST4 = null;
const STRIP_TRAILING_AMOUNT = true;  // "SALE DEBIT 9.00" -> "SALE DEBIT"

const cents = (n) => Math.round(n * 100);

const num = (v) => {
  if (v === null || v === undefined || v === '') return null;
  if (typeof v === 'number') return Number.isFinite(v) ? v : null;
  let s = String(v).trim();
  const paren = /^\(.*\)$/.test(s);
  s = s.replace(/[()]/g, '').replace(/[^0-9.,\-]/g, '');
  if (/,\d{2}$/.test(s)) s = s.replace(/\./g, '').replace(',', '.');
  else s = s.replace(/,/g, '');
  const n = parseFloat(s);
  if (!Number.isFinite(n)) return null;
  return paren ? -Math.abs(n) : n;
};

// The model may return a string, an array, or {transactions:[...]}.
// It has also been observed wrapping JSON in ``` fences (see RESULTS.md).
const toArray = (raw) => {
  let v = raw;
  if (typeof v === 'string') {
    let s = v.trim().replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();
    try {
      v = JSON.parse(s);
    } catch (e) {
      const m = s.match(/\[[\s\S]*\]|\{[\s\S]*\}/);
      if (!m) throw new Error(`Model output is not JSON: ${s.slice(0, 200)}`);
      v = JSON.parse(m[0]);
    }
  }
  if (Array.isArray(v)) return v;
  if (v && Array.isArray(v.transactions)) return v.transactions;
  throw new Error(`Expected an array of transactions, got ${typeof v}`);
};

let sourceFile = null;
try {
  const form = $('On form submission').first().json;
  sourceFile = Object.values(form).find((f) => f && f.filename)?.filename ?? null;
} catch (e) { /* node renamed or run standalone */ }

const rows = [];
let prevBalance = null;

for (const item of $input.all()) {
  for (const t of toArray(item.json.output ?? item.json)) {
    const amount  = num(t.amount);
    const balance = num(t.balance_after);

    if (!/^\d{4}-\d{2}-\d{2}$/.test(t.date ?? '')) {
      throw new Error(`Bad date "${t.date}" in: ${JSON.stringify(t)}`);
    }
    if (amount === null) {
      throw new Error(`Bad amount "${t.amount}" in: ${JSON.stringify(t)}`);
    }

    // Integrity check: this statement prints a running balance, so each row
    // must equal the previous balance plus the amount. This is the cheapest
    // way to catch a silently truncated context window or a dropped row.
    if (prevBalance !== null && balance !== null) {
      const expected = cents(prevBalance) + cents(amount);
      if (expected !== cents(balance)) {
        throw new Error(
          `Balance chain broke at ${t.date} "${t.description}": ` +
          `expected ${expected / 100}, statement says ${balance}. ` +
          `A row was probably dropped or misread.`
        );
      }
    }
    if (balance !== null) prevBalance = balance;

    let description = String(t.description ?? '').trim();
    if (STRIP_TRAILING_AMOUNT) {
      description = description.replace(/\s+[\d,]+\.\d{2}$/, '').trim();
    }

    rows.push({
      json: {
        txn_date:        t.date,
        description:     description.slice(0, 200),
        amount,
        direction:       amount < 0 ? 'debit' : 'credit',
        currency:        CURRENCY,
        balance_after:   balance,
        category:        t.category ?? 'other',
        account_last4:   ACCOUNT_LAST4,
        statement_start: rows.length === 0 ? t.date : rows[0].json.txn_date,
        statement_end:   null,   // backfilled below
        source_file:     sourceFile,
      },
    });
  }
}

const lastDate = rows.at(-1)?.json.txn_date ?? null;
for (const r of rows) r.json.statement_end = lastDate;

return rows;
```

Feed that straight into **Data Table → Insert row** with *Map Automatically* —
the keys already match the column names in [section 1](#1-create-the-data-table-columns-first).

Three notes on the sample output this was written against:

- **`direction` is derived, not trusted.** The model labelled
  `IBK FUND TFR TO A/C` as a credit and `PYMT FROM A/C` as a debit, which reads
  backwards from the wording — but the balance chain confirms the *signs* are
  right, so the wording is the bank's, not an error. Recomputing `direction`
  from `sign(amount)` means the two can never disagree.
- **Descriptions carry the amount twice.** `"SALE DEBIT 9.00"` happens because
  the PDF-to-text step flattens the amount column into the description column.
  `STRIP_TRAILING_AMOUNT` removes it; set it to `false` if you would rather
  keep the raw text.
- **`statement_start`/`statement_end` are inferred** from the first and last
  transaction dates, which is not the same as the statement period. If you need
  the real period, put the wrapper object back in the schema and let the model
  read it off the header.

---

## Gotchas on this rig

These are specific to running E4B on the ZimaBlade, not generic n8n advice.

**1. The AI Agent node needs a tool-calling model.** n8n's Tools Agent expects
function calling; `gemma4:e4b` through Ollama is not reliable there, and this
job has no tools anyway. Prefer the **Basic LLM Chain** node — same System
Message, same Structured Output Parser, no tool-calling requirement — or keep
the raw HTTP path in [`extract-statement.json`](extract-statement.json), which
already sets `format: json`, `think: false` and `temperature: 0`.

**2. Timeouts will bite before accuracy does.** At the measured **1.2 tok/s**,
a 40-transaction statement is roughly 1,800 output tokens ≈ **25 minutes** of
generation. The 30-minute HTTP timeout in `OPERATING.md` is not much headroom.
Raise `EXECUTIONS_TIMEOUT_MAX`, and split statements longer than ~50
transactions into page-sized chunks (Extract from File per page → Loop Over
Items → same prompt → merge) rather than one giant call.

**3. Watch `num_ctx`.** A multi-page statement is easily 4–8k tokens. If the
context window is left at Ollama's default, the tail of the statement is
silently dropped and you get a confident, incomplete answer — the worst kind of
failure here. Raise the context length on the Ollama Chat Model node, and
sanity-check the result: the row count and `closing_balance − opening_balance`
vs `SUM(amount)` should agree.

**4. Dates as String, not Date.** Data Table Date columns want a full ISO
datetime; feeding them a bare `YYYY-MM-DD` invites timezone drift that can shift
a transaction across a day boundary. A `YYYY-MM-DD` string sorts correctly
lexicographically and stays exactly what the statement said.

**5. `think: false` matters.** Per `RESULTS.md` it is a strict win for E4B —
faster, never less accurate. The Ollama Chat Model node may not expose it; if
it doesn't, that is a concrete reason to stay on the HTTP Request path.

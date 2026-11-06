# CBS Assisted Assessment (RSB_Apur_Assistida)

A Business Central AL extension that integrates with the Brazilian Federal Revenue
Service's (Receita Federal) **CBS Assisted Assessment** API, automatically collects CBS
debt data, and reconciles it against the company's own fiscal history (issued NF-e).

> **CBS** (Contribuição sobre Bens e Serviços) is the new Brazilian tax on goods and
> services created by the 2023 tax reform. "Apuração Assistida" ("Assisted Assessment") is
> the official Receita Federal service that pre-calculates the CBS owed by a taxpayer,
> based on the NF-e already issued, and makes that calculation available through a REST
> API.

## 1. What this extension does

1. **Collects** debt data from the Revenue Service API on a schedule, using the standard
   Business Central Job Queue.
2. **Imports** the JSON returned by the API into normalized, auditable tables.
3. **Publishes** each batch atomically — a batch only becomes visible once the whole
   import has finished without errors, so the panel never shows partial data.
4. **Reconciles** each imported debt against the company's own fiscal history (the NF-e
   actually issued), flagging matches, divergences and gaps.
5. **Presents** the result on a panel filterable by period (competência), with drill-down
   to every supporting record (requests, files, batches, log entries).

## 2. Scope (MVP)

| Area | Status |
|---|---|
| CBS **Debits** service (`/debitos`) | ✅ Implemented |
| Credits, Payments, Settlements services | 🔲 Planned for a later phase (enum values exist, no collection logic yet) |
| OAuth2 Client Credentials authentication | ✅ Implemented (secret stored only in Isolated Storage, never in a table field or log) |
| Automatic collection via Job Queue | ✅ Implemented (state machine with retry/backoff) |
| Atomic batch publication & idempotency by file hash | ✅ Implemented |
| Reconciliation against fiscal history | ✅ Implemented through a pluggable interface (`ICbsFiscalHistory`) — the extension ships only a "no adapter linked" default; a localization/partner extension must supply the real adapter that reads the company's NF-e |
| Reverse lookup (notes issued with no matching debt) | ✅ Implemented |
| Coverage/gap report by period | ✅ Table and export ready; the job that populates it is left to the implementing partner |
| CSV export (reconciliation result, coverage report) | ✅ Implemented |
| Audit/telemetry log | ✅ Implemented (`CBS Log Entry`) — never stores tokens, secrets, signed URLs or taxpayer document bodies |

Everything is scoped to **one company** at a time (Business Central's native
per-company data isolation is relied upon instead of a custom "Company" key on every
table).

## 3. Solution architecture (high level)

```
Job Queue ──▶ CBS Job Queue Dispatcher ──▶ CBS Collection Orchestrator ──▶ ICbsHttpClient
                                                                              │
                                                              CBS Tax Authority Connector
                                                                              │
                                                                        CBS File (raw JSON)
                                                                              │
                                                                     CBS Batch Publisher
                                                                              │
                                                                     CBS JSON Importer
                                                                              │
                                                                        CBS Debt (ledger)
                                                                              │
                                                              CBS Reconciliation Engine ──▶ ICbsFiscalHistory
                                                                              │                  │
                                                                     CBS Reconciliation    CBS Default Adapter
                                                                                           (partner supplies the real one)
```

Key design decisions:

- **Two extensibility seams** keep the core independent of any specific localization or
  test harness:
  - `ICbsHttpClient` — swap the real `CBS Tax Authority Connector` for a mock in tests.
  - `ICbsFiscalHistory` — swap the default (no-op) adapter for one that reads real NF-e
    data from whatever localization extension manages them.
- **Secrets never touch a table field.** The OAuth2 client secret lives only in
  Isolated Storage and is only ever read as `SecretText`.
- **Natural-key collision detection.** A new collection never silently overwrites an
  existing `CBS Debt` record; it is only replaced through an explicit republication batch.
- **Atomic publication.** A batch is marked `Published` only after the entire import
  finishes without error, in a single final transaction.

## 4. Object reference

| Type | Name | Purpose |
|---|---|---|
| Table | `CBS Setup` | Single per-company configuration record |
| Table | `CBS Credential` | OAuth2 Client Credentials per environment |
| Table | `CBS Request` | One row per collection cycle (ticket, state machine) |
| Table | `CBS File` | Raw JSON downloaded from the Revenue Service |
| Table | `CBS Debt` | Normalized CBS debt ledger (the core data) |
| Table | `CBS Batch` | Atomic publication control |
| Table | `CBS Reconciliation` | Reconciliation evaluations (audit trail, one row per evaluation) |
| Table | `CBS Coverage` | Collection coverage/gaps by period |
| Table | `CBS Log Entry` | Audit/telemetry event log |
| Table | `CBS Fiscal History Buffer` | Temporary transfer buffer used by `ICbsFiscalHistory` |
| Interface | `ICbsHttpClient` | HTTP abstraction for the Revenue Service API |
| Interface | `ICbsFiscalHistory` | Abstraction over the company's own fiscal history |
| Page | `CBS Setup Card` | Configuration |
| Page | `CBS Credential List` / `CBS Credential Card` | Credential management |
| Page | `CBS Panel` | Main dashboard by period |
| Page | `CBS Debt List` | All imported debts |
| Page | `CBS Request List` | Collection cycle history/troubleshooting |
| Page | `CBS Reconciliation List` | Reconciliation audit trail |

## 5. Step-by-step: pages and first-time setup

### Step 1 — Create a credential (`CBS Credential List` → `CBS Credential Card`)

1. Open **CBS Credentials** (search or via the Setup page's *Credentials* action).
2. Create a new record: `Code`, `Description`, `Environment` (Production or Restricted
   Production/sandbox), `Client Id`, `Token Url` and `Scope` as registered with the
   Revenue Service.
3. In the masked **Client Secret** field, type the client secret once and leave the
   field — it is written straight to Isolated Storage and the typed value is cleared from
   the screen immediately. The **Secret Configured** flag confirms it was stored.
4. Set **Active** = Yes.

### Step 2 — Configure the company (`CBS Setup Card`)

1. Open **CBS Setup**.
2. Under **Configuration**: pick the `Environment`, fill in `Base CNPJ` (8 digits) and
   `Taxpayer CNPJ` (14 digits), select the `Credential Code` created in Step 1, and the
   `Active Service` (only *Debts* is implemented).
3. Under **Reconciliation**: pick the `Fiscal History Adapter` (requires a partner
   extension implementing `ICbsFiscalHistory`; leave as *No Link* otherwise) and set the
   `Reconciliation Tolerance` (maximum accepted difference to classify a debt as
   *Reconciled*).
4. Under **Default panel filters**: set the default `Starting Period`/`Ending Period`
   shown when the panel opens.
5. Under **Operation**: review `Incremental Window Days`, `JSON Retention Days` and
   `Daily Opening Quota` (sensible defaults are pre-filled).
6. Use the **Credentials** and **CBS Panel** actions to navigate without leaving the
   setup flow.

### Step 3 — Schedule automatic collection

Create a **Job Queue Entry** with:
- *Object Type to Run* = Codeunit
- *Object ID to Run* = `CBS Job Queue Dispatcher` (50138)
- A recurrence (e.g., every 15–30 minutes)

Each run processes any request still in progress and opens a new one if none is pending
and the daily quota allows it. No manual action is required afterwards; progress can be
tracked on **CBS Requests**.

### Step 4 — Track collection progress (`CBS Request List`)

Open **CBS Requests** to see every collection cycle, its `Local State` (the extension's
own state machine) and `Remote State` (as last reported by the API), along with retry
counters and timestamps. Use this page to diagnose a stuck or failed request — the
`Remote State Detail` field carries the last error message.

### Step 5 — Review imported debts (`CBS Debt List`)

Open **CBS Debts** to see every normalized debt record (period, document, NF-e access
key, origin and every CBS amount breakdown). Use the **Reconciliations** action on a
line to jump straight to its reconciliation history.

### Step 6 — Review reconciliation results (`CBS Reconciliation List`)

Open **CBS Reconciliations** to see every evaluation, its `Classification` (Reconciled,
Divergent, Adjustment, Note without Matching Debt, Debt without Matching Note, Matched
Note without Declared CBS, No Fiscal History Adapter Linked), the computed `Difference`
and the evaluator/timestamp.

### Step 7 — Use the panel for day-to-day monitoring (`CBS Panel`)

Open **CBS Panel** (also reachable from the Setup page). It opens pre-filtered to the
default period range configured in Step 2 and shows the filtered debts together with
running totals for **Total CBS Assessed** and **Total Outstanding Balance**. Change the
page filters to inspect any other period, environment or NI. Use the
**Reconciliations** action to drill into a specific debt.

## 6. Translations

The extension ships with the `TranslationFile` feature enabled. All AL source — object
names, field names, procedures, captions, tooltips and error messages — is written in
English (`en-US`), which is the base/source language. A complete Brazilian Portuguese
translation is provided in
[`Translations/RSB_Apur_Assistida.pt-BR.xlf`](./Translations/RSB_Apur_Assistida.pt-BR.xlf),
covering every caption, tooltip and user-facing message. Technical identifiers coming
directly from the Revenue Service's JSON contract (e.g. `pa`, `cbs`, `chave`,
`tiqueteSolicitacao`) are intentionally left untouched in the code, since changing them
would break the integration.

To add another language, run `createLanguageXlf` against
`Translations/RSB_Apur_Assistida.g.xlf` with the new language code, then translate the
resulting file.

## 7. Security notes

- The OAuth2 client secret is **never** stored in a table field, never logged and never
  converted to plain `Text` — it flows exclusively as `SecretText`/Isolated Storage.
- Telemetry and the audit log (`CBS Log Entry`) only ever store technical metadata
  (codes, counters, durations); they never store a CNPJ, an NF-e key, a token, a secret
  or a signed URL.
- `CBS Setup`, `CBS Credential`, `CBS Request`, `CBS File`, `CBS Debt`, `CBS Batch`,
  `CBS Reconciliation`, `CBS Coverage` and `CBS Log Entry` are all `Access = Internal`;
  only the pages in section 4 expose them to end users.

## 8. Open items / `[VALIDATE]` markers

A few integration details are marked `[VALIDATE]` directly in the source code and must be
confirmed against the official Revenue Service documentation before go-live:
official base URLs, token endpoint, required OAuth2 scope, and the exact date-time format
of `urlAssinadaExpiraEm`. Search the codebase for `[VALIDATE]` to find every occurrence.

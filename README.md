# CBS Assisted Assessment (RSB_Apur_Assistida)

A Business Central AL extension that integrates with the Brazilian Federal Revenue
Service's (Receita Federal) **CBS Assisted Assessment** API, automatically collects CBS
debt data, and reconciles it against the company's own fiscal history (issued NF-e).

> **CBS** (Contribuição sobre Bens e Serviços) is the new Brazilian tax on goods and
> services created by the 2023 tax reform. "Apuração Assistida" ("Assisted Assessment") is
> the official Receita Federal service that pre-calculates the CBS owed by a taxpayer,
> based on the NF-e already issued, and makes that calculation available through a REST
> API.

**Target platform:** Business Central 29 (2026 release wave 2), AL runtime 18.0, SaaS only.
**Source language:** `en-US` (see section 7 — a pt-BR translation ships with the app).

---

## 1. What this extension does

1. **Collects** debt data from the Revenue Service API on a schedule, using the standard
   Business Central Job Queue (or on demand, with **Run Collection Now**).
2. **Imports** the JSON returned by the API into normalized, auditable tables.
3. **Publishes** each batch atomically — a batch only becomes visible once the whole
   import has finished without errors, so the panel never shows partial data.
4. **Reconciles** each imported debt against the company's own fiscal history (the NF-e
   actually issued), classifying matches, divergences and exceptions.
5. **Presents** the result on a panel filterable by period (competência), with drill-down
   to every supporting record (requests, files, batches, log entries).

---

## 2. ⚠️ Before the first run: two mandatory settings

Both are **environment configuration**, not code — an extension cannot do either for you.

### 2.1 Allow HttpClient Requests

Outbound HTTP is **blocked by default** for every extension in Business Central. Without
this flag the connector reports a network failure even when credentials and DNS are fine.

1. Open **Extension Management**.
2. Select **CBS Assisted Assessment** → **Configure**.
3. On **Extension Settings**, enable **Allow HttpClient Requests**.

> Copying an environment resets this flag to `false`. Re-check it after any environment
> copy or restore.

### 2.2 Assign a permission set

The app ships three permission sets and does **not** require SUPER:

| Permission set | Profile | Can do |
|---|---|---|
| **CBS Leitura** | Management, audit | Read everything; run the exporter |
| **CBS Operacao** | Fiscal user | Run collection, reconcile, reverse lookup, export — cannot change Setup or Credential |
| **CBS Admin** | IT | Configure Setup and Credential, purge, rebuild coverage |

Assign one of them (or a combination) to every user who needs the app.

---

## 3. Scope (MVP)

| Area | Status |
|---|---|
| CBS **Debits** service (`/debitos`) | ✅ Implemented |
| Credits, Payments, Settlements services | 🔲 Planned (enum values exist, no collection logic yet) |
| OAuth2 Client Credentials authentication | ✅ Implemented — secret in Isolated Storage, token cached in memory-of-storage and invalidated on 401 |
| Automatic collection via Job Queue | ✅ Implemented (state machine with retry/backoff) |
| Manual collection (**Run Collection Now**) | ✅ Implemented — same code path as the Job Queue |
| Atomic batch publication & idempotency by file hash | ✅ Implemented |
| Panel of debts by period | ✅ Implemented — reads **published batches only** |
| Reconciliation against fiscal history | ✅ Engine implemented and wired to the UI. Ships only a *No Link* adapter: a partner extension must implement `ICbsFiscalHistory` for the real NF-e source |
| Reverse lookup (notes issued with no matching debt) | ✅ Implemented (action on the panel and on the reconciliation list) |
| Reconciliation result export (CSV) | ✅ Implemented |
| Coverage ledger (last collection + debt count per period) | ✅ Implemented — **Rebuild Coverage** action on Setup |
| JSON retention purge | ✅ Implemented — **Purge Expired JSON** action on Setup |
| Audit/telemetry log | ✅ Implemented (`CBS Log Entry`) — never stores tokens, secrets, signed URLs or document bodies |
| Automated tests | 🟡 11 cases (6 reconciliation + 5 import). Running them needs the **Test Runner** extension installed in the sandbox |

Everything is scoped to **one company** at a time (Business Central's native
per-company data isolation is relied upon instead of a custom "Company" key on every
table).

### Out of scope for the MVP

- Credits, payments and settlements (the enum values and endpoint paths exist, unused).
- The consolidated balance composition of the portal.
- Accounting entries and fiscal bookkeeping — reconciliation is advisory only.
- Retroactive historical load.
- Multiple matrices / branches beyond one matrix per configuration.
- DFe other than NF-e model 55. A CT-e or NFS-e debt is imported but classified
  **Not Applicable**, never as a false "debt without note".

---

## 4. Solution architecture (high level)

```
Job Queue ──▶ CBS Job Queue Dispatcher ──▶ CBS Collection Orchestrator ──▶ ICbsHttpClient
   or UI                │                                                        │
   button               │                                        CBS Tax Authority Connector
                        │                                                        │
                        │                                                  CBS File (raw JSON)
                        │                                                        │
                        │                                               CBS Batch Publisher
                        │                                                        │
                        │                                               CBS JSON Importer
                        │                                                        │
                        │                                                  CBS Debt (ledger)
                        │                                                        │
                        └────────────────▶ CBS Reconciliation Engine ──▶ ICbsFiscalHistory
                                                        │                          │
                                               CBS Reconciliation        CBS Default Adapter
                                                                        (partner supplies the real one)
```

Key design decisions:

- **Two extensibility seams.** `ICbsHttpClient` swaps the real connector for a mock in
  tests; `ICbsFiscalHistory` swaps the no-op adapter for one reading real NF-e data. Both
  are `Access = Public` so a **separate app from another publisher** can implement them —
  that is the point of the seam.
- **Secrets never touch a table field.** The OAuth2 client secret lives only in Isolated
  Storage and is read as `SecretText`.
- **Visibilidade só do que foi publicado (ADR-04).** `CBS Batch.Published` is written in a
  single final transaction, and `CBS Debt.Published` is set in that same transaction. The
  panel filters `Published = true`, so a failed import is invisible.
- **Natural-key collision detection.** A new collection never silently overwrites an
  existing `CBS Debt`: the original is preserved and the collision is logged. Replacement
  happens only through an explicit republication batch.

---

## 5. Object reference

| Type | ID | Name | Purpose |
|---|---|---|---|
| Table | 50100 | `CBS Setup` | Single per-company configuration record |
| Table | 50101 | `CBS Credential` | OAuth2 Client Credentials per environment |
| Table | 50102 | `CBS Request` | One row per collection cycle (ticket, state machine) |
| Table | 50103 | `CBS File` | Raw JSON downloaded from the Revenue Service |
| Table | 50104 | `CBS Debt` | Normalized CBS debt ledger (the core data) |
| Table | 50105 | `CBS Reconciliation` | Reconciliation evaluations (one row per evaluation = audit trail) |
| Table | 50106 | `CBS Batch` | Atomic publication control |
| Table | 50107 | `CBS Coverage` | Collection coverage/gaps by period |
| Table | 50108 | `CBS Log Entry` | Audit/telemetry event log |
| Table | 50130 | `CBS Fiscal History Buffer` | Temporary transfer buffer used by `ICbsFiscalHistory` |
| Enum | 50111 | `CBS Fiscal History Adapter` | Extensible adapter selector (public) |
| Enum | 50117 | `CBS Environment Type` | Production / Restricted Production |
| Enum | 50119 | `CBS Document Type` | DFe model codes (55 NF-e, 57 CT-e, 91 NFS-e, …) |
| Interface | — | `ICbsHttpClient` | HTTP abstraction for the Revenue Service API |
| Interface | — | `ICbsFiscalHistory` | Abstraction over the company's own fiscal history (public) |
| Codeunit | 50133 | `CBS Tax Authority Connector` | Real HTTP implementation |
| Codeunit | 50138 | `CBS Job Queue Dispatcher` | Single entry point for the Job Queue |
| Codeunit | 50141 | `CBS Maintenance` | JSON purge + coverage rebuild |
| Page | 50150 | `CBS Setup Card` | Configuration + maintenance actions |
| Page | 50151 | `CBS Debt List` | All imported debts |
| Page | 50152 | `CBS Request List` | Collection cycle history + **Run Collection Now** |
| Page | 50153 | `CBS Reconciliation List` | Reconciliation trail + actions |
| Page | 50154 | `CBS Panel` | Main dashboard by period + actions |
| Page | 50159/50160 | `CBS Credential List` / `CBS Credential Card` | Credential management |
| Page | 50100 | `CBS Reverse Lookup Request` | Dialog for the issue-date range |

The main pages are also grouped under **CBS Assisted Assessment** in the *Order
Processor* Role Center.

---

## 6. Step-by-step: first-time setup

### Step 1 — Create a credential (`CBS Credential List` → `CBS Credential Card`)

1. Open **CBS Credentials** (or the *Credentials* action on the Setup page).
2. Create a record: `Code`, `Description`, `Environment` (Production or Restricted
   Production), `Client Id`, `Token Url` and `Scope` as registered with the Revenue
   Service.
3. In the masked **Client Secret** field, type the secret once and leave the field — it is
   written straight to Isolated Storage and cleared from screen. **Secret Configured**
   confirms it was stored.
4. Set **Active** = Yes.

### Step 2 — Configure the company (`CBS Setup Card`)

| Group on the page | What to fill in |
|---|---|
| **Configuration** | `Environment`, `Base CNPJ` (8 digits), `Taxpayer CNPJ` (14 digits), `Credential Code`, `Active Service` (only *Debts* is implemented), `Collection Blocked` |
| **Reconciliation** | `Fiscal History Adapter` (leave *No Link* until a partner adapter exists) and `Reconciliation Tolerance` |
| **Default Panel Filters** | default `Starting Period` / `Ending Period` when the panel opens |
| **Operation** | `Incremental Window Days` (8), `JSON Retention Days` (180), `Daily Opening Quota` (4) |

> `Incremental Window Days` documents the Revenue Service rule (recent queries are limited
> to the last 8 days); the window itself is decided by the API, not by this field.

### Step 3 — Schedule automatic collection

Create a **Job Queue Entry**:

- *Object Type to Run* = Codeunit
- *Object ID to Run* = `CBS Job Queue Dispatcher` (50138)
- Recurrence: every 15–30 minutes
- Job Queue Category: a dedicated one (e.g. `CBS-COLETA`) so it does not compete with the
  customer's routines

Each run advances any request still in progress and opens a new one only if none is
pending **and** the daily quota allows it. To test without waiting, use **Run Collection
Now** on *CBS Requests* or on the Setup card.

### Step 4 — Track collection progress (`CBS Request List`)

Shows every cycle with `Local State` (our state machine), `Remote State` (last reported by
the API), retry counters and timestamps. `Remote State Detail` carries the last error
message. Use it first when a request looks stuck.

### Step 5 — Review imported debts (`CBS Debt List`)

Every normalized debt: period, document type, NF-e access key, origin and each CBS amount
breakdown. `Published` tells whether the row is already visible on the panel.

### Step 6 — Reconcile and review results

On **CBS Panel** or **CBS Reconciliation List**:

- **Reconcile Pending Debts** — evaluates every debt that has no evaluation yet.
- **Reverse Lookup** — asks for an issue-date range and flags notes issued in that window
  with no matching debt.
- **Export Reconciliation to CSV** — downloads the trail for Excel.

Classifications: *Reconciled*, *Divergent*, *Adjustment* (internal item-vs-total
divergence), *Note without Matching Debt*, *Debt without Matching Note*, *Matched Note
without Declared CBS*, *No Fiscal History Adapter Linked*, *Not Applicable* (document is
not NF-e).

### Step 7 — Day-to-day monitoring (`CBS Panel`)

Opens pre-filtered to the default period range and shows the published debts with running
**Total CBS Assessed** and **Total Outstanding Balance**. Change the page filters for any
other period, environment or NI.

### Step 8 — Maintenance (`CBS Setup Card`)

- **Purge Expired JSON** — clears the raw JSON past `JSON Retention Days`. The row and its
  hash are kept, so idempotency and audit survive.
- **Rebuild Coverage** — rebuilds `CBS Coverage` (last collection and debt count per
  period) from published data.
- **Load Demo Data** — see section 9.

---

## 7. Translations

`TranslationFile` is enabled and the source language is `en-US`. A Brazilian Portuguese
translation is provided in
[`Translations/RSB_Apur_Assistida.pt-BR.xlf`](./Translations/RSB_Apur_Assistida.pt-BR.xlf).

> ⚠️ **Known gap:** the pt-BR file currently has no accented characters (`Configuracao`,
> `debito`, `conciliacao`) and no `state="translated"` attribute, so a regeneration of the
> XLF can discard the work. Both must be fixed before AppSource submission.

Identifiers coming straight from the Revenue Service JSON contract (`pa`, `cbs`, `chave`,
`tiqueteSolicitacao`) are intentionally left as-is — renaming them would break the
integration.

To add another language, run `createLanguageXlf` against
`Translations/RSB_Apur_Assistida.g.xlf` and translate the result.

---

## 8. Security and data protection

- The OAuth2 client secret is **never** in a table field, never logged, never converted to
  plain `Text` — it flows only as `SecretText` / Isolated Storage.
- The access token is **cached** in Isolated Storage with a 5-minute safety margin and is
  dropped on any HTTP 401, so a revoked token never gets stuck.
- The signed download URL is a temporary secret: it is used in a request **without** an
  `Authorization` header and is never logged.
- Telemetry and `CBS Log Entry` store technical metadata only (codes, counters, durations)
  — never a CNPJ, an NF-e key, a token, a secret or a signed URL.
- `DataClassification` is declared on every field. CNPJ/NI are
  `EndUserIdentifiableInformation`; fiscal values are `CustomerContent`.
- All data tables are `Access = Internal`; only the pages expose them to users, and only
  through the permission sets in section 2.2.

---

## 9. Demo data

**Load Demo Data** (on `CBS Setup Card`) creates a coherent, self-contained scenario so the
extension can be demonstrated without any connection to the Revenue Service:

| What | Content |
|---|---|
| Setup | Fictitious base/taxpayer CNPJ, Restricted Production, tolerance 1,00 — **only fills what is empty**, never changes a configured environment |
| Credential | `DEMO`, fake client id/secret, inactive for real use |
| Collection cycles | 3 `CBS Request` already **Published**, one per period |
| Batches | 3 `CBS Batch` Published, one per period (so batch lineage is visible) |
| Debts | 8 rows across 3 periods (see below) |
| Reconciliations | 6 evaluations covering 6 classifications |
| Coverage | Rebuilt from the demo debts |

The 8 debts are designed to exercise every classification:

| # | Period | Document | Origin | Amount | Expected result |
|---|---|---|---|---|---|
| 000001 | -2 | NF-e | Normal | 1.250,75 | **Reconciled** |
| 000002 | -2 | NF-e | Return by PCONT | 430,10 | **Divergent** (declared 500,00) |
| 000003 | -1 | NF-e | Normal | 980,00 | **Debt without Matching Note** |
| 000004 | -1 | NF-e | Normal | 2.100,55 | **Matched Note without Declared CBS** |
| 000005 | current | NF-e | Normal | 310,40 | *left pending* |
| 000006 | current | NF-e | Credit Cancellation | 75,20 | *left pending* |
| 000007 | current | NF-e | Normal | 190,00 | **Adjustment** (items 170,00 vs total 190,00) |
| 000008 | current | CT-e | Normal | 120,00 | **Not Applicable** (not NF-e) |

The two pending debts exist on purpose: they are what **Reconcile Pending Debts** will
process on the first click, so the action and the resulting trail can be demonstrated live.

It is safe to run more than once — existing demo records are reused, never duplicated, and
no record outside the demo set is touched or deleted.

---

## 10. Open items / `[VALIDATE]` markers

Integration details marked `[VALIDATE]` in the source must be confirmed against the
official Revenue Service documentation before go-live. Search the codebase for
`[VALIDATE]`:

| Item | Where | Status |
|---|---|---|
| Token endpoint and scope (Receita Integra) | `CBS Credential`, `CBS Tax Authority Connector` | Not published in the CBS API docs — must come from Receita Integra |
| Restricted-production base URL (`api-prr…`) | `CBS Url Helper` | Assumption, unconfirmed |
| Exact format of `urlAssinadaExpiraEm` | `CBS Tax Authority Connector` | Parsed defensively (`[TryFunction]`), never aborts the cycle |
| Isolated Storage behaviour inside a Job Queue session | `CBS Credential` | Used for both the secret and the token cache |
| Whether the Brazilian localization exposes `vCBS`/`gCBS` in a table or only in the XML | `ICbsFiscalHistory` adapter | Decides whether the partner adapter reads a table or parses XML |

All other integration details are now confirmed against the official contract
(`docs.receitafederal.gov.br/apuracao-cbs/debito.html` and `guiaapiassincrona.html`):
`POST /apuracao-cbs/v2/debitos/{cnpj}` with an 8-digit base CNPJ, `Authorization: Bearer
<token>`, `{"urlRetorno":""}` body, HTTP 201 with `tiqueteSolicitacao` / `tEASegundos`,
situations `PENDENTE` / `EM_PROCESSAMENTO` / `CONCLUIDA` / `ERRO` / `EXPIRADA`, 240-minute
processing limit, 4 openings per day per API, signed URL valid for 48 hours and downloadable
without a bearer token, and `documento` as the **DFe model code** (55 = NF-e).

---

## 11. Building and testing

```bash
# from the project root
AL: Download Symbols      # or: dotnet build / alc from AL-Go
```

- Compiles against **BC 29** symbols (`System Application`, `Base Application`,
  `Business Foundation` 29.0).
- The 11 automated tests live in `src/Test/`. They **compile without extra dependencies**
  (assertions are local, deliberately not `Library Assert`). To *run* them, install the
  **Test Runner** extension in the sandbox and use the AL Test Tool.
- `schemaUpdateMode: ForceSync` is set in `.vscode/launch.json` for the Dev and UAT
  sandboxes.

### Upgrading from a build before 11/11

`CBS Debt.Document` changed from `Integer` to `Enum`, and `CBS Debt.Published` was added.
Rows imported by an older build stay with `Published = false` and therefore out of the
panel. In a sandbox, reload demo data or run **Rebuild Coverage**; in a live base, an
upgrade codeunit must set `Published = true` where the batch is published.

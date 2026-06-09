# nhtsa-hybrid-search
National Highway Transportation Safety  - Hybrid relational and semantic search
# NHTSA Hybrid Search — Semantic + Relational over 2.4M rows

Hybrid search over the U.S. National Highway Traffic Safety Administration (NHTSA) safety dataset: combine **in-database semantic vector search** with **hard relational filters** (make / model / year / crash / fire) to find the *right* recalls and complaints by meaning, not just keywords — entirely inside SQL Server 2025.

> Built to answer questions like *"show me Ford Expedition complaints that describe a transmission problem, model year 2018–2020, where a crash occurred"* — semantic intent **and** structured filters, in one query.

---

## The problem
Public vehicle-safety data is large, messy, and keyword-hostile. The same defect is described a hundred different ways across millions of free-text narratives, so a `LIKE '%transmission%'` search misses most of what matters. I wanted search that understands *meaning* but still respects hard facts (the make, the model year, whether there was a fire).

## What it does
- Loads the full NHTSA recalls + complaints feeds into typed SQL Server tables.
- Generates 768-dimension text embeddings **in the database** from the defect/complaint narratives.
- Runs **hybrid search**: an approximate-nearest-neighbor vector search for semantic intent, then joins back to the relational tables to apply exact filters (make, model, model year, crash, fire, component, state).

## The data
| Table | Rows | Notes |
|---|---|---|
| `dbo.Recalls` | **240,846** | Typed, PK `RecordID`; defect / consequence / corrective-action narratives |
| `dbo.Complaints` | **2,210,945** | Typed; make / model / year / crash / fire / injuries / deaths / component / state / narrative |
| `dbo.RecallVectors` | 14,979 | One embedding per **distinct recall campaign** (240k rows dedupe to ~15k campaigns) · DiskANN index |
| `dbo.ComplaintVectors` | 11,645 | Embedded subset (Ford Expedition complaints) as a focused, fast demo · DiskANN index |

*Source: NHTSA ODI flat files — `static.nhtsa.gov/odi/ffdd/rcl/FLAT_RCL_POST_2010.zip` and `.../cmpl/FLAT_CMPL.zip` (tab-delimited, no header). Embeddings were scoped deliberately — recalls deduped to campaigns, complaints subset to a single make/model — so the demo stays fast without embedding all 2.2M narratives.*

## Tech stack
- **SQL Server 2025** — native `VECTOR(768)` type, `VECTOR_SEARCH`, and **DiskANN** approximate-nearest-neighbor indexes
- **In-database embeddings** via `AI_GENERATE_EMBEDDINGS` against a local **Ollama** model (`nomic-embed-text`) registered as an external model
- **T-SQL** for schema, loading, and the hybrid query patterns
- **PowerShell** (`embed_loader_generic.ps1`) — a reusable batch embedding loader I wrote

## How it works
1. **Load** the raw flat files into staging, then into typed tables (`nhtsa_setup_relational.sql`, `build_recalls.sql`, `build_complaints.sql`).
2. **Embed** the narratives into `*Vectors` tables and build DiskANN indexes (`build_nhtsa_vectors_text.sql`, plus the loader).
3. **Search (hybrid):** `VECTOR_SEARCH` over the small `*Vectors` table for semantic intent, oversample the top N, then `JOIN`/`EXISTS` back to the big relational table to apply exact filters — a post-filter pattern that keeps ANN fast while still honoring structured constraints (`nhtsa_hybrid_demos.sql`, `hybrid_expedition_2019.sql`).

## Engineering challenges solved
Real public data is where the interesting problems live. A few I had to work through:

- **Server-side file access.** `BULK INSERT` runs as the SQL Server service account (`NT Service\MSSQLSERVER`), which can't read out of a user profile folder. Fix: stage the data under `C:\ProgramData\...` and grant the service account read access with `icacls`.
- **Row terminators & encoding.** The feeds mix CRLF and LF rows and contain bytes that don't map cleanly in the default code page. Using `ROWTERMINATOR='0x0a'`, stripping stray `CHAR(13)`, and tuning `CODEPAGE`/`DATAFILETYPE` (with `MAXERRORS` to skip a handful of malformed rows) made a 2.4M-row load reliable.
- **Embedding messy free text at scale.** PowerShell's `ConvertTo-Json` mangles real-world narrative text (control characters, stray quotes), which Ollama rejects with a 400. The loader strips control characters, builds the JSON body by hand, and POSTs UTF-8 bytes — with per-batch `try/catch` so one bad row can't abort a multi-hour job.

## Repo structure
| File | Purpose |
|---|---|
| `nhtsa_setup_relational.sql` | Create the database and typed `Recalls` / `Complaints` tables |
| `build_recalls.sql` | Stage + load the recalls feed |
| `build_complaints.sql` | Stage + load the complaints feed |
| `build_nhtsa_vectors_text.sql` | Build the `*Vectors` tables, generate embeddings, create DiskANN indexes |
| `nhtsa_hybrid_demos.sql` | Hybrid semantic + relational query examples |
| `hybrid_expedition_2019.sql` | A full worked example (Ford Expedition, model year 2019) |
| `embed_loader_generic.ps1` | Reusable PowerShell batch embedding loader |

## Reproduce (high level)
1. SQL Server 2025 with the `VECTOR` features enabled; Ollama running locally with `nomic-embed-text` pulled.
2. Download the two NHTSA zips, unzip the flat files into a service-readable folder.
3. Run the SQL scripts in the order above; run `embed_loader_generic.ps1` to populate the vector columns.
4. Try the queries in `nhtsa_hybrid_demos.sql`.

*No credentials required — everything runs against a local SQL Server (Windows auth) and a local Ollama instance.*

---

*Part of my applied-AI portfolio — see [adam-sacks-portfolio](https://github.com/thesurfermonkey/adam-sacks-portfolio).*

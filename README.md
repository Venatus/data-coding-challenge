# data-coding-challenge

## Build a Marketing Data Mini-Pipeline (ClickHouse + Dagster + dbt)

### Goal: Build a simple but production-grade data pipeline:

- Extract marketing-relevant data from free CoinGecko API using Dagster (as an asset).
- Persist the raw payloads locally (e.g., data/raw/) or in cloud storage (S3/GCS/etc.).
- Load the raw data into ClickHouse as a source table (another Dagster asset).
- Transform the data with dbt following best practices (sources -> staging -> marts).

## Use CoinGecko
### Extract data from API (free)
1. Snapshot (no date dimension):
`GET /api/v3/coins/markets?vs_currency=usd&ids=bitcoin,ethereum`

2. Time series (has date dimension):
`GET /api/v3/coins/{id}/market_chart?vs_currency=usd&days=30&interval=daily`
(call for bitcoin and ethereum)

Pass your CoinGecko Demo key via x_cg_demo_api_key=... query param.

### Ingest the data
Create two raw tables in your warehouse:
- `raw.coin_markets_snapshot`
Columns: `ingested_at_ts, asset_id, symbol, name, current_price_usd, market_cap_usd, total_volume_usd, pct_change_24h, last_updated_ts`
- `raw.coin_price_history`
Columns: `asset_id, price_date (DATE), close_price_usd, market_cap_usd, total_volume_usd, source_ts_ms`.

Write a small Dagster asset that:
- fetches endpoint (1) once and upserts a single snapshot row per asset,
- fetches endpoint (2) for 30 days per asset and upserts one row per date.

Keep credentials in env vars; include a short README with run instructions.

### Create dbt models (use staging/ and marts/)

- stg_coin_markets_snapshot.sql – type cast, rename, dedupe to the latest snapshot per asset.
- stg_coin_price_history.sql – convert UNIX ms -> timestamp, derive price_date, one row per (asset_id, price_date).
- dim_asset.sql (mart) – latest name/symbol per asset_id.
- fct_asset_prices_daily.sql (mart) – one row per (asset_id, price_date) with:
    * close_price_usd, market_cap_usd, total_volume_usd,
    * daily_return_pct (based on previous day’s close),
    * optionally sma_7d_close (simple moving average).
- Add basic tests in schema.yml: not_null & unique on (asset_id, price_date) for the fact; not_null on key fields in dims/stgs.

### Deliverables
1. A repo with:
- README.md (how to run it end-to-end)
- Makefile (targets below)
- `dagster/` project with at least two assets:
    - extract asset (calls the API, writes raw files or lands to cloud)
    - load asset (ingests to ClickHouse “raw/source” table)
- `dbt/` project:
    - sources.yml pointing to the raw table in ClickHouse
    - staging/ models that cast/clean
    - one or more marts models with meaningful aggregations
    - tests (unique/not null) + unit tests + docs
2. Brief notes on design decisions and trade-offs
3. Provide a simple Makefile to set up and run everything end-to-end.
4. You can use Docker or your local installs. Keep it pragmatic and runnable.

### Notes: 
- a minimal `docker-compose.yml` for ClickHouse is provided in this repository.
- Keep secrets out of git. Provide `.env.example`.
- Favor small, readable functions.
- Document anything we need to know to run your pipeline in under 5 minutes.
- Database is optional: We suggest ClickHouse by default, but you may use any analytical/OLTP database you prefer—e.g. PostgreSQL, BigQuery, Snowflake, DuckDB, etc.
- Dagster orchestrator is optional: We suggest Dagster, but you may use any orchestrator you’re comfortable with (e.g., Airflow, Prefect, Mage, Argo, Temporal, Flyte).

## Timebox
3–6 hours. We’re not judging line count - focus on clarity, data pipeline design, correctness, and simplicity.

## Evaluation
- Correctness and reproducibility (does make all work?)
- Dagster design (assets/resources/config; simple, composable)
- dbt best practices (sources, staging, marts, tests, docs)
- Data modeling (sensible column types, keys, grain)
- If you are using ClickHouse focus on MergeTree choices, ordering keys.
- Code quality (readability, small functions, tests)
- Docs & UX (the README and Makefile are clear)

### Optional "Nice to Haves"
A few things to consider:
- Incremental loading in dbt (by created_ts)
- A snapshot for slowly changing attributes (if applicable)
- Basic data quality checks in Dagster (row count, schema drift)
- Emit Dagster metadata/artifacts (preview table, sample rows)
- Push raw files to S3 (use boto3) and load from there

## Functional acceptance criteria
- A one-command ingest works (e.g., make ingest or python ingest.py --coins bitcoin,ethereum).
- dbt run succeeds and builds the four models above.
- dbt test passes for the provided tests.
- A short README explains how to set env vars, run ingest, then dbt run/test, and shows 1–2 example queries (e.g., top 5 daily returns last 30 days).
- Provide a Makefile with the targets below so we can run it end-to-end.


## Suggested repo structure 

```sh
.
├─ Makefile
├─ README.md
├─ .env.example
├─ requirements.txt
├─ docker-compose.yml              # optional (ClickHouse or your DB)
├─ data/
│  └─ raw/
├─ dagster/
│  ├─ __init__.py
│  ├─ defs.py                      # Dagster Definitions
│  ├─ resources.py                 # e.g., DB clients, storage, etc.
│  ├─ assets/
│  │  ├─ extract.py                # extract asset (API -> JSONL/S3)
│  │  └─ load.py                   # load asset (ingest -> DB source table)
│  └─ dbt/                         # dbt project lives INSIDE Dagster
│     ├─ dbt_project.yml
│     ├─ profiles.yml              # project-local for simplicity
│     └─ models/
│        ├─ sources.yml
│        ├─ staging/
│        │  ├─ stg_events.sql
│        │  └─ stg_events.yml
│        └─ marts/
│           ├─ fct_daily_mentions.sql
│           └─ fct_daily_mentions.yml

```

## How we'll run it
Typical flow:
```
cp .env.example .env   # edit if needed
make setup
make up                 # optional if using docker-compose
make extract            # invokes Dagster extract asset
make load               # invokes Dagster load asset
make dbt_deps
make dbt_run
make dbt_test
```

Then we’ll check:
- Tables exist in ClickHouse and contain rows
- dbt models build + tests pass
- Clear notes on any assumptions

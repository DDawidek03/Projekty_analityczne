# Project 1: Macroeconomic Analysis — Full ETL Pipeline (GUS BDL API)

## Overview
This project implements a complete, production-grade **ETL/ELT pipeline** for regional macroeconomic data, sourced from the **Statistics Poland (GUS)** public REST API. The pipeline extracts 8 key performance indicators for **380+ Polish counties (powiats)** across 7 years (2018–2024), transforms deeply nested JSON responses, and loads the results into a **star schema** in a **PostgreSQL** database — ready for advanced SQL analysis, a **Power BI** report and natural-language queries through an **MCP server**.

> **Key Highlight:** This project demonstrates **two independent data loading strategies** (ETL and ELT), showcasing versatility in both Python-centric and SQL-centric data engineering approaches.

## Business Objectives
- Automate the extraction of 8 macroeconomic indicators using a scalable, loop-driven architecture.
- Handle API rate-limiting (HTTP 429), pagination, and robust error handling.
- Process nested JSON API responses into flat, analytical structures using **Pandas** and **Apache Parquet**.
- Model the data as a **star schema** (fact + dimensions) with incremental, idempotent loading.
- Deliver clean, compressed data to **PostgreSQL** for SQL analysis and **Power BI** for executive dashboarding.

---

## Data Architecture: Medallion Pattern (Bronze → Silver → Gold)

```
   ┌─────────────┐      ┌──────────────────┐      ┌───────────────────┐
   │  GUS REST   │      │   Pandas + JSON   │      │    PostgreSQL     │
   │    API      │ ───► │   Normalize +     │ ───► │   Staging  →      │
   │  (Source)   │      │   Pivot Table     │      │   Star Schema     │
   └─────────────┘      └──────────────────┘      └───────────────────┘
     Bronze Layer          Silver Layer              Gold Layer
   01_extract_api.py    02_transform_pandas.py    03a / 03b scripts
      Raw JSON          Apache Parquet (backup)    fact + dimensions
```

---

## Two Data Loading Strategies (ETL vs ELT)

This project intentionally implements **two different approaches** to the Gold Layer. Both fill the same staging table and run the same SQL, so they produce an identical star schema (verified row by row):

### Approach A: ELT — Raw JSON → PostgreSQL (SQL-Centric)
**Script:** `03a_load_sql_raw_json.py`

In this approach, raw JSON files are loaded directly into PostgreSQL, and the database engine handles all transformation logic using advanced SQL functions:
- **`json_to_recordset()`** — PostgreSQL native JSON parsing
- **`CROSS JOIN`** — Flattening nested arrays inside the database
- **`ON CONFLICT DO UPDATE` (UPSERT)** — Idempotent, incremental loading
- **Star Schema**: `dim_units`, `dim_year` and `fact_economic_indicators` built directly by the load script

> *Best suited for:* Teams with strong SQL/DBA expertise, real-time ingestion pipelines, and environments where Python is not available.

### Approach B: ETL — Parquet → PostgreSQL (Python-Centric)
**Script:** `03b_load_sql_parquet.py`

In this approach, all transformation is handled upstream in Python (Pandas), and the pre-processed, wide-format **Apache Parquet** file (which also serves as a backup of the extracted data) is loaded into PostgreSQL via `SQLAlchemy`:
- **`pd.json_normalize()`** — Recursive JSON flattening in Python
- **`pivot_table()`** — Reshaping long-to-wide format (Silver layer)
- **`to_parquet()` / `read_parquet()`** — Columnar storage with compression (PyArrow engine)
- **`melt()` + `to_sql()`** — Unpivot back to long format and bulk insert into the staging table, then the shared SQL builds the star schema

> *Best suited for:* Data Science teams, rapid prototyping, and environments where Python/Pandas is the primary tool.

---

## Data Model: Star Schema

![Star schema in PostgreSQL (DBeaver ER diagram)](images/star_schema.png)

**Grain:** one row = one county × one year (380 × 7 = **2,660 rows**). Foreign keys guarantee that every fact row points to an existing county and year.

### Tables

| Object | Type | Rows | Purpose |
|---|---|---|---|
| `fact_economic_indicators` | Fact | 2,660 | All 8 indicators per county and year, plus `loaded_at` audit timestamp |
| `dim_units` | Dimension | 380 | County name, unit type (314 land counties, 66 city counties), voivodeship (derived from characters 3–4 of the unit code) |
| `dim_year` | Dimension | 7 | Year 2018–2024 and `year_date` (31 Dec) for time intelligence in BI tools |
| `stg_gus_values` | Staging | 21,280 | Long format (indicator × county × year), cleared on every load. Not for analysis |
| `gus_indicators` | View | 2,660 | Flat fact + county view with Polish column names, used by `sql_analysis/04_business_queries.sql` |

### Measures

| Column | Indicator | Unit | Additive? |
|---|---|---|---|
| `unemployment_value` | Registered unemployed | persons | Yes |
| `population_value` | Total population | persons | Yes |
| `investment_value` | Capital investment in enterprises | thousand PLN | Yes |
| `salary_value` | Average gross monthly salary | PLN | No — use a population-weighted average |
| `new_firms_value` | New REGON entities | per 10k working-age pop. | No |
| `crime_detection_value` | Crime detection rate | % | No |
| `births_rate_value` | Live births | per 1,000 pop. | No — weight by population |
| `deaths_rate_value` | Deaths | per 1,000 pop. | No — weight by population |

The fact table is **wide** (one column per indicator). With a fixed set of indicators this keeps ratio calculations simple, e.g. unemployment as a share of population:

```sql
select
    u.voivodeship_name,
    f.year,
    round(sum(f.unemployment_value)::numeric / sum(f.population_value) * 100, 2) as unemployment_pct
from fact_economic_indicators f
join dim_units u on u.id = f.id_units
group by u.voivodeship_name, f.year
order by f.year, unemployment_pct desc;
```

### Loading logic

Both loaders run in a **single transaction**: either the whole load succeeds or the database stays unchanged.

1. `sql/01_create_star_schema.sql` — creates tables if they don't exist (`CREATE TABLE IF NOT EXISTS`) and clears the staging table. Existing data is never dropped.
2. Loader fills `stg_gus_values` — from raw JSON via `json_to_recordset()` (03a) or from Parquet via `melt()` (03b).
3. `sql/02_populate_star_schema.sql` — **incremental UPSERT** (`ON CONFLICT DO UPDATE`):
   - new counties and years are appended, existing rows are updated;
   - rows not present in the current load (e.g. older years) stay untouched;
   - `COALESCE` keeps the previous value if an indicator is missing in the current load.
4. `sql/03_quality_checks.sql` — expected result: 380 counties, 7 years, 2,660 fact rows, 0 NULLs, 16 voivodeships.

**Adding a new year:** add it to `LATA` in `scripts/config.py`, then run steps 1 → 2 → 3. Historical years remain in the database.

---

## Project Structure

```
01_Macroeconomic_Analysis_GUS/
├── README.md                          # Project documentation
├── Zadanie_Dodatkowe.md               # Business requirements & analyst brief
├── Projekt_1.pbix                     # Power BI report (connected to the PostgreSQL star schema)
├── miary_dax.md                       # DAX measures used in the report, with explanations
├── M_power_query.pq                   # Power Query M: fetching one indicator straight from the GUS API
│
├── scripts/
│   ├── 01_extract_api.py              # Bronze: API extraction, pagination, rate-limit handling
│   ├── 02_transform_pandas.py         # Silver: JSON flattening, pivot, Parquet export
│   ├── 03a_load_sql_raw_json.py       # Gold (ELT): JSON → staging via SQL → star schema
│   ├── 03b_load_sql_parquet.py        # Gold (ETL): Parquet → staging via Pandas → star schema
│   ├── config.py                      # Shared paths, indicator list, DB connection (.env)
│   └── sql/
│       ├── 01_create_star_schema.sql  # DDL: staging + dim_units, dim_year, fact (PK/FK)
│       ├── 02_populate_star_schema.sql# Staging → dimensions + facts, flat view gus_indicators
│       └── 03_quality_checks.sql      # Row counts, NULL checks, voivodeship coverage
│
├── sql_analysis/
│   ├── 04_business_queries.sql        # Business Queries: Window Functions (LAG), CTEs, Aggregations
│   └── ANALYTICAL_BRIEF.md            # Research questions and report requirements (PL)
│
├── mcp_server/
│   ├── server.py                      # MCP server: 7 read-only tools over the star schema
│   ├── gemini_client.py               # CLI client: ask Gemini a question, it calls the tools
│   ├── requirements.txt
│   └── README.md                      # Setup for Gemini, Claude Desktop, Claude Code, MCP Inspector
│
├── images/
│   ├── star_schema.png                # ER diagram of the star schema (DBeaver)
│   ├── mcp_gemini_demo.png            # Gemini answering a question via MCP tools
│   └── pbi_*.png                      # Power BI report pages (4 screenshots)
│
└── dane/
    ├── dane_*.json                    # Raw API responses (Bronze layer)
    └── merged_data.parquet            # Transformed wide-format dataset (Silver layer)
```

## Power BI Report

`Projekt_1.pbix` connects to the PostgreSQL star schema (`dim_units`, `dim_year`, `fact_economic_indicators`, 1:N relationships). It has 4 pages: **Dashboard**, **Inwestycje** (investment), **Demografia** (demography) and **Rynek pracy** (labour market).

Every page shares a navigation panel and two slicers: year range and voivodeship (screenshots below are filtered to mazowieckie).

**Dashboard:** salary KPIs and year-over-year growth, county salary vs national average 2018–2024, top counties ranked by salary with an index (national average = 100), average salary per voivodeship.

![Power BI: Dashboard](images/pbi_dashboard.png)

**Rynek pracy (labour market):** unemployment rate vs national rate, salary vs unemployment scatter (bubble size = population), year-over-year change in the unemployment rate as a waterfall chart.

![Power BI: Rynek pracy](images/pbi_rynek_pracy.png)

**Inwestycje (investment):** decomposition tree (county type → salary group → unemployment group → year → county), investment per resident vs national level, year-over-year investment change by county type.

![Power BI: Inwestycje](images/pbi_inwestycje.png)

**Demografia (demography):** county map, births and deaths per 1,000 residents over time, deaths-to-births ratio per voivodeship against the 1.5 crisis threshold, county table with natural increase and population change.

![Power BI: Demografia](images/pbi_demografia.png)

All measures are documented in [`miary_dax.md`](miary_dax.md), grouped by level: basic aggregations and `DIVIDE`, `CALCULATE` and filter context, year-over-year comparisons, rankings and iterators. Includes a population-weighted average, so large and small counties are not counted equally.

[`M_power_query.pq`](M_power_query.pq) shows an alternative path: loading one indicator (average salary) straight from the GUS API in Power Query M, with paging and record expansion.

## MCP Server: Ask the Data in Natural Language

[`mcp_server/`](mcp_server/) contains a **Model Context Protocol** server that lets an AI model (Gemini, Claude) answer questions about the county data. The model does not write SQL. It calls 7 fixed, parameterised, read-only tools (`top_counties`, `get_indicator`, `compare_to_national`, `voivodeship_summary`, …), and column names come from a whitelist, so model or user text never ends up in the query.

```bash
python3 mcp_server/gemini_client.py "Top 5 counties by unemployment in 2023"
```

![MCP + Gemini demo](images/mcp_gemini_demo.png)

Setup for Claude Desktop, Claude Code and MCP Inspector, plus the read-only database role, is in [`mcp_server/README.md`](mcp_server/README.md).

## Indicators Tracked

| Indicator ID | Name (PL) | Name (EN) | Unit | GUS Subject |
|---|---|---|---|---|
| 459121 | Bezrobocie | Unemployment | persons | P2425 |
| 64428 | Wynagrodzenia | Average Salary | PLN | P3045 |
| 155064 | Nakłady inwestycyjne | Capital Investments | thousand PLN | P2862 |
| 58565 | Wykrywalność przestępstw | Crime Detection Rate | % | P2290 |
| 395374 | Nowe podmioty REGON | Newly Registered Businesses | per 10k working-age pop. | P2419 |
| 72305 | Ludność ogółem | Total Population | persons | P2137 |
| 450540 | Urodzenia | Live Births Rate | per 1,000 pop. | — |
| 450541 | Zgony | Deaths Rate | per 1,000 pop. | — |

## Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| Extraction | Python `requests` | REST API communication, pagination, HTTP 429 handling |
| Transformation | `pandas`, `json`, `glob` | JSON flattening, pivot tables, data merging |
| Storage | Apache Parquet (`pyarrow`) | Columnar compression, type preservation |
| Database | PostgreSQL 16 | Relational storage, analytical SQL queries |
| ORM / Connector | SQLAlchemy + psycopg2 | Python ↔ PostgreSQL bridge |
| Visualization | Power BI Desktop (DAX, Power Query M) | 4-page report: dashboard, investment, demography, labour market |
| AI access | MCP server (`mcp` SDK) + Gemini / Claude | Natural-language questions answered through read-only SQL tools |

## How to Run
```bash
# Run from any directory — paths are resolved in scripts/config.py

# Step 1: Extract raw data from GUS API (Bronze Layer)
python scripts/01_extract_api.py

# Step 2: Transform & merge into Parquet (Silver Layer)
python scripts/02_transform_pandas.py

# Step 3: Load into PostgreSQL and build the star schema (Gold Layer) — choose one:
python scripts/03a_load_sql_raw_json.py   # ELT approach (SQL-centric)
python scripts/03b_load_sql_parquet.py    # ETL approach (Python-centric)
```

Database credentials are read from `.env` in the project root (`DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`, `DB_NAME`). See [Data Model: Star Schema](#data-model-star-schema) for what step 3 builds.

## Current Status
- [x] REST API Integration with pagination & rate-limit handling
- [x] Pandas data transformation & Apache Parquet export
- [x] PostgreSQL loading (two independent strategies: ETL & ELT)
- [x] Star schema with incremental UPSERT loading and quality checks
- [x] Advanced SQL Analysis (Window Functions, CTEs, Ranking)
- [x] Power BI report (4 pages) with documented DAX measures
- [x] MCP server: AI model queries the star schema through read-only tools

---

## Legal Disclaimer & Data Sources
**Data Source Attribution:**
All public statistical data utilized in this project is sourced from the **Statistics Poland (Główny Urząd Statystyczny - GUS)** via their official [Local Data Bank (BDL) API](https://bdl.stat.gov.pl/api/v1/).

**License:**
The data is provided under the **Creative Commons Attribution 4.0 International (CC BY 4.0)** license. The original creator of the statistical data is Statistics Poland (GUS). This repository and its creator are not affiliated with, nor endorsed by, Statistics Poland.

# Project 1: Macroeconomic Analysis — Full ETL Pipeline (GUS BDL API)

## Overview
This project implements a complete, production-grade **ETL/ELT pipeline** for regional macroeconomic data, sourced from the **Statistics Poland (GUS)** public REST API. The pipeline extracts 7 key performance indicators for **380+ Polish counties (powiats)** across 7 years (2018–2024), transforms deeply nested JSON responses into a flat analytical model, and loads the results into a **PostgreSQL** relational database — ready for advanced SQL analysis and **Power BI** dashboarding.

> **Key Highlight:** This project demonstrates **two independent data loading strategies** (ETL and ELT), showcasing versatility in both Python-centric and SQL-centric data engineering approaches.

## Business Objectives
- Automate the extraction of 7 macroeconomic indicators using a scalable, loop-driven architecture.
- Handle API rate-limiting (HTTP 429), pagination, and robust error handling.
- Process nested JSON API responses into flat, analytical structures using **Pandas** and **Apache Parquet**.
- Deliver clean, compressed data to **PostgreSQL** for SQL analysis and **Power BI** for executive dashboarding.

---

## Data Architecture: Medallion Pattern (Bronze → Silver → Gold)

```
   ┌─────────────┐      ┌──────────────────┐      ┌───────────────────┐
   │  GUS REST   │      │   Pandas + JSON   │      │    PostgreSQL     │
   │    API      │ ───► │   Normalize +     │ ───► │   Analytical      │
   │  (Source)   │      │   Pivot Table     │      │   Tables          │
   └─────────────┘      └──────────────────┘      └───────────────────┘
     Bronze Layer          Silver Layer              Gold Layer
   01_extract_api.py    02_transform_pandas.py    03a / 03b scripts
      Raw JSON             Apache Parquet          SQL-ready tables
```

---

## Two Data Loading Strategies (ETL vs ELT)

This project intentionally implements **two different approaches** to the Gold Layer, demonstrating flexibility in real-world data engineering:

### Approach A: ELT — Raw JSON → PostgreSQL (SQL-Centric)
**Script:** `03a_load_sql_raw_json.py`

In this approach, raw JSON files are loaded directly into PostgreSQL, and the database engine handles all transformation logic using advanced SQL functions:
- **`json_to_recordset()`** — PostgreSQL native JSON parsing
- **`CROSS JOIN`** — Flattening nested arrays inside the database
- **`ON CONFLICT DO UPDATE` (UPSERT)** — Idempotent, incremental loading
- **Star Schema**: Separate `dim_units` (dimension) and `fact_economic_indicators` (fact) tables

> *Best suited for:* Teams with strong SQL/DBA expertise, real-time ingestion pipelines, and environments where Python is not available.

### Approach B: ETL — Parquet → PostgreSQL (Python-Centric)
**Script:** `03b_load_sql_parquet.py`

In this approach, all transformation is handled upstream in Python (Pandas), and the pre-processed, wide-format **Apache Parquet** file is loaded into PostgreSQL via `SQLAlchemy`:
- **`pd.json_normalize()`** — Recursive JSON flattening in Python
- **`pivot_table()`** — Reshaping long-to-wide format for analytical queries
- **`to_parquet()` / `read_parquet()`** — Columnar storage with compression (PyArrow engine)
- **`to_sql()`** — Automated DDL generation and bulk insert via SQLAlchemy ORM

> *Best suited for:* Data Science teams, rapid prototyping, and environments where Python/Pandas is the primary tool.

---

## Project Structure

```
01_Macroeconomic_Analysis_GUS/
├── README.md                          # Project documentation
├── Zadanie_Dodatkowe.md               # Business requirements & analyst brief
│
├── scripts/
│   ├── 01_extract_api.py              # Bronze: API extraction, pagination, rate-limit handling
│   ├── 02_transform_pandas.py         # Silver: JSON flattening, pivot, Parquet export
│   ├── 03a_load_sql_raw_json.py       # Gold (ELT): Direct JSON → PostgreSQL via advanced SQL
│   └── 03b_load_sql_parquet.py        # Gold (ETL): Parquet → PostgreSQL via Pandas/SQLAlchemy
│
├── sql_analysis/
│   └── 04_business_queries.sql        # Business Queries: Window Functions (LAG), CTEs, Aggregations
│
└── dane/
    ├── dane_*.json                    # Raw API responses (Bronze layer)
    └── merged_data.parquet            # Transformed wide-format dataset (Silver layer)
```

## Indicators Tracked

| Indicator ID | Name (PL) | Name (EN) | Unit | GUS Subject |
|---|---|---|---|---|
| 459121 | Bezrobocie | Unemployment | persons | P2425 |
| 64428 | Wynagrodzenia | Average Salary | PLN | P3045 |
| 155064 | Nakłady inwestycyjne | Capital Investments | thousand PLN | P2862 |
| 58565 | Wykrywalność przestępstw | Crime Detection Rate | % | P2290 |
| 395374 | Nowe podmioty REGON | Newly Registered Businesses | per 10k working-age pop. | P2419 |
| 72305 | Ludność ogółem | Total Population | persons | P2137 |
| 3149 | Urodzenia | Births | persons | P3149 |

## Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| Extraction | Python `requests` | REST API communication, pagination, HTTP 429 handling |
| Transformation | `pandas`, `json`, `glob` | JSON flattening, pivot tables, data merging |
| Storage | Apache Parquet (`pyarrow`) | Columnar compression, type preservation |
| Database | PostgreSQL 16 | Relational storage, analytical SQL queries |
| ORM / Connector | SQLAlchemy + psycopg2 | Python ↔ PostgreSQL bridge |
| Visualization | Power BI *(planned)* | Executive dashboards, KPI reporting |

## How to Run
```bash
cd scripts/

# Step 1: Extract raw data from GUS API (Bronze Layer)
python 01_extract_api.py

# Step 2: Transform & merge into Parquet (Silver Layer)
python 02_transform_pandas.py

# Step 3: Load into PostgreSQL (Gold Layer) — choose one:
python 03a_load_sql_raw_json.py   # ELT approach (SQL-centric)
python 03b_load_sql_parquet.py    # ETL approach (Python-centric)
```

## Current Status
- [x] REST API Integration with pagination & rate-limit handling
- [x] Pandas data transformation & Apache Parquet export
- [x] PostgreSQL loading (two independent strategies: ETL & ELT)
- [x] Advanced SQL Analysis (Window Functions, CTEs, Ranking)
- [ ] Power BI Executive Dashboard

---

## Legal Disclaimer & Data Sources
**Data Source Attribution:**
All public statistical data utilized in this project is sourced from the **Statistics Poland (Główny Urząd Statystyczny - GUS)** via their official [Local Data Bank (BDL) API](https://bdl.stat.gov.pl/api/v1/).

**License:**
The data is provided under the **Creative Commons Attribution 4.0 International (CC BY 4.0)** license. The original creator of the statistical data is Statistics Poland (GUS). This repository and its creator are not affiliated with, nor endorsed by, Statistics Poland.

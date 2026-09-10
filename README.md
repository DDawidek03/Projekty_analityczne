# Data Analytics Portfolio

Welcome to my professional Data Analytics portfolio. This repository showcases my analytical workflow, focusing on **Database-First** principles, **Data Quality** standards, and **Actionable Business Reporting**.

## My Approach to Data Analysis
- **Database-First**: Building robust structures in PostgreSQL and DuckDB rather than processing massive data purely in memory.
- **Medallion Architecture (Bronze/Silver/Gold)**: Structuring data from raw API/File extraction (Bronze), through cleansing (Silver), to finalized analytical layers (Gold).
- **Data Quality Focus**: Verifying duplicates, handling NULLs, and ensuring consistent data types before reporting.
- **Business-Oriented Output**: Delivering insights, KPIs, and concrete recommendations rather than just visualizations.

## Technology Stack
- **Databases**: PostgreSQL (Relational), DuckDB (Columnar/Parquet processing)
- **Programming**: Python (Pandas, API Integration, PyArrow)
- **Reporting & BI**: Power BI, SQL (Window Functions, CTEs, Aggregations)

---

## Projects Overview

| Project | Business Domain | Key Technologies | Status |
|---|---|---|---|
| [**01. Macroeconomic Analysis (GUS API)**](./01_Macroeconomic_Analysis_GUS) | Economics, Public Data | Python, Parquet, PostgreSQL, SQL (Window Functions) | DB & SQL Complete |
| [**02. RFM Customer Segmentation**](./02_RFM_Segmentation_ECommerce) | E-Commerce, CRM | PostgreSQL, SQL Window Functions | Planned |
| [**03. Cohort Retention Analysis**](./03_Cohort_Retention_Analysis) | Behavioral Analytics, Churn | PostgreSQL, Datetime Operations | Planned |
| [**04. Big Data ETL (NYC Taxi)**](./04_BigData_ETL_NYCTaxi) | Big Data, ETL | DuckDB, Apache Parquet | Planned |
| [**05. Global Economic Indicators**](./05_WorldBank_Global_Indicators) | Macroeconomics, Time-Series | REST API, SQL LEAD/LAG | Planned |
| [**06. Financial Fraud Detection**](./06_Financial_Fraud_Detection) | Banking, Anomaly Detection | SQL Statistics (Z-Score, StdDev) | Planned |
| [**07. ABC/XYZ Inventory Classification**](./07_ABC_XYZ_Inventory_Classification) | Retail, Supply Chain | SQL Advanced Aggregations | Planned |

---

## Legal Disclaimer & Data Sources
**Data Source Attribution:**
All public statistical data utilized in Project 01 (Macroeconomic Analysis) is sourced from the **Statistics Poland (Główny Urząd Statystyczny - GUS)** via their official [Local Data Bank (BDL) API](https://bdl.stat.gov.pl/api/v1/).

**License:**
The data is provided under the **Creative Commons Attribution 4.0 International (CC BY 4.0)** license. The original creator of the statistical data is Statistics Poland (GUS). This repository and its creator are not affiliated with, nor endorsed by, Statistics Poland.

---
*Created by a Data Analyst dedicated to clean code and scalable data architecture.*

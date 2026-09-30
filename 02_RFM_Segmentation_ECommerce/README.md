# RFM Customer Segmentation – Olist Brazilian E-Commerce

**Stack:** PostgreSQL · SQL Window Functions · CTE · Aggregation  
**Dataset:** [Olist Brazilian E-Commerce (Kaggle)](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) – 8 relational tables, ~100k orders  
**Status:** Completed

---

## What's this project about?

Olist is a Brazilian marketplace that connects small sellers to major e-commerce platforms. The dataset contains real order data from 2016 to 2018.

The goal was to segment customers using RFM analysis (Recency, Frequency, Monetary) and answer a few practical business and data quality questions along the way. The kind of stuff you'd actually do in a BI role.

---

## Data Quality Checks (Layer 1)

Before building any model, I verified two things:

**1. Customer ID deduplication**  
The dataset has two customer identifiers: `customer_id` (technical, per-order) and `customer_unique_id` (per actual person). Using the wrong one inflates customer counts and breaks retention analysis. Average orders per `customer_id` ≈ 1.0 (useless), per `customer_unique_id` ≈ 1.03 (reflects real repeat buyers).

**2. Payment vs. order value discrepancy**  
Cross-checked `olist_order_payments` against `olist_order_items` (price + freight). Found orders where the difference exceeds 180 BRL – likely due to installment interest not captured in the items table. Top 10 discrepancies identified with a CTE-based query to avoid fan-out errors from direct multi-table joins.

---

## RFM Model (Layer 2)

Built in 4 sequential CTE steps:

| Step | What it does |
|---|---|
| `rfm` | Pulls last purchase date, order count, total payments per unique customer |
| `order_dates` | Gets the reference date (MAX timestamp in the whole dataset) |
| `raw_rfm` | Calculates R (days since last order), F (unique orders), M (total spend) |
| `rfm_scores` | Assigns 1–5 quintile scores using `NTILE(5)` window function |
| `rfm_segments` | Maps score combinations to business segments via `CASE WHEN` |

**Segment definitions:**

| Segment | Logic |
|---|---|
| Champions | R=5, F≥4, M≥4 |
| Loyal Customers | F≥4 |
| Potential Loyalists | R≥4, F between 2 and 3 |
| At Risk | R≤2, F≥3 |
| Hibernating / Lost | R=1, F=1 |
| General / Promotable | Everyone else |

**Key finding:**  
Champions represent less than 8% of the customer base but generate ~2.4M BRL in revenue – nearly the same as the General/Promotable group (39% of all customers). The General segment averages 62 BRL per customer vs 315 BRL for Champions. Classic Pareto distribution.

---

## Advanced SQL (Layer 3 – Recruitment Tasks)

Four SQL problems typical in Junior/Mid Data Analyst interviews:

| Task | Technique |
|---|---|
| 3.1 – 7-day Moving Average & Running Total | `ROWS BETWEEN 6 PRECEDING AND CURRENT ROW`, cumulative `SUM OVER` |
| 3.2 – Market basket analysis (top product pairs) | Self-JOIN on `order_id`, deduplication with `a.product_id < b.product_id` |
| 3.3 – Delivery delay vs. review score | `CASE WHEN` status flag, `NULLIF` for empty string casting, window function for % share |
| 3.4 – Payment method pivot | Conditional aggregation using `FILTER (WHERE ...)` |

---

## Business Conclusions

1. **Loyal Customers drive the business.** They're 32% of the base and responsible for the largest revenue block. Protecting this group should be the top marketing priority.

2. **Champions are disproportionately valuable.** A small group spending 5x the average. Deserve a separate retention track (VIP perks, early access), not a generic newsletter.

3. **Late deliveries destroy ratings.** Orders delivered after the estimated date average ~2.5 stars vs ~4.2 for on-time deliveries. The logistics issue has a direct, measurable impact on brand perception.

---

## Files

```
02_RFM_Segmentation_ECommerce/
├── 01_rfm_queries.sql    # All queries: data quality, RFM model, advanced SQL tasks
├── README.md
└── Data/                 # Raw CSV files (not tracked in git)
```

---

## What I learned

Window functions clicked for me on this project. The `NTILE(5)` approach for quintile scoring is something I'll reuse – it's cleaner than writing manual `CASE WHEN` percentile breakpoints. The `FILTER` clause for conditional aggregation was also new to me and genuinely more readable than the `SUM(CASE WHEN ...)` pattern.

The hardest part was avoiding fan-out in the payment discrepancy query. A direct multi-table JOIN without pre-aggregating via CTE multiplies rows and produces wrong sums – learned that the hard way.

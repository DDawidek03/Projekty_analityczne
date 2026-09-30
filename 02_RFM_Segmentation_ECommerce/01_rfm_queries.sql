-- ============================================================
-- PROJECT 2: RFM Customer Segmentation
-- Dataset: Olist Brazilian E-Commerce
-- Environment: PostgreSQL
-- ============================================================


-- ============================================================
-- LAYER 1 | DATA QUALITY CHECKS
-- ============================================================

-- Task 1.1 | customer_id vs customer_unique_id
-- The dataset has two identifiers. customer_id is generated per order,
-- so one person placing 3 orders gets 3 different customer_ids.
-- customer_unique_id tracks the actual human. Using customer_id
-- for retention or RFM would inflate the customer count and break the model.
-- Result: avg per customer_id ≈ 1.0 (everyone looks like a new customer)
--         avg per customer_unique_id ≈ 1.03 (reflects real repeat buyers)

with customer_unique as (

	select count(oo.order_id) as order_count
	from olist_customer oc
	inner join olist_orders oo on oo.customer_id = oc.customer_id
	group by oc.customer_unique_id

), customer as (

	select count(oo.order_id) as order_count
	from olist_customer oc
	inner join olist_orders oo on oo.customer_id = oc.customer_id
	group by oc.customer_id

)
select
	(select avg(order_count) from customer_unique) as avg_unique,
	(select avg(order_count) from customer) as avg_customer;


-- Task 1.2 | Zero and negative payments
-- Quick scan for transactions that shouldn't exist in a clean dataset.

select *
from olist_order_payments oop
where oop.payment_value = 0 or oop.payment_value < 0;


-- Task 1.2 | Payment vs. order value discrepancy (top 10)
-- Cross-checking what the customer paid against what the order was worth
-- (product price + freight). Differences > 0 suggest installment interest
-- or fees that don't appear in the items table.
-- Used CTEs to pre-aggregate both sides before joining.
-- Joining raw tables directly would cause row multiplication (fan-out)
-- if one order has multiple items and multiple payment entries.

with sum_payments as (

	select oop.order_id, sum(oop.payment_value) as total_payments
	from olist_order_payments oop
	group by oop.order_id

), sum_products as (

	select ooi.order_id, sum(ooi.price + ooi.freight_value) as total_items_val
	from olist_order_items ooi
	group by ooi.order_id

)
select
	sp.order_id,
	(sp.total_payments - spr.total_items_val) as difference,
	round(sp.total_payments::numeric, 2),
	round(spr.total_items_val::numeric, 2)
from sum_payments as sp
inner join sum_products as spr on spr.order_id = sp.order_id
order by difference desc
limit 10;


-- ============================================================
-- LAYER 2 | RFM SEGMENTATION MODEL
-- ============================================================

-- Full model built in 5 CTE steps:
-- rfm          → raw metrics per unique customer (R date, F count, M sum)
-- order_dates  → single reference date (MAX timestamp in the dataset)
-- raw_rfm      → calculates actual R/F/M values
-- rfm_scores   → quintile scoring 1-5 using NTILE window function
-- rfm_segments → maps score combinations to business labels
-- Final SELECT → executive summary grouped by segment

with rfm as (

	select
		max(oo.order_purchase_timestamp::date) as customer_dayes,
		oc.customer_unique_id as customer_unique_id,
		count(distinct oo.order_id) as total_orders,
		round(sum(oop.payment_value::numeric), 2) as total_amount
	from olist_orders oo
	inner join olist_customer oc on oc.customer_id = oo.customer_id
	inner join olist_order_payments oop on oop.order_id = oo.order_id
	group by oc.customer_unique_id

), order_dates as (

	-- Reference "today" for the dataset. Using current_date would make
	-- everyone look inactive since the data ends in 2018.
	select max(oo.order_purchase_timestamp::date) as order_dayes
	from olist_orders oo

), raw_rfm as (

	select
		rfm.customer_unique_id,
		(od.order_dayes - rfm.customer_dayes) as recency_days,
		rfm.total_orders as frequency,
		rfm.total_amount as monetary
	from rfm
	cross join order_dates od

), rfm_scores as (

	-- NTILE(5) splits customers into 5 equal buckets ranked by each metric.
	-- Recency is sorted DESC because fewer days = more recent = better score.
	-- Frequency and Monetary are sorted ASC so highest values get score 5.
	select
		rr.customer_unique_id,
		rr.recency_days,
		rr.frequency,
		rr.monetary,
		ntile(5) over (order by recency_days desc) as r_score,
		ntile(5) over (order by frequency)         as f_score,
		ntile(5) over (order by monetary)          as m_score
	from raw_rfm as rr

), rfm_segmnets as (

	-- CASE WHEN order matters here. Champions are evaluated first (most
	-- restrictive condition). If Loyal Customers came before Champions,
	-- everyone with F≥4 would land in Loyal and Champions would be empty.
	select
		rs.customer_unique_id,
		rs.recency_days || ' Days' as recency_days,
		rs.frequency,
		rs.monetary,
		case
			when r_score = 5 and f_score >= 4 and m_score >= 4 then 'Champions'
			when f_score >= 4                                   then 'Loyal Customers'
			when r_score >= 4 and f_score > 2 and f_score <= 3 then 'Potential Loyalists'
			when r_score <= 2 and f_score >= 3                  then 'At Risk'
			when r_score = 1 and f_score = 1                    then 'Hibernating / Lost'
			else 'General / Promotable'
		end as rfm_segment
	from rfm_scores rs

)
-- Executive summary: one row per segment with revenue and share breakdown.
-- SUM(COUNT(*)) OVER () gives total customer count across all segments
-- without a subquery, so we can calculate % share in a single pass.
select
	rfm_s.rfm_segment,
	round(count(rfm_s.customer_unique_id), 0) as number_of_customers,
	round(avg(rfm_s.monetary), 2) as average_expenses,
	round(sum(rfm_s.monetary), 2) as total_revenue,
	round((count(rfm_s.customer_unique_id) * 100.0) / sum(count(rfm_s.customer_unique_id)) over (), 2) || ' %' as percentage_share
from rfm_segmnets as rfm_s
group by rfm_s.rfm_segment
order by total_revenue desc;


-- ============================================================
-- LAYER 3 | ADVANCED SQL – RECRUITMENT TASKS
-- ============================================================

-- Task 3.1 | Running Total & 7-day Moving Average
-- Common interview question: show daily revenue + cumulative trend + smoothed trend.
-- CTE aggregates first, window functions run on top of already-grouped data.
-- ROWS BETWEEN 6 PRECEDING AND CURRENT ROW = look back 6 rows + current = 7 days.

with daily_revenue as (

	select
		sum(oop.payment_value) as Suma_przychodu,
		oo.order_purchase_timestamp::date as order_date
	from olist_order_payments as oop
	join olist_orders oo on oop.order_id = oo.order_id
	group by oo.order_purchase_timestamp::date

)
select
	Suma_przychodu,
	order_date,
	sum(Suma_przychodu) over (order by order_date) as running_total,
	avg(Suma_przychodu) over (order by order_date rows between 6 preceding and current row) as srednia_kroczaca
from daily_revenue;


-- Task 3.2 | Market Basket Analysis – top product pairs bought together
-- Self-join on order_id finds all products bought in the same order.
-- Condition a.product_id < b.product_id eliminates both self-matches
-- (shoe paired with itself) and mirror duplicates (A+B and B+A counted as one pair).
-- Joined olist_products twice to get category names for both products.

select
	count(*) as liczba_zamownien,
	ooi.product_id,
	ooi_2.product_id,
	op.product_category_name,
	op2.product_category_name
from olist_order_items as ooi
join olist_order_items as ooi_2 on ooi.order_id = ooi_2.order_id
join olist_products op  on op.product_id  = ooi.product_id
join olist_products op2 on op2.product_id = ooi_2.product_id
where ooi.product_id < ooi_2.product_id
group by ooi.product_id, ooi_2.product_id, op.product_category_name, op2.product_category_name
order by liczba_zamownien desc
limit 5;


-- Task 3.3 | Delivery delay vs. review score
-- Comparing on-time vs. late deliveries across three metrics:
-- order count, avg star rating, and avg delay in days.
-- NULLIF handles empty strings in date columns (stored as '' instead of NULL).
-- Without it, the ::date cast throws an error on empty values.
-- Window function calculates % share within a single query pass.

select
	count(*) as liczba_zamowien,
	round((count(*) * 100.0) / sum(count(*)) over (), 2) || ' %' as procent_calosci,
	round(avg(oor.review_score), 2) as srednia_ilosc_gwiazdek,
	round(avg(
		nullif(os.order_delivered_customer_date, '')::date
		- nullif(os.order_estimated_delivery_date, '')::date
	), 1) || ' dni' as srednie_opoznienie,
	case
		when os.order_delivered_customer_date > os.order_estimated_delivery_date then 'Opoznione'
		else 'na czas'
	end status_dostawy
from public.olist_orders os
inner join public.olist_order_reviews oor on os.order_id = oor.order_id
where os.order_estimated_delivery_date is not null
group by status_dostawy;


-- Task 3.4 | Payment method pivot (conditional aggregation)
-- Converts rows into columns – one column per payment type.
-- FILTER is PostgreSQL-native syntax, cleaner than SUM(CASE WHEN ...).
-- Result: single row with revenue totals broken down by payment method.

select
	sum(oop.payment_value) filter (where oop.payment_type = 'credit_card') as credit_card_total,
	sum(oop.payment_value) filter (where oop.payment_type = 'boleto')      as boleto_total,
	sum(oop.payment_value) filter (where oop.payment_type = 'voucher')     as voucher_total
from olist_order_payments oop;
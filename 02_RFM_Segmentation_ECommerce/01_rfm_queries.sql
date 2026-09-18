with customer_unique as (

	select  count(oo.order_id ) as order_count
		from olist_customer oc 
		inner join olist_orders oo 
		on oo.customer_id  = oc.customer_id 
	group by oc.customer_unique_id  
	
), customer as (

	select  count(oo.order_id ) as order_count
		from olist_customer oc 
		inner join olist_orders oo 
		on oo.customer_id  = oc.customer_id 
	group by oc.customer_id   
)
select 
  (select avg(order_count) from customer_unique) as avg_unique,
  (select avg(order_count) from customer) as avg_customer;
	
--- The customer_unique column should be used because its average is ~ 1.03, which means there are a few customers with a higher amount of orders, making it more accurate
--- additionally, the regular id average is 1, which means this data is not perfectly accurate because all ids have 1, meaning all orders are assigned to different ids which can lead to issues

select *
from olist_order_payments oop 
where oop.payment_value = 0 or oop.payment_value < 0

with sum_payments as (

	select oop.order_id, sum(oop.payment_value) as total_payments
	from olist_order_payments oop 
	group by oop.order_id 

), sum_products as (

	select ooi.order_id, sum(ooi.price + ooi.freight_value ) as total_items_val
	from olist_order_items ooi 
	group by ooi.order_id 
)

select sp.order_id, (sp.total_payments - spr.total_items_val) as difference, round(sp.total_payments::numeric,2), round(spr.total_items_val::numeric,2)
from sum_payments as sp
inner join sum_products as spr
on spr.order_id = sp.order_id
order by difference desc
limit 10

with rfm as (

	select  max(oo.order_purchase_timestamp::date) as customer_dayes, 
			oc.customer_unique_id as customer_unique_id,
			count(distinct oo.order_id ) as total_orders,
			round(sum(oop.payment_value::numeric),2) as total_amount
	from olist_orders oo 
	inner join olist_customer oc on oc.customer_id = oo.customer_id
	inner join olist_order_payments oop on oop.order_id = oo.order_id 
	group by oc.customer_unique_id 

), order_dates as (

	select max(oo.order_purchase_timestamp::date) as order_dayes
	from olist_orders oo
	
), raw_rfm as (

	select  
    	rfm.customer_unique_id,
    	( od.order_dayes - rfm.customer_dayes ) as recency_days,
    	rfm.total_orders as frequency,
    	rfm.total_amount as monetary

	from rfm
	cross join order_dates od
), rfm_scores as (

	select  
    	rr.customer_unique_id,
    	rr.recency_days,
    	rr.frequency,
    	rr.monetary,
    	ntile(5) over (order by recency_days desc ) AS r_score,
    	ntile(5) over (order by frequency ) AS f_score,
    	ntile(5) over (order by monetary ) AS m_score

	from raw_rfm as rr
	
), rfm_segmnets as (

select rs.customer_unique_id,
	   rs.recency_days || ' Days' as recency_days,
       rs.frequency,
       rs.monetary,
		case
			when r_score = 5 and f_score >= 4 and m_score >= 4 then 'Champions'
			when f_score >= 4 then 'Loyal Customers'
			when r_score >= 4 and f_score > 2 and f_score <= 3 then 'Potential Loyalists'
			when r_score <= 2 and f_score >= 3 then 'At Risk'
			when r_score = 1 and f_score = 1 then 'Hibernating / Lost'
			else 'General / Promotable'
		end as rfm_segment
from rfm_scores rs
)

select 
		rfm_s.rfm_segment,
		round(count(rfm_s.customer_unique_id),0) as number_of_customers,
		round(AVG(rfm_s.monetary),2) as average_expenses,
		round(SUM(rfm_s.monetary),2) as total_revenue,
		ROUND((COUNT(rfm_s.customer_unique_id) * 100.0) / SUM(COUNT(rfm_s.customer_unique_id)) OVER (), 2) || ' %' AS percentage_share
from rfm_segmnets as rfm_s
group by rfm_s.rfm_segment
order by total_revenue desc

--- 3.4
select 
	   SUM(oop.payment_value) filter (where oop.payment_type = 'credit_card') as credit_card_total,
	   SUM(oop.payment_value) filter ( where oop.payment_type = 'boleto') as boleto_total,
	   SUM(oop.payment_value) filter ( where oop.payment_type = 'voucher') as voucher_total
from olist_order_payments oop
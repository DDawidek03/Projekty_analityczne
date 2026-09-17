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
)

select  
    rfm.customer_unique_id,
    ( od.order_dayes - rfm.customer_dayes ) as recency_days,
    rfm.total_orders as frequency,
    rfm.total_amount as monetary
from rfm
cross join order_dates od
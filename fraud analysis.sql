---return 5 times
WITH refund_repl_detail AS (
Select o.order_id, s.shipment_id, o.email,o.address_id,
       case
           when lower(o.notes) like '%replace%' or lower(o.notes) like '%rpl%' or
                lower(o.notes) like '%repl%' or roh.order_id <> 0 then 1
           else 0 end                                                  as likely_replacement,
       case when lower(o.notes) like '%refund%' or lower(o.notes) like '%ref%' or lower(o.notes) like '%credit%' or roc.return_order_id is not null
       then 1 else 0 end as likely_refund
from shipment s
JOIN orders o
ON o.order_id = s.order_id
left join ugcld.return_order ro ON ro.shipment_id = s.shipment_id
LEFT JOIN ugcld.return_order_history roh
ON ro.return_order_id = roh.return_order_id and roh.order_id <> 0
and lower(roh.notes) like '%replace%'
LEFT JOIN return_order_credit roc
ON roc.return_order_id = roh.return_order_id
WHERE s.authorized::date >= '2020-01-01'::date and s.authorized::date <= '2020-12-31'::Date
Group by 1,2,3,5,6
)
SELECT case when email is not null then email else address_id::varchar
end as contact,
       count(distinct order_id) refund_replace_count
FROM refund_repl_detail
WHERE likely_replacement + likely_refund > 0
GROUP BY contact
HAVING count(distinct order_id) >= 5
;

---return by reason
with list as(
with returns as(
select distinct o.order_id, s.shipment_id, rosr.reason_name, ro.return_order_id, roh.notes
FROM shipment s JOIN orders o ON o.order_id = s.order_id
JOIN return_order ro ON ro.shipment_id = s.shipment_id
LEFT JOIN return_order_history roh ON ro.return_order_id = roh.return_order_id and (lower(roh.notes) like '%replace%' AND roh.order_id <> 0)
JOIN return_order_sku ros ON ros.return_order_id=ro.return_order_id
JOIN return_order_sku_reason rosr ON rosr.return_order_sku_reason_id=ros.return_order_sku_reason_id
LEFT JOIN return_order_credit roc ON roc.return_order_id = roh.return_order_id
where (lower(roh.notes) like '%replace%' OR lower(o.notes) like '%rpl%'
OR lower(o.notes) like '%repl%' OR  lower(o.notes) like '%refund%'
OR lower(o.notes) like '%ref%' or lower(o.notes) like '%credit%' or roc.return_order_id is not null OR roh.order_id <> 0)
AND s.authorized::date >= '2020-01-01'::date
AND s.authorized::date <= '2020-12-31'::Date
)
SELECT returns.*, roh.notes notes1, roh2.notes notes2 
from returns
JOIN shipment s ON s.shipment_id = returns.shipment_id
LEFT JOIN return_order_history roh ON returns.return_order_id = roh.return_order_id and (lower(roh.notes) like '%with call tag attached')
LEFT JOIN return_order_history roh2 ON returns.return_order_id = roh2.return_order_id and (roh2.notes iLIKE '%updated the status of SKU%' OR roh2.notes iLIKE '% RTI%')
WHERE s.is_cancelled = 0)


select list.order_id, list.shipment_id, list.reason_name, list.return_order_id,
CASE when list.notes1 like '%with call tag attached' then 'label sent' else'label unsent' end as "label status",
CASE when list.notes2 like '%updated the status of SKU%' OR list.notes2 iLIKE '% RTI%' then 'item return' else'item not return' end as "item status"
from list

;


---return by sku
with list as (
select distinct o.order_id, s.shipment_id,osk.sku,case when sk.sze || ' '|| sk.color like '%&#%' or sk.sze || ' '|| sk.color like '%nbsp%' then sk.sze else sk.sze || ' '|| sk.color end as description, o.notes
FROM shipment s JOIN orders o ON o.order_id = s.order_id
JOIN return_order ro ON ro.shipment_id = s.shipment_id
LEFT JOIN return_order_history roh ON ro.return_order_id = roh.return_order_id and (lower(roh.notes) like '%replace%' AND roh.order_id <> 0)
JOIN return_order_sku ros ON ros.return_order_id=ro.return_order_id
JOIN order_sku osk ON osk.order_sku_id=ros.order_sku_id
JOIN sku sk on sk.sku=osk.sku
JOIN return_order_sku_reason rosr ON rosr.return_order_sku_reason_id=ros.return_order_sku_reason_id
LEFT JOIN return_order_credit roc ON roc.return_order_id = roh.return_order_id
where (lower(roh.notes) like '%replace%' OR lower(o.notes) like '%rpl%'
OR lower(o.notes) like '%repl%' OR  lower(o.notes) like '%refund%'
OR lower(o.notes) like '%ref%' or lower(o.notes) like '%credit%' or roc.return_order_id is not null OR roh.order_id <> 0)
AND s.authorized::date >= '2020-01-01'::date
AND s.authorized::date <= '2020-12-31'::Date
order by o.order_id
)
select list.sku,list.description, count(distinct list.order_id) total_return
from list
group by 1,2
order by total_return desc
;

---return by value
with list as(
with returns as(
SELECT distinct o.order_id,s.shipment_id, osk.sku,ro.return_order_id, roh.NOTES
FROM shipment s JOIN orders o ON o.order_id = s.order_id
JOIN return_order ro ON ro.shipment_id = s.shipment_id
LEFT JOIN return_order_history roh ON ro.return_order_id = roh.return_order_id  and (lower(roh.notes) like '%replace%' AND roh.order_id <> 0)
JOIN return_order_sku ros ON ros.return_order_id=ro.return_order_id
LEFT JOIN order_sku osk ON osk.order_sku_id=ros.order_sku_id
LEFT JOIN return_order_credit roc ON roc.return_order_id = roh.return_order_id
JOIN return_order_sku_reason rosr ON rosr.return_order_sku_reason_id=ros.return_order_sku_reason_id
where (lower(roh.notes) like '%replace%' OR lower(o.notes) like '%rpl%'
OR lower(o.notes) like '%repl%' OR  lower(o.notes) like '%refund%'
OR lower(o.notes) like '%ref%' or lower(o.notes) like '%credit%' or roc.return_order_id is not null OR roh.order_id <> 0)
AND s.authorized::date >= '2020-01-01'::date
AND s.authorized::date <= '2020-12-31'::Date
AND s.is_cancelled = 0

)

SELECT returns.*, roh.notes notes1, roh2.notes notes2 
from returns
JOIN shipment s ON s.shipment_id = returns.shipment_id
LEFT JOIN return_order_history roh ON returns.return_order_id = roh.return_order_id and (lower(roh.notes) like '%with call tag attached')
LEFT JOIN return_order_history roh2 ON returns.return_order_id = roh2.return_order_id and (roh2.notes iLIKE '%updated the status of SKU%' OR roh2.notes iLIKE '% RTI%')
)
select distinct list.order_id, list.shipment_id, list.sku,
CASE when list.notes1 like '%with call tag attached' then 'label sent' else'label unsent' end as "label status",
CASE when list.notes2 is not null then 'item return' else'item not return' end as "item status"
from list

;
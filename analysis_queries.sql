-- E-commerce product analytics
-- MySQL 8. Window functions are standard syntax, date functions are not.

create database retail;
use retail;

create table transactions (
    Invoice      varchar(20),
    StockCode    varchar(20),
    Description  varchar(200),
    Quantity     int,
    InvoiceDate  datetime,
    Price        decimal(10,2),
    Customer_ID  varchar(20),
    Country      varchar(50),
    Revenue      decimal(12,2)
);

create index idx_invoice on transactions (Invoice);


-- 1. Monthly KPIs

select
    date_format(InvoiceDate, '%Y-%m')                as month,
    count(distinct Invoice)                          as orders,
    count(distinct Customer_ID)                      as customers,
    round(sum(Revenue), 2)                           as revenue,
    round(sum(Revenue) / count(distinct Invoice), 2) as aov
from transactions
group by month
order by month;


-- 2. Cohort retention by months since first purchase

with first_purchase as (
    select
        Customer_ID,
        min(date_format(InvoiceDate, '%Y-%m-01')) as cohort_month
    from transactions
    group by Customer_ID
),
activity as (
    select distinct
        t.Customer_ID,
        f.cohort_month,
        timestampdiff(month, f.cohort_month, date_format(t.InvoiceDate, '%Y-%m-01')) as cohort_index
    from transactions t
    join first_purchase f on t.Customer_ID = f.Customer_ID
)
select
    cohort_month,
    count(distinct case when cohort_index = 0 then Customer_ID end) as m0,
    count(distinct case when cohort_index = 1 then Customer_ID end) as m1,
    count(distinct case when cohort_index = 2 then Customer_ID end) as m2,
    count(distinct case when cohort_index = 3 then Customer_ID end) as m3,
    count(distinct case when cohort_index = 4 then Customer_ID end) as m4
from activity
group by cohort_month
order by cohort_month;


-- 3. RFM segmentation
-- Segments use R and F only. M correlates with F and would double count.

with rfm as (
    select
        Customer_ID,
        datediff('2011-12-10', max(InvoiceDate)) as recency,
        count(distinct Invoice)                  as frequency,
        sum(Revenue)                             as monetary
    from transactions
    group by Customer_ID
),
scored as (
    select
        Customer_ID, recency, frequency, monetary,
        ntile(5) over (order by recency desc)            as r_score,
        ntile(5) over (order by frequency, Customer_ID)  as f_score,
        ntile(5) over (order by monetary)                as m_score
    from rfm
)
select
    case
        when r_score >= 4 and f_score >= 4 then 'Champions'
        when r_score >= 3 and f_score >= 3 then 'Loyal'
        when r_score >= 4 and f_score <= 2 then 'New'
        when r_score <= 2 and f_score >= 3 then 'At Risk'
        else 'Hibernating'
    end                     as segment,
    count(*)                as customers,
    round(sum(monetary), 0) as revenue,
    round(avg(monetary), 0) as avg_value
from scored
group by segment
order by revenue desc;


-- 4. Top products by revenue against reach

with product_revenue as (
    select
        StockCode,
        max(Description)        as description,
        sum(Revenue)            as revenue,
        count(distinct Invoice) as invoices
    from transactions
    group by StockCode
)
select
    rank() over (order by revenue desc)        as revenue_rank,
    dense_rank() over (order by invoices desc) as popularity_rank,
    description,
    round(revenue, 0) as revenue,
    invoices
from product_revenue
order by revenue desc
limit 15;


-- 5. Running total with month on month and year on year change

with monthly as (
    select
        date_format(InvoiceDate, '%Y-%m-01') as month,
        sum(Revenue) as revenue
    from transactions
    group by month
)
select
    month,
    round(revenue, 0)                            as revenue,
    round(sum(revenue) over (order by month), 0) as running_total,
    round(lag(revenue) over (order by month), 0) as prev_month,
    round(100 * (revenue - lag(revenue) over (order by month))
              / lag(revenue) over (order by month), 1)     as mom_pct,
    round(100 * (revenue - lag(revenue, 12) over (order by month))
              / lag(revenue, 12) over (order by month), 1) as yoy_pct
from monthly
order by month;


-- 6. Co-purchase pairs
-- a.StockCode < b.StockCode keeps each pair in one direction only.
-- Restricted to products in 200+ invoices, otherwise the join is 20x larger.

with popular as (
    select StockCode
    from transactions
    group by StockCode
    having count(distinct Invoice) >= 200
)
select
    a.StockCode               as product_a,
    b.StockCode               as product_b,
    max(a.Description)        as name_a,
    max(b.Description)        as name_b,
    count(distinct a.Invoice) as pair_count
from transactions a
join transactions b
    on a.Invoice = b.Invoice
    and a.StockCode < b.StockCode
where a.StockCode in (select StockCode from popular)
  and b.StockCode in (select StockCode from popular)
group by a.StockCode, b.StockCode
having count(distinct a.Invoice) >= 100
order by pair_count desc
limit 20;


-- 7. Days between first and second purchase

with ordered as (
    select
        Customer_ID,
        Invoice,
        min(InvoiceDate) as order_date,
        row_number() over (partition by Customer_ID order by min(InvoiceDate)) as order_no
    from transactions
    group by Customer_ID, Invoice
),
gaps as (
    select
        Customer_ID,
        datediff(
            max(case when order_no = 2 then order_date end),
            max(case when order_no = 1 then order_date end)
        ) as days_to_second
    from ordered
    where order_no <= 2
    group by Customer_ID
)
select
    case
        when days_to_second is null then 'never returned'
        when days_to_second <= 30   then '0-30 days'
        when days_to_second <= 60   then '31-60 days'
        when days_to_second <= 90   then '61-90 days'
        else '90+ days'
    end      as bucket,
    count(*) as customers,
    round(100 * count(*) / sum(count(*)) over (), 1) as pct
from gaps
group by bucket
order by customers desc;
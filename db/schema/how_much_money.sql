create or replace view ufimtsev_food.how_much_money as 
    with recursive months as (
        select
            date_trunc('month', min(o.order_timestamp))::date as month,
            date_trunc('month', max(o.order_timestamp))::date as max_month 
        from ufimtsev_food."order" o
        where o.status = 'доставлен'

        union all

        select
            (m.month + interval '1 month')::date, max_month
        from months m
        where m.month < m.max_month
    ),
    grouped_orders as (
        select 
            date_trunc('month', o.order_timestamp)::date as month,
            sum(o.order_amount) as sum_without_commission,
            sum(o.total_amount) as sum_with_commission
        from ufimtsev_food."order" o
        where o.status = 'доставлен'
        group by date_trunc('month', o.order_timestamp) 
    ),
    grouped_salary as (
        select 
            cp.year,
            cp.month,
            sum(cp.amount) as total_salary
        from ufimtsev_food.courier_pay cp 
        group by cp.year, cp.month
    )

    select 
        to_char(m.month, 'YYYY-MM') as year_month,
        coalesce(o.sum_without_commission, 0) as sum_no_commission,
        coalesce(o.sum_with_commission, 0) as sum_with_commission,
        coalesce(o.sum_with_commission, 0) - coalesce(o.sum_without_commission, 0) as commission,
        lag(coalesce(o.sum_with_commission, 0) - coalesce(o.sum_without_commission, 0)) over (order by m.month) as prev_commission,
        coalesce(o.sum_with_commission, 0) 
            - coalesce(o.sum_without_commission, 0) 
            - lag(coalesce(o.sum_with_commission, 0) 
            - coalesce(o.sum_without_commission, 0)) over (order by m.month) as commission_diff,
        coalesce(gs.total_salary, 0) as courier_pay,
        coalesce(o.sum_with_commission, 0) - coalesce(o.sum_without_commission, 0) - coalesce(gs.total_salary, 0) as net_profit
    from months m
    left join grouped_orders o on o.month = m.month
    left join grouped_salary gs on 
        gs.year = extract(year from m.month)
        and gs.month = extract(month from m.month)
    where m.month is not null
    order by m.month;
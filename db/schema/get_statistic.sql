create or replace function ufimtsev_food.get_statistic()
returns table (
    restaurant_name varchar(100), 
    best_product_name varchar(100),
    total_amount numeric(10, 2),
    avg_amount numeric(10, 2),
    best_user varchar(50)
) as $$
begin
    return query
    with delivered_orders as materialized (
        select 
            o.order_id,
            o.restaurant_id,
            o.client_id,
            o.total_amount
        from ufimtsev_food."order" o
        where o.status = 'доставлен'
    ),
    best_product as (
        select 
            best_product.restaurant_id,
            best_product.product_name,
            best_product.summa,
            best_product.row_num
        from (
            select
                o.restaurant_id,
                p.product_name,
                sum(os.quantity) as summa,
                row_number() over (partition by o.restaurant_id order by sum(os.quantity) desc, random()) as row_num
            from ufimtsev_food.product p
            join ufimtsev_food.order_structure os on p.product_id = os.product_id
            join delivered_orders o on o.order_id = os.order_id
            group by p.product_name, o.restaurant_id, p.product_id
        ) as best_product
        where best_product.row_num = 1
    ),
    best_buyer as (
        select 
            o.restaurant_id, 
            c.login,
            count(o.order_id) as orders_count,
            row_number() over (partition by o.restaurant_id order by count(o.order_id) desc, random()) as row_num
        from delivered_orders o
        left join ufimtsev_food.client c on c.client_id = o.client_id
        group by o.restaurant_id, c.login
    ),
    order_stats as (
        select
            o.restaurant_id,
            sum(o.total_amount) as total_amount,
            avg(o.total_amount) as avg_amount
        from delivered_orders o
        group by o.restaurant_id
    )

    select 
        r.restaurant_name as restaurant_name,
        bp.product_name as best_product_name,
        ost.total_amount as total_amount,
        ost.avg_amount as avg_amount,
        bb.login as best_user
    from ufimtsev_food.restaurant r
    left join best_product bp on bp.restaurant_id = r.restaurant_id
    left join best_buyer bb on bb.restaurant_id = r.restaurant_id
        and bb.row_num = 1
    left join order_stats ost on ost.restaurant_id = r.restaurant_id;

end;
$$ language plpgsql;
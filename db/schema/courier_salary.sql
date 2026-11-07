create or replace procedure ufimtsev_food.courier_salary() as $$
declare
    d_courier record;
    d_orders_count int;
    d_total_commission numeric(10, 2);
    d_salary numeric(10, 2);
    d_new_coefficient numeric(3, 1);
    d_coefficient_used numeric(5, 2);
begin
    for d_courier in
        select *
        from ufimtsev_food.courier c
        where c.hire_date < date_trunc('month', now()::date) + interval '1 month'
            and (c.dismissal_date is null
                or c.dismissal_date >= date_trunc('month', now()::date))
    loop

        select count(o.order_id), coalesce(sum(o.commission), 0) into d_orders_count, d_total_commission
        from ufimtsev_food."order" o
        where o.courier_id = d_courier.courier_id
            and o.status = 'доставлен'
            and date_trunc('month', o.delivery_timestamp) = date_trunc('month', now()::date);
        
        select cp.coefficient_used into d_coefficient_used
        from ufimtsev_food.courier_pay cp
        where cp.courier_id = d_courier.courier_id
            and cp.year = extract(year from now()::date)
            and cp.month = extract(month from now()::date);
        
        d_coefficient_used = coalesce(d_coefficient_used, d_courier.coefficient);

        d_salary = d_coefficient_used * d_total_commission;

        insert into ufimtsev_food.courier_pay (year, month, courier_id, amount, coefficient_used)
        values (
            extract(year from now()::date), extract(month from now()::date),
            d_courier.courier_id, d_salary, d_coefficient_used)
        on conflict (year, month, courier_id)
        do update set
            amount = d_salary,
            coefficient_used = d_coefficient_used;

        if d_orders_count <= 150 then
            d_new_coefficient = 0.1;
        elsif d_orders_count <= 250 then
            d_new_coefficient = 0.2;
        elsif d_orders_count <= 500 then
            d_new_coefficient = 0.3;
        else
            d_new_coefficient = 0.5;
        end if;

        if d_courier.dismissal_date is null then
            update ufimtsev_food.courier
            set coefficient = d_new_coefficient
            where courier_id = d_courier.courier_id;
        end if;

    end loop;
end;
$$ language plpgsql;
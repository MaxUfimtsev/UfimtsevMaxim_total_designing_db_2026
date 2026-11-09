create or replace procedure ufimtsev_food.courier_salary() as $$
declare
    d_courier record;
    d_orders_count int;
    d_total_commission numeric;
    d_salary numeric(8, 2);
    d_new_coefficient numeric(2, 1);
begin
    for d_courier in
        select *
        from ufimtsev_food.courier c
        where c.dismissal_date is null
            or dismissal_date >= date_trunc('month', current_date)
    loop

        select count(o.order_id), coalesce(sum(o.commission), 0) into d_orders_count, d_total_commission
        from ufimtsev_food."order" o
        where o.courier_id = d_courier.courier_id
            and o.status = 'доставлен'
            and date_trunc('month', o.delivery_timestamp) = date_trunc('month', current_date);

        d_salary = d_courier.coefficient * d_total_commission;

        insert into ufimtsev_food.courier_pay (year, month, courier_id, amount, coefficient_used)
        values (
            extract(year from current_date), extract(month from current_date),
            d_courier.courier_id, d_salary, d_courier.coefficient)
        on conflict (year, month, courier_id)
        do update set
            amount = d_salary,
            coefficient_used = d_courier.coefficient;

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
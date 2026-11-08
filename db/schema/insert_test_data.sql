create or replace procedure ufimtsev_food.insert_test_data(value int) as $$
declare
    d_courier_status ufimtsev_food.courier_status;
    d_hire_date date;
    d_dismissal_date date;
    d_client_count bigint;
    d_client_id uuid;
    d_address_id uuid;
    d_restaurant_address_id uuid;
    d_product_category_id uuid;
    d_restaurant_id uuid;
    d_order_status ufimtsev_food.order_status;
    d_courier_id uuid;
    d_order_id uuid;
    d_order_timestamp timestamp;
    d_delivery_timestamp timestamp;
    d_order_amount numeric;
    d_order_total numeric;
    d_review_entity_type ufimtsev_food.review_entity_type;
    d_review_entity_id uuid;
    d_pay_month date;
    d_pay_coefficient numeric;
    d_next_coefficient numeric;
    d_delivered_count bigint;
    d_commission_sum numeric;
begin
    if value is null or value <= 0 then
        raise exception 'Value должен быть положительным';
    end if;

    select count(*) into d_client_count
    from ufimtsev_food.client;

    for i in 1..value
    loop
        d_product_category_id = exts.uuid_generate_v4();

        insert into ufimtsev_food.product_category (product_category_id, product_category_name)
        values (d_product_category_id, 'Категория  ' || i);
        
        if i = 1 then
            d_courier_status = 'свободен';
        else   
            d_courier_status = (enum_range(null::ufimtsev_food.courier_status))[
                floor(random() * 4)::int + 1
            ];
        end if;

        d_hire_date = now()::date - floor(random() * 180)::int;

        if d_courier_status = 'уволен' then
            d_dismissal_date = d_hire_date + floor(random() * (now()::date - d_hire_date + 1))::int;
        else
            d_dismissal_date = null;
        end if;

        d_courier_id = exts.uuid_generate_v4();

        insert into ufimtsev_food.courier (courier_id, FIO, phone_number, status, hire_date, dismissal_date)
        values (
            d_courier_id,
            'Курьер ' || substring(md5(random()::text), 1, 12), 
            '+7' || (floor(random()*9000000000)+1000000000)::bigint::text, 
            d_courier_status, d_hire_date, d_dismissal_date);

        d_client_id = exts.uuid_generate_v4();

        insert into ufimtsev_food.client (client_id, login, password, phone_number)
        values (
            d_client_id,
            'client_' || (d_client_count + i),
            md5(random()::text),
            '+7' || (1000000000 + d_client_count + i)::text
        );
        
        for j in 1..5
        loop
            d_address_id = exts.uuid_generate_v4();
            insert into ufimtsev_food.address (address_id, street, house_number)
            values (d_address_id, 'Имя улицы ' || substring(md5(random()::text), 1, 12), j::text);
            if j = 1 then
                d_restaurant_address_id = d_address_id;
            else
                insert into ufimtsev_food.client_address (client_id, address_id)
                values (d_client_id, d_address_id);
            end if;
        end loop;


        d_restaurant_id = exts.uuid_generate_v4();

        insert into ufimtsev_food.restaurant (restaurant_id, restaurant_name, address_id, description, work_start, work_end, company_details, status)
        values (
            d_restaurant_id,
            'Ресторан ' || i,
            d_restaurant_address_id,
            'Описание ресторана ' || i,
            '09:00',
            '22:00',
            'Реквизиты ресторана ' || i,
            (enum_range(null::ufimtsev_food.restaurant_status))[floor(random()*2)::int+1]
        );

        for j in 1..5
        loop
            insert into ufimtsev_food.product (product_name, product_category_id, price, restaurant_id, status, description)
            values (
                'Блюдо ' || i || '_' || j,
                d_product_category_id,
                round((200 + random() * 4800)::numeric, 2),
                d_restaurant_id,
                (enum_range(null::ufimtsev_food.product_status))[floor(random()*3)::int+1],
                'Описание блюда ' || i || '_' || j
            );
        end loop;

        select sum(price) into d_order_amount
        from ufimtsev_food.product
        where restaurant_id = d_restaurant_id;

        for j in 1..5
        loop
            d_order_status = (enum_range(null::ufimtsev_food.order_status))[
                floor(random() * 5)::int + 1
            ];

            d_order_timestamp = now()::timestamp - floor(random() * 180 + 1)::int * interval '1 day';
            d_order_timestamp = greatest(d_order_timestamp, d_hire_date::timestamp);

            if d_courier_status = 'уволен' then
                d_order_timestamp = least(d_order_timestamp, d_dismissal_date::timestamp);
            end if;

            if d_order_status = 'доставлен' then
                d_delivery_timestamp = d_order_timestamp + interval '1 hour';
            else
                d_delivery_timestamp = null;
            end if;

            d_order_id = exts.uuid_generate_v4();

            insert into ufimtsev_food."order" (
                order_id, courier_id, client_id, address_id, restaurant_id, 
                order_timestamp, delivery_timestamp,
                order_amount, status, pay_status, description)
            values (
                d_order_id, d_courier_id, d_client_id, d_address_id, d_restaurant_id,
                d_order_timestamp, d_delivery_timestamp, 
                d_order_amount, d_order_status, 'оплачен', 'Заказ' || i || '_' || j
            );

            insert into ufimtsev_food.order_structure (order_id, product_id, quantity)
            select d_order_id, p.product_id, 1
            from ufimtsev_food.product p
            where p.restaurant_id = d_restaurant_id;

            select total_amount into d_order_total
            from ufimtsev_food."order"
            where order_id = d_order_id;

            insert into ufimtsev_food.payment (order_id, payment_type, status, amount, transaction_id, payment_timestamp)
            values (
                d_order_id, 
                (enum_range(null::ufimtsev_food.payment_type))[floor(random()*3)::int+1], 
                'успех', d_order_total, exts.uuid_generate_v4(), d_order_timestamp + interval '15 minute');

            d_review_entity_type = (enum_range(null::ufimtsev_food.review_entity_type))[
                floor(random() * 3)::int + 1
            ];

            if d_review_entity_type = 'блюдо' then
                select product_id into d_review_entity_id
                from ufimtsev_food.order_structure
                where order_id = d_order_id
                order by random()
                limit 1;
            elsif d_review_entity_type = 'ресторан' then
                d_review_entity_id = d_restaurant_id;
            else
                d_review_entity_id = d_order_id;
            end if;

            insert into ufimtsev_food.review (client_id, review_timestamp, entity_id, entity_type, order_id, description, rating)
            values (
                d_client_id, d_order_timestamp + interval '2 hours', 
                d_review_entity_id, d_review_entity_type, d_order_id, 
                'Отзыв клиента' || i || ' на заказ ' || j,
                floor(random() * 5)::int + 1);
        end loop;

        d_pay_coefficient = 0.1;
        for j in 0..5
        loop
            d_pay_month = (date_trunc('month', now()::date) - (5 - j) * interval '1 month')::date;

            if d_pay_month < date_trunc('month', d_hire_date)::date then
                continue;
            end if;

            if d_courier_status = 'уволен' and d_pay_month > date_trunc('month', d_dismissal_date)::date then
                exit;
            end if;

            select count(*), coalesce(sum(commission), 0) into d_delivered_count, d_commission_sum
            from ufimtsev_food."order"
            where courier_id = d_courier_id
                and status = 'доставлен'
                and delivery_timestamp >= greatest(d_pay_month, d_hire_date)::timestamp
                and delivery_timestamp < d_pay_month + interval '1 month'
                and (d_courier_status <> 'уволен' or delivery_timestamp < (d_dismissal_date+1)::timestamp);

            if d_delivered_count <= 150 then
                d_next_coefficient = 0.1;
            elsif d_delivered_count <= 250 then 
                d_next_coefficient = 0.2;
            elsif d_delivered_count <= 500 then
                d_next_coefficient = 0.3;
            else
                d_next_coefficient = 0.5;
            end if;

            insert into ufimtsev_food.courier_pay (year, month, courier_id, amount, coefficient_used)
            values (
                extract(year from d_pay_month)::int,
                extract(month from d_pay_month)::int,
                d_courier_id,
                round(d_pay_coefficient * d_commission_sum, 2),
                d_pay_coefficient
            );

            d_pay_coefficient = d_next_coefficient;
        end loop;

        if d_courier_status <> 'уволен' then
            update ufimtsev_food.courier
            set coefficient = d_pay_coefficient
            where courier_id = d_courier_id;
        end if;

    end loop;
end;
$$ language plpgsql;
create or replace procedure ufimtsev_food.insert_test_data(value int) as $$
declare
    d_courier_status ufimtsev_food.courier_status;
    d_hire_date date;
    d_dismissal_date date;
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
    d_pay_coefficient numeric;
    d_next_coefficient numeric;
    d_delivered_count bigint;
    d_commission_sum numeric;
    d_work_start time;
    d_work_end time;
    d_courier_firstname varchar(60);
    d_courier_lastname varchar(60);
    d_courier_midname varchar(80);
    d_product_ids uuid[];
    d_quantity int;
    d_random_product_count int;
    k record;
begin

    for i in 1..value
    loop
        -- создание категорий
        d_product_category_id = exts.uuid_generate_v4();

        insert into ufimtsev_food.product_category(product_category_id, product_category_name)
        values (
            d_product_category_id, 
            substring(repeat(md5(random()::text), 4), 1, ceil(random() * 99 + 1)::int));
        
        -- создание курьеров
        if i = 1 then
            d_courier_status = 'свободен';
        else   
            d_courier_status = (enum_range(null::ufimtsev_food.courier_status))[
                floor(random() * 4)::int + 1
            ];
        end if;

        d_hire_date = current_date - floor(random() * 180)::int;

        if d_courier_status = 'уволен' then
            d_dismissal_date = d_hire_date + floor(random() * (current_date - d_hire_date + 1))::int;
        else
            d_dismissal_date = null;
        end if;

        d_courier_id = exts.uuid_generate_v4();
        d_courier_firstname = substring(repeat(md5(random()::text), 2), 1, ceil(random() * 59 + 1)::int);
        d_courier_lastname = substring(repeat(md5(random()::text), 2), 1, ceil(random() * 59 + 1)::int);
        d_courier_midname = substring(repeat(md5(random()::text), 3), 1, ceil(random() * 79 + 1)::int);

        insert into ufimtsev_food.courier (courier_id, first_name, last_name, middle_name, phone_number, status, hire_date, dismissal_date)
        values (
            d_courier_id, d_courier_firstname, d_courier_lastname, d_courier_midname, 
            '+7' || (floor(random()*9000000000)+1000000000)::text, 
            d_courier_status, d_hire_date, d_dismissal_date);

        -- создание клиентов
        d_client_id = exts.uuid_generate_v4();

        insert into ufimtsev_food.client (client_id, login, password, phone_number)
        values (
            d_client_id,
            substring(repeat(md5(random()::text), 2), 1, ceil(random() * 49 + 1)::int),
            md5(random()::text),
            '+7' || (floor(random()*9000000000)+1000000000)::text
        );
        
        for j in 1..5
        loop
            -- создание адресов
            d_address_id = exts.uuid_generate_v4();
            insert into ufimtsev_food.address (address_id, street, house_number)
            values (
                d_address_id, 
                substring(repeat(md5(random()::text), 4), 1, ceil(random() * 99 + 1)::int),
                (ceil(random() * 999 + 1)::int)::text);
            if j = 1 then
                d_restaurant_address_id = d_address_id;
            else
                -- создание клиент_адрес
                insert into ufimtsev_food.client_address (client_id, address_id)
                values (d_client_id, d_address_id);
            end if;
        end loop;

        -- создание ресторанов
        d_restaurant_id = exts.uuid_generate_v4();
        d_work_start = '7:00'::time + (floor(random() * 4)::int * interval '1 hour');
        d_work_end = d_work_start + interval '12 hour';

        insert into ufimtsev_food.restaurant (restaurant_id, restaurant_name, address_id, description, work_start, work_end, inn, ogrn, bank_account, status)
        values (
            d_restaurant_id,
            substring(repeat(md5(random()::text), 4), 1, ceil(random() * 99 + 1)::int),
            d_restaurant_address_id,
            substring(repeat(md5(random()::text), 4), 1, ceil(random() * 99 + 1)::int),
            d_work_start,
            d_work_end,
            lpad(floor(random() * 1000000000000)::text, 12, '0'),
            lpad(floor(random() * 1000000000000000)::text, 15, '0'),
            lpad(floor(random() * 10000000000)::text, 10, '0') || lpad(floor(random() * 10000000000)::text, 10, '0'),
            (enum_range(null::ufimtsev_food.restaurant_status))[floor(random()*2)::int+1]
        );
        
        -- создание меню блюд
        for j in 1..5
        loop
            insert into ufimtsev_food.product (product_name, product_category_id, price, restaurant_id, status, description)
            values (
                substring(repeat(md5(random()::text), 4), 1, ceil(random() * 99 + 1)::int),
                d_product_category_id,
                round((200 + random() * 4800)::numeric, 2),
                d_restaurant_id,
                (enum_range(null::ufimtsev_food.product_status))[floor(random()*3)::int+1],
                substring(repeat(md5(random()::text), 4), 1, ceil(random() * 99 + 1)::int)
            );
        end loop;

        -- создание заказов
        for j in 1..5
        loop

            -- лимит для разного количества блюд в заказах и разной суммы соответственно
            d_random_product_count = floor(1 + random() * 5);
            select array_agg(prod.product_id) into d_product_ids
            from (
                select product_id
                from ufimtsev_food.product
                where restaurant_id = d_restaurant_id
                order by random()
                limit d_random_product_count
            ) prod;

            select sum(price) into d_order_amount
            from ufimtsev_food.product
            where product_id = any(d_product_ids);

            d_quantity = greatest(floor(random() * 5)::int + 1, ceil(1000 / (d_order_amount * 1.1))::int);

            d_order_amount = d_order_amount * d_quantity;

            d_order_status = (enum_range(null::ufimtsev_food.order_status))[
                floor(random() * 5)::int + 1
            ];
            if random() < 0.6 then
                d_order_status = 'доставлен';
            end if;

            if d_courier_status = 'уволен' then
                d_order_timestamp = d_hire_date + floor(random() * (d_dismissal_date - d_hire_date + 1))::int;
            else
                d_order_timestamp = d_hire_date + floor(random() * (current_date - d_hire_date + 1))::int;
            end if;

            if d_order_status = 'доставлен' then
                d_delivery_timestamp = d_order_timestamp + (15 + random() * 45) * interval '1 minute';
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
                d_order_amount, d_order_status, 'оплачен', substring(repeat(md5(random()::text), 4), 1, ceil(random() * 99 + 1)::int)
            );

            -- создание структуры заказов
            insert into ufimtsev_food.order_structure (order_id, product_id, quantity)
            select d_order_id, unnest(d_product_ids), d_quantity;

            -- создание списка попыток оплаты
            select total_amount into d_order_total
            from ufimtsev_food."order"
            where order_id = d_order_id;

            insert into ufimtsev_food.payment (order_id, payment_type, status, amount, transaction_id, payment_timestamp)
            values (
                d_order_id, 
                (enum_range(null::ufimtsev_food.payment_type))[floor(random()*3)::int+1], 
                'успех', d_order_total, exts.uuid_generate_v4(), d_order_timestamp + interval '3 minute');

            -- создание отзывов
            d_review_entity_type = (enum_range(null::ufimtsev_food.review_entity_type))[
                floor(random() * 3)::int + 1
            ];

            if d_review_entity_type = 'блюдо' then
                d_review_entity_id = d_product_ids[floor(random() * array_length(d_product_ids, 1))::int + 1];
            elsif d_review_entity_type = 'ресторан' then
                d_review_entity_id = d_restaurant_id;
            else
                d_review_entity_id = d_order_id;
            end if;

            insert into ufimtsev_food.review (client_id, review_timestamp, entity_id, entity_type, order_id, description, rating)
            values (
                d_client_id, d_order_timestamp + (1 + random() * 3) * interval '1 hour', 
                d_review_entity_id, d_review_entity_type, d_order_id, 
                substring(repeat(md5(random()::text), 4), 1, ceil(random() * 99 + 1)::int),
                floor(random() * 5)::int + 1);
        end loop;

        -- создание таблицы зарплаты
        d_pay_coefficient = 0.1;
        for k in select
                extract(year  from m)::int as y,
                extract(month from m)::int as m
            from generate_series(
                date_trunc('month', current_date - interval '5 months'),
                date_trunc('month', current_date),
                interval '1 month'
            ) as m
        loop

            select count(*), coalesce(sum(commission), 0) into d_delivered_count, d_commission_sum
            from ufimtsev_food."order"
            where courier_id = d_courier_id
                and status = 'доставлен'
                and extract(year from delivery_timestamp) = k.y
                and extract(month from delivery_timestamp) = k.m;
            
            if d_delivered_count <= 150 then
                d_next_coefficient = 0.1;
            elsif d_delivered_count <= 250 then 
                d_next_coefficient = 0.2;
            elsif d_delivered_count <= 500 then
                d_next_coefficient = 0.3;
            else
                d_next_coefficient = 0.5;
            end if;

            insert into ufimtsev_food.courier_pay(year, month, courier_id, amount, coefficient_used)
            values(
                k.y, k.m, d_courier_id, round(d_pay_coefficient * d_commission_sum, 2), d_pay_coefficient
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
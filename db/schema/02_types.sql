create table ufimtsev_food.client (
    client_id uuid primary key default exts.uuid_generate_v4(),
    login varchar(50) not null unique,
    password varchar(32) not null check(password ~ '^[0-9a-f]{32}$'),
    phone_number char(12) not null unique
);

create table ufimtsev_food.address (
    address_id uuid primary key default exts.uuid_generate_v4(),
    street varchar(100) not null,
    house_number varchar(10) not null,
    apartment_office varchar(10)
);

create table ufimtsev_food.client_address (
    client_id uuid not null references ufimtsev_food.client (client_id),
    address_id uuid not null references ufimtsev_food.address (address_id),
    primary key (client_id, address_id)
);

create table ufimtsev_food.restaurant (
    restaurant_id uuid primary key default exts.uuid_generate_v4(),
    restaurant_name varchar(100) not null,
    address_id uuid not null unique references ufimtsev_food.address (address_id),
    description text not null,
    work_start time not null,
    work_end time not null check (work_end > work_start),
    company_details text not null,
    rating numeric(3, 2) check (rating between 0 and 5),
    status ufimtsev_food.restaurant_status not null
);

create table ufimtsev_food.courier (
    courier_id uuid primary key default exts.uuid_generate_v4(),
    FIO varchar(200) not null,
    phone_number char(12) not null,
    status ufimtsev_food.courier_status not null,
    hire_date date not null,
    dismissal_date date check (status <> 'уволен' or dismissal_date is not null) check (dismissal_date >= hire_date),
    coefficient numeric(5, 2) not null default 0.1 check (coefficient between 0.1 and 0.5)
);

create table ufimtsev_food.courier_pay (
    year int not null,
    month int not null check (month between 1 and 12),
    courier_id uuid not null references ufimtsev_food.courier (courier_id),
    amount numeric(10, 2) not null check (amount >= 0),
    coefficient_used numeric(5, 2) not null check (coefficient_used between 0.1 and 0.5),
    primary key (year, month, courier_id) 
);

create table ufimtsev_food.product_category (
    product_category_id uuid primary key default exts.uuid_generate_v4(),
    product_category_name varchar(100) not null
);

create table ufimtsev_food.product (
    product_id uuid primary key default exts.uuid_generate_v4(),
    product_name varchar(100) not null,
    product_category_id uuid not null references ufimtsev_food.product_category (product_category_id),
    price numeric(10, 2) not null check (price >= 0),
    restaurant_id uuid not null references ufimtsev_food.restaurant (restaurant_id),
    photo_url text,
    rating numeric(3, 2) check (rating between 0 and 5),
    status ufimtsev_food.product_status not null,
    description text not null
);

create table ufimtsev_food."order" (
    order_id uuid primary key default exts.uuid_generate_v4(),
    courier_id uuid not null references ufimtsev_food.courier (courier_id),
    client_id uuid not null references ufimtsev_food.client (client_id),
    address_id uuid not null references ufimtsev_food.address (address_id),
    restaurant_id uuid not null references ufimtsev_food.restaurant (restaurant_id),
    order_timestamp timestamp not null,
    delivery_timestamp timestamp check (status <> 'доставлен' or delivery_timestamp is not null) check (delivery_timestamp >= order_timestamp),
    order_amount numeric(10, 2) not null,
    commission numeric(10, 2) generated always as (round(order_amount*0.1, 2)) stored,
    total_amount numeric(10, 2) generated always as (order_amount + round(order_amount*0.1, 2)) stored
        check (total_amount >= 1000),
    status ufimtsev_food.order_status not null,
    pay_status ufimtsev_food.order_pay_status not null,
    description text not null,
    foreign key (client_id, address_id) references ufimtsev_food.client_address (client_id, address_id),
    unique (order_id, client_id),
    unique (order_id, total_amount)
);

create table ufimtsev_food.order_structure (
    order_id uuid not null references ufimtsev_food."order" (order_id),
    product_id uuid not null references ufimtsev_food.product (product_id),
    quantity numeric(10, 2) not null check (quantity > 0),
    primary key (order_id, product_id)
);

create or replace function ufimtsev_food.check_restaurant_menu() returns trigger as $$
declare
    rest_match boolean;
begin
    select (o.restaurant_id = p.restaurant_id) into rest_match
    from ufimtsev_food."order" o
    cross join ufimtsev_food.product p
    where o.order_id = new.order_id
        and p.product_id = new.product_id;
    
    if rest_match is not true then
        raise exception 'Ресторан не верный';
    end if;
    return new;
end;
$$ language plpgsql;

create trigger check_restaurant_menu
before insert or update on ufimtsev_food.order_structure
for each row execute procedure ufimtsev_food.check_restaurant_menu();

create table ufimtsev_food.payment (
    payment_id uuid primary key default exts.uuid_generate_v4(),
    order_id uuid not null references ufimtsev_food."order" (order_id),
    payment_type ufimtsev_food.payment_type not null,
    status ufimtsev_food.payment_status not null,
    amount numeric(10, 2) not null,
    transaction_id uuid not null unique,
    payment_timestamp timestamp not null,
    foreign key (order_id, amount) references ufimtsev_food."order" (order_id, total_amount)
);

create table ufimtsev_food.review (
    review_id uuid primary key default exts.uuid_generate_v4(),
    client_id uuid not null references ufimtsev_food.client (client_id),
    review_timestamp timestamp not null,
    entity_id uuid not null,
    entity_type ufimtsev_food.review_entity_type not null,
    order_id uuid not null references ufimtsev_food."order" (order_id),
    description text not null,
    photo_url text,
    rating numeric(3, 2) not null check (rating between 1 and 5),
    foreign key (order_id, client_id) references ufimtsev_food."order" (order_id, client_id),
    unique (order_id, entity_type, entity_id)
);

create or replace function ufimtsev_food.check_entity_type() returns trigger as $$
begin
    if new.entity_type = 'блюдо' then
        if not exists (
            select 1
            from ufimtsev_food.order_structure os
            where os.order_id = new.order_id
                and os.product_id = new.entity_id
        ) then
            raise exception 'Блюдо отсутствует';
        end if;
    end if;
    if new.entity_type = 'ресторан' then
        if not exists (
            select 1
            from ufimtsev_food."order" o
            where o.order_id = new.order_id
                and o.restaurant_id = new.entity_id
        ) then
            raise exception 'Ресторан отсутствует';
        end if;
    end if;
    if new.entity_type = 'заказ' then
        if new.entity_id <> new.order_id then
            raise exception 'Указан неверный заказ';
        end if;
    end if;
    return new;
end;
$$ language plpgsql;

create trigger check_entity_type
before insert or update on ufimtsev_food.review
for each row execute procedure ufimtsev_food.check_entity_type();

create or replace function ufimtsev_food.rating_change() returns trigger as $$
begin
    if tg_op <> 'INSERT' then

        if old.entity_type = 'блюдо' then
            update ufimtsev_food.product
            set rating = (
                select avg(rating)
                from ufimtsev_food.review
                where entity_type = 'блюдо'
                    and entity_id = old.entity_id
            )
            where product_id = old.entity_id;

        elsif old.entity_type = 'ресторан' then
            update ufimtsev_food.restaurant
            set rating = (
                select avg(rating)
                from ufimtsev_food.review
                where entity_type = 'ресторан'
                    and entity_id = old.entity_id
            )
            where restaurant_id = old.entity_id;
        end if;

    end if;

    if tg_op <> 'DELETE' then

        if new.entity_type = 'блюдо' then
            update ufimtsev_food.product
            set rating = (
                select avg(rating)
                from ufimtsev_food.review
                where entity_type = 'блюдо'
                    and entity_id = new.entity_id
            )
            where product_id = new.entity_id;

        elsif new.entity_type = 'ресторан' then
            update ufimtsev_food.restaurant
            set rating = (
                select avg(rating)
                from ufimtsev_food.review
                where entity_type = 'ресторан'
                    and entity_id = new.entity_id
            )
            where restaurant_id = new.entity_id;
        end if;

    end if;

    if tg_op = 'DELETE' then
        return old;
    end if;

    return new;
end;
$$ language plpgsql;

create trigger rating_change
after insert or update or delete on ufimtsev_food.review
for each row execute procedure ufimtsev_food.rating_change();
create or replace procedure ufimtsev_food.add_product(
    p_restaurant_id uuid, 
    p_product_category_id uuid, 
    p_name varchar(100), 
    p_price numeric(10, 2), 
    p_rating numeric(3, 2), 
    p_status ufimtsev_food.product_status, 
    p_description text, 
    p_photo_url text default null
) as $$
declare
    d_product_id uuid;
    has_restaurant boolean;
    has_product_category boolean;
begin
    d_product_id = exts.uuid_generate_v4();

    select (count(*) > 0) into has_restaurant
    from ufimtsev_food.restaurant r
    where r.restaurant_id = p_restaurant_id;

    if has_restaurant = false then
        raise exception 'Указанного ресторана нет в базе';
    end if;

    select (count(*) > 0) into has_product_category
    from ufimtsev_food.product_category pc
    where pc.product_category_id = p_product_category_id;

    if has_product_category = false then
        raise exception 'Указанной категории нет в базе';
    end if;

    if p_price is null or p_price < 0 then
        raise exception 'Цена блюда не может быть отрицательной';
    end if;

    insert into ufimtsev_food.product (product_id, restaurant_id, product_category_id, product_name, price, rating, status, description, photo_url)
    values (d_product_id, p_restaurant_id, p_product_category_id, p_name, p_price, p_rating, p_status, p_description, p_photo_url);

end;
$$ language plpgsql;
create or replace procedure ufimtsev_food.add_product(
    p_restaurant_id uuid, 
    p_product_category_id uuid, 
    p_name varchar(100), 
    p_price numeric(6, 2), 
    p_rating numeric(3, 2), 
    p_status ufimtsev_food.product_status, 
    p_description text, 
    p_photo_url text default null
) as $$
begin
    insert into ufimtsev_food.product (
        restaurant_id, product_category_id, 
        product_name, price, rating, status, description, photo_url)
    values (
        p_restaurant_id, p_product_category_id, 
        p_name, p_price, p_rating, p_status, p_description, p_photo_url);

end;
$$ language plpgsql;
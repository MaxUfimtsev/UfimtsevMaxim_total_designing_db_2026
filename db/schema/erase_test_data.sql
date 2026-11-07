create or replace procedure ufimtsev_food.erase_test_data() as $$
begin
    TRUNCATE TABLE
        ufimtsev_food.payment,
        ufimtsev_food.review,
        ufimtsev_food.order_structure,
        ufimtsev_food.courier_pay,
        ufimtsev_food."order",
        ufimtsev_food.restaurant,
        ufimtsev_food.client_address,
        ufimtsev_food.address,
        ufimtsev_food.product,
        ufimtsev_food.client,
        ufimtsev_food.courier,
        ufimtsev_food.product_category
    CASCADE;
end;
$$ language plpgsql;
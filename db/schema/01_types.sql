create schema ufimtsev_food;

create type ufimtsev_food.restaurant_status as enum ('активен', 'неактивен');
create type ufimtsev_food.product_status as enum ('доступно', 'нет_в_наличии', 'архив');
create type ufimtsev_food.courier_status as enum ('свободен', 'занят', 'на_доставке', 'уволен');
create type ufimtsev_food.order_status as enum ('создан', 'готовится', 'в_доставке', 'доставлен', 'отменен');
create type ufimtsev_food.order_pay_status as enum ('ожидает', 'оплачен', 'ошибка');
create type ufimtsev_food.payment_type as enum ('карта', 'наличные', 'безнал');
create type ufimtsev_food.payment_status as enum ('успех', 'ошибка', 'в_обработке');
create type ufimtsev_food.review_entity_type as enum ('блюдо', 'ресторан', 'заказ');
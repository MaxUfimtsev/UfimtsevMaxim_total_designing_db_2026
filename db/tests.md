# Протокол для самопроверки

Заполняется по желанию. 

По данному протоколу работа будет проверяться преподавателем.

**Если на каком-то этапе функционал оказывается нерабочим, значит учащийся проигнорировал обязательное тестирование и работа может быть отправлена на доработку без проверки и комментариев или по работе может быть проставлен незачет, если лимит доработок исчерпан.**

## Окружение

| Параметр | Значение |
|---|---|
| PostgreSQL version | `SELECT version();` → 17.2 |
| Дата проверки | ___ |
| Схема | `ufimtsev_food` |
| Роль-аудитор | `inspector` |

Все проверки — под `inspector`, если не указано иное.

Заполняй «Факт» и «Вердикт» по каждой проверке. «Вердикт»: `OK` / `FAIL: <что именно>`.

---

## A. Подготовка

### A.1. Восстановление бэкапа

Ожидается: без ошибок.
Факт: Копия успешно восстанавливается (12 таблиц + 1 представление). 
Вердикт: ОК

### A.2. Переключение на inspector

```sql
SET ROLE inspector;
SET search_path TO ufimtsev_food, exts;
SELECT current_user;
```

Ожидается: `inspector`.
Факт: current_user = inspector
Вердикт: ОК

---

## B. FOOD-101: Структура схемы

### B.1. Схема существует

```sql
SELECT schema_name FROM information_schema.schemata
WHERE schema_name LIKE '%_food';
```

Ожидается: `ufimtsev_food`.
Факт: ufimtsev_food

### B.2. Схема `exts` с `uuid-ossp`

```sql
SELECT extname, extnamespace::regnamespace AS schema
FROM pg_extension WHERE extname = 'uuid-ossp';
```

Ожидается: `uuid-ossp`, схема `exts`.
Факт: uuid-ossp | exts

### B.3. Все 12 исходных таблиц + N после нормализации

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'ufimtsev_food'
ORDER BY table_name;
```

Ожидается: `address`, `client`, `client_address`, `courier`, `courier_pay`, `order`, `order_structure`, `payment`, `product`, `product_category`, `restaurant`, `review` (12 + N штук).
Факт: `address`, `client`, `client_address`, `courier`, `courier_pay`, `order`, `order_structure`, `payment`, `product`, `product_category`, `restaurant`, `review` 

### B.4. Все PK — `uuid`

```sql
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ufimtsev_food'
  AND column_name LIKE '%_id'
  AND data_type != 'uuid';
```

Ожидается: пусто.
Факт: пусто

### B.5. Enum-типы

```sql
SELECT t.typname, array_agg(e.enumlabel ORDER BY e.enumsortorder) AS values
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'ufimtsev_food'
GROUP BY t.typname
ORDER BY t.typname;
```

Ожидается: 8 типов со значениями из constraints.md.
Факт: 

| typname | values |
| --- | --- |
| courier_status | `свободен`, `занят`, `на_доставке`, `уволен` |
| order_pay_status | `ожидает`, `оплачен`, `ошибка` |
| order_status | `создан`, `готовится`, `в_доставке`, `доставлен`, `отменен` |
|payment_status | `успех`, `ошибка`, `в_обработке` |
| payment_type | `карта`, `наличные`, `безнал` |
| product_status | `доступно`, `нет_в_наличии`, `архив` |
| restaurant_status | `активен`, `неактивен` |
| review_entity_type | `блюдо`, `ресторан`, `заказ` |
---


### B.6. FK-ограничения

```sql
SELECT conname, conrelid::regclass AS tbl, confrelid::regclass AS ref
FROM pg_constraint
WHERE contype = 'f'
  AND connamespace = 'ufimtsev_food'::regnamespace
ORDER BY tbl, conname;
```

Ожидается: не менее 15 FK, все из erd.md.
Факт: 18 FK

### B.7. Пароль — MD5

```sql
SELECT length(password) AS len, password
FROM ufimtsev_food.client LIMIT 5;
```

Ожидается: `len = 32`, hex-строка.
Факт: 32 | 271e84a874843f0aad16fefd6e32378d

---

## C. FOOD-102: `insert_test_data(value)`

### C.1. Чистая схема

```sql
CALL erase_test_data();
```

Ожидается: без ошибок.
Факт: без ошибок

### C.2. Первый запуск

```sql
CALL insert_test_data(10);
```

Ожидается: без ошибок.
Факт: без ошибок

### C.3. Распределение строк (BR-11.7)

```sql
SELECT 'client' AS tbl, count(*) FROM ufimtsev_food.client
UNION ALL SELECT 'courier', count(*) FROM ufimtsev_food.courier
UNION ALL SELECT 'product_category', count(*) FROM ufimtsev_food.product_category
UNION ALL SELECT 'restaurant', count(*) FROM ufimtsev_food.restaurant
UNION ALL SELECT 'address', count(*) FROM ufimtsev_food.address
UNION ALL SELECT 'product', count(*) FROM ufimtsev_food.product
UNION ALL SELECT 'order', count(*) FROM ufimtsev_food."order"
UNION ALL SELECT 'review', count(*) FROM ufimtsev_food.review
UNION ALL SELECT 'payment', count(*) FROM ufimtsev_food.payment
ORDER BY tbl;
```

Ожидается: 10, 10, 10, 10, 50, 50, 50, 50, 50.
Факт: `address` = 50, `client` = 10, `courier` = 10, `order` = 50, `payment` = 103, 
`product` = 50, `product_category` = 10, `restaurant` = 10, `review` = 50

### C.4. Адреса ресторанов vs клиентов (BR-11.7)

```sql
SELECT 'restaurant addresses' AS cat, count(*) FROM ufimtsev_food.restaurant WHERE address_id IS NOT NULL
UNION ALL
SELECT 'total addresses', count(*) FROM ufimtsev_food.address;
```

Ожидается: 10 ресторанных адресов, 50 всего → 40 клиентских.
Факт: restaurant addresses -> 10, total addresses -> 50

### C.5. Нет пустых строк (BR-11.3)

```sql
SELECT count(*) FROM ufimtsev_food.client WHERE login = '' OR password = '' OR phone_number = '';
-- и аналогично для других varchar-полей с NOT NULL
```

Ожидается: 0.
Факт: 0

### C.6. Нет NULL там, где запрещено (BR-11.3)

```sql
SELECT count(*) FROM ufimtsev_food."order" WHERE client_id IS NULL OR restaurant_id IS NULL
  OR courier_id IS NULL OR address_id IS NULL OR total_amount IS NULL;
-- и аналогично для других NOT NULL полей
```

Ожидается: 0.
Факт: 0

### C.7. Минимум один активный курьер (BR-6.6)

```sql
SELECT count(*) FROM ufimtsev_food.courier WHERE status != 'уволен';
```

Ожидается: `>= 1`.
Факт: 7

### C.8. `courier_pay` консистентен с правилами (BR-10.2)

```sql
SELECT cp.year, cp.month, cp.courier_id, cp.amount, cp.coefficient_used,
       round(coalesce((
           SELECT sum(o.commission)
           FROM ufimtsev_food."order" o
           WHERE o.courier_id = cp.courier_id
             AND o.status = 'доставлен'
             AND extract(year  from o.order_timestamp) = cp.year
             AND extract(month from o.order_timestamp) = cp.month
       ), 0) * cp.coefficient_used, 2) AS expected_amount
FROM ufimtsev_food.courier_pay cp
LIMIT 20;
```

Ожидается: `amount = expected_amount` в каждой строке.
Факт: `True`

### C.9. Повторный вызов не ломает

```sql
DO $$
BEGIN
    FOR i IN 1..10 LOOP
        CALL ufimtsev_food.insert_test_data(10);
    END LOOP;
END $$;
```

Ожидается: без ошибок, данные добавляются или заменяются (по решению студента, задокументированному в constraints.md).
Факт: Данные добавились без ошибок

---

## D. Проверки бизнес-правил на сгенерированных данных

### D.1. Все FK валидны (нет orphans)

```sql
SELECT 'order_structure → order' AS fk, count(*) AS orphans
FROM order_structure os
LEFT JOIN "order" o ON os.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'order_structure → product', count(*)
FROM order_structure os
LEFT JOIN product p ON os.product_id = p.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'payment → order', count(*)
FROM payment pmt
LEFT JOIN "order" o ON pmt.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'review → order', count(*)
FROM review r
LEFT JOIN "order" o ON r.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'courier_pay → courier', count(*)
FROM courier_pay cp
LEFT JOIN courier c ON cp.courier_id = c.courier_id
WHERE c.courier_id IS NULL
UNION ALL
SELECT 'client_address → client', count(*)
FROM client_address ca
LEFT JOIN client c ON ca.client_id = c.client_id
WHERE c.client_id IS NULL
UNION ALL
SELECT 'client_address → address', count(*)
FROM client_address ca
LEFT JOIN address a ON ca.address_id = a.address_id
WHERE a.address_id IS NULL;
```

Ожидается: все 0.
Факт: Все 0

### D.2. Минимальная сумма заказа (BR-1.8)

```sql
SELECT count(*) FROM "order" WHERE total_amount < 1000;
```

Ожидается: 0.
Факт: 0

### D.3. Комиссия = 10% (BR-1.4)

```sql
SELECT count(*) FROM "order" WHERE round(order_amount * 0.10, 2) != commission;
```

Ожидается: 0.
Факт: 0

### D.4. `total_amount = order_amount + commission`

```sql
SELECT count(*) FROM "order"
WHERE round(order_amount + commission, 2) != total_amount;
```

Ожидается: 0.
Факт: 0

### D.5. Дата доставки не раньше создания (BR-7.13)

```sql
SELECT count(*) FROM "order"
WHERE delivery_timestamp IS NOT NULL AND delivery_timestamp < order_timestamp;
```

Ожидается: 0.
Факт: 0

### D.6. Адрес доставки принадлежит клиенту (BR-7.4)

```sql
SELECT count(*) FROM "order" o
LEFT JOIN client_address ca
  ON ca.client_id = o.client_id AND ca.address_id = o.address_id
WHERE ca.client_id IS NULL;
```

Ожидается: 0.
Факт: 0

### D.7. Все блюда в заказе из одного ресторана (BR-7.3)

```sql
SELECT count(DISTINCT os.order_id)
FROM order_structure os
JOIN "order" o ON os.order_id = o.order_id
JOIN product p ON os.product_id = p.product_id
WHERE p.restaurant_id != o.restaurant_id;
```

Ожидается: 0.
Факт: 0

### D.8. Ровно одна успешная оплата на заказ (BR-8.1)

```sql
SELECT order_id, count(*) AS cnt
FROM payment
WHERE status = 'успех'
GROUP BY order_id
HAVING count(*) != 1;
```

Ожидается: пусто.
Факт: Пусто

### D.9. Сумма оплаты = `total_amount` заказа (BR-8.4)

```sql
SELECT count(*) FROM payment p
JOIN "order" o ON p.order_id = o.order_id
WHERE p.amount != o.total_amount;
```

Ожидается: 0.
Факт: 0

### D.10. Нет дубликатов в `client_address` (BR-2.5)

```sql
SELECT client_id, address_id, count(*)
FROM client_address
GROUP BY client_id, address_id
HAVING count(*) > 1;
```

Ожидается: пусто.
Факт: Пусто

### D.11. Нет дубликатов в `order_structure` (BR-7.16)

```sql
SELECT order_id, product_id, count(*)
FROM order_structure
GROUP BY order_id, product_id
HAVING count(*) > 1;
```

Ожидается: пусто.
Факт: Пусто

### D.12. `work_end > work_start` (BR-4.4)

```sql
SELECT count(*) FROM restaurant WHERE work_end <= work_start;
```

Ожидается: 0.
Факт: 0

### D.13. `dismissal_date >= hire_date` (BR-6.3)

```sql
SELECT count(*) FROM courier
WHERE dismissal_date IS NOT NULL AND dismissal_date < hire_date;
```

Ожидается: 0.
Факт: 0

### D.14. Рейтинг блюд/ресторанов соответствует отзывам (BR-9.6)

```sql
-- product.rating = AVG(review.rating) по отзывам на блюдо
SELECT p.product_id, p.rating,
       (SELECT round(avg(r.rating), 2) FROM review r
        WHERE r.entity_type = 'блюдо' AND r.entity_id = p.product_id) AS expected
FROM product p
WHERE p.rating IS NOT NULL
LIMIT 20;
```

Ожидается: `rating = expected`.
Факт: Все rating равны expected значениям

---

## E. Функции и процедуры

### E.1. `add_product` — успешный вызов

```sql
SELECT count(*) AS before FROM ufimtsev_food.product;

DO $$
declare
    v_restaurant_id uuid;
    v_category_id uuid;
begin
    select restaurant_id into v_restaurant_id
    from ufimtsev_food.restaurant
    limit 1;

    select product_category_id into v_category_id
    from ufimtsev_food.product_category
    limit 1;

    call ufimtsev_food.add_product(
        p_restaurant_id => v_restaurant_id,
        p_product_category_id => v_category_id,
        p_name => 'Тестовое блюдо',
        p_price => 250,
        p_rating => 4.5,
        p_status => 'доступно',
        p_description => 'Описание'
    );
end $$;

SELECT count(*) AS after FROM ufimtsev_food.product;
```

Ожидается: `after = before + 1`.
Факт: `Правильно`
Немного изменен тест, потому что выдало ошибку, что в качестве аргумента call нельзя использовать подзапрос

### E.2. `add_product` — падает на несуществующий ресторан

```sql
DO $$
DECLARE
    v_restaurant_id uuid;
    v_category_id uuid;
BEGIN
    SELECT restaurant_id INTO v_restaurant_id
    FROM ufimtsev_food.restaurant
    LIMIT 1;

    SELECT product_category_id INTO v_category_id
    FROM ufimtsev_food.product_category
    LIMIT 1;

    CALL ufimtsev_food.add_product(
        p_restaurant_id => '00000000-0000-0000-0000-000000000000',
        p_product_category_id => v_category_id,
        p_name => 'Тестовое блюдо',
        p_price => 250,
        p_rating => 4.5,
        p_status => 'доступно',
        p_description => 'Описание'
    );
END $$;
```

Ожидается: ошибка с внятным сообщением.
Факт: "SQL Error [P0001]: ОШИБКА: Указанного ресторана нет в базе"

### E.3. `rating_change` — пересчитывает рейтинг

```sql
-- Выбрать заказ, блюдо и клиента
SELECT p.product_id, p.rating FROM ufimtsev_food.product p WHERE p.rating IS NOT NULL LIMIT 1;

-- Выбрать заказ выбранного блюда
SELECT os.order_id FROM ufimtsev_food.order_structure os WHERE os.product_id = '72e55f92-6e1a-4fcc-aeba-44e9574d8737' LIMIT 1;

-- Выбрать клиента выбранного заказа
SELECT o.client_id FROM ufimtsev_food."order" o WHERE o.order_id = 'f8be7c39-4708-4040-b988-5a7213e758c9';

-- Вставить отзыв на это блюдо
INSERT INTO ufimtsev_food.review (review_id, client_id, review_timestamp, entity_id, entity_type, order_id, description, rating)
VALUES (
    exts.uuid_generate_v4(),
    '9a8c2221-3813-4f98-8ba9-d449b0b10981',
    localtimestamp,
    '72e55f92-6e1a-4fcc-aeba-44e9574d8737',
    'блюдо',
    'f8be7c39-4708-4040-b988-5a7213e758c9',
    'Тестовый отзыв',
    5
);

SELECT rating FROM ufimtsev_food.product WHERE product_id = '72e55f92-6e1a-4fcc-aeba-44e9574d8737';
```

Ожидается: `rating` пересчитан.
Факт: Пересчитан. Добавил несколько дополнительных запросом, чтобы отзыв добавился к правильному заказу и все было связано

### E.4. `rating_change` — удаление отзыва

```sql
-- Найти созданный отзыв в прошлом тесте
SELECT r.review_id FROM ufimtsev_food.review r WHERE r.description = 'Тестовый отзыв' LIMIT 1;

-- Удалить отзыв из E.3
DELETE FROM ufimtsev_food.review WHERE review_id = '784845cb-5dfd-4ffb-a003-0b0405903192';

SELECT rating FROM ufimtsev_food.product WHERE product_id = '72e55f92-6e1a-4fcc-aeba-44e9574d8737';
```

Ожидается: если других отзывов нет — `rating IS NULL`; иначе — пересчитан.
Факт: Пересчитан. Опять добавил строку с запросом для поиска только что созданного отзыва.

### E.5. `get_statistic()`

```sql
SELECT * FROM ufimtsev_food.get_statistic();
```

Ожидается:
- Колонки: `restaurant_name`, `best_product_name`, `total_amount`, `avg_amount`, `best_user`.
- По одной строке на ресторан.
- `best_user` = `client.login` (не NULL при наличии заказов).

Факт: Функция возвращает 10 строк, по одной на каждый ресторан.

### E.6. `courier_salary()`

```sql
-- До
SELECT courier_id, coefficient FROM ufimtsev_food.courier ORDER BY courier_id;

CALL ufimtsev_food.courier_salary();

-- После
SELECT courier_id, coefficient FROM ufimtsev_food.courier ORDER BY courier_id;
SELECT year, month, courier_id, amount, coefficient_used
FROM ufimtsev_food.courier_pay
ORDER BY year DESC, month DESC, courier_id
LIMIT 20;
```

Ожидается:
- `courier.coefficient` пересчитан для работающих (по BR-10.2).
- У уволенных — не изменился.
- `courier_pay` содержит запись за текущий месяц.

Факт: ЗП и коэффициенты рассчитаны корректно

### E.7. `courier_salary()` — повторный вызов

```sql
CALL ufimtsev_food.courier_salary();
SELECT count(*) FROM ufimtsev_food.courier_pay
WHERE year = extract(year from current_date)
  AND month = extract(month from current_date);
```

Ожидается: количество не изменилось (idempotency / обновление).
Факт: Повторный вызов не создал дубликатов, лишь обновил выплаты

---

## F. Представление `how_much_money`

### F.1. Колонки

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'ufimtsev_food'
  AND table_name = 'how_much_money'
ORDER BY ordinal_position;
```

Ожидается: `year_month` (text), `sum_no_commission`, `sum_with_commission`, `commission`, `prev_commission`, `commission_diff`, `courier_pay`, `net_profit` (numeric).
Факт: 
| column_name | data_type |
| --- | --- |
| year_month | text |
| sum_no_commission | numeric |
| sum_with_commission | numeric |
|commission | numeric |
| prev_commission | numeric |
| commission_diff | numeric |
| courier_pay | numeric |
| net_profit | numeric |

### F.2. Месяцы покрыты

```sql
SELECT * FROM ufimtsev_food.how_much_money ORDER BY year_month;
```

Ожидается: месяцы от первого доставленного заказа до последнего (не пропущено ни одного).
Факт: Выведено 4 строки месяцев по порядку по заполненным данным из insert_test_data()

### F.3. Месяцы без заказов присутствуют (BR-11.9)

```sql
SELECT year_month FROM ufimtsev_food.how_much_money
WHERE sum_no_commission = 0 OR sum_no_commission IS NULL;
```

Ожидается: если в какие-то месяцы заказов не было — они есть в результате.
Факт: Пусто, так как заказы были все 6 месяцев сгенерированных данных, но именно доставленных заказов было только 4 месяца

### F.4. Корректность сумм

```sql
SELECT year_month,
       sum_no_commission,
       sum_with_commission,
       commission,
       prev_commission,
       commission_diff,
       courier_pay,
       net_profit
FROM ufimtsev_food.how_much_money
ORDER BY year_month
LIMIT 10;
```

Ожидается:
- `commission = sum_with_commission - sum_no_commission`.
- `commission_diff = commission - prev_commission` (NULL для первого месяца).
- `net_profit = commission - courier_pay`.

Факт: Все расчеты верны

---

## G. Права `inspector`

### G.1. Права на схему

```sql
SELECT
    nspname AS schema_name,
    has_schema_privilege('inspector', nspname, 'USAGE') AS usage,
    has_schema_privilege('inspector', nspname, 'CREATE') AS create
FROM pg_namespace
WHERE nspname = 'ufimtsev_food';
```

Ожидается: Ожидается: `<фамилия>_food`, `true`, `true` (полный доступ).
Факт: 
| schema_name | usage | create |
| --- | --- |
| ufimtsev_food | true | true |

### G.2. Права на таблицы

```sql
SELECT table_name, string_agg(privilege_type, ', ') AS privs
FROM information_schema.role_table_grants
WHERE grantee = 'inspector' AND table_schema = 'ufimtsev_food'
GROUP BY table_name;
```

Ожидается: у каждой таблицы `SELECT, INSERT, UPDATE, DELETE` (или `ALL`).
Факт: Пользователь имеет все необходимые права
`TRIGGER`, `REFERENCES`, `TRUNCATE`, `DELETE`, `UPDATE`, `SELECT`, `INSERT`

### G.3. `information_schema` читается под `inspector`

```sql
SET ROLE inspector;
SELECT count(*) FROM information_schema.tables
WHERE table_schema = 'ufimtsev_food';
RESET ROLE;
```

Ожидается: 12 + N (количество таблиц).
Факт: 13

### G.4. `pg_catalog` читается под `inspector`

```sql
SET ROLE inspector;
SELECT count(*) FROM pg_catalog.pg_tables
WHERE schemaname = 'ufimtsev_food';
RESET ROLE;
```

Ожидается: 12 + N.
Факт: 12

### G.5. Все процедуры/функции работают под `inspector`

```sql
SET ROLE inspector;
SET search_path TO ufimtsev_food, exts;

CALL erase_test_data();
CALL insert_test_data(10);
CALL courier_salary();
SELECT * FROM get_statistic();
SELECT * FROM how_much_money LIMIT 5;

RESET ROLE;
```

Ожидается: без `permission denied`.
Факт: Все выполняется без ошибок

---

## H. Оптимизация `get_statistic` (BR-11.8)

### H.1. `EXPLAIN ANALYZE` — паттерн «избыточные подзапросы»

```sql
EXPLAIN ANALYZE
SELECT c.courier_id,
       (SELECT count(*) FROM "order" o WHERE o.courier_id = c.courier_id AND o.status = 'доставлен') AS cnt,
       (SELECT coalesce(sum(commission), 0) FROM "order" o WHERE o.courier_id = c.courier_id AND o.status = 'доставлен') AS commission_sum
FROM courier c;
```

Ожидается: два SubPlan, каждый — скан `"order"`. Время растёт линейно от числа курьеров.
Факт: время 0.307 мс, план 0.235 мс. Два SubPlan, каждый выполняется 10 раз

### H.2. `EXPLAIN ANALYZE` — паттерн «один JOIN»

```sql
EXPLAIN ANALYZE
SELECT c.courier_id,
       count(o.order_id) AS cnt,
       coalesce(sum(o.commission), 0) AS commission_sum
FROM courier c
LEFT JOIN "order" o ON o.courier_id = c.courier_id AND o.status = 'доставлен'
GROUP BY c.courier_id;
```

Ожидается: один `Hash Right Join` / `Hash Left Join`, один скан `"order"`. Время меньше, чем в H.1.
Факт: время 0.161 мс, план 0.374 мс. Время выполнения запроса ускорилось, повторные SubPlan устранены

### H.3. Применить к `get_statistic`

```sql
EXPLAIN ANALYZE SELECT * FROM get_statistic();
```

Ожидается: без `LATERAL`, без множественных подзапросов к одной таблице, без оконных функций там, где хватает агрегата.
Факт: `LATERAL` и лишние подзапросы и окна не используются. Plan time = 0.026 мс, Execution time = 0.531 мс

---

## I. Очистка и повторная генерация

### I.1. `erase_test_data` очищает всё

```sql
CALL erase_test_data();

SELECT 'client' AS tbl, count(*) FROM client
UNION ALL SELECT 'courier', count(*) FROM courier
UNION ALL SELECT 'product_category', count(*) FROM product_category
UNION ALL SELECT 'restaurant', count(*) FROM restaurant
UNION ALL SELECT 'address', count(*) FROM address
UNION ALL SELECT 'product', count(*) FROM product
UNION ALL SELECT 'order', count(*) FROM "order"
UNION ALL SELECT 'review', count(*) FROM review
UNION ALL SELECT 'payment', count(*) FROM payment
UNION ALL SELECT 'order_structure', count(*) FROM order_structure
UNION ALL SELECT 'client_address', count(*) FROM client_address
UNION ALL SELECT 'courier_pay', count(*) FROM courier_pay;
```

Ожидается: все 0.
Факт: Все 0

### I.2. Повторный `erase_test_data` не падает

```sql
CALL erase_test_data();
```

Ожидается: без ошибок.
Факт: нет ошибок

### I.3. После очистки `insert_test_data` снова работает

```sql
CALL insert_test_data(10);
SELECT count(*) FROM "order";
```

Ожидается: 50.
Факт: 50


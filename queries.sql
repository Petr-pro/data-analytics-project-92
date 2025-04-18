-- 1) top_10_total_income - запрос для вывода топ-10 продавцов по доходу
WITH seller_stats AS (
    SELECT 
        e.employee_id,                  -- ID продавца
        e.first_name || ' ' || e.last_name AS seller,  -- Полное имя продавца
        COUNT(s.sales_id) AS operations, -- считаем количество проведенных сделок
        SUM(p.price * s.quantity) AS income -- Общий доход (цена × количество проданных единиц)
    FROM employees e
    -- LEFT JOIN чтобы включить всех продавцов, даже без продаж
    LEFT JOIN sales s ON e.employee_id = s.sales_person_id  -- Связь с таблицей продаж
    LEFT JOIN products p ON s.product_id = p.product_id     -- Связь с таблицей продуктов для получения цен
    GROUP BY e.employee_id, seller  -- Группировка по ID и имени продавца
)
-- Основной запрос для вывода результатов
SELECT 
    seller,                          -- Имя продавца
    operations,                      -- Количество сделок
    FLOOR(COALESCE(income, 0)) AS income  -- Доход, округленный вниз до целого, с заменой NULL на 0
FROM seller_stats
-- Сортировка по доходу по убыванию, NULLS LAST расположит нулевые продажи в конце списка
ORDER BY income DESC NULLS LAST
LIMIT 10;  -- Ограничение вывода 10 записями

-- 2)lowest_average_income - Выводит продавцов со средним доходом выше среднего по компании 
-- Основной CTE для сбора статистики по продавцам
WITH seller_stats AS (
    SELECT 
        e.employee_id,                  -- Уникальный идентификатор продавца
        e.first_name || ' ' || e.last_name AS seller,  -- Полное имя продавца
        COUNT(s.sales_id) AS operations, -- Количество совершенных сделок
        SUM(p.price * s.quantity) AS income,  -- Общий доход от всех продаж
        SUM(p.price * s.quantity) / NULLIF(COUNT(s.sales_id), 0) AS avg_income_per_sale
        -- Средний доход на одну сделку с защитой от деления на ноль
    FROM employees e
    -- Используем LEFT JOIN, так как нам нужны только продавцы с продажами
    INNER JOIN sales s ON e.employee_id = s.sales_person_id  -- Связь с таблицей продаж
    INNER JOIN products p ON s.product_id = p.product_id     -- Связь с таблицей товаров
    GROUP BY e.employee_id, e.first_name, e.last_name        -- Группировка по продавцам
    HAVING SUM(p.price * s.quantity) > 0
),
-- CTE для расчета среднего дохода по всем продавцам
avg_income_all AS (
    SELECT 
        AVG(avg_income_per_sale) AS avg_income  -- Среднее значение дохода на сделку
    FROM seller_stats
)
-- Основной запрос для вывода результатов
SELECT 
    seller,  -- Имя продавца
    FLOOR(avg_income_per_sale) AS average_income  -- Средний доход на сделку (округленный вниз)
FROM seller_stats ss
CROSS JOIN avg_income_all a
-- Фильтр: ВЫШЕ общего среднего
WHERE avg_income_per_sale > a.avg_income
-- Сортировка по убыванию среднего дохода (от наибольшего к наименьшему)
ORDER BY avg_income_per_sale DESC;

-- 3) day_of_the_week_income - Анализ продаж по дням недели с правильной сортировкой (пн-вс) 
-- Запрос для анализа продаж по дням недели и продавцам
SELECT
    e.first_name || ' ' || e.last_name AS seller,
    -- 'FMDay' формат возвращает полное название дня без пробелов (например, "Monday")
    TO_CHAR(s.sale_date, 'FMDay') AS day_of_week,
    -- SUM(p.price * s.quantity) - сумма произведений цены на количество
    -- FLOOR() - округление до целого в меньшую сторону
    FLOOR(SUM(p.price * s.quantity)) AS income
FROM products p 
JOIN sales s ON p.product_id = s.product_id
JOIN employees e ON s.sales_person_id = e.employee_id
GROUP BY 
    e.first_name,
    e.last_name,
    TO_CHAR(s.sale_date, 'FMDay'),
    EXTRACT(dow FROM s.sale_date)   -- Дополнительная группировка по числовому значению дня (для сортировки)
ORDER BY
    -- 1. Сортировка по дням недели (понедельник-воскресенье)
    CASE EXTRACT(dow FROM s.sale_date)
        WHEN 0 THEN 7  -- Воскресенье (0) перемещаем в конец (присваиваем 7)
        ELSE EXTRACT(dow FROM s.sale_date)  -- Остальные дни сохраняют свои значения (1-6)
    END,
    e.last_name,
    e.first_name,
    income DESC;

-- 4) special_offer - создаем таблицу с именем покупателя, датой перовой покупки по акции и имя продавца

WITH zero_value_sales AS (
    SELECT
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer,  -- Полное имя клиента
        MIN(s.sale_date) AS first_sale_date,  -- Самая ранняя дата продажи для клиента
        --Подзапрос для определения продавца, оформившего первую продажу
        (
            SELECT e.first_name || ' ' || e.last_name 
            FROM employees e 
            JOIN sales s2 ON e.employee_id = s2.sales_person_id
            WHERE s2.customer_id = c.customer_id
            AND s2.sale_date = MIN(s.sale_date)  -- Только для первой продажи
            LIMIT 1 -- Используем LIMIT 1 для гарантии одной записи
        ) AS seller
    FROM customers c
    JOIN sales s ON c.customer_id = s.customer_id
    JOIN products p ON s.product_id = p.product_id
    GROUP BY c.customer_id, c.first_name, c.last_name
    -- Фильтр: только клиенты с нулевой суммой покупок
    HAVING SUM(s.quantity * p.price) = 0  
)
-- Основной запрос для вывода результатов
SELECT
    customer,
    first_sale_date AS sale_date,
    seller
FROM zero_value_sales
ORDER BY customer_id;

--5) customers_by_month - Выбираем данные о продажах, сгруппированные по месяцам 
select
    -- Форматируем дату в виде 'YYYY-MM' (например '1996-09')
    to_char(s.sale_date, 'YYYY-MM') as selling_month,
    -- Считаем количество уникальных клиентов в каждом месяце
    count(DISTINCT s.customer_id) as total_customers,
    -- Суммируем выручку (количество × цену) и округляем вниз до целого числа
    floor(sum(s.quantity * p.price)) as income
from sales s
-- Соединяем таблицу продаж с таблицей продуктов
join products p
    on s.product_id = p.product_id
-- Группируем результаты по отформатированному месяцу
group by to_char(s.sale_date, 'YYYY-MM')
-- Можно добавить сортировку по месяцам в хронологическом порядке
order by selling_month;

-- 6) age_groups - Запрос для анализа распределения клиентов по возрастным категориям
SELECT 
    age_category,           -- Название возрастной категории
    COUNT(*) AS age_count   -- Количество клиентов в категории
FROM (
    -- Внутренний подзапрос для классификации клиентов по возрастам
    SELECT 
        customer_id,
        CASE
            WHEN age BETWEEN 16 AND 25 THEN '16-25'      -- Возраст 16-25 лет
            WHEN age BETWEEN 26 AND 40 THEN '26-40'      -- Возраст 26-40 лет
            WHEN age > 40 THEN '40+'                     -- Возраст старше 40 лет
            ELSE 'Другая категория'                     -- Остальные случаи (если age < 16)
        END AS age_category
    FROM customers
    WHERE age >= 16  -- Фильтр: только клиенты старше 16 лет
) AS categorized_customers
GROUP BY age_category
-- Сортировка результатов по порядку возрастных категорий
ORDER BY 
    CASE age_category
        WHEN '16-25' THEN 1   -- Первая категория (самая младшая)
        WHEN '26-40' THEN 2   -- Вторая категория
        WHEN '40+' THEN 3     -- Третья категория (самая старшая)
        ELSE 4                -- Прочие категории (если есть)
    END;

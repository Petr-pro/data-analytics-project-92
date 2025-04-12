-- 1) top_10_total_income - запрос для вывода топ-10 продавцов по доходу
with seller_stats as (
    -- собираем базовую статистику по продавцам
    select 
        e.employee_id,  -- id продавца
        e.first_name || ' ' || e.last_name as seller,  -- полное имя продавца
        count(s.sales_id) as operations,  -- количество сделок
        sum(p.price * s.quantity) as income  -- общий доход
    from employees e
    left join sales s on e.employee_id = s.sales_person_id  -- присоединяем продажи
    left join products p on s.product_id = p.product_id  -- присоединяем информацию о товарах
    group by e.employee_id, e.first_name, e.last_name  -- группируем по продавцам
)
select 
    seller,  -- имя продавца
    operations,  -- количество сделок
    floor(coalesce(income, 0)) as income  -- доход (с заменой null на 0 и округлением вниз)
from seller_stats
order by 
    case when income = 0 or income is null then 1 else 0 end,  -- сначала продавцы с доходом
    income desc  -- сортировка по доходу (убывание)
limit 10;  -- ограничиваем вывод 10 записями

-- 2)lowest_average_income - Выводит продавцов со средним доходом выше среднего по компании 
-- Формируем временную таблицу с базовой статистикой по продавцам
with seller_stats as (
    select 
        e.employee_id,  -- ID продавца
        e.first_name || ' ' || e.last_name as seller,  -- Полное имя продавца
        count(s.sales_id) as operations,  -- Количество совершенных сделок
        sum(p.price * s.quantity) as income  -- Общий доход от продаж
    from employees e
    -- Присоединяем таблицу продаж (LEFT JOIN чтобы включить всех продавцов)
    left join sales s on e.employee_id = s.sales_person_id
    -- Присоединяем таблицу товаров для получения цен
    left join products p on s.product_id = p.product_id
    group by e.employee_id, e.first_name, e.last_name
    -- Исключаем продавцов без продаж (с нулевым доходом)
    having sum(p.price * s.quantity) > 0  
),
-- Вычисляем средний доход на сделку по всем продавцам
avg_income_all as (
    select avg(income / nullif(operations, 0)) as avg_income
    from seller_stats
    -- NULLIF защищает от деления на ноль (хотя HAVING уже исключил нулевые доходы)
)
-- Итоговый результат: продавцы с доходом выше среднего
select 
    seller,  -- Имя продавца
    floor(income / nullif(operations, 0)) as average_income  -- Средний доход на сделку (округленный)
from seller_stats ss
-- Соединяем с таблицей средних значений (CROSS JOIN для сравнения каждого продавца со средним)
cross join avg_income_all a
-- Фильтр: оставляем только продавцов с доходом выше среднего
where income / nullif(operations, 0) < a.avg_income  
-- Сортировка по общему доходу (от наибольшего к наименьшему)
order by average_income;  

-- 3) day_of_the_week_income - Анализ продаж по дням недели с правильной сортировкой (пн-вс) 
select
    -- Конкатенируем имя и фамилию продавца в одно поле
    e.first_name || ' ' || e.last_name as seller,
    -- Преобразуем числовое значение дня недели в текстовое название
    case extract(dow from s.sale_date)
        when 0 then 'sunday'
        when 1 then 'monday'
        when 2 then 'tuesday'
        when 3 then 'wednesday'
        when 4 then 'thursday'
        when 5 then 'friday'
        when 6 then 'saturday'
    end as day_of_week,
    -- Считаем общий доход (цена × количество) и округляем до целого числа
    floor(sum(p.price * s.quantity)) as income --округляем в меньшую сторону сумму продаж
-- Основные таблицы данных
from products p
-- Соединяем таблицу продуктов с таблицей продаж по ID продукта
join sales s on p.product_id = s.product_id
-- Соединяем с таблицей сотрудников по ID продавца
join employees e on s.sales_person_id = e.employee_id
-- Группируем результаты по:
-- 1) имени продавца
-- 2) дню недели (текстовое представление)
-- 3) дню недели (числовое представление - нужно для корректной сортировки)
group by seller, day_of_week, extract(dow from s.sale_date)
-- Сортируем результаты:
order by
    -- 1) Сначала по дню недели (используем CASE для правильного порядка):
    --    - Понедельник (1) будет первым
    --    - Воскресенье (0) переносим в конец (присваиваем значение 7)
    case extract(dow from s.sale_date)
        when 0 then 7  -- Воскресенье в конец
        else extract(dow from s.sale_date)
    end,
    -- 2) Затем по имени продавца (в алфавитном порядке)
    seller,
    -- 3) Внутри каждого продавца и дня недели сортируем по доходу (по убыванию)
    income desc:

-- 4) special_offer - создаем таблицу с именем покупателя, датой перовой покупки по акции и имя продавца
-- special_offer Создаем временную таблицу (CTE) с информацией о специальных заказах
with special_orders as (
    select
        c.first_name || ' ' || c.last_name as customer,  -- объединяем имя и фамилию клиента
        s.sale_date,                                    -- дата продажи
        e.first_name || ' ' || e.last_name as seller,    -- объединяем имя и фамилию продавца
        sum(s.quantity * p.price) as special_sale,       -- рассчитываем сумму продажи
        s.customer_id                                   -- идентификатор клиента
    from customers c 
    join sales s 
        on c.customer_id = s.customer_id 
    join employees e 
        on s.sales_person_id = e.employee_id
    join products p 
        on s.product_id = p.product_id
    group by customer, s.sale_date, seller, s.customer_id  -- группируем по этим полям
    having sum(s.quantity * p.price) = 0
),
-- Добавляем CTE для выбора только первой записи каждого клиента
unique_customers as (
    select 
        customer,
        sale_date,
        seller,
        customer_id,
        -- Нумеруем записи для каждого клиента по дате продажи
        row_number() over (partition by customer_id order by sale_date) as rn
    from special_orders
)
-- Основной запрос:
select 
    customer,                   -- имя клиента
    sale_date,                  -- самая ранняя дата продажи
    seller                      -- имя продавца
from unique_customers
where rn = 1  -- Берем только первую запись для каждого клиента
order by customer_id;          -- сортируем по идентификатору клиента

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
-- Первая часть: подсчет клиентов в возрастной категории 16-25 лет
select
    '16-25' as age_category,          -- Название возрастной категории
    count(distinct customer_id) as age_count  -- Уникальное количество клиентов
from customers
where age >= 16 and age <= 25         -- Условие для возраста 16-25 включительно
union                                -- Объединение с результатами следующего запроса
-- Вторая часть: подсчет клиентов в возрастной категории 26-40 лет
select
    '26-40' as age_category,          -- Название возрастной категории
    count(distinct customer_id) as age_count  -- Уникальное количество клиентов
from customers
where age >= 26 and age <= 40         -- Условие для возраста 26-40 включительно
union                                -- Объединение с результатами следующего запроса
-- Третья часть: подсчет клиентов в возрастной категории 40+
select
    '40+' as age_category,            -- Название возрастной категории
    count(distinct customer_id) as age_count  -- Уникальное количество клиентов
from customers
where age > 40                       -- Условие для возраста старше 40 лет
-- Сортировка результатов по названию возрастной категории
order by age_category;
/*
Примечания:
1. Используется UNION для объединения результатов трех отдельных запросов
2. count(distinct customer_id) гарантирует, что каждый клиент учитывается только один раз
3. Порядок категорий в результате будет: '16-25', '26-40', '40+'
4. Для возрастных границ:
   - 16-25: включает клиентов от 16 до 25 лет включительно
   - 26-40: включает клиентов от 26 до 40 лет включительно
   - 40+: клиенты старше 40 лет (не включая 40)

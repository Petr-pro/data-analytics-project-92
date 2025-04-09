-- 1) запрос для вывода топ-10 продавцов по доходу
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
    round(coalesce(income, 0), 0) as income  -- доход (с заменой null на 0 и округлением)
from seller_stats
order by 
    case when income = 0 or income is null then 1 else 0 end,  -- сначала продавцы с доходом
    income desc  -- сортировка по доходу (убывание)
limit 10;  -- ограничиваем вывод 10 записями 

-- 2) Выводит продавцов со средним доходом выше среднего по компании
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
    round(income / nullif(operations, 0), 0) as average_income  -- Средний доход на сделку (округленный)
from seller_stats ss
-- Соединяем с таблицей средних значений (CROSS JOIN для сравнения каждого продавца со средним)
cross join avg_income_all a
-- Фильтр: оставляем только продавцов с доходом выше среднего
where income / nullif(operations, 0) > a.avg_income  
-- Сортировка по общему доходу (от наибольшего к наименьшему)
order by income desc;  

-- 3) Анализ продаж по дням недели с правильной сортировкой (пн-вс)
-- Первый CTE: анализируем продажи по товарам и продавцам
with amount_tab as (
    select
        p.name,                          -- Название товара
        s.sales_person_id,               -- ID продавца
        sum(p.price * s.quantity) as sum_amount, -- Сумма продаж (цена × количество)
        sum(s.quantity) as operations    -- Количество проданных единиц
    from products p
    join sales s                         -- Соединяем таблицы товаров и продаж
        on p.product_id = s.product_id   -- По ID товара
    group by p.product_id, s.sales_person_id -- Группируем по товару и продавцу
    order by sum_amount desc, p.name     -- Сортировка по сумме продаж и названию товара
),
-- Второй CTE: агрегируем данные по продавцам
name_salers as (
    select
        e.employee_id,
        e.first_name || ' ' || e.last_name as seller, -- Полное имя продавца
        operations,                       -- Количество операций из предыдущего CTE
        sum(at.sum_amount) as income      -- Суммарный доход продавца
    from employees e
    join amount_tab at                    -- Соединяем с предыдущим CTE
        on e.employee_id = at.sales_person_id -- По ID продавца
    group by seller, operations, e.employee_id -- Группируем по продавцу и операциям
    order by income desc                  -- Сортировка по доходу (убывание)
),
-- Третий CTE: анализируем продажи по дням недели
day_sale as (
    select
        ns.seller,
        -- Преобразуем номер дня недели в название
        case extract(dow from s.sale_date)
            when 0 then 'воскресенье'
            when 1 then 'понедельник'
            when 2 then 'вторник'
            when 3 then 'среда'
            when 4 then 'четверг'
            when 5 then 'пятница'
            when 6 then 'суббота'
        end as day_of_week,
        -- Создаем поле для сортировки (пн=1, вт=2,..., вс=7)
        case when extract(dow from s.sale_date) = 0 then 7 
             else extract(dow from s.sale_date) 
        end as day_sort_order,
        round(sum(ns.income), 0) as income  -- Доход с округлением
    from name_salers ns
    join sales s
        on ns.employee_id = s.sales_person_id
    group by ns.seller, day_of_week, day_sort_order
)
-- Итоговый запрос: суммарные продажи по дням недели
select
    day_sort_order,      -- Порядковый номер дня для сортировки
    day_of_week,         -- Название дня недели
    sum(income) as income  -- Суммарный доход по дню
from day_sale
group by day_of_week, day_sort_order  -- Группируем по дням недели
order by 
    day_sort_order   -- Сортировка от понедельника (1) до воскресенья (7)
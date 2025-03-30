--составляем запрос для вывода таблицы с колличеством операций и суммой продаж по каждому продавцу
-- первый cte (common table expression) - amount_tab
-- создаю временную таблицу для подсчета суммы продаж по каждому товару и продавцу
with amount_tab as (
    select
        p.name,                          -- название товара из таблицы products
        s.sales_person_id,               -- id продавца из таблицы sales
        sum(p.price * s.quantity) as sum_amount, -- сумма продаж: цена товара × количество проданных единиц
        sum(s.quantity) as operations    -- общее количество проданных единиц (операций/сделок)
    from products p
    join sales s                         -- объединяю таблицы товаров и продаж
        on p.product_id = s.product_id   -- по полю product_id (идентификатор товара)
    group by p.product_id, s.sales_person_id -- группирую по товару и продавцу
    order by sum_amount desc, p.name     -- сортирую по убыванию суммы продаж, затем по имени товара
),
-- второй cte - name_salers
-- создаю таблицу с информацией о продавцах и их продажах
name_salers as (
    select
        -- объединяю имя и фамилию продавца в одно поле
        e.first_name || ' ' || e.last_name as seller,
        operations,                       -- количество операций из предыдущего cte
        sum(at.sum_amount) as income      -- суммарный доход продавца по всем товарам
    from employees e
    join amount_tab at                    -- соединяю с предыдущей временной таблицей
        on e.employee_id = at.sales_person_id -- по id продавца
    group by seller, operations           -- группирую по продавцу и количеству операций
    order by income desc                  -- сортирую по доходу (по убыванию)
)
-- основной запрос
-- выбираю топ-10 продавцов по доходу
select
    seller,                               -- имя продавца
    sum(operations) as operations,        -- общее количество операций (суммирую возможные дубли)
    round(sum(income), 0) as income       -- общий доход продавца, округляю до целого
from name_salers
group by seller                           -- группирую только по продавцу (агрегирую данные)
order by income desc                      -- сортирую по убыванию дохода
limit 10;                                 -- ограничиваю вывод 10 записями (топ-10 продавцов)


--составляем запрос для вывода таблицы со средней выручкой продавца за сделку с округлением до целого
-- первый cte (common table expression) - amount_tab
-- вычисляет сумму продаж и количество операций для каждой пары "товар-продавец"
with amount_tab as (
    select
        p.name,                          -- название товара
        s.sales_person_id,               -- id продавца
        sum(p.price * s.quantity) as sum_amount,  -- общая сумма продаж (цена × количество)
        sum(s.quantity) as operations    -- общее количество проданных единиц
    from products p
    join sales s 
        on p.product_id = s.product_id    -- соединяем таблицы товаров и продаж
    group by p.product_id, s.sales_person_id  -- группируем по товару и продавцу
    order by sum_amount desc, p.name      -- сортируем по сумме продаж и названию товара
),
-- второй cte - name_salers
-- объединяет данные о продажах с информацией о продавцах
name_salers as (
    select
        e.first_name || ' ' || e.last_name as seller,  -- полное имя продавца
        operations,                         -- количество операций из предыдущего cte
        sum(at.sum_amount) as income        -- суммарный доход продавца по всем товарам
    from employees e
    join amount_tab at
        on e.employee_id = at.sales_person_id  -- соединяем с предыдущим cte по id продавца
    group by seller, operations              -- группируем по продавцу и количеству операций
    order by income desc                     -- сортируем по доходу (по убыванию)
),
-- третий cte - avg_amount
-- вычисляет общее количество операций и суммарный доход для каждого продавца
avg_amount as (
    select
        seller,                             -- имя продавца
        sum(operations) as operations,      -- общее количество операций продавца
        sum(income) as income               -- общий доход продавца
    from name_salers
    group by seller                         -- группируем только по продавцу
    order by income desc                    -- сортируем по доходу (по убыванию)
),
-- четвертый cte - avg_income_all
-- вычисляет средний доход на одну операцию по всем продавцам
avg_income_all as (
    select avg(income / operations) as avg_income
    from avg_amount
)
-- основной запрос
-- выбирает продавцов, чей средний доход на операцию ниже общего среднего
select
    a.seller,                               -- имя продавца
    round(sum(a.income / a.operations), 0) as average_income  -- средний доход на операцию (округленный)
from avg_amount a
cross join avg_income_all ai                -- присоединяем общее среднее значение ко всем строкам
group by a.seller, ai.avg_income    -- группируем по продавцу и общему среднему
having sum(a.income / a.operations) < ai.avg_income  -- фильтруем только тех, кто ниже среднего
order by average_income;                    -- сортируем по среднему доходу (по возрастанию)


--Третий отчет содержит информацию о выручке по дням недели. Каждая запись содержит имя и 
--фамилию продавца, день недели и суммарную выручку
-- первый cte (common table expression) - amount_tab
-- создаю временную таблицу для подсчета суммы продаж по каждому товару и продавцу
with amount_tab as (
    select
        p.name,                          -- название товара из таблицы products
        s.sales_person_id,               -- id продавца из таблицы sales
        sum(p.price * s.quantity) as sum_amount, -- сумма продаж: цена товара × количество проданных единиц
        sum(s.quantity) as operations    -- общее количество проданных единиц (операций/сделок)
    from products p
    join sales s                         -- объединяю таблицы товаров и продаж
        on p.product_id = s.product_id   -- по полю product_id (идентификатор товара)
    group by p.product_id, s.sales_person_id -- группирую по товару и продавцу
    order by sum_amount desc, p.name     -- сортирую по убыванию суммы продаж, затем по имени товара
),
-- второй cte - name_salers
-- создаю таблицу с информацией о продавцах и их продажах
name_salers as (
    select
        -- объединяю имя и фамилию продавца в одно поле
        e.employee_id,
        e.first_name || ' ' || e.last_name as seller,
        operations,                       -- количество операций из предыдущего cte
        sum(at.sum_amount) as income      -- суммарный доход продавца по всем товарам
    from employees e
    join amount_tab at                    -- соединяю с предыдущей временной таблицей
        on e.employee_id = at.sales_person_id -- по id продавца
    group by seller, operations, e.employee_id -- группирую по продавцу, количеству операций и id
    order by income desc                  -- сортирую по доходу (по убыванию)
),
-- основной запрос
-- анализирую продажи по дням недели с правильной сортировкой (пн-вс)
day_sale as (
    select
        ns.seller,
        case extract(dow from s.sale_date)
            when 0 then 'воскресенье'
            when 1 then 'понедельник'
            when 2 then 'вторник'
            when 3 then 'среда'
            when 4 then 'четверг'
            when 5 then 'пятница'
            when 6 then 'суббота'
        end as day_of_week,
        -- Преобразуем нумерацию дней для сортировки (пн=1, вт=2,..., вс=7)
        case when extract(dow from s.sale_date) = 0 then 7 
             else extract(dow from s.sale_date) 
        end as day_sort_order,
        round(sum(ns.income), 0) as income
    from name_salers ns
    join sales s
        on ns.employee_id = s.sales_person_id
    group by ns.seller, day_of_week, day_sort_order
)
select
    seller,
    day_of_week,
    income
from day_sale
order by 
    day_sort_order, seller, income desc  -- Сортировка от понедельника (1) до воскресенья (7)
   
-- 

-- Вывод названия всех таблиц схемы fantasy
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'fantasy'

-- Изучение данных таблицы users
SELECT
    c.table_schema,
    c.table_name,
    c.column_name,
    c.data_type,
    k.constraint_name
FROM
    information_schema.columns c
LEFT JOIN
    information_schema.key_column_usage k
    ON c.table_schema = k.table_schema
    AND c.table_name = k.table_name
    AND c.column_name = k.column_name
WHERE
    c.table_schema = 'fantasy'
    AND c.table_name = 'users'

-- Вывод первых строк таблицы users + подсчет общего количества строк в таблице
SELECT 
    *, 
   (SELECT COUNT(*) AS row_count FROM fantasy.users) 
FROM fantasy.users
GROUP BY id, tech_nickname, class_id, ch_id, birthdate, pers_gender, registration_dt, server, race_id, payer, loc_id
LIMIT 5

-- Проверка пропусков в таблице users
SELECT  
    COUNT(*) 
FROM fantasy.users 
WHERE loc_id IS NULL OR class_id IS NULL OR ch_id IS NULL OR pers_gender IS NULL OR server IS NULL OR race_id IS NULL OR payer IS NULL

-- Знакомство с категориальными данными таблицы users
SELECT 
    server, 
    COUNT(*)
FROM fantasy.users
GROUP BY server

-- Знакомство с таблицей events
SELECT c.table_schema,
       c.table_name,
       c.column_name,
       c.data_type,
       k.constraint_name
FROM information_schema.columns AS c 
LEFT JOIN information_schema.key_column_usage AS k 
    USING(table_name, column_name, table_schema)
WHERE c.table_schema = 'fantasy' AND c.table_name = 'events'
ORDER BY c.table_name;

-- Вывод первых строк таблицы events + подсчет общего количества строк в таблице
SELECT 
    *, 
    (SELECT COUNT(*) AS row_count FROM fantasy.events)
FROM fantasy.events
LIMIT 5

-- Проверка пропусков в таблице events
SELECT 
    COUNT(*)
FROM fantasy.events
WHERE date IS NULL OR time IS NULL OR amount IS NULL OR seller_id IS NULL

-- Изучаем пропуски в таблице events
SELECT 
    SUM(CASE WHEN date IS NOT NULL THEN 1 ELSE 0 END) AS data_count,
    SUM(CASE WHEN time IS NOT NULL THEN 1 ELSE 0 END) AS data_time,
    SUM(CASE WHEN amount IS NOT NULL THEN 1 ELSE 0 END) AS data_amount,
    SUM(CASE WHEN seller_id IS NOT NULL THEN 1 ELSE 0 END) AS data_seller_id
FROM fantasy.events
WHERE date IS NULL
  OR time IS NULL
  OR amount IS NULL
  OR seller_id IS NULL;

--



-- Аналитика информации о том как клиенты федеральной сотовой кампании "Мегасеть" пользуются услугами кампании с точки зреня двух тарифных планов


-- ЗНАКОМСТВО С ДАННЫМИ
-- Проверка соответствия данных описанию
SELECT * FROM telecom.users
LIMIT 20

-- Проверка, что в данных для каждого пользователя нет пропусков 
SELECT * FROM telecom.users 
WHERE user_id IS NULL OR age IS NULL OR churn_date IS NULL OR city IS NULL OR first_name IS NULL OR last_name IS NULL OR reg_date IS NULL OR tariff IS NULL 
LIMIT 10

-- Подсчет доли активных клиентов
SELECT 
  COUNT(
    CASE 
    WHEN churn_date IS NULL
    THEN 1
    END
  ) / COUNT(*)::real
FROM telecom.users u

-- Вывод ID клиентов, у которых больше одного тарифного плана и количество тарифных планов у клиентов.
SELECT user_id,
  COUNT(DISTINCT tariff)
FROM telecom.users 
WHERE churn_date IS NULL
GROUP BY user_id
HAVING COUNT(DISTINCT tariff) > 1

-- Знакомство с данными об услугах, которыми пользовались клиенты, выявление пропусков 
SELECT * FROM telecom.calls
WHERE duration IS NULL OR call_date IS NULL

-- Проверка аномалий в данных о длительности разговора
SELECT 
  MIN(duration) AS min_duration,
  MAX(duration) AS max_duration
FROM telecom.calls

-- Изучение доли пропущенных звонков
SELECT
  COUNT(
    CASE 
    WHEN duration = 0
    THEN 1 
    END
  )/COUNT(*)::real
FROM telecom.calls

-- Изучение общей длительности разговоров каждого пользователя в день
SELECT 
  user_id, 
  call_date,
  SUM(duration)/60.0 AS total_day_duration
FROM telecom.calls 
GROUP BY user_id, call_date
ORDER BY total_day_duration DESC
LIMIT 10


-- СЧИТАЕМ СТАТИСТИКУ ДЛЯ КАЖДОГО КЛИЕНТА
-- Длительность разговоров клиента в месяц
WITH 
monthly_duration AS ( 
  SELECT
    user_id,
    DATE(DATE_TRUNC('month', call_date::timestamp)) AS dt_month,
    CEIL(SUM(duration)) AS month_duration
  FROM telecom.calls
  GROUP BY user_id, dt_month
)
SELECT * FROM monthly_duration
LIMIT 5

-- Количество интернет-трафика в месяц
WITH monthly_duration AS (
    SELECT user_id,
           DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,    
           CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),
monthly_internet AS (
    SELECT user_id,
      DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,
      SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet 
    GROUP BY user_id, dt_month
)
SELECT * FROM monthly_internet
LIMIT 5

-- Количество сообщений в месяц
WITH monthly_duration AS (
    SELECT user_id,
           DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,    
           CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),
monthly_internet AS (
    SELECT user_id,
           DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,  
           SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),
monthly_sms AS (
    SELECT 
      user_id, 
      DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,
      COUNT(*) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
)
SELECT * FROM monthly_sms
LIMIT 5

-- Соединяем данные о клиентах и их месячную активность
WITH monthly_duration AS (
    SELECT user_id,
           DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,    
           CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),
monthly_internet AS (
    SELECT user_id,
           DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,  
           SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),
monthly_sms AS (
    SELECT user_id,
           DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,  
           COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),
user_activity_months AS (
    SELECT user_id, dt_month
    FROM monthly_duration
    UNION 
    SELECT user_id, dt_month
    FROM monthly_internet
    UNION 
    SELECT user_id, dt_month
    FROM monthly_sms
)

SELECT * FROM user_activity_months
ORDER BY user_id ASC, dt_month ASC
LIMIT 5

-- Объединяем данные о клиентах в одну таблицу
WITH monthly_duration AS (
    SELECT user_id,
           DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,    
           CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),
monthly_internet AS (
    SELECT user_id,
           DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,  
           SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),
monthly_sms AS (
    SELECT user_id,
           DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,  
           COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),
user_activity_months AS (
    SELECT user_id, dt_month
    FROM monthly_duration
    UNION
    SELECT user_id, dt_month
    FROM monthly_internet   
    UNION
    SELECT user_id, dt_month
    FROM monthly_sms
),
users_stat AS (
    SELECT a.user_id, 
    a.dt_month, 
    d.month_duration AS month_duration,
    i.month_mb_traffic AS month_mb_traffic, 
    m.month_sms AS month_sms
    FROM user_activity_months a
    LEFT JOIN monthly_duration d USING (user_id, dt_month)
    LEFT JOIN monthly_internet i USING (user_id, dt_month)
    LEFT JOIN monthly_sms m USING (user_id, dt_month)
)
SELECT * FROM users_stat
ORDER BY user_id ASC, dt_month ASC
LIMIT 10

-- Траты клиентов вне тарифного лимита
WITH monthly_duration AS (
    SELECT user_id, 
           DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,    
           CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),
monthly_internet AS (
    SELECT user_id,
           DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,  
           SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),
monthly_sms AS (
    SELECT user_id,
           DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,  
           COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),
user_activity_months AS (
    SELECT user_id, dt_month
    FROM monthly_duration
    UNION
    SELECT user_id, dt_month
    FROM monthly_internet   
    UNION
    SELECT user_id, dt_month
    FROM monthly_sms
),
users_stat AS (
    SELECT 
        u.user_id,
        u.dt_month,
        month_duration,
        month_mb_traffic,
        month_sms
    FROM user_activity_months AS u
    LEFT JOIN monthly_duration AS md ON u.user_id = md.user_id AND u.dt_month= md.dt_month
    LEFT JOIN monthly_internet AS mi ON u.user_id = mi.user_id AND u.dt_month= mi.dt_month
    LEFT JOIN monthly_sms AS mm ON u.user_id = mm.user_id AND u.dt_month= mm.dt_month
),
user_over_limits AS ( 
  SELECT
    s.user_id,
    s.dt_month,
    u.tariff, 
    s.month_duration,
    s.month_mb_traffic,
    s.month_sms,
    CASE
        WHEN s.month_duration > t.minutes_included
            THEN s.month_duration - t.minutes_included
        ELSE 0
    END AS duration_over,
    CASE
        WHEN s.month_mb_traffic > t.mb_per_month_included
            THEN (s.month_mb_traffic - t.mb_per_month_included)/1024
        ELSE 0
    END AS gb_traffic_over,
    CASE
        WHEN s.month_sms > t.messages_included
            THEN s.month_sms - t.messages_included
        ELSE 0
    END AS sms_over
    FROM users_stat s
    LEFT JOIN telecom.users u USING (user_id)
    LEFT JOIN telecom.tariffs t ON u.tariff = t.tariff_name
)
SELECT * FROM user_over_limits
ORDER BY user_id, dt_month
LIMIT 10

-- ДЕЛАЕМ РАСЧЕТЫ ДЛЯ ЗАКАЗЧИКА
-- Траты клиентов по месяцам
WITH monthly_duration AS (
    SELECT user_id,
           DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,    
           CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),
monthly_internet AS (
    SELECT user_id,
           DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,  
           SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),
monthly_sms AS (
    SELECT user_id,
           DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,  
           COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),
user_activity_months AS (
    SELECT user_id, dt_month
    FROM monthly_duration
    UNION
    SELECT user_id, dt_month
    FROM monthly_internet   
    UNION
    SELECT user_id, dt_month
    FROM monthly_sms
),
users_stat AS (
    SELECT u.user_id,
           u.dt_month,
           month_duration,
           month_mb_traffic,
           month_sms
    FROM user_activity_months AS u
    LEFT JOIN monthly_duration AS md ON u.user_id = md.user_id AND u.dt_month= md.dt_month
    LEFT JOIN monthly_internet AS mi ON u.user_id = mi.user_id AND u.dt_month= mi.dt_month
    LEFT JOIN monthly_sms AS mm ON u.user_id = mm.user_id AND u.dt_month= mm.dt_month
),
user_over_limits AS (
    SELECT us.user_id,
           us.dt_month,
           u.tariff,
           us.month_duration,
           us.month_mb_traffic,
           us.month_sms,
        CASE 
            WHEN us.month_duration >= t.minutes_included 
            THEN (us.month_duration - t.minutes_included)
            ELSE 0
        END AS duration_over,    
        CASE 
            WHEN us.month_mb_traffic >= t.mb_per_month_included 
            THEN (us.month_mb_traffic - t.mb_per_month_included) / 1024::real
            ELSE 0
        END AS gb_traffic_over,     
        CASE 
            WHEN us.month_sms >= t.messages_included 
            THEN (us.month_sms - t.messages_included)
            ELSE 0
        END AS sms_over
    FROM users_stat AS us
    LEFT JOIN (SELECT tariff, user_id FROM telecom.users) AS u ON us.user_id = u.user_id
    LEFT JOIN telecom.tariffs AS t ON u.tariff = t.tariff_name
),
users_costs AS (
    SELECT 
      o.user_id, 
      o.dt_month,
      o.tariff,
      o.month_duration,
      o.month_mb_traffic,
      o.month_sms, 
      t.rub_monthly_fee,
      (t.rub_monthly_fee + o.duration_over * rub_per_minute + o.gb_traffic_over * t.rub_per_gb + o.sms_over * rub_per_message) AS total_cost
    FROM user_over_limits o 
    LEFT JOIN telecom.tariffs t ON o.tariff = t.tariff_name
)
SELECT * FROM users_costs
ORDER BY user_id, dt_month
LIMIT 10

-- Средние траты активных клиентов
WITH monthly_duration AS (
    SELECT user_id,
           DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,    
           CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),
monthly_internet AS (
    SELECT user_id,
           DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,  
           SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),
monthly_sms AS (
    SELECT user_id,
           DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,  
           COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),
user_activity_months AS (
    SELECT user_id, dt_month
    FROM monthly_duration
    UNION
    SELECT user_id, dt_month
    FROM monthly_internet   
    UNION
    SELECT user_id, dt_month
    FROM monthly_sms
),
users_stat AS (
    SELECT u.user_id,
           u.dt_month,
           month_duration,
           month_mb_traffic,
           month_sms
    FROM user_activity_months AS u
    LEFT JOIN monthly_duration AS md ON u.user_id = md.user_id AND u.dt_month= md.dt_month
    LEFT JOIN monthly_internet AS mi ON u.user_id = mi.user_id AND u.dt_month= mi.dt_month
    LEFT JOIN monthly_sms AS mm ON u.user_id = mm.user_id AND u.dt_month= mm.dt_month
),
user_over_limits AS (
    SELECT us.user_id,
           us.dt_month,
           u.tariff,
           us.month_duration,
           us.month_mb_traffic,
           us.month_sms,
        CASE 
            WHEN us.month_duration >= t.minutes_included 
            THEN (us.month_duration - t.minutes_included)
            ELSE 0
        END AS duration_over,
        CASE 
            WHEN us.month_mb_traffic >= t.mb_per_month_included 
            THEN (us.month_mb_traffic - t.mb_per_month_included) / 1024::real
            ELSE 0
        END AS gb_traffic_over,    
        CASE 
            WHEN us.month_sms >= t.messages_included 
            THEN (us.month_sms - t.messages_included)
            ELSE 0
        END AS sms_over
    FROM users_stat AS us
    LEFT JOIN (SELECT tariff, user_id FROM telecom.users) AS u ON us.user_id = u.user_id
    LEFT JOIN telecom.tariffs AS t ON u.tariff = t.tariff_name
),
users_costs AS (
    SELECT uol.user_id,
           uol.dt_month,
           uol.tariff,
           uol.month_duration,
           uol.month_mb_traffic,
           uol.month_sms,
           t.rub_monthly_fee, 
           t.rub_monthly_fee + uol.duration_over * t.rub_per_minute
           + uol.gb_traffic_over * t.rub_per_gb + uol.sms_over * t.rub_per_message AS total_cost 
    FROM user_over_limits AS uol
    LEFT JOIN telecom.tariffs AS t ON uol.tariff = t.tariff_name
)
SELECT u.tariff,
  COUNT(DISTINCT u.user_id) AS total_users,
  ROUND(AVG(u.total_cost)::NUMERIC, 2) AS avg_total_cost
FROM users_costs u
LEFT JOIN telecom.users us USING (user_id)
WHERE us.churn_date IS NULL
GROUP BY u.tariff

-- Активные клиенты и их траты
WITH monthly_duration AS (
    SELECT user_id,
           DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,    
           CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),
monthly_internet AS (
    SELECT user_id,
           DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,  
           SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),
monthly_sms AS (
    SELECT user_id,
           DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,  
           COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),
user_activity_months AS (
    SELECT user_id, dt_month
    FROM monthly_duration
    UNION
    SELECT user_id, dt_month
    FROM monthly_internet   
    UNION
    SELECT user_id, dt_month
    FROM monthly_sms
),
users_stat AS (
    SELECT u.user_id,
           u.dt_month,
           month_duration,
           month_mb_traffic,
           month_sms
    FROM user_activity_months AS u
    LEFT JOIN monthly_duration AS md ON u.user_id = md.user_id AND u.dt_month= md.dt_month
    LEFT JOIN monthly_internet AS mi ON u.user_id = mi.user_id AND u.dt_month= mi.dt_month
    LEFT JOIN monthly_sms AS mm ON u.user_id = mm.user_id AND u.dt_month= mm.dt_month
),
user_over_limits AS (
    SELECT us.user_id,
           us.dt_month,
           u.tariff,
           us.month_duration,
           us.month_mb_traffic,
           us.month_sms,
        CASE 
            WHEN us.month_duration >= t.minutes_included 
            THEN (us.month_duration - t.minutes_included)
            ELSE 0
        END AS duration_over,      
        CASE 
            WHEN us.month_mb_traffic >= t.mb_per_month_included 
            THEN (us.month_mb_traffic - t.mb_per_month_included) / 1024::real
            ELSE 0
        END AS gb_traffic_over,   
        CASE 
            WHEN us.month_sms >= t.messages_included 
            THEN (us.month_sms - t.messages_included)
            ELSE 0
        END AS sms_over
    FROM users_stat AS us
    LEFT JOIN (SELECT tariff, user_id FROM telecom.users) AS u ON us.user_id = u.user_id
    LEFT JOIN telecom.tariffs AS t ON u.tariff = t.tariff_name
),
users_costs AS (
    SELECT uol.user_id,
           uol.dt_month,
           uol.tariff,
           uol.month_duration,
           uol.month_mb_traffic,
           uol.month_sms,
           t.rub_monthly_fee, 
           t.rub_monthly_fee + uol.duration_over * t.rub_per_minute
           + uol.gb_traffic_over * t.rub_per_gb + uol.sms_over * t.rub_per_message AS total_cost 
    FROM user_over_limits AS uol
    LEFT JOIN telecom.tariffs AS t ON uol.tariff = t.tariff_name
)
SELECT c.tariff, 
  COUNT(DISTINCT c.user_id),
  ROUND(AVG(c.total_cost)::NUMERIC, 2) AS avg_total_cost,
  (ROUND(AVG(c.total_cost- c.rub_monthly_fee)::NUMERIC, 2)) AS overcost
FROM users_costs c
LEFT JOIN telecom.users u USING (user_id)
WHERE u.churn_date IS NULL AND total_cost > rub_monthly_fee
GROUP BY c.tariff, c.rub_monthly_fee



/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Никитина Виктория
 * Дата: 03/08/2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT 
	(SELECT COUNT(*) AS total_users FROM fantasy.users), 
	COUNT(payer) AS payers, 
	COUNT(payer) / (SELECT COUNT(*) FROM fantasy.users)::float AS payers_share
FROM fantasy.users
WHERE payer = 1;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
	WITH total AS (
		SELECT 
			r.race,
			COUNT(u.race_id) OVER(PARTITION BY race) AS total_in_race
		FROM fantasy.race r
		LEFT JOIN fantasy.users u USING (race_id)
	),
	payers AS (
		SELECT 
			r.race,
			COUNT(u.race_id) OVER(PARTITION BY race) AS payers_in_race
		FROM fantasy.race r
		LEFT JOIN fantasy.users u USING (race_id)
		WHERE u.payer = 1
	)
	
	SELECT 
		t.race, 
		p.payers_in_race,
		t.total_in_race, 
		p.payers_in_race / t.total_in_race::float AS payers_share
	FROM total t
	JOIN payers p USING (race)
	GROUP BY race, total_in_race, payers_in_race 
	ORDER BY payers_share DESC; 


-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT 
	COUNT(transaction_id) AS total_count,
	SUM(amount) AS total_sum, 
	MIN(amount) AS min_amount, 
	MAX(amount) AS max_amount,
	AVG(amount) AS avg_amount, 
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median, 
	stddev(amount) AS std
FROM fantasy.events ;

-- 2.2: Аномальные нулевые покупки:
WITH extra AS (
	SELECT 
		COUNT(*) AS null_amount, 
		(SELECT count(*) FROM fantasy.events) AS total_amount
	FROM fantasy.events
	WHERE amount = 0
)
SELECT 
	null_amount, 
	null_amount / total_amount::float AS null_amount_share
FROM extra;

-- 2.3: Популярные эпические предметы:
WITH items AS (
	SELECT
		i.game_items,
		count(*) AS absolute_count,
		(SELECT count(*) FROM fantasy.events WHERE amount <> 0) AS total_count
	FROM fantasy.events e
	JOIN fantasy.items i USING (item_code)
	WHERE e.amount <> 0
	GROUP BY i.game_items 
),
users AS (
SELECT
	i.game_items,
	count(DISTINCT id) AS users_item, 
	(SELECT count(DISTINCT id) FROM fantasy.events WHERE amount <> 0) AS total_user_count
FROM fantasy.events e
JOIN fantasy.items i USING (item_code)
WHERE e.amount <> 0
GROUP BY i.game_items
)
SELECT 
	i.game_items,
	i.absolute_count, 
	i.absolute_count / i.total_count::float AS relative_count, 
	u.users_item / u.total_user_count::float AS users_item_share
FROM items i
JOIN users u USING (game_items)
ORDER BY absolute_count DESC;

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH extra AS (
    SELECT 
        e.id, 
        r.race,
       	COUNT(*) AS user_orders_count,
        SUM(amount) AS user_orders_sum, 
        AVG(amount) AS user_avgsum
    FROM fantasy.events e
    JOIN fantasy.users u USING(id)
    JOIN fantasy.race r using(race_id)
    WHERE e.amount <> 0
    GROUP BY e.id, r.race
), 
total AS (
	SELECT 
		r.race, 
        COUNT(DISTINCT e.id) AS total_customers, 
        COUNT(*) AS total_events, 
        SUM(amount) AS total_sum
    FROM fantasy.events e
    JOIN fantasy.users u USING(id)
    JOIN fantasy.race r using(race_id)
    WHERE e.amount <> 0
    GROUP BY r.race
), 
race_users AS (
	SELECT 
		r.race,
        COUNT(DISTINCT u.id) AS total_users
    FROM fantasy.users u
    JOIN fantasy.race r using(race_id)
    GROUP BY r.race
),
race_payers AS (
	SELECT 
		r.race,
        COUNT(DISTINCT u.id) AS total_payers
    FROM fantasy.users u
    JOIN fantasy.race r using(race_id)
    JOIN fantasy.events e USING (id)
    WHERE payer = 1 AND e.amount <> 0
    GROUP BY r.race
), 
users AS (
	SELECT 
		r.race,
		count(DISTINCT id) AS customer_payers
	FROM fantasy.users u
	JOIN fantasy.race r USING (race_id)
	JOIN fantasy.events e USING (id)
	WHERE u.payer = 1 AND e.amount <> 0
	GROUP BY r.race
)
SELECT 
	e.race,
	u.total_users,
	t.total_customers, 
	p.total_payers,
	t.total_customers  / u.total_users::float AS customers_share,
	us.customer_payers / t.total_customers::float AS payers_share, 
	t.total_events  / t.total_customers AS events_per_person, 
	avg(e.user_avgsum) AS avg_cost_one1,
	avg(e.user_orders_sum)/(t.total_events  / t.total_customers) AS avg_cost_one2, 
	avg(e.user_orders_sum) AS avg_cost_all
FROM extra e
JOIN total t USING (race) 
JOIN race_users u USING (race)
JOIN race_payers p USING (race)
JOIN users us using(race)
GROUP BY race, total_users, total_customers, total_payers, total_events, us.customer_payers 
ORDER BY u.total_users DESC
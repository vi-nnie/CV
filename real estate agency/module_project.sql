WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
 district_column as (
		select case when id in (select id
				from real_estate.flats f 
				left join real_estate.city c using (city_id)
				where c.city = 'Санкт-Петербург') 
			then 'Санкт-Петербург'
		else 'Ленинградская область'
		end as city_part,
		*
from real_estate.flats f
WHERE id IN (SELECT * FROM filtered_id)
),
active as (
	select case
				when days_exposition >= 1 and days_exposition <= 30
					then 'month'
				when days_exposition >= 31 and days_exposition <= 90
					then 'quarter'
				when days_exposition >= 91 and days_exposition <= 180
					then 'half year'
				when days_exposition >= 181
					then 'more than half year'
			end as seg, 
			*
	from real_estate.advertisement a 
	WHERE id IN (SELECT * FROM filtered_id)
)
select 
    d.city_part, 
    a.seg, 
    count(*) AS total_in_seg, 
    round(count(*) * 100.0 / sum(count(*)) over (partition by d.city_part), 2) as total_in_seg_per, 
    round(avg(a.last_price)::numeric, 2) AS avg_price,
    round(avg(a.last_price / d.total_area)::numeric, 2) AS avg_price_per_sqm,
    round(avg(d.total_area)::numeric, 2) AS avg_area,
    round(avg(d.rooms)::numeric, 1) AS avg_rooms,
    round(avg(case when d.balcony > 0 then 1 else 0 end) * 100, 2) AS balcony_percentage
from district_column d
left join active a using(id)
where a.seg IS NOT NULL
group by d.city_part, a.seg
order by d.city_part;



-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ), 
publication_stats as (
    select 
        extract(month from a.first_day_exposition) as publication_month,
        count(*) as publications_count,
        rank() over (order by count(*) desc) as publication_rank
    from real_estate.advertisement a
    WHERE id IN (SELECT * FROM filtered_id)
    group by extract(month from a.first_day_exposition)
),
removal_stats as (
    select 
        extract(month from a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) as removal_month,
        count(*) as removals_count,
        rank() over (order by count(*) DESC) AS removal_rank
    from real_estate.advertisement a
    where a.days_exposition IS NOT null and id IN (SELECT * FROM filtered_id)
    group by extract(month from a.first_day_exposition + INTERVAL '1 day' * a.days_exposition)
),
price_stats as (
    select 
        extract(month from a.first_day_exposition) as month,
        AVG(a.last_price / f.total_area) AS avg_price_per_sqm,
        AVG(f.total_area) AS avg_total_area,
        COUNT(*) AS transactions_count
    from real_estate.advertisement a 
    join real_estate.flats f using(id)
    WHERE id IN (SELECT * FROM filtered_id)
    group by extract(month from a.first_day_exposition)
)
select  
    ps.publication_month,
    ps.publications_count,
    ps.publication_rank,
    rs.removals_count,
    rs.removal_rank,
    round(pr.avg_price_per_sqm::numeric, 2),
    round(pr.avg_total_area::numeric, 2),
    pr.transactions_count
from publication_stats ps
left join removal_stats rs on ps.publication_month = rs.removal_month
left join price_stats pr on ps.publication_month = pr.month
order by ps.publication_month;




-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ), 
district_column as (
		select case when id in (select id
				from real_estate.flats f 
				left join real_estate.city c using (city_id)
				where c.city = 'Санкт-Петербург') 
			then 'Санкт-Петербург'
		else 'Ленинградская область'
		end as city_part,
		*
from real_estate.flats f),
task_data as (
	select *, 
		   (a.last_price) / (d.total_area) as price_per_sqm
	from district_column d
	left join real_estate.city c using(city_id)
	left join real_estate.advertisement a using (id)
	where d.city_part = 'Ленинградская область' and id IN (SELECT * FROM filtered_id)
)
select city, 
	   count(*) as cnt_amount, 
	   ROUND(COUNT(CASE WHEN days_exposition IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) as share_sold,
	   round(avg(price_per_sqm)::numeric, 2) as avg_price_per_sqm, 
	   round(avg(total_area)::numeric, 2) as avg_area, 
	   round(avg(days_exposition)::numeric, 2) as avg_days_publication
from task_data
group by city
order by cnt_amount desc
limit 10




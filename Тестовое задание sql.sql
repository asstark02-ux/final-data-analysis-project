USE test_tasks;
ALTER TABLE audience MODIFY COLUMN `date` DATE;
ALTER TABLE listers MODIFY COLUMN `date` DATE;

#1. Чему равен MAU продукта? 
SELECT COUNT(DISTINCT user_id) AS MAU 
FROM audience;


#2. Чему будет равен DAU?
SELECT ROUND(AVG(daily_active_users)) AS DAU
FROM (
    SELECT `date`, COUNT(DISTINCT user_id) AS daily_active_users
    FROM audience
    GROUP BY `date`
) AS daily_counts;


#3. Чему будет равен retention первого дня у пользователей, пришедших в продукт 1 ноября
WITH first_appear as (
    SELECT user_id, MIN(`date`) as first_date
    FROM audience
    GROUP BY user_id
),
cohort_nov1 as (
    SELECT user_id 
    FROM first_appear 
    WHERE first_date = '2023-11-01'
),
returned_day1 as (
    SELECT DISTINCT a.user_id
    FROM audience a
    JOIN cohort_nov1 c ON a.user_id = c.user_id
    WHERE a.`date` = '2023-11-02'
)
SELECT 
    (SELECT COUNT(*) FROM returned_day1) / (SELECT COUNT(*) FROM cohort_nov1) * 100 AS retention_day_1;
    

#5. Посчитайте пользовательскую конверсию в просмотр объявления за ноябрь? (в пользователях)
SELECT 
    (COUNT(DISTINCT CASE WHEN view_adverts > 0 THEN user_id END) / COUNT(DISTINCT user_id)) * 100 AS conversion_to_view
FROM audience;


#6. Посчитайте среднее количество просмотренных объявлений на пользователя в ноябре
SELECT AVG(total_user_views) AS avg_adverts_per_user
FROM (
    SELECT user_id, SUM(view_adverts) AS total_user_views
    FROM audience
    GROUP BY user_id
) AS user_sums;


#9. По датасету с листерами посчитайте средний доход на пользователя
SELECT AVG(user_income) AS avg_income_per_lister
FROM (
    SELECT user_id, SUM(revenue) AS user_income
    FROM listers
    GROUP BY user_id
) AS lister_sums;
#1. Список клиентов с непрерывной историей за год

WITH check_summary AS (
    SELECT 
        ID_client,
        Id_check,
        DATE_FORMAT(STR_TO_DATE(date_new, '%Y-%m-%d'), '%Y-%m') AS formatted_month,
        SUM(Sum_payment) AS check_amount
    FROM transactions
    WHERE STR_TO_DATE(date_new, '%Y-%m-%d') BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ID_client, Id_check, DATE_FORMAT(STR_TO_DATE(date_new, '%Y-%m-%d'), '%Y-%m')
)
SELECT 
    ID_client AS `ID Клиента`,
    ROUND(AVG(check_amount), 2) AS `Средний чек за период`,
    ROUND(SUM(check_amount) / 12, 2) AS `Средняя сумма покупок в месяц`,
    COUNT(DISTINCT Id_check) AS `Количество операций за период`
FROM check_summary
GROUP BY ID_client
HAVING COUNT(DISTINCT formatted_month) = 12;



#2. Метрики в разрезе месяцев (а, b, c, d, e)

WITH 
cheks AS (
    SELECT 
        DATE_FORMAT(STR_TO_DATE(date_new, '%Y-%m-%d'), '%Y-%m') AS month_id,
        Id_check,
        ID_client,
        SUM(Sum_payment) AS check_sum
    FROM transactions
    WHERE STR_TO_DATE(date_new, '%Y-%m-%d') BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY month_id, Id_check, ID_client
),
year_totals AS (
    SELECT 
        COUNT(DISTINCT Id_check) AS total_year_ops,
        SUM(check_sum) AS total_year_sum
    FROM cheks
),
monthly_metrics AS (
    SELECT 
        c.month_id,
        AVG(c.check_sum) AS avg_check_amount,                    
        COUNT(DISTINCT c.Id_check) AS monthly_ops_count,         
        COUNT(DISTINCT c.ID_client) AS monthly_active_clients,
        SUM(c.check_sum) AS monthly_total_sum
    FROM cheks c
    GROUP BY c.month_id
),
gender_metrics AS (
    SELECT 
        DATE_FORMAT(STR_TO_DATE(t.date_new, '%Y-%m-%d'), '%Y-%m') AS month_id,
        IFNULL(NULLIF(cust.Gender, ''), 'NA') AS gender_group,
        COUNT(DISTINCT t.Id_check) AS gender_ops_count,
        SUM(t.Sum_payment) AS gender_spending
    FROM transactions t
    LEFT JOIN customers cust ON t.ID_client = cust.Id_client
    WHERE STR_TO_DATE(t.date_new, '%Y-%m-%d') BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY month_id, gender_group
),
monthly_totals AS (
    SELECT 
        month_id,
        SUM(gender_ops_count) AS total_ops_in_month,
        SUM(gender_spending) AS total_spending_in_month
    FROM gender_metrics
    GROUP BY month_id
)
SELECT 
    mm.month_id AS `Месяц`,
    ROUND(mm.avg_check_amount, 2) AS `a) Ср. чек, руб`,
    mm.monthly_ops_count AS `b) Число операций (всего)`,
    mm.monthly_active_clients AS `c) Активных клиентов`,
    
    ROUND((mm.monthly_ops_count / MAX(yt.total_year_ops)) * 100, 2) AS `d) Доля операций от года, %`,
    ROUND((mm.monthly_total_sum / MAX(yt.total_year_sum)) * 100, 2) AS `d) Доля суммы от года, %`,
    
    ROUND(SUM(CASE WHEN gm.gender_group = 'M' THEN gm.gender_ops_count ELSE 0 END) / MAX(mt.total_ops_in_month) * 100, 2) AS `e) Доля операций M, %`,
    ROUND(SUM(CASE WHEN gm.gender_group = 'M' THEN gm.gender_spending ELSE 0 END) / MAX(mt.total_spending_in_month) * 100, 2) AS `e) Доля затрат M, %`,
    
    ROUND(SUM(CASE WHEN gm.gender_group = 'F' THEN gm.gender_ops_count ELSE 0 END) / MAX(mt.total_ops_in_month) * 100, 2) AS `e) Доля операций F, %`,
    ROUND(SUM(CASE WHEN gm.gender_group = 'F' THEN gm.gender_spending ELSE 0 END) / MAX(mt.total_spending_in_month) * 100, 2) AS `e) Доля затрат F, %`,
    
    ROUND(SUM(CASE WHEN gm.gender_group = 'NA' THEN gm.gender_ops_count ELSE 0 END) / MAX(mt.total_ops_in_month) * 100, 2) AS `e) Доля операций NA, %`,
    ROUND(SUM(CASE WHEN gm.gender_group = 'NA' THEN gm.gender_spending ELSE 0 END) / MAX(mt.total_spending_in_month) * 100, 2) AS `e) Доля затрат NA, %`
FROM monthly_metrics mm
CROSS JOIN year_totals yt
JOIN monthly_totals mt ON mm.month_id = mt.month_id
JOIN gender_metrics gm ON mm.month_id = gm.month_id
GROUP BY mm.month_id, mm.avg_check_amount, mm.monthly_ops_count, mm.monthly_active_clients, mm.monthly_total_sum
ORDER BY mm.month_id;



#3. Возрастные группы клиентов и поквартальный анализ

WITH raw_data AS (
    SELECT 
        t.Id_check,
        t.Sum_payment,
        DATE_FORMAT(STR_TO_DATE(t.date_new, '%Y-%m-%d'), '%Y-Q%q') AS year_quarter,
        CASE 
            WHEN cust.Age IS NULL THEN 'Данные отсутствуют'
            WHEN cust.Age BETWEEN 0 AND 19 THEN '0-19 лет'
            WHEN cust.Age BETWEEN 20 AND 29 THEN '20-29 лет'
            WHEN cust.Age BETWEEN 30 AND 39 THEN '30-39 лет'
            WHEN cust.Age BETWEEN 40 AND 49 THEN '40-49 лет'
            WHEN cust.Age BETWEEN 50 AND 59 THEN '50-59 лет'
            WHEN cust.Age BETWEEN 60 AND 69 THEN '60-69 лет'
            ELSE '70+ лет'
        END AS age_group
    FROM transactions t
    LEFT JOIN customers cust ON t.ID_client = cust.Id_client
    WHERE STR_TO_DATE(t.date_new, '%Y-%m-%d') BETWEEN '2015-06-01' AND '2016-06-01'
),
checks_aggregated AS (
    SELECT 
        age_group,
        year_quarter,
        Id_check,
        SUM(Sum_payment) AS check_sum
    FROM raw_data
    GROUP BY age_group, year_quarter, Id_check
),
age_group_totals AS (
    SELECT 
        age_group,
        SUM(check_sum) AS total_sum_period,
        COUNT(DISTINCT Id_check) AS total_ops_period
    FROM checks_aggregated
    GROUP BY age_group
),
quarterly_totals AS (
    SELECT 
        year_quarter,
        SUM(check_sum) AS q_total_sum,
        COUNT(DISTINCT Id_check) AS q_total_ops
    FROM checks_aggregated
    GROUP BY year_quarter
),
quarterly_by_age AS (
    SELECT 
        ca.age_group,
        ca.year_quarter,
        SUM(ca.check_sum) AS q_age_sum,
        COUNT(DISTINCT ca.Id_check) AS q_age_ops
    FROM checks_aggregated ca
    GROUP BY ca.age_group, ca.year_quarter
)
SELECT 
    qba.age_group AS `Возрастная группа`,
    qba.year_quarter AS `Квартал`,
    
    MAX(agt.total_sum_period) AS `Сумма за весь период`,
    MAX(agt.total_ops_period) AS `Операций за весь период`,
    
    ROUND(MAX(qba.q_age_sum), 2) AS `Ср. сумма за квартал`,
    ROUND(MAX(qba.q_age_ops), 2) AS `Ср. кол-во операций за квартал`,
    
    ROUND((MAX(qba.q_age_sum) / MAX(qt.q_total_sum)) * 100, 2) AS `% от суммы квартала`,
    ROUND((MAX(qba.q_age_ops) / MAX(qt.q_total_ops)) * 100, 2) AS `% от операций квартала`
FROM quarterly_by_age qba
JOIN age_group_totals agt ON qba.age_group = agt.age_group
JOIN quarterly_totals qt ON qba.year_quarter = qt.year_quarter
GROUP BY qba.age_group, qba.year_quarter
ORDER BY qba.age_group, qba.year_quarter;

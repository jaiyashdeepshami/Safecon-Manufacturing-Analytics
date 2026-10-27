-- 02_analysis_queries.sql
-- Safecon Manufacturing Analytics (synthetic data)
-- Run after 01_setup_and_import.sql. Quantity and quality KPIs use Qty_Valid = 1;
-- on-time % and delay use Date_Valid = 1; downtime queries use no filter.

-- ===== Query 1: Plant Wise Produced Quantity =====
SELECT Plant, SUM(Produced_Quantity) AS Total_Produced FROM fact_production
where Qty_Valid = 1
GROUP BY Plant;

-- ===== Query 2: Plant Wise Rejection, Rework, Wastage % =====
SELECT
    Plant,
    SUM(Rejected_Quantity) AS Total_Rejected,
    ROUND(SUM(Rejected_Quantity) / SUM(Produced_Quantity) * 100, 2) AS Rejection_Rate_Pct,
    ROUND(SUM(Rework_Quantity)   / SUM(Produced_Quantity) * 100, 2) AS Rework_Rate_Pct,
    ROUND(SUM(Wastage_Quantity)  / SUM(Produced_Quantity) * 100, 2) AS Wastage_Pct
FROM fact_production
WHERE Qty_Valid = 1
GROUP BY Plant;

-- ===== Query 3: Plant Wise Production Achievement % =====
SELECT
    Plant,
    ROUND(SUM(Produced_Quantity) / SUM(Planned_Quantity) * 100, 2) AS Achievement_pct
FROM fact_production
WHERE Qty_Valid = 1
group by Plant;

-- ===== Query 4: Product Category wise Total produced, Rejected Rate, Batch Failure =====
SELECT
    d.Product_Category,
    SUM(f.Produced_Quantity) AS Total_Produced,
    ROUND(SUM(f.Rejected_Quantity) / SUM(f.Produced_Quantity) * 100, 2) AS Rejection_Rate_Pct,
    ROUND(SUM(f.Batch_Failure_Flag) / COUNT(*) * 100, 2) AS Batch_Failure_Rate_Pct
FROM fact_production f
JOIN dim_product d
    ON f.Product_ID = d.Product_ID
WHERE f.Qty_Valid = 1
GROUP BY d.Product_Category
ORDER BY Rejection_Rate_Pct DESC;

-- ===== Query 5: Highest Rejection Rate Products (Minimum 100 Batches) =====
SELECT
	d.Product_Name,
    d.Product_Category,
    ROUND(SUM(f.Rejected_Quantity) / SUM(f.Produced_Quantity) * 100, 2) AS Rejection_Rate_Pct,
    count(*) AS Total_Btaches
FROM fact_production f
JOIN dim_product d
    ON f.Product_ID = d.Product_ID
WHERE f.Qty_Valid = 1
GROUP BY d.Product_id, d.Product_Name, d.Product_Category
HAVING COUNT(*) >= 100
ORDER BY Rejection_Rate_Pct DESC
LIMIT 10;

-- ===== Query 6: Machine-Wise Downtime =====
SELECT
    m.Machine_ID,
    m.Machine_Name,
    m.Plant,
    m.Machine_Type,
    COUNT(*) AS Total_Batches,
    ROUND(SUM(f.Downtime_Hours), 2) AS Total_Downtime_Hrs,
    ROUND(AVG(f.Downtime_Hours), 2) AS Avg_Downtime_Per_Batch
FROM fact_production f
JOIN dim_machine m
    ON f.Machine_ID = m.Machine_ID
GROUP BY m.Machine_ID, m.Machine_Name, m.Plant, m.Machine_Type
ORDER BY Total_Downtime_Hrs DESC
LIMIT 10;

-- ===== Query 7: Downtime Reason Analysis =====
SELECT
    Downtime_Reason,
    COUNT(*) AS Batches,
    ROUND(SUM(Downtime_Hours), 2) AS Total_Downtime_Hrs,
    ROUND(SUM(Downtime_Hours) / (SELECT SUM(Downtime_Hours) FROM fact_production) * 100, 2) AS Share_Pct
FROM fact_production
GROUP BY Downtime_Reason
ORDER BY Total_Downtime_Hrs DESC;

-- ===== Query 8: Monthly Production and Quality Trend =====
SELECT
    dd.`Year`,
    dd.Month_No,
    dd.Month_Name,
    SUM(f.Produced_Quantity) AS Total_Produced,
    ROUND(SUM(f.Rejected_Quantity) / SUM(f.Produced_Quantity) * 100, 2) AS Rejection_Rate_Pct,
    ROUND(SUM(f.Batch_Failure_Flag) / COUNT(*) * 100, 2) AS Batch_Failure_Rate_Pct
FROM fact_production f
JOIN dim_date dd
    ON f.Production_Date = dd.`Date`
WHERE f.Qty_Valid = 1
GROUP BY dd.`Year`, dd.Month_No, dd.Month_Name
ORDER BY dd.`Year`, dd.Month_No;

-- ===== Query 9: MoM Growth % =====
WITH monthly AS (
    SELECT
        dd.`Year` AS Yr,
        dd.Month_No AS Mn,
        dd.Month_Year AS Month_Label,
        SUM(f.Produced_Quantity) AS Total_Produced
    FROM fact_production f
    JOIN dim_date dd
        ON f.Production_Date = dd.`Date`
    WHERE f.Qty_Valid = 1
    GROUP BY dd.`Year`, dd.Month_No, dd.Month_Year
)
SELECT
    Month_Label,
    Total_Produced,
    LAG(Total_Produced) OVER (ORDER BY Yr, Mn) AS Prev_Month_Produced,
    ROUND((Total_Produced - LAG(Total_Produced) OVER (ORDER BY Yr, Mn))
          / LAG(Total_Produced) OVER (ORDER BY Yr, Mn) * 100, 2) AS MoM_Growth_Pct
FROM monthly
ORDER BY Yr, Mn;

-- ===== Query 10: Humidity Band Vs Quality =====
SELECT
    CASE
        WHEN Ambient_Humidity_Percent IS NULL THEN 'Unknown'
        WHEN Ambient_Humidity_Percent <= 70 THEN '1. Low (<=70)'
        WHEN Ambient_Humidity_Percent <= 80 THEN '2. Medium (70-80)'
        ELSE '3. High (>80)'
    END AS Humidity_Band,
    COUNT(*) AS Batches,
    ROUND(SUM(Rejected_Quantity) / SUM(Produced_Quantity) * 100, 2) AS Rejection_Rate_Pct,
    ROUND(SUM(Rework_Quantity)   / SUM(Produced_Quantity) * 100, 2) AS Rework_Rate_Pct,
    ROUND(SUM(Wastage_Quantity)  / SUM(Produced_Quantity) * 100, 2) AS Wastage_Pct,
    ROUND(SUM(Batch_Failure_Flag) / COUNT(*) * 100, 2) AS Batch_Failure_Rate_Pct
FROM fact_production
WHERE Qty_Valid = 1
GROUP BY Humidity_Band
ORDER BY Humidity_Band;

-- ===== Query 11: Downtime Band Vs Achievement And Quality =====
SELECT
    CASE
        WHEN Downtime_Hours IS NULL THEN 'Unknown'
        WHEN Downtime_Hours = 0 THEN '1. None (0)'
        WHEN Downtime_Hours <= 2 THEN '2. Low (0-2)'
        WHEN Downtime_Hours <= 5 THEN '3. Medium (2-5)'
        ELSE '4. High (>5)'
    END AS Downtime_Band,
    COUNT(*) AS Batches,
    ROUND(SUM(Produced_Quantity) / SUM(Planned_Quantity) * 100, 2) AS Achievement_Pct,
    ROUND(SUM(Rejected_Quantity) / SUM(Produced_Quantity) * 100, 2) AS Rejection_Rate_Pct,
    ROUND(SUM(Batch_Failure_Flag) / COUNT(*) * 100, 2) AS Batch_Failure_Rate_Pct
FROM fact_production
WHERE Qty_Valid = 1
GROUP BY Downtime_Band
ORDER BY Downtime_Band;

-- ===== Query 12: Machine Downtime Ranking within Each Plant =====
SELECT
    m.Plant,
    m.Machine_ID,
    m.Machine_Name,
    ROUND(SUM(f.Downtime_Hours), 2) AS Total_Downtime_Hrs,
    RANK() OVER (PARTITION BY m.Plant ORDER BY SUM(f.Downtime_Hours) DESC) AS Downtime_Rank_In_Plant
FROM fact_production f
JOIN dim_machine m
    ON f.Machine_ID = m.Machine_ID
GROUP BY m.Plant, m.Machine_ID, m.Machine_Name
ORDER BY m.Plant, Downtime_Rank_In_Plant;

-- ===== Query 13: Plant Scorecard (Production, Quality, Downtime and Delivery KPIs) =====
WITH prod_kpi AS (
    SELECT
        Plant,
        COUNT(*) AS Batches,
        SUM(Produced_Quantity) AS Total_Produced,
        ROUND(SUM(Produced_Quantity) / SUM(Planned_Quantity) * 100, 2) AS Achievement_Pct,
        ROUND(SUM(Rejected_Quantity) / SUM(Produced_Quantity) * 100, 2) AS Rejection_Rate_Pct,
        ROUND(SUM(Rework_Quantity)   / SUM(Produced_Quantity) * 100, 2) AS Rework_Rate_Pct,
        ROUND(SUM(Wastage_Quantity)  / SUM(Produced_Quantity) * 100, 2) AS Wastage_Pct,
        ROUND(SUM(Batch_Failure_Flag) / COUNT(*) * 100, 2) AS Batch_Failure_Rate_Pct
    FROM fact_production
    WHERE Qty_Valid = 1
    GROUP BY Plant
),
down_kpi AS (
    SELECT
        Plant,
        ROUND(SUM(Downtime_Hours), 2) AS Total_Downtime_Hrs,
        ROUND(AVG(Downtime_Hours), 2) AS Avg_Downtime_Per_Batch
    FROM fact_production
    GROUP BY Plant
),
ord_kpi AS (
    SELECT
        Plant,
        COUNT(*) AS Total_Orders,
        ROUND(AVG(CASE WHEN Date_Valid = 1 THEN On_Time_Flag END) * 100, 2) AS On_Time_Pct,
        ROUND(AVG(Delay_Days_Clean), 2) AS Avg_Delay_Days,
        ROUND(SUM(CASE WHEN Qty_Valid = 1 THEN Shipped_Quantity END)
              / SUM(CASE WHEN Qty_Valid = 1 THEN Ordered_Quantity END) * 100, 2) AS Fulfillment_Pct
    FROM fact_orders
    GROUP BY Plant
)
SELECT
    p.Plant, p.Batches, p.Total_Produced, p.Achievement_Pct,
    p.Rejection_Rate_Pct, p.Rework_Rate_Pct, p.Wastage_Pct, p.Batch_Failure_Rate_Pct,
    d.Total_Downtime_Hrs, d.Avg_Downtime_Per_Batch,
    o.Total_Orders, o.On_Time_Pct, o.Avg_Delay_Days, o.Fulfillment_Pct
FROM prod_kpi p
JOIN down_kpi d ON p.Plant = d.Plant
JOIN ord_kpi  o ON p.Plant = o.Plant;

-- ===== Query 14: Client-wise Delivery Performance (Fulfillment, On-Time % and Delay) =====
SELECT
    c.Client_Name,
    c.Client_Type,
    c.Priority_Level,
    COUNT(*) AS Total_Orders,
    ROUND(SUM(CASE WHEN o.Qty_Valid = 1 THEN o.Shipped_Quantity END)
          / SUM(CASE WHEN o.Qty_Valid = 1 THEN o.Ordered_Quantity END) * 100, 2) AS Fulfillment_Pct,
    ROUND(AVG(CASE WHEN o.Date_Valid = 1 THEN o.On_Time_Flag END) * 100, 2) AS On_Time_Pct,
    ROUND(AVG(o.Delay_Days_Clean), 2) AS Avg_Delay_Days
FROM fact_orders o
JOIN dim_client c
    ON o.Client_ID = c.Client_ID
GROUP BY c.Client_ID, c.Client_Name, c.Client_Type, c.Priority_Level
ORDER BY On_Time_Pct ASC;

-- ===== Query 15: Order-level average downtime vs delivery =====
-- Production rows are summed up per order first (avoids double counting), then joined to orders.
WITH order_prod AS (
  SELECT Order_ID, COUNT(*) AS Batches, AVG(Downtime_Hours) AS Avg_Downtime_Per_Batch
  FROM fact_production GROUP BY Order_ID)
SELECT CASE WHEN p.Order_ID IS NULL THEN '0. No production rows'
            WHEN p.Avg_Downtime_Per_Batch IS NULL THEN 'Unknown'
            WHEN p.Avg_Downtime_Per_Batch = 0 THEN '1. None (0)'
            WHEN p.Avg_Downtime_Per_Batch <= 2 THEN '2. Low (0-2)'
            WHEN p.Avg_Downtime_Per_Batch <= 5 THEN '3. Medium (2-5)'
            ELSE '4. High (>5)' END AS Order_Downtime_Band,
       COUNT(*) AS Orders,
       ROUND(AVG(CASE WHEN o.Date_Valid = 1 THEN o.On_Time_Flag END) * 100, 2) AS On_Time_Pct,
       ROUND(AVG(o.Delay_Days_Clean), 2) AS Avg_Delay_Days
FROM fact_orders o LEFT JOIN order_prod p ON o.Order_ID = p.Order_ID
GROUP BY Order_Downtime_Band ORDER BY Order_Downtime_Band;

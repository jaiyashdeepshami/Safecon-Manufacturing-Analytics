-- 01_setup_and_import.sql
-- Safecon Manufacturing Analytics (synthetic data)
-- Replace <path> with your own folder (forward slashes only), e.g. C:/projects/safecon
-- Needs local_infile enabled (see STEP 2). Run top to bottom.

-- ========== PART 1: Production and dimension tables ==========
-- STEP 1: Database
CREATE DATABASE IF NOT EXISTS safecon_ops;
USE safecon_ops;
-- STEP 2: Permission for LOAD DATA (once per server)
-- Also needed: in Workbench, Connection - Advanced - Others, add OPT_LOCAL_INFILE=1 on a new line, then restart Workbench
SET GLOBAL local_infile = 1;
SHOW VARIABLES LIKE 'local_infile';   -- expected: ON
-- STEP 3: Final fact table
CREATE TABLE fact_production (
    Production_ID            VARCHAR(12) PRIMARY KEY,
    Batch_ID                 VARCHAR(25),
    Order_ID                 VARCHAR(20),
    Production_Date          DATE,
    Plant                    VARCHAR(20),
    Department               VARCHAR(30),
    Product_ID               VARCHAR(10),
    Client_ID                VARCHAR(10),
    Machine_ID               VARCHAR(15),
    Shift                    VARCHAR(10),
    Operator_Count           INT,
    Planned_Quantity         INT,
    Produced_Quantity        INT,
    Accepted_Quantity        INT,
    Rejected_Quantity        INT,
    Rework_Quantity          INT,
    Wastage_Quantity         INT,
    Production_Start_Time    DATETIME,
    Production_End_Time      DATETIME,
    Production_Cycle_Hours   DECIMAL(6,2),
    Downtime_Hours           DECIMAL(6,2),
    Downtime_Reason          VARCHAR(40),
    Ambient_Humidity_Percent DECIMAL(5,1),
    Temperature_C            DECIMAL(5,1),
    Quality_Status           VARCHAR(20),
    Batch_Failure_Flag       TINYINT,
    Qty_Valid                TINYINT
);
-- STEP 4: Staging table (all text, so the load can never fail on data types)
DROP TABLE IF EXISTS stg_fact_production;
CREATE TABLE stg_fact_production (
    Production_ID VARCHAR(50), Batch_ID VARCHAR(50), Order_ID VARCHAR(50),
    Production_Date VARCHAR(50), Plant VARCHAR(50), Department VARCHAR(50),
    Product_ID VARCHAR(50), Client_ID VARCHAR(50), Machine_ID VARCHAR(50),
    Shift VARCHAR(50), Operator_Count VARCHAR(50), Planned_Quantity VARCHAR(50),
    Produced_Quantity VARCHAR(50), Accepted_Quantity VARCHAR(50),
    Rejected_Quantity VARCHAR(50), Rework_Quantity VARCHAR(50),
    Wastage_Quantity VARCHAR(50), Production_Start_Time VARCHAR(50),
    Production_End_Time VARCHAR(50), Production_Cycle_Hours VARCHAR(50),
    Downtime_Hours VARCHAR(50), Downtime_Reason VARCHAR(50),
    Ambient_Humidity_Percent VARCHAR(50), Temperature_C VARCHAR(50),
    Quality_Status VARCHAR(50), Batch_Failure_Flag VARCHAR(50), Qty_Valid VARCHAR(50)
);
-- STEP 5: Load the CSV into staging
LOAD DATA LOCAL INFILE '<path>/fact_production_final.csv'
INTO TABLE stg_fact_production
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
-- STEP 6: Inspect staging BEFORE moving data
SELECT COUNT(*) FROM stg_fact_production;       -- expected 60,973
SELECT * FROM stg_fact_production LIMIT 3;      -- check columns line up
-- STEP 7: Move to the final table (blank text becomes NULL)
INSERT INTO fact_production
 (Production_ID, Batch_ID, Order_ID, Production_Date, Plant, Department, Product_ID,
  Client_ID, Machine_ID, Shift, Operator_Count, Planned_Quantity, Produced_Quantity,
  Accepted_Quantity, Rejected_Quantity, Rework_Quantity, Wastage_Quantity,
  Production_Start_Time, Production_End_Time, Production_Cycle_Hours, Downtime_Hours,
  Downtime_Reason, Ambient_Humidity_Percent, Temperature_C, Quality_Status,
  Batch_Failure_Flag, Qty_Valid)
SELECT
  Production_ID, Batch_ID, Order_ID, Production_Date, Plant, Department, Product_ID,
  Client_ID, NULLIF(Machine_ID,''), NULLIF(Shift,''), NULLIF(Operator_Count,''),
  Planned_Quantity, Produced_Quantity, Accepted_Quantity, NULLIF(Rejected_Quantity,''),
  Rework_Quantity, Wastage_Quantity, Production_Start_Time, NULLIF(Production_End_Time,''),
  Production_Cycle_Hours, NULLIF(Downtime_Hours,''), Downtime_Reason,
  NULLIF(Ambient_Humidity_Percent,''), NULLIF(Temperature_C,''), Quality_Status,
  Batch_Failure_Flag, Qty_Valid
FROM stg_fact_production;
-- STEP 8: Verification
SELECT COUNT(*) FROM fact_production;
SELECT COUNT(*) - COUNT(Ambient_Humidity_Percent) AS humidity_null FROM fact_production;
SELECT MIN(Production_Date), MAX(Production_Date) FROM fact_production;
SELECT DISTINCT Plant FROM fact_production;
SELECT Quality_Status, COUNT(*) FROM fact_production GROUP BY Quality_Status;
-- STEP 9: Dimension tables
CREATE TABLE dim_client (
  Client_ID VARCHAR(10) PRIMARY KEY, Client_Name VARCHAR(60), Client_Type VARCHAR(30),
  Region VARCHAR(40), Priority_Level VARCHAR(10));
LOAD DATA LOCAL INFILE '<path>/Dim_Client.csv'
INTO TABLE dim_client
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
SELECT COUNT(*) FROM dim_client;
SELECT * FROM dim_client LIMIT 5;
SELECT DISTINCT Priority_Level, LENGTH(Priority_Level) FROM dim_client;
CREATE TABLE dim_product (
  Product_ID VARCHAR(10) PRIMARY KEY, Product_Name VARCHAR(80), Product_Category VARCHAR(30),
  Dosage_Form VARCHAR(30), Standard_Batch_Size INT);
LOAD DATA LOCAL INFILE '<path>/Dim_Product.csv'
INTO TABLE dim_product
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
SELECT COUNT(*) FROM dim_product;
SELECT * FROM dim_product LIMIT 5;
CREATE TABLE dim_machine (
  Machine_ID VARCHAR(15) PRIMARY KEY, Machine_Name VARCHAR(60), Plant VARCHAR(20),
  Machine_Type VARCHAR(50), Installation_Year INT);
LOAD DATA LOCAL INFILE '<path>/Dim_Machine.csv'
INTO TABLE dim_machine
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
SELECT COUNT(*) FROM dim_machine;
SELECT * FROM dim_machine LIMIT 5;
CREATE TABLE dim_date (
  `Date` DATE PRIMARY KEY, `Year` INT, Quarter VARCHAR(5), Month_No INT, Month_Name VARCHAR(10),
  Month_Year VARCHAR(10), Week_No INT, Day_Name VARCHAR(12), Is_Weekend TINYINT,
  Fiscal_Year VARCHAR(10), Season VARCHAR(20));
LOAD DATA LOCAL INFILE "<path>/Dim_Date.csv"
INTO TABLE dim_date
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
SELECT COUNT(*) FROM dim_date;
SELECT * FROM dim_date LIMIT 5;

-- ========== PART 2: Fact_Orders import, profiling, cleaning and flags ==========

-- ----- Importing Fact_Order.Csv File -----
USE safecon_ops;
CREATE TABLE stg_fact_orders (
    Order_ID            VARCHAR(50),
    Order_Date          VARCHAR(50),
    Client_ID           VARCHAR(50),
    Client_Name         VARCHAR(50),
    Plant               VARCHAR(50),
    Product_ID          VARCHAR(50),
    Product_Category    VARCHAR(50),
    Ordered_Quantity    VARCHAR(50),
    Produced_Quantity   VARCHAR(50),
    Shipped_Quantity    VARCHAR(50),
    Promised_Ship_Date  VARCHAR(50),
    Actual_Ship_Date    VARCHAR(50),
    Shipment_Status     VARCHAR(50),
    Delay_Days          VARCHAR(50),
    On_Time_Flag        VARCHAR(50)
);
LOAD DATA LOCAL INFILE "<path>/Fact_Orders_raw.csv"
INTO TABLE stg_fact_orders
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
SELECT COUNT(*) FROM stg_fact_orders;      -- expected 15,045
SELECT * FROM stg_fact_orders LIMIT 5;

-- ----- Fact_Orders Data Profiling (Before Cleaning) -----
USE safecon_ops;
-- A) Duplicate orders
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT Order_ID) AS unique_orders
FROM stg_fact_orders;
-- B) Values of Plant, Shipment_Status, On_Time_Flag
SELECT 'Plant' AS col, Plant AS value, COUNT(*) AS cnt
FROM stg_fact_orders GROUP BY Plant
UNION ALL
SELECT 'Shipment_Status', Shipment_Status, COUNT(*)
FROM stg_fact_orders GROUP BY Shipment_Status
UNION ALL
SELECT 'On_Time_Flag', On_Time_Flag, COUNT(*)
FROM stg_fact_orders GROUP BY On_Time_Flag;
-- C) Order_Date formats
SELECT
    SUM(Order_Date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')     AS iso_yyyy_mm_dd,
    SUM(Order_Date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$')     AS dd_mm_yyyy,
    SUM(Order_Date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$')  AS dd_mon_yyyy,
    COUNT(*) AS total
FROM stg_fact_orders;
-- D) Extra Spaces in Client_Name
SELECT COUNT(*) AS names_with_extra_spaces
FROM stg_fact_orders
WHERE Client_Name <> TRIM(Client_Name);
-- E) Formats And Blanks of Promised And Actual Ship Date
SELECT 'Promised_Ship_Date' AS col,
       SUM(Promised_Ship_Date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')    AS iso,
       SUM(Promised_Ship_Date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$')    AS dd_mm_yyyy,
       SUM(Promised_Ship_Date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$') AS dd_mon_yyyy,
       SUM(Promised_Ship_Date = '' OR Promised_Ship_Date IS NULL)       AS blank,
       COUNT(*) AS total
FROM stg_fact_orders
UNION ALL
SELECT 'Actual_Ship_Date',
       SUM(Actual_Ship_Date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'),
       SUM(Actual_Ship_Date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'),
       SUM(Actual_Ship_Date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'),
       SUM(Actual_Ship_Date = '' OR Actual_Ship_Date IS NULL),
       COUNT(*)
FROM stg_fact_orders;
-- F) Shipment_Status aur On_Time_Flag
SELECT TRIM(Shipment_Status) AS status, On_Time_Flag, COUNT(*) AS cnt
FROM stg_fact_orders
GROUP BY TRIM(Shipment_Status), On_Time_Flag
ORDER BY status, On_Time_Flag;
-- G) Proof of DD/MM/YYYY is day/month  ( not month/day )
SELECT
    SUM(CAST(SUBSTRING(Order_Date,1,2) AS UNSIGNED) > 12) AS first_part_gt_12,
    SUM(CAST(SUBSTRING(Order_Date,4,2) AS UNSIGNED) > 12) AS second_part_gt_12
FROM stg_fact_orders
WHERE Order_Date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$';

-- ----- Fact_Orders Cleaning and Load -----
USE safecon_ops;
CREATE TABLE fact_orders (
    Order_ID           VARCHAR(20) PRIMARY KEY,
    Order_Date         DATE,
    Client_ID          VARCHAR(10),
    Plant              VARCHAR(20),
    Product_ID         VARCHAR(10),
    Ordered_Quantity   INT,
    Produced_Quantity  INT,
    Shipped_Quantity   INT,
    Promised_Ship_Date DATE,
    Actual_Ship_Date   DATE,
    Shipment_Status    VARCHAR(20),
    Delay_Days         INT,
    On_Time_Flag       TINYINT
);
INSERT INTO fact_orders
    (Order_ID, Order_Date, Client_ID, Plant, Product_ID, Ordered_Quantity, Produced_Quantity,
     Shipped_Quantity, Promised_Ship_Date, Actual_Ship_Date, Shipment_Status, Delay_Days, On_Time_Flag)
SELECT Order_ID, Order_Date, Client_ID, Plant, Product_ID, Ordered_Quantity, Produced_Quantity,
       Shipped_Quantity, Promised_Ship_Date, Actual_Ship_Date, Shipment_Status, Delay_Days, On_Time_Flag
FROM (
    SELECT
        UPPER(TRIM(Order_ID)) AS Order_ID,
        CASE
            WHEN Order_Date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'    THEN STR_TO_DATE(Order_Date, '%Y-%m-%d')
            WHEN Order_Date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'    THEN STR_TO_DATE(Order_Date, '%d/%m/%Y')
            WHEN Order_Date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$' THEN STR_TO_DATE(Order_Date, '%d-%b-%Y')
        END AS Order_Date,
        UPPER(TRIM(Client_ID)) AS Client_ID,
        CASE
            WHEN UPPER(LEFT(TRIM(Plant), 1)) = 'A' THEN 'Agra'
            WHEN UPPER(LEFT(TRIM(Plant), 1)) = 'R' THEN 'Rudrapur'
            ELSE 'CHECK'
        END AS Plant,
        UPPER(TRIM(Product_ID)) AS Product_ID,
        NULLIF(TRIM(Ordered_Quantity), '')  AS Ordered_Quantity,
        NULLIF(TRIM(Produced_Quantity), '') AS Produced_Quantity,
        NULLIF(TRIM(Shipped_Quantity), '')  AS Shipped_Quantity,
        CASE
            WHEN Promised_Ship_Date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'    THEN STR_TO_DATE(Promised_Ship_Date, '%Y-%m-%d')
            WHEN Promised_Ship_Date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'    THEN STR_TO_DATE(Promised_Ship_Date, '%d/%m/%Y')
            WHEN Promised_Ship_Date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$' THEN STR_TO_DATE(Promised_Ship_Date, '%d-%b-%Y')
        END AS Promised_Ship_Date,
        CASE
            WHEN Actual_Ship_Date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'    THEN STR_TO_DATE(Actual_Ship_Date, '%Y-%m-%d')
            WHEN Actual_Ship_Date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'    THEN STR_TO_DATE(Actual_Ship_Date, '%d/%m/%Y')
            WHEN Actual_Ship_Date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$' THEN STR_TO_DATE(Actual_Ship_Date, '%d-%b-%Y')
        END AS Actual_Ship_Date,
        CASE
            WHEN LOWER(TRIM(Shipment_Status)) LIKE 'on%'   THEN 'On Time'
            WHEN LOWER(TRIM(Shipment_Status)) LIKE 'del%'  THEN 'Delayed'
            WHEN LOWER(TRIM(Shipment_Status)) LIKE 'part%' THEN 'Partially Shipped'
            ELSE 'CHECK'
        END AS Shipment_Status,
        NULLIF(TRIM(Delay_Days), '') AS Delay_Days,
        CASE
            WHEN TRIM(On_Time_Flag) IN ('1', 'Y') THEN 1
            WHEN TRIM(On_Time_Flag) IN ('0', 'N') THEN 0
        END AS On_Time_Flag,
        ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(Order_ID)) ORDER BY Order_ID) AS rn
    FROM stg_fact_orders
) t
WHERE rn = 1;
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT Order_ID) AS unique_orders FROM fact_orders;
SELECT Plant, COUNT(*) AS cnt FROM fact_orders GROUP BY Plant;
SELECT Shipment_Status, On_Time_Flag, COUNT(*) AS cnt
FROM fact_orders GROUP BY Shipment_Status, On_Time_Flag ORDER BY Shipment_Status, On_Time_Flag;
SELECT MIN(Order_Date) AS min_order, MAX(Order_Date) AS max_order,
       SUM(Order_Date IS NULL)         AS order_date_null,
       SUM(Promised_Ship_Date IS NULL) AS promised_null,
       SUM(Actual_Ship_Date IS NULL)   AS actual_null
FROM fact_orders;
--Delay date vs Actual date difference
SELECT
    SUM(Promised_Ship_Date IS NOT NULL AND Actual_Ship_Date IS NOT NULL
        AND Delay_Days = GREATEST(DATEDIFF(Actual_Ship_Date, Promised_Ship_Date), 0)) AS delay_consistent,
    SUM(Promised_Ship_Date IS NOT NULL AND Actual_Ship_Date IS NOT NULL
        AND Delay_Days <> GREATEST(DATEDIFF(Actual_Ship_Date, Promised_Ship_Date), 0)) AS delay_inconsistent,
    SUM(Delay_Days IS NULL) AS delay_days_null,
    SUM(Promised_Ship_Date IS NULL OR Actual_Ship_Date IS NULL) AS cannot_check_dates_missing,
    SUM(Actual_Ship_Date < Order_Date) AS ship_before_order,
    SUM(Shipped_Quantity > Ordered_Quantity) AS shipped_gt_ordered
FROM fact_orders;
--On time flag vs Delay days
SELECT On_Time_Flag,
       CASE WHEN Delay_Days IS NULL THEN 'Delay_Days NULL'
            WHEN Delay_Days > 0 THEN 'Late (>0)'
            ELSE 'Not late (0)' END AS delay_group,
       COUNT(*) AS cnt
FROM fact_orders
GROUP BY On_Time_Flag, delay_group
ORDER BY On_Time_Flag, delay_group;
--Delay_Days vs Date Difference Check
SELECT Order_ID, Promised_Ship_Date, Actual_Ship_Date, Delay_Days,
       DATEDIFF(Actual_Ship_Date, Promised_Ship_Date) AS date_diff,
       On_Time_Flag, Shipment_Status
FROM fact_orders
WHERE Promised_Ship_Date IS NOT NULL AND Actual_Ship_Date IS NOT NULL
  AND Delay_Days <> GREATEST(DATEDIFF(Actual_Ship_Date, Promised_Ship_Date), 0)
LIMIT 10;
--Ship Date Before Order Date Check
SELECT Order_ID, Order_Date, Promised_Ship_Date, Actual_Ship_Date, Delay_Days
FROM fact_orders
WHERE Actual_Ship_Date < Order_Date;
--Shipped > Ordered Check
SELECT Order_ID, Ordered_Quantity, Shipped_Quantity,
       Shipped_Quantity - Ordered_Quantity AS excess, Shipment_Status
FROM fact_orders
WHERE Shipped_Quantity > Ordered_Quantity;

-- ----- Fact_Orders Data Quality Fixes (Flags and Delay_Days Recalculation) -----
USE safecon_ops;
SET SQL_SAFE_UPDATES = 0;
ALTER TABLE fact_orders
    ADD COLUMN Delay_Days_Clean INT,
    ADD COLUMN Date_Valid TINYINT,
    ADD COLUMN Qty_Valid TINYINT;
UPDATE fact_orders
SET Date_Valid = CASE
        WHEN Promised_Ship_Date IS NULL OR Actual_Ship_Date IS NULL THEN 0
        WHEN Actual_Ship_Date < Order_Date THEN 0
        ELSE 1 END,
    Qty_Valid = CASE
        WHEN Ordered_Quantity IS NULL OR Shipped_Quantity IS NULL THEN 0
        WHEN Shipped_Quantity > Ordered_Quantity THEN 0
        ELSE 1 END;
UPDATE fact_orders
SET Delay_Days_Clean = CASE
        WHEN Date_Valid = 1
        THEN GREATEST(DATEDIFF(Actual_Ship_Date, Promised_Ship_Date), 0)
        ELSE NULL END;
SET SQL_SAFE_UPDATES = 1;

-- ----- Fact_Orders Data Quality Fixes: Validation -----
--V1: Flag Counts
SELECT SUM(Date_Valid = 0) AS date_invalid, SUM(Qty_Valid = 0) AS qty_invalid, COUNT(*) AS total
FROM fact_orders;
--V2: Delay_Days_Clean Range
SELECT MIN(Delay_Days_Clean) AS min_delay, MAX(Delay_Days_Clean) AS max_delay,
       SUM(Delay_Days_Clean IS NULL) AS delay_null
FROM fact_orders;
--V3: On_Time_Flag vs Date-based Delay
-- 3) Kya On_Time_Flag asli dates se match karta hai?
SELECT On_Time_Flag,
       CASE WHEN Delay_Days_Clean > 0 THEN 'Late by dates' ELSE 'Not late by dates' END AS date_group,
       COUNT(*) AS cnt
FROM fact_orders
WHERE Date_Valid = 1
GROUP BY On_Time_Flag, date_group
ORDER BY On_Time_Flag, date_group;

# Data Dictionary

All data is synthetic (simulated) and created for a portfolio project. Column types are those used in the MySQL tables in `sql/01_setup_and_import.sql`.

## fact_production (one row = one batch on one machine, 60,973 rows)

| Column | Type | Meaning |
|---|---|---|
| Production_ID | VARCHAR(12), primary key | Unique row ID |
| Batch_ID | VARCHAR(25) | Batch identifier |
| Order_ID | VARCHAR(20) | Order this batch belongs to (about 4 batches per order) |
| Production_Date | DATE | Date of production |
| Plant | VARCHAR(20) | Agra or Rudrapur |
| Department | VARCHAR(30) | Manufacturing department |
| Product_ID | VARCHAR(10) | Links to dim_product |
| Client_ID | VARCHAR(10) | Links to dim_client |
| Machine_ID | VARCHAR(15) | Links to dim_machine (blank for some rows) |
| Shift | VARCHAR(10) | Shift of the batch |
| Operator_Count | INT | Number of operators |
| Planned_Quantity | INT | Planned units |
| Produced_Quantity | INT | Units produced |
| Accepted_Quantity | INT | Units accepted (Produced - Rejected - Rework) |
| Rejected_Quantity | INT | Units rejected |
| Rework_Quantity | INT | Units sent for rework |
| Wastage_Quantity | INT | Material lost, counted separately |
| Production_Start_Time | DATETIME | Batch start |
| Production_End_Time | DATETIME | Batch end |
| Production_Cycle_Hours | DECIMAL(6,2) | Hours taken for the batch |
| Downtime_Hours | DECIMAL(6,2) | Hours of machine downtime |
| Downtime_Reason | VARCHAR(40) | Reason for the downtime |
| Ambient_Humidity_Percent | DECIMAL(5,1) | Factory humidity (impossible values were blanked) |
| Temperature_C | DECIMAL(5,1) | Factory temperature |
| Quality_Status | VARCHAR(20) | Passed, Failed or Rework Required |
| Batch_Failure_Flag | TINYINT | 1 if the batch failed |
| Qty_Valid | TINYINT | 1 if quantities add up, 0 if flagged as inconsistent |

## fact_orders (one row = one B2B order, 15,000 rows after cleaning)

| Column | Type | Meaning |
|---|---|---|
| Order_ID | VARCHAR(20), primary key | Unique order ID |
| Order_Date | DATE | Date the order was placed |
| Client_ID | VARCHAR(10) | Links to dim_client |
| Plant | VARCHAR(20) | Agra or Rudrapur |
| Product_ID | VARCHAR(10) | Links to dim_product |
| Ordered_Quantity | INT | Units ordered |
| Produced_Quantity | INT | Units produced |
| Shipped_Quantity | INT | Units shipped |
| Promised_Ship_Date | DATE | Promised shipping date |
| Actual_Ship_Date | DATE | Actual shipping date |
| Shipment_Status | VARCHAR(20) | On Time, Delayed or Partially Shipped |
| Delay_Days | INT | Raw delay column. Found unreliable, not used |
| On_Time_Flag | TINYINT | 1 if shipped on time |
| Delay_Days_Clean | INT | Delay in days recalculated from the dates |
| Date_Valid | TINYINT | 1 if the dates are usable |
| Qty_Valid | TINYINT | 1 if the quantities are usable |

## Dimension tables

| Table | Columns |
|---|---|
| dim_client (28 rows) | Client_ID, Client_Name, Client_Type, Region, Priority_Level |
| dim_product (60 rows) | Product_ID, Product_Name, Product_Category, Dosage_Form, Standard_Batch_Size |
| dim_machine (40 rows) | Machine_ID, Machine_Name, Plant, Machine_Type, Installation_Year |
| dim_date (1,096 rows) | Date, Year, Quarter, Month_No, Month_Name, Month_Year, Week_No, Day_Name, Is_Weekend, Fiscal_Year (April to March), Season |

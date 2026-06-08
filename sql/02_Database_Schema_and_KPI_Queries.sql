-- SKU Master
CREATE TABLE sku_master (
    sku_code            VARCHAR(10) PRIMARY KEY,
    sku_name            VARCHAR(100),
    category            VARCHAR(50),
    brand               VARCHAR(50),
    unit                VARCHAR(10),
    selling_price       NUMERIC(10,2),
    cost_price          NUMERIC(10,2),
    monthly_target_units INT,
    gross_margin_pct    NUMERIC(5,1),
    annual_target_units  INT
);

-- Region & Depot Master
CREATE TABLE region_depot (
    region                  VARCHAR(50) PRIMARY KEY,
    depot                   VARCHAR(100),
    no_of_customers         INT,
    distance_from_nagpur_km INT
);

-- Sales Rep Master
CREATE TABLE sales_rep (
    rep_id              VARCHAR(10) PRIMARY KEY,
    rep_name            VARCHAR(100),
    region              VARCHAR(50),
    monthly_target_inr  NUMERIC(12,2),
    annual_target_inr   NUMERIC(12,2)
);

-- Customer Master
CREATE TABLE customer_master (
    customer_id         VARCHAR(10) PRIMARY KEY,
    customer_name       VARCHAR(100),
    region              VARCHAR(50),
    credit_limit_inr    NUMERIC(10,2),
    payment_terms_days  INT,
    customer_type       VARCHAR(30),
    assigned_rep        VARCHAR(10)
);

-- Sales Transactions
CREATE TABLE sales_transactions (
    invoice_no      VARCHAR(15),
    invoice_date    DATE,
    month           INT,
    quarter         VARCHAR(5),
    sku_code        VARCHAR(10),
    sku_name        VARCHAR(100),
    category        VARCHAR(50),
    brand           VARCHAR(50),
    customer_id     VARCHAR(10),
    customer_name   VARCHAR(100),
    region          VARCHAR(50),
    depot           VARCHAR(100),
    rep_id          VARCHAR(10),
    qty_sold        INT,
    unit_price      NUMERIC(10,2),
    discount_pct    NUMERIC(5,1),
    gross_sales     NUMERIC(12,2),
    net_sales       NUMERIC(12,2),
    cogs            NUMERIC(12,2),
    gross_profit    NUMERIC(12,2)
);

-- Monthly Targets
CREATE TABLE monthly_targets (
    month               INT,
    month_name          VARCHAR(10),
    sku_code            VARCHAR(10),
    sku_name            VARCHAR(100),
    category            VARCHAR(50),
    brand               VARCHAR(50),
    target_units        INT,
    target_value_inr    NUMERIC(12,2)
);

-- Inventory Transactions
CREATE TABLE inventory_txns (
    txn_id          VARCHAR(15),
    txn_date        DATE,
    month           INT,
    depot           VARCHAR(100),
    sku_code        VARCHAR(10),
    sku_name        VARCHAR(100),
    category        VARCHAR(50),
    txn_type        VARCHAR(10),   -- GRN / ISSUE / DAMAGE
    qty             INT,
    unit_cost       NUMERIC(10,2),
    total_cost      NUMERIC(12,2)
);

-- Dispatch Logistics
CREATE TABLE dispatch_logistics (
    dispatch_id             VARCHAR(15),
    dispatch_date           DATE,
    month                   INT,
    depot                   VARCHAR(100),
    vehicle_no              VARCHAR(20),
    driver_name             VARCHAR(100),
    region_served           VARCHAR(50),
    planned_km              INT,
    actual_km               INT,
    fuel_cost_inr           NUMERIC(10,2),
    toll_charges_inr        NUMERIC(10,2),
    loading_charges_inr     NUMERIC(10,2),
    planned_delivery_hrs    INT,
    actual_delivery_hrs     INT,
    delay_hours             INT,
    no_of_drops             INT,
    successful_drops        INT,
    delivery_success_pct    NUMERIC(5,1),
    status                  VARCHAR(15)
);

-- Cost Budget vs Actual
CREATE TABLE cost_budget_actual (
    month           INT,
    month_name      VARCHAR(15),
    cost_category   VARCHAR(50),
    budget_inr      NUMERIC(12,2),
    actual_inr      NUMERIC(12,2),
    variance_inr    NUMERIC(12,2),
    variance_pct    NUMERIC(6,1),
    flag            VARCHAR(20)
);

-- Monthly KPI Summary
CREATE TABLE monthly_kpi (
    month                   INT,
    month_name              VARCHAR(15),
    net_sales_inr           NUMERIC(15,2),
    gross_profit_inr        NUMERIC(15,2),
    gp_margin_pct           NUMERIC(5,1),
    sales_target_inr        NUMERIC(15,2),
    target_achievement_pct  NUMERIC(5,1),
    total_opex_inr          NUMERIC(12,2),
    opex_budget_inr         NUMERIC(12,2),
    opex_variance_pct       NUMERIC(6,1),
    grn_units               INT,
    issue_units             INT,
    damage_units            INT,
    dispatch_trips          INT,
    on_time_deliveries      INT,
    otd_pct                 NUMERIC(5,1),
    invoices_raised         INT,
    active_customers        INT,
    active_skus             INT
);

-- Row counts across all tables
SELECT 'sales_transactions' AS tbl, COUNT(*) FROM sales_transactions
UNION ALL SELECT 'inventory_txns',  COUNT(*) FROM inventory_txns
UNION ALL SELECT 'dispatch_logistics', COUNT(*) FROM dispatch_logistics
UNION ALL SELECT 'monthly_targets',    COUNT(*) FROM monthly_targets
UNION ALL SELECT 'cost_budget_actual', COUNT(*) FROM cost_budget_actual;

-- Check for NULLs in critical columns
SELECT COUNT(*) AS null_invoices
FROM sales_transactions
WHERE invoice_no IS NULL OR sku_code IS NULL OR net_sales IS NULL;

-- Check date range
SELECT MIN(invoice_date), MAX(invoice_date) FROM sales_transactions;

-- Verify all SKUs in transactions exist in master
SELECT DISTINCT sku_code FROM sales_transactions
WHERE sku_code NOT IN (SELECT sku_code FROM sku_master);

-- Check negative quantities (data issue)
SELECT * FROM sales_transactions WHERE qty_sold <= 0;
SELECT * FROM inventory_txns    WHERE qty <= 0;

--Sales Performance KPIs
--Monthly Sales vs Target (with achievement %)
SELECT
    st.month,
    TO_CHAR(DATE_TRUNC('month', MIN(st.invoice_date)), 'Mon-YYYY') AS month_name,
    ROUND(SUM(st.net_sales), 0)                         AS actual_sales,
    ROUND(SUM(mt.target_value_inr), 0)                  AS target_sales,
    ROUND(SUM(st.net_sales) / NULLIF(SUM(mt.target_value_inr), 0) * 100, 1) AS achievement_pct,
    ROUND(SUM(st.gross_profit), 0)                      AS gross_profit,
    ROUND(SUM(st.gross_profit) / NULLIF(SUM(st.net_sales), 0) * 100, 1)     AS gp_margin_pct,
    -- Exception flag
    CASE
        WHEN SUM(st.net_sales) / NULLIF(SUM(mt.target_value_inr), 0) < 0.80 THEN '🔴 Below 80%'
        WHEN SUM(st.net_sales) / NULLIF(SUM(mt.target_value_inr), 0) < 0.95 THEN '🟡 Below 95%'
        ELSE '🟢 On Track'
    END AS flag
FROM sales_transactions st
JOIN monthly_targets mt USING (month, sku_code)
GROUP BY st.month
ORDER BY st.month;

--MTD and YTD Sales (run this any day)
-- Change '2024-11-20' to today's date
WITH today AS (SELECT '2024-11-20'::DATE AS d),
     curr_month AS (SELECT EXTRACT(MONTH FROM d)::INT AS m, EXTRACT(DAY FROM d)::INT AS day_no FROM today)

SELECT
    -- MTD
    ROUND(SUM(CASE WHEN EXTRACT(MONTH FROM invoice_date) = (SELECT m FROM curr_month)
              THEN net_sales ELSE 0 END), 0) AS mtd_sales,
    -- YTD
    ROUND(SUM(CASE WHEN invoice_date <= (SELECT d FROM today)
              THEN net_sales ELSE 0 END), 0) AS ytd_sales,
    -- Previous month same period (pro-rated)
    ROUND(SUM(CASE WHEN EXTRACT(MONTH FROM invoice_date) = (SELECT m FROM curr_month) - 1
                    AND EXTRACT(DAY FROM invoice_date) <= (SELECT day_no FROM curr_month)
              THEN net_sales ELSE 0 END), 0) AS prev_month_same_period
FROM sales_transactions;


--Sales Rep Performance Dashboard
SELECT
    st.rep_id,
    sr.rep_name,
    sr.region,
    ROUND(SUM(st.net_sales), 0)                             AS actual_sales_inr,
    sr.annual_target_inr                                    AS annual_target_inr,
    ROUND(SUM(st.net_sales) / sr.annual_target_inr * 100, 1) AS ytd_achievement_pct,
    COUNT(DISTINCT st.invoice_no)                           AS invoices_raised,
    COUNT(DISTINCT st.customer_id)                          AS unique_customers,
    ROUND(AVG(st.net_sales), 0)                             AS avg_invoice_value,
    ROUND(SUM(st.gross_profit) / NULLIF(SUM(st.net_sales),0) * 100, 1) AS gp_margin_pct,
    RANK() OVER (ORDER BY SUM(st.net_sales) DESC)           AS sales_rank
FROM sales_transactions st
JOIN sales_rep sr ON st.rep_id = sr.rep_id
GROUP BY st.rep_id, sr.rep_name, sr.region, sr.annual_target_inr
ORDER BY actual_sales_inr DESC;

--Top 10 SKUs by Revenue
SELECT
    st.sku_code,
    st.sku_name,
    st.category,
    st.brand,
    ROUND(SUM(st.net_sales), 0)     AS total_revenue,
    SUM(st.qty_sold)                AS total_units,
    ROUND(SUM(st.gross_profit), 0)  AS total_gross_profit,
    ROUND(SUM(st.gross_profit) / NULLIF(SUM(st.net_sales),0) * 100, 1) AS gp_pct,
    ROUND(SUM(st.net_sales) * 100.0 / SUM(SUM(st.net_sales)) OVER (), 1) AS revenue_share_pct,
    RANK() OVER (ORDER BY SUM(st.net_sales) DESC) AS rank
FROM sales_transactions st
GROUP BY st.sku_code, st.sku_name, st.category, st.brand
ORDER BY total_revenue DESC
LIMIT 10;


-- Region-wise Sales Heatmap
SELECT
    region,
    ROUND(SUM(CASE WHEN month=1  THEN net_sales ELSE 0 END),0) AS jan,
    ROUND(SUM(CASE WHEN month=2  THEN net_sales ELSE 0 END),0) AS feb,
    ROUND(SUM(CASE WHEN month=3  THEN net_sales ELSE 0 END),0) AS mar,
    ROUND(SUM(CASE WHEN month=4  THEN net_sales ELSE 0 END),0) AS apr,
    ROUND(SUM(CASE WHEN month=5  THEN net_sales ELSE 0 END),0) AS may,
    ROUND(SUM(CASE WHEN month=6  THEN net_sales ELSE 0 END),0) AS jun,
    ROUND(SUM(CASE WHEN month=7  THEN net_sales ELSE 0 END),0) AS jul,
    ROUND(SUM(CASE WHEN month=8  THEN net_sales ELSE 0 END),0) AS aug,
    ROUND(SUM(CASE WHEN month=9  THEN net_sales ELSE 0 END),0) AS sep,
    ROUND(SUM(CASE WHEN month=10 THEN net_sales ELSE 0 END),0) AS oct,
    ROUND(SUM(CASE WHEN month=11 THEN net_sales ELSE 0 END),0) AS nov,
    ROUND(SUM(CASE WHEN month=12 THEN net_sales ELSE 0 END),0) AS dec,
    ROUND(SUM(net_sales), 0) AS full_year_total
FROM sales_transactions
GROUP BY region
ORDER BY full_year_total DESC;


--Monthly Stock Summary per SKU
SELECT
    month,
    sku_code,
    sku_name,
    category,
    SUM(CASE WHEN txn_type = 'GRN'    THEN qty ELSE 0 END) AS grn_units,
    SUM(CASE WHEN txn_type = 'ISSUE'  THEN qty ELSE 0 END) AS issued_units,
    SUM(CASE WHEN txn_type = 'DAMAGE' THEN qty ELSE 0 END) AS damage_units,
    SUM(CASE WHEN txn_type = 'GRN'    THEN qty ELSE 0 END)
  - SUM(CASE WHEN txn_type IN ('ISSUE','DAMAGE') THEN qty ELSE 0 END) AS net_movement,
    ROUND(SUM(CASE WHEN txn_type = 'DAMAGE' THEN qty ELSE 0 END) * 100.0
          / NULLIF(SUM(CASE WHEN txn_type = 'GRN' THEN qty ELSE 0 END), 0), 2) AS damage_pct
FROM inventory_txns
GROUP BY month, sku_code, sku_name, category
ORDER BY month, sku_code;


--Closing Stock & Days of Inventory (DOI)
WITH monthly_issue AS (
    SELECT sku_code, month,
           SUM(CASE WHEN txn_type = 'ISSUE' THEN qty ELSE 0 END) AS issued
    FROM inventory_txns GROUP BY sku_code, month
),
running_stock AS (
    SELECT
        it.sku_code,
        sk.sku_name,
        sk.category,
        it.month,
        SUM(CASE WHEN it.txn_type = 'GRN'    THEN it.qty ELSE 0 END)
      - SUM(CASE WHEN it.txn_type IN ('ISSUE','DAMAGE') THEN it.qty ELSE 0 END) AS closing_stock,
        mi.issued AS monthly_issues
    FROM inventory_txns it
    JOIN sku_master sk USING (sku_code)
    JOIN monthly_issue mi ON it.sku_code = mi.sku_code AND it.month = mi.month
    GROUP BY it.sku_code, sk.sku_name, sk.category, it.month, mi.issued
)
SELECT
    month,
    sku_code,
    sku_name,
    category,
    closing_stock,
    monthly_issues,
    -- DOI = (closing stock / avg daily issues); assume 30 days
    ROUND(closing_stock / NULLIF(monthly_issues / 30.0, 0), 1) AS days_of_inventory,
    CASE
        WHEN closing_stock / NULLIF(monthly_issues / 30.0, 0) < 7  THEN '🔴 Critical - Reorder Now'
        WHEN closing_stock / NULLIF(monthly_issues / 30.0, 0) < 15 THEN '🟡 Low Stock'
        WHEN closing_stock / NULLIF(monthly_issues / 30.0, 0) > 60 THEN '⚠️ Excess Stock'
        ELSE '🟢 Healthy'
    END AS stock_status
FROM running_stock
ORDER BY month, days_of_inventory;


--Slow-Moving SKU Identification
-- SKUs with issues < 60% of GRN in any month = slow moving
SELECT
    sku_code,
    sku_name,
    category,
    month,
    grn_qty,
    issued_qty,
    ROUND(issued_qty * 100.0 / NULLIF(grn_qty, 0), 1) AS movement_rate_pct,
    damage_qty,
    ROUND(damage_qty * 100.0 / NULLIF(grn_qty, 0), 2) AS damage_rate_pct
FROM (
    SELECT
        sku_code, sku_name, category, month,
        SUM(CASE WHEN txn_type='GRN'    THEN qty ELSE 0 END) AS grn_qty,
        SUM(CASE WHEN txn_type='ISSUE'  THEN qty ELSE 0 END) AS issued_qty,
        SUM(CASE WHEN txn_type='DAMAGE' THEN qty ELSE 0 END) AS damage_qty
    FROM inventory_txns
    GROUP BY sku_code, sku_name, category, month
) t
WHERE issued_qty < grn_qty * 0.60
ORDER BY movement_rate_pct;


--Inventory Turnover Ratio (Annual)
SELECT
    sk.sku_code,
    sk.sku_name,
    sk.category,
    ROUND(SUM(it.total_cost) FILTER (WHERE it.txn_type = 'ISSUE'), 0) AS annual_cogs,
    ROUND(AVG(
        CASE WHEN it.txn_type = 'GRN' THEN it.qty * sk.cost_price END
    ), 0) AS avg_inventory_value,
    ROUND(
        SUM(it.total_cost) FILTER (WHERE it.txn_type = 'ISSUE')
        / NULLIF(AVG(CASE WHEN it.txn_type = 'GRN' THEN it.qty * sk.cost_price END), 0)
    , 2) AS inventory_turnover_ratio,
    ROUND(365.0 /
        NULLIF(
            SUM(it.total_cost) FILTER (WHERE it.txn_type = 'ISSUE')
            / NULLIF(AVG(CASE WHEN it.txn_type = 'GRN' THEN it.qty * sk.cost_price END), 0)
        , 0)
    , 0) AS days_sales_in_inventory
FROM inventory_txns it
JOIN sku_master sk USING (sku_code)
GROUP BY sk.sku_code, sk.sku_name, sk.category
ORDER BY inventory_turnover_ratio DESC;


--Dispatch & Logistics KPIs
--Monthly Dispatch Efficiency Summary
SELECT
    month,
    depot,
    COUNT(*)                                              AS total_trips,
    SUM(CASE WHEN status = 'On-Time' THEN 1 ELSE 0 END)  AS on_time_trips,
    ROUND(SUM(CASE WHEN status='On-Time' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS otd_pct,
    SUM(no_of_drops)                                      AS total_drops,
    SUM(successful_drops)                                 AS successful_drops,
    ROUND(SUM(successful_drops) * 100.0 / NULLIF(SUM(no_of_drops),0), 1) AS delivery_success_pct,
    ROUND(SUM(fuel_cost_inr + toll_charges_inr + loading_charges_inr), 0) AS total_logistics_cost,
    ROUND(AVG(actual_km), 0)                              AS avg_km_per_trip,
    ROUND(SUM(fuel_cost_inr + toll_charges_inr + loading_charges_inr)
          / NULLIF(SUM(successful_drops),0), 0)           AS cost_per_delivery
FROM dispatch_logistics
GROUP BY month, depot
ORDER BY month, depot;

 --Vehicle Utilisation & Cost Analysis
 SELECT
    vehicle_no,
    COUNT(*)                                                AS total_trips,
    SUM(actual_km)                                          AS total_km_driven,
    ROUND(SUM(fuel_cost_inr), 0)                           AS total_fuel_cost,
    ROUND(SUM(fuel_cost_inr) / NULLIF(SUM(actual_km),0), 2) AS fuel_cost_per_km,
    SUM(CASE WHEN status='Delayed' THEN 1 ELSE 0 END)      AS delayed_trips,
    ROUND(AVG(delay_hours),1)                               AS avg_delay_hrs,
    ROUND(SUM(toll_charges_inr + loading_charges_inr), 0)  AS other_costs
FROM dispatch_logistics
GROUP BY vehicle_no
ORDER BY total_km_driven DESC;

--Delayed Delivery Root Cause Summary
SELECT
    depot,
    region_served,
    COUNT(*) FILTER (WHERE status = 'Delayed')              AS delayed_trips,
    COUNT(*)                                                AS total_trips,
    ROUND(COUNT(*) FILTER (WHERE status='Delayed') * 100.0 / COUNT(*), 1) AS delay_rate_pct,
    ROUND(AVG(delay_hours) FILTER (WHERE status='Delayed'), 1) AS avg_delay_hrs,
    MAX(delay_hours)                                        AS max_delay_hrs
FROM dispatch_logistics
GROUP BY depot, region_served
HAVING COUNT(*) FILTER (WHERE status = 'Delayed') > 0
ORDER BY delay_rate_pct DESC;

--Cost Variance Report
--Monthly Budget vs Actual by Cost Head
SELECT
    month,
    month_name,
    cost_category,
    ROUND(budget_inr, 0)          AS budget,
    ROUND(actual_inr, 0)          AS actual,
    ROUND(variance_inr, 0)        AS variance,
    variance_pct,
    flag,
    -- Running YTD variance
    ROUND(SUM(variance_inr) OVER (
        PARTITION BY cost_category ORDER BY month
    ), 0) AS ytd_cumulative_variance
FROM cost_budget_actual
ORDER BY month, cost_category;

--Worst Over-Budget Categories (Full Year)
SELECT
    cost_category,
    ROUND(SUM(budget_inr), 0)    AS annual_budget,
    ROUND(SUM(actual_inr), 0)    AS annual_actual,
    ROUND(SUM(variance_inr), 0)  AS annual_variance,
    ROUND(SUM(variance_inr) * 100.0 / NULLIF(SUM(budget_inr),0), 1) AS annual_variance_pct,
    COUNT(*) FILTER (WHERE flag = 'Over Budget')  AS months_over_budget,
    COUNT(*) FILTER (WHERE flag = 'Under Budget') AS months_under_budget
FROM cost_budget_actual
GROUP BY cost_category
ORDER BY annual_variance DESC;

--Cost as % of Sales (OpEx Ratio)
SELECT
    c.month,
    c.month_name,
    ROUND(SUM(c.actual_inr), 0)         AS total_opex,
    k.net_sales_inr,
    ROUND(SUM(c.actual_inr) * 100.0 / NULLIF(k.net_sales_inr, 0), 1) AS opex_to_sales_pct,
    ROUND(k.gross_profit_inr, 0)         AS gross_profit,
    ROUND((k.gross_profit_inr - SUM(c.actual_inr)), 0) AS net_operating_profit
FROM cost_budget_actual c
JOIN monthly_kpi k USING (month)
GROUP BY c.month, c.month_name, k.net_sales_inr, k.gross_profit_inr
ORDER BY c.month;

--Views for Power BI / Reporting
-- View 1: Sales Dashboard Feed
CREATE VIEW vw_sales_dashboard AS
SELECT
    st.invoice_no,
    st.invoice_date,
    st.month,
    st.quarter,
    st.sku_code,
    st.sku_name,
    st.category,
    st.brand,
    st.customer_id,
    st.customer_name,
    st.region,
    st.depot,
    st.rep_id,
    st.qty_sold,
    st.unit_price,
    st.discount_pct,
    st.gross_sales,
    st.net_sales,
    st.cogs,
    st.gross_profit,
    -- from joins
    sr.rep_name,
    sm.gross_margin_pct,
    mt.target_units,
    mt.target_value_inr,
    ROUND(st.net_sales / NULLIF(mt.target_value_inr, 0) * 100, 1) AS sku_achievement_pct
FROM sales_transactions st
LEFT JOIN sales_rep sr       ON st.rep_id  = sr.rep_id
LEFT JOIN sku_master sm      ON st.sku_code = sm.sku_code
LEFT JOIN monthly_targets mt ON st.sku_code = mt.sku_code AND st.month = mt.month;

-- View 2: Inventory Status Feed
CREATE VIEW vw_inventory_status AS
SELECT
    month,
    depot,
    sku_code,
    sku_name,
    category,
    SUM(CASE WHEN txn_type='GRN'    THEN qty ELSE 0 END) AS grn_qty,
    SUM(CASE WHEN txn_type='ISSUE'  THEN qty ELSE 0 END) AS issued_qty,
    SUM(CASE WHEN txn_type='DAMAGE' THEN qty ELSE 0 END) AS damage_qty,
    SUM(CASE WHEN txn_type='GRN' THEN qty ELSE 0 END)
  - SUM(CASE WHEN txn_type IN ('ISSUE','DAMAGE') THEN qty ELSE 0 END) AS closing_stock
FROM inventory_txns
GROUP BY month, depot, sku_code, sku_name, category;

-- View 3: Logistics KPI Feed
CREATE VIEW vw_logistics_kpi AS
SELECT
    month,
    depot,
    COUNT(*)                                                    AS trips,
    ROUND(AVG(delivery_success_pct), 1)                        AS avg_delivery_success_pct,
    ROUND(SUM(fuel_cost_inr + toll_charges_inr + loading_charges_inr), 0) AS total_cost,
    ROUND(SUM(CASE WHEN status='On-Time' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS otd_pct
FROM dispatch_logistics
GROUP BY month, depot;

--Automated Weekly Report Query
SELECT
    k.month,
    k.month_name,
    k.net_sales_inr,
    k.sales_target_inr,
    k.target_achievement_pct,
    k.gp_margin_pct,
    k.total_opex_inr,
    k.opex_variance_pct,
    k.otd_pct,
    k.damage_units,
    k.active_customers,
    -- Exception alerts
    CASE WHEN k.target_achievement_pct < 80 THEN 'ALERT: Sales below 80% of target' ELSE NULL END AS sales_alert,
    CASE WHEN k.otd_pct < 85               THEN 'ALERT: OTD below 85%'             ELSE NULL END AS delivery_alert,
    CASE WHEN k.opex_variance_pct > 10     THEN 'ALERT: OpEx over budget by 10%+'  ELSE NULL END AS cost_alert
FROM monthly_kpi k
ORDER BY k.month;


-- 1. All tables row count (confirm data is intact)
SELECT 'sales_transactions'  AS table_name, COUNT(*) AS rows FROM sales_transactions
UNION ALL SELECT 'inventory_txns',           COUNT(*) FROM inventory_txns
UNION ALL SELECT 'dispatch_logistics',       COUNT(*) FROM dispatch_logistics
UNION ALL SELECT 'monthly_targets',          COUNT(*) FROM monthly_targets
UNION ALL SELECT 'cost_budget_actual',       COUNT(*) FROM cost_budget_actual
UNION ALL SELECT 'monthly_kpi',             COUNT(*) FROM monthly_kpi
UNION ALL SELECT 'sku_master',              COUNT(*) FROM sku_master
UNION ALL SELECT 'customer_master',         COUNT(*) FROM customer_master
UNION ALL SELECT 'sales_rep',               COUNT(*) FROM sales_rep
UNION ALL SELECT 'region_depot',            COUNT(*) FROM region_depot;

-- 2. Quick sales summary by month
SELECT month, month_name, net_sales_inr, target_achievement_pct, gp_margin_pct, otd_pct
FROM monthly_kpi
ORDER BY month;

-- 3. Check all views are working
SELECT COUNT(*) FROM vw_sales_dashboard;
SELECT COUNT(*) FROM vw_inventory_status;
SELECT COUNT(*) FROM vw_logistics_kpi;

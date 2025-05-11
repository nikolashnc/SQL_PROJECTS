-- SQL ANALYSIS REPORT

-- ===============================
-- 1. CHANGES OVER TIME
-- ===============================
-- Purpose: This section tracks how key metrics (such as total sales, number of customers, and quantity sold) 
-- evolve over time. It helps identify trends, patterns, and seasonal variations by analyzing data 
-- across different time intervals, including yearly, monthly, and a combination of both.
-- -------------------------------

-- 1.1 Total sales, customers, and quantity grouped by year
SELECT 
    CONCAT('$',' ',SUM(sales_amount)) AS 'Total Sales',
    YEAR(order_date) AS Year,
    COUNT(DISTINCT(customer_key)) AS 'Total Customers',
    SUM(quantity) AS 'Total Quantity'
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date) DESC;

-- 1.2 Total sales, customers, and quantity grouped by month 
SELECT 
    CONCAT('$',' ',SUM(sales_amount)) AS 'Total Sales',
    MONTH(order_date) AS Month,
    COUNT(DISTINCT(customer_key)) AS 'Total Customers',
    SUM(quantity) AS 'Total Quantity'
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY MONTH(order_date)
ORDER BY MONTH(order_date);

-- 1.3 Monthly breakdown including year (year/month granularity)
SELECT 
    CONCAT('$',' ',SUM(sales_amount)) AS 'Total Sales',
    DATETRUNC(MONTH, order_date) AS 'Year/Month',
    COUNT(DISTINCT(customer_key)) AS 'Total Customers',
    SUM(quantity) AS 'Total Quantity'
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY DATETRUNC(MONTH, order_date) DESC;


-- ===============================
-- 2. CUMULATIVE ANALYSIS
-- ===============================
-- Purpose: This section calculates cumulative metrics, such as running totals and moving averages, 
-- to monitor how key values accumulate over time. It aids in evaluating long-term growth and identifying 
-- performance trends.
-- -------------------------------

-- 2.1 Running total of sales by year
SELECT 
    order_year,
    Total_Sales,
    SUM(Total_Sales) OVER (ORDER BY order_year) AS Running_total
FROM (
    SELECT 
        YEAR(order_date) AS order_year,
        SUM(sales_amount) AS Total_Sales
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY YEAR(order_date)
) AS SUBQUERY;


-- ===============================
-- 3. PERFORMANCE ANALYSIS
-- ===============================
-- Purpose: Analyzes sales performance by comparing current sales to previous years and benchmarks. 
-- Helps identify changes and trends to support data-driven business decisions.
-- -------------------------------

WITH Yearly_product_sales AS (
    SELECT 
        YEAR(order_date) AS Current_Year,
        Product_name,
        SUM(sales_amount) AS Current_Sales
    FROM gold.fact_sales
    JOIN gold.dim_products 
        ON gold.fact_sales.product_key = gold.dim_products.product_key
    WHERE order_date IS NOT NULL
    GROUP BY YEAR(order_date), product_name
)
SELECT 
    Current_Year,
    Product_name,
    Current_Sales,
    LAG(Current_Sales, 1) OVER (PARTITION BY Product_name ORDER BY Current_Year) AS Previous_Year_Sales
FROM Yearly_product_sales
ORDER BY Product_name, Current_Year;

-- ===============================
-- 4. CATEGORY CONTRIBUTION TO SALES
-- ===============================
-- Purpose: Determines the relative contribution of each product category to the total sales. 
-- Useful for analyzing which categories are most profitable or have the highest sales volume.
-- -------------------------------

WITH CTE AS (
    SELECT 
        category,
        SUM(sales_amount) AS Sales
    FROM gold.fact_sales
    JOIN gold.dim_products 
        ON gold.fact_sales.product_key = gold.dim_products.product_key
    WHERE order_date IS NOT NULL
    GROUP BY category
)
SELECT 
    category,
    Sales,
    CONCAT(ROUND((CAST(Sales AS FLOAT) / SUM(Sales) OVER ()) * 100, 2), '%') AS Percentage_of_Total
FROM CTE;

-- (Continued in the file)


-- ===============================
-- 5. PRODUCT COST SEGMENTATION
-- ===============================
-- Purpose: Segments products based on their cost to analyze distribution across price ranges. 
-- This helps in understanding pricing strategies and inventory management.
-- -------------------------------

WITH product_segment AS (
    SELECT 
        product_name,
        cost,
        CASE 
            WHEN cost < 100 THEN 'Below 100'
            WHEN cost BETWEEN 100 AND 500 THEN '100-500'
            WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
            ELSE 'Above 1000'
        END AS cost_range
    FROM gold.dim_products
)
SELECT 
    cost_range,
    COUNT(product_name) AS total_products
FROM product_segment
GROUP BY cost_range
ORDER BY total_products DESC;


-- ===============================
-- 6. CUSTOMER SEGMENTATION
-- ===============================
-- Purpose: Classifies customers into segments (VIP, Regular, New) based on their purchase history, 
-- spending, and order frequency. This is valuable for targeted marketing and customer loyalty strategies.
-- -------------------------------

WITH Customer_Segmentation AS (
    SELECT 
        CONCAT(first_name, ' ', last_name) AS Name,
        SUM(sales_amount) AS Sales,
        MIN(order_date) AS first_order,
        MAX(order_date) AS last_order
    FROM gold.fact_sales
    JOIN gold.dim_customers 
        ON gold.fact_sales.customer_key = gold.dim_customers.customer_key
    GROUP BY first_name, last_name
)
SELECT
    Name,
    Sales,
    DATEDIFF(MONTH, first_order, last_order) AS life_spam_months,
    CASE 
        WHEN Sales >= 5000 AND DATEDIFF(MONTH, first_order, last_order) >= 12 THEN 'VIP'
        WHEN Sales <= 5000 AND DATEDIFF(MONTH, first_order, last_order) >= 12 THEN 'Regular'
        ELSE 'New'
    END AS Segmentation
FROM Customer_Segmentation;


-- ===============================
-- 7. CUSTOMER SEGMENTATION GROUPED
-- ===============================
-- Purpose: Aggregates the number of customers within each segment (VIP, Regular, New) for easy analysis.
-- -------------------------------

WITH Customer_Segmentation AS (
    SELECT 
        CONCAT(first_name, ' ', last_name) AS Name,
        SUM(sales_amount) AS Sales,
        MIN(order_date) AS first_order,
        MAX(order_date) AS last_order
    FROM gold.fact_sales
    JOIN gold.dim_customers 
        ON gold.fact_sales.customer_key = gold.dim_customers.customer_key
    GROUP BY first_name, last_name
)
SELECT
    COUNT(Name) AS Customer_Count,
    Segmentation
FROM (
    SELECT
        Name,
        CASE 
            WHEN Sales >= 5000 AND DATEDIFF(MONTH, first_order, last_order) >= 12 THEN 'VIP'
            WHEN Sales < 5000 AND DATEDIFF(MONTH, first_order, last_order) >= 12 THEN 'Regular'
            ELSE 'New'
        END AS Segmentation
    FROM Customer_Segmentation
) AS Segmentation_Group
GROUP BY Segmentation;


-- ===============================
-- 8. CUSTOMER REPORT VIEW
-- ===============================
-- Purpose: Creates a detailed report view of customers, including segmentation, age groups, 
-- order history, and average order values. This view helps in understanding customer behavior.
-- -------------------------------

CREATE VIEW gold.report_customers AS
WITH base_query AS (
    SELECT 
        s.order_number,
        s.product_key,
        s.order_date,
        s.sales_amount,
        s.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        DATEDIFF(YEAR, c.birthdate, GETDATE()) AS age
    FROM gold.fact_sales AS s
    JOIN gold.dim_customers AS c
        ON s.customer_key = c.customer_key
    JOIN gold.dim_products AS p
        ON s.product_key = p.product_key
    WHERE s.order_date IS NOT NULL
),
customer_aggregation AS (
    SELECT 
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        MAX(order_date) AS last_order_date,
        DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan
    FROM base_query
    GROUP BY 
        customer_key,
        customer_number,
        customer_name,
        age
)
SELECT
    *
FROM customer_aggregation;


-- ===============================
-- 9. PRODUCT REPORT VIEW
-- ===============================
-- Purpose: Generates a summarized report of product performance, including sales, 
-- segmentation, and average order revenue. It provides a comprehensive view of product lifecycles.
-- -------------------------------

CREATE VIEW gold.report_products AS
WITH base_query AS (
    SELECT
        f.order_number,
        f.order_date,
        f.customer_key,
        f.sales_amount,
        f.quantity,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE order_date IS NOT NULL
),
product_aggregations AS (
    SELECT
        *
    FROM base_query
)
SELECT 
    *
FROM product_aggregations;

-- Preview the report
SELECT * FROM gold.report_products

-- END OF ANALYSIS

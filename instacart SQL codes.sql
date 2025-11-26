-- Instacart Project
-- Objective: Define a clearer and more specific goal (e.g., sales growth, acquiring new customers, retaining loyal customers)
-- Establish hypotheses aligned with the topic + conclusion 
-- (Brief service description – identify current service issues with external sources – analyze loyal/new/inactive customer characteristics – propose data-driven solutions – final conclusions & expected outcomes such as revenue impact)
-- Analyze what products customers purchase, in what patterns, and in what combinations
-- Extract insights on repeat-purchased items, recommended items, demand patterns, and product combinations

-- Core Questions:
-- 1) Which products sell the most?
--    → Insights focused on top-selling items and revenue drivers
-- 2) Which products are most frequently reordered?
--    → High-loyalty products / retention-critical items
-- 3) Which products are purchased together? (Market Basket)
--    → Cross-selling and recommendation strategies
-- 4) When do customers purchase the most? (day/time)
--    → Marketing timing & operational staffing optimization


## Verify that all datasets are loaded correctly
SHOW DATABASES;
USE instacart;
SHOW TABLES;
SELECT * FROM products;
SELECT * FROM orders;
SELECT * FROM order_products_train;
SELECT * FROM departments;
SELECT * FROM aisles;
SELECT * FROM order_products_prior;


## Check schema & data types for each table
DESCRIBE orders;                -- bigint, text, double / Null allowed
DESCRIBE order_products_prior;  -- bigint / Null allowed
DESCRIBE products;              -- bigint, text / Null allowed
DESCRIBE aisles;                -- bigint, text / Null allowed
DESCRIBE order_products_train;  -- bigint / Null allowed
DESCRIBE departments;           -- bigint, text / Null allowed


-- Join all relevant tables into a combined dataset
SELECT 
    pp.*,
    p.product_name,
    a.aisle,
    d.department,
    od.user_id,
    od.order_dow,
    od.order_hour_of_day
FROM order_products_prior pp
JOIN products p ON pp.product_id = p.product_id
JOIN aisles a ON p.aisle_id = a.aisle_id
JOIN departments d ON p.department_id = d.department_id 
JOIN orders od ON pp.order_id = od.order_id;


SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM order_products_prior;


######################## Missing Value Check
-- aisles: No missing values
SELECT
    SUM(aisle_id IS NULL) AS aisle_id_null,
    SUM(aisle IS NULL) AS aisle_null
FROM aisles;

-- departments: No missing values
SELECT
    SUM(department_id IS NULL) AS department_id_null,
    SUM(department IS NULL) AS department_null
FROM departments;

-- products: No missing values
SELECT
    SUM(product_id IS NULL) AS product_id_null,
    SUM(product_name IS NULL) AS product_name_null,
    SUM(aisle_id IS NULL) AS aisle_id_null,
    SUM(department_id IS NULL) AS department_id_null
FROM products;

-- order_products_train: No missing values
SELECT
    SUM(order_id IS NULL) AS order_id_null,
    SUM(product_id IS NULL) AS product_id_null,
    SUM(add_to_cart_order IS NULL) AS add_to_cart_order_null,
    SUM(reordered IS NULL) AS reordered_null
FROM order_products_train;

-- order_products_prior: No missing values
SELECT
    SUM(order_id IS NULL) AS order_id_null,
    SUM(product_id IS NULL) AS product_id_null,
    SUM(add_to_cart_order IS NULL) AS add_to_cart_order_null,
    SUM(reordered IS NULL) AS reordered_null
FROM order_products_prior;

-- orders: Only 'days_since_prior_order' has 206,209 NULLs (first-time customers)
SELECT 
    SUM(order_id IS NULL) AS order_id_null,
    SUM(user_id IS NULL) AS user_id_null,
    SUM(order_number IS NULL) AS order_number_null,
    SUM(order_dow IS NULL) AS order_dow_null,
    SUM(order_hour_of_day IS NULL) AS order_hour_null,
    SUM(days_since_prior_order IS NULL) AS days_since_prior_order_null
FROM orders;

-- (Optional) Modify data types using ALTER or set index keys (can also test in Python)


####################### EDA
-- Top-selling products
SELECT p.product_id, p.product_name, COUNT(*) AS count
FROM order_products_prior pp
JOIN products p ON pp.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY count DESC 
LIMIT 20;

## Results (Top 10)
-- 1. Banana
-- 2. Bag of Organic Bananas
-- 3. Organic Strawberries
-- 4. Organic Baby Spinach
-- 5. Organic Hass Avocado
-- 6. Organic Avocado
-- 7. Large Lemon
-- 8. Strawberries
-- 9. Limes
-- 10. Organic Whole Milk


-- Products with highest reorder rate
SELECT
    p.product_id,
    p.product_name,
    SUM(pp.reordered) / COUNT(*) AS reorder_rate,
    COUNT(*) AS total_orders
FROM order_products_prior pp
JOIN products p ON pp.product_id = p.product_id
GROUP BY p.product_id, p.product_name
HAVING total_orders > 100
ORDER BY reorder_rate DESC
LIMIT 20;

## Results (Top examples)
-- chocolate love bar (92%)
-- Benchbreak Chardonnay (89%)
-- Natural clay odor eliminator (87%)


-- Which categories drive the highest volume?
SELECT d.department, COUNT(*) as cnt
FROM order_products_prior pp
JOIN products p ON pp.product_id=p.product_id
JOIN departments d ON p.department_id = d.department_id 
GROUP BY d.department
ORDER BY cnt DESC;

## Results
-- 1. Produce
-- 2. Dairy & Eggs
-- 3. Snacks
-- 4. Beverages
-- 5. Frozen


##################### Customer Behavior Analysis
-- Order volume by day of week
SELECT order_dow, COUNT(*) 
FROM orders
GROUP BY order_dow
ORDER BY COUNT(*) DESC;

## Results
-- 1. Sunday
-- 2. Monday
-- 3. Tuesday
-- 4. Friday
-- 5. Saturday


-- Order volume by hour of day
SELECT order_hour_of_day, COUNT(*)
FROM orders
GROUP BY order_hour_of_day
ORDER BY COUNT(*) DESC;

## Results
-- Peak: 10–11 AM, 11–12 PM, 3–4 PM, 2–3 PM, 1–2 PM


######## Total orders per customer
SELECT user_id, COUNT(order_id) AS total_orders
FROM orders
GROUP BY user_id
ORDER BY total_orders DESC;

## Observation
-- Many customers have up to 100 total orders → need to define loyalty thresholds


######## Average reorder cycle
SELECT AVG(days_since_prior_order) AS avg_reorder_cycle
FROM orders
WHERE days_since_prior_order IS NOT NULL;

-- Avg: 11 days


#### User-level average reorder rate
SELECT user_id, AVG(reordered) AS avg_user_reorder_rate
FROM order_products_prior opp
JOIN orders o ON opp.order_id = o.order_id
GROUP BY user_id
ORDER BY avg_user_reorder_rate DESC;

## Insight:
-- Customers with 80%+ reorder rate: ideal targets for loyalty programs
-- Histogram can help find cutoff thresholds for loyalty segmentation


######## Average cart size per customer
SELECT user_id, AVG(order_size) AS avg_cart_size
FROM ( 
    SELECT o.user_id, o.order_id, COUNT(*) AS order_size
    FROM order_products_prior pp
    JOIN orders o ON pp.order_id = o.order_id
    GROUP BY o.order_id
) t
GROUP BY user_id;


##### First-purchase vs reorder ratio
SELECT reordered, COUNT(*) 
FROM order_products_prior
GROUP BY reordered;

## Insights:
-- About 59% of all purchases are reorders → majority of revenue depends on repeated usage
-- Reinforces the need for retention and repeat-purchase strategies


-- First purchase vs reorder comparison by product
SELECT 
    p.product_id, 
    p.product_name, 
    SUM(CASE WHEN pp.reordered = 0 THEN 1 ELSE 0 END) AS first_purchase,
    SUM(CASE WHEN pp.reordered = 1 THEN 1 ELSE 0 END) AS reorder,
    COUNT(*) AS total_orders 
FROM order_products_prior pp
JOIN products p ON pp.product_id = p.product_id 
GROUP BY p.product_id, p.product_name
ORDER BY first_purchase DESC 
LIMIT 10;

## Insight:
-- Produce items dominate both first-time and repeat purchases
-- Suggests produce is a major entry point for new customers


-- Hypothesis:
-- Since top-selling items skew toward organic/premium types, Instacart users may be more willing to pay for higher-quality products.


# Transition Analysis: which product tends to follow another in cart sequence
SELECT 
    pp.order_id,
    p.product_name AS first_product,
    p2.product_name AS next_product
FROM order_products_prior pp 
JOIN order_products_prior pp2
    ON pp.order_id = pp2.order_id 
    AND pp.add_to_cart_order + 1 = pp2.add_to_cart_order 
JOIN products p ON pp.product_id = p.product_id
JOIN products p2 ON pp2.product_id = p2.product_id 
ORDER BY pp.order_id, pp.add_to_cart_order
LIMIT 20;

-- NOTE: Too large to fully execute on entire dataset


# Category of the first added product per order (first-choice category)
SELECT 
    d.department,
    COUNT(*) AS first_choice
FROM order_products_prior pp
JOIN products p ON pp.product_id = p.product_id
JOIN departments d ON p.department_id = d.department_id
WHERE pp.add_to_cart_order = 1
GROUP BY d.department
ORDER BY first_choice DESC
LIMIT 10;

## Results
-- 1. Produce
-- 2. Dairy & Eggs
-- 3. Beverages
-- 4. Snacks
-- 5. Frozen
-- 6. Pantry
-- 7. Bakery
-- 8. Deli
-- 9. Household
-- 10. Meat & Seafood


-- Products added earliest in carts
SELECT 
    p.product_name,
    AVG(pp.add_to_cart_order) AS avg
FROM order_products_prior pp
JOIN products p ON pp.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY avg ASC
LIMIT 10;

-- Later-added products in carts:
-- Likely impulse purchases rather than essentials


# Customer purchase cycle analysis
SELECT 
    user_id,
    AVG(days_since_prior_order) AS avg_purchase_gap,
    MAX(days_since_prior_order) AS max_purchase_gap,
    COUNT(order_id) AS total_orders
FROM orders 
WHERE days_since_prior_order IS NOT NULL
GROUP BY user_id
ORDER BY avg_purchase_gap DESC 
LIMIT 50;

## Insights:
-- Many customers repurchase every ~30 days
-- Larger gaps indicate reduced activity
-- Customers with stable cycles and high order count = core loyalty group
-- Best to design proactive reminders around 30-day cycles


# Product reorder rate (reordered %)
SELECT 
    p.product_id,
    p.product_name,
    COUNT(*) AS total_orders, 
    SUM(pp.reordered) AS total_reorders, 
    ROUND(SUM(pp.reordered) / COUNT(*)*100, 2) AS reorder_rate
FROM order_products_prior pp
JOIN products p ON pp.product_id = p.product_id 
GROUP BY p.product_id, p.product_name
HAVING COUNT(*) > 500
ORDER BY reorder_rate DESC 
LIMIT 20;

## Findings:
-- Dairy products dominate reorder rates (85%+)
-- Water & bananas also high
-- High-rate items are bought routinely (weekly/monthly)
-- These products drive Instacart’s recurring revenue → must be prioritized for retention strategy


# Frequently paired products (cart sequence cross-sell)
SELECT 
    pp.product_id AS first_product_id,
    p.product_name AS first_product,
    pp2.product_id AS next_product_id,
    p2.product_name AS next_product,
    COUNT(*) AS pair_count
FROM order_products_prior pp
JOIN order_products_prior pp2
    ON pp.order_id = pp2.order_id
    AND pp.add_to_cart_order + 1 = pp2.add_to_cart_order
JOIN products p ON pp.product_id = p.product_id
JOIN products p2 ON pp2.product_id = p2.product_id
GROUP BY 
    pp.product_id, p.product_name,
    pp2.product_id, p2.product_name
ORDER BY pair_count DESC
LIMIT 30;


# Category-driven customer analysis
SELECT 
    d.department,
    COUNT(*) AS total_items,
    ROUND(SUM(pp.reordered)/COUNT(*)*100, 2) AS reorder_rate
FROM order_products_prior pp
JOIN products p ON pp.product_id = p.product_id
JOIN departments d ON p.department_id = d.department_id
GROUP BY d.department
ORDER BY total_items DESC;

## Insight:
-- Customers who frequently buy fresh produce tend to be more loyal and active.


# Customer segmentation: identifying key customer groups
SELECT 
    user_id,
    product_id,
    COUNT(*) AS purchase_count
FROM (
    SELECT 
        o.user_id,
        pp.product_id
    FROM order_products_prior pp
    JOIN orders o ON pp.order_id = o.order_id
) AS t
GROUP BY user_id, product_id
ORDER BY user_id, purchase_count DESC;

## Core product categories linked to top customers:
-- Produce
-- Dairy & Eggs
-- Snacks
-- Beverages
-- Frozen


# Extract list of customers with longest inactivity
SELECT 
    user_id,
    MAX(days_since_prior_order) AS max_gap
FROM orders
GROUP BY user_id
ORDER BY max_gap DESC
LIMIT 100;

-- Customers with >30 days since last purchase → high inactivity risk


###################################################################
# Hypothesis 1:
# Relationship between total purchase count & reorder rate
SELECT 
    o.user_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(pp.reordered) / COUNT(*) AS reorder_rate
FROM orders o
JOIN order_products_prior pp ON o.order_id = pp.order_id
GROUP BY o.user_id;


## Hypothesis 2:
-- Use standard deviation to measure consistency of purchase cycles
SELECT 
    user_id,
    COUNT(order_id) AS total_orders,
    AVG(days_since_prior_order) AS avg_cycle,
    STDDEV(days_since_prior_order) AS cycle_std,
    MIN(days_since_prior_order),
    MAX(days_since_prior_order)
FROM orders
WHERE days_since_prior_order IS NOT NULL
GROUP BY user_id;

SELECT 
    AVG(days_since_prior_order) AS overall_avg_cycle,
    STDDEV(days_since_prior_order) AS overall_cycle_std,
    MIN(days_since_prior_order) AS overall_min_cycle,
    MAX(days_since_prior_order) AS overall_max_cycle
FROM orders;

## Overall:
-- Avg purchase cycle: 11 days
-- Cycle std dev: 9 days
-- Min: 0 days, Max: 30+ days
-- Customer purchase cycles vary significantly → tiered/segmented marketing strategy is essential

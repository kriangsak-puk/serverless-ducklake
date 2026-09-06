-- Example curated mart: one row per order, joined with customer + line-item totals.
-- Rebuilt in full each Transform run (small data volume here makes CREATE OR REPLACE the
-- simplest correct option — a real-scale mart would incrementalize this).
CREATE OR REPLACE TABLE mart_order_summary AS
SELECT
    o.order_id,
    o.order_date,
    o.status,
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.country,
    o.total_amount,
    SUM(oi.quantity) AS total_items,
    COUNT(DISTINCT oi.product_id) AS distinct_products
FROM orders o
JOIN customers c USING (customer_id)
JOIN order_items oi USING (order_id)
GROUP BY ALL;

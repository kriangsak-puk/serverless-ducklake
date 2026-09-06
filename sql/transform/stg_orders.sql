INSERT INTO orders
SELECT
    order_id::BIGINT,
    customer_id::BIGINT,
    order_date::DATE,
    status,
    total_amount::DECIMAL(10, 2)
FROM read_csv_auto('{raw_uri}', header=true) AS src
WHERE src.order_id NOT IN (SELECT order_id FROM orders);

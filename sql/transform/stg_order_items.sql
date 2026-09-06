INSERT INTO order_items
SELECT
    order_item_id::BIGINT,
    order_id::BIGINT,
    product_id::BIGINT,
    quantity::INTEGER,
    unit_price::DECIMAL(10, 2)
FROM read_csv_auto('{raw_uri}', header=true) AS src
WHERE src.order_item_id NOT IN (SELECT order_item_id FROM order_items);

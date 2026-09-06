INSERT INTO products
SELECT
    product_id::BIGINT,
    name,
    category,
    unit_price::DECIMAL(10, 2),
    created_at::TIMESTAMP
FROM read_csv_auto('{raw_uri}', header=true) AS src
WHERE src.product_id NOT IN (SELECT product_id FROM products);

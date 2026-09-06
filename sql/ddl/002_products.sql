CREATE TABLE IF NOT EXISTS products (
    product_id   BIGINT,
    name         VARCHAR,
    category     VARCHAR,
    unit_price   DECIMAL(10, 2),
    created_at   TIMESTAMP
);

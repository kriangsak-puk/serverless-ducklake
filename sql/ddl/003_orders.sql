CREATE TABLE IF NOT EXISTS orders (
    order_id       BIGINT,
    customer_id    BIGINT,
    order_date     DATE,
    status         VARCHAR,
    total_amount   DECIMAL(10, 2)
);

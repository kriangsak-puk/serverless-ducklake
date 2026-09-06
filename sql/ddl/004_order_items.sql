CREATE TABLE IF NOT EXISTS order_items (
    order_item_id   BIGINT,
    order_id        BIGINT,
    product_id      BIGINT,
    quantity        INTEGER,
    unit_price      DECIMAL(10, 2)
);

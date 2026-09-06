-- No PRIMARY KEY constraint: dedup on customer_id is handled by the transform's
-- anti-join INSERT (see sql/transform/stg_customers.sql), not enforced by the table.
CREATE TABLE IF NOT EXISTS customers (
    customer_id   BIGINT,
    first_name    VARCHAR,
    last_name     VARCHAR,
    email         VARCHAR,
    signup_date   DATE,
    country       VARCHAR
);

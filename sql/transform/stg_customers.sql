INSERT INTO customers
SELECT
    customer_id::BIGINT,
    first_name,
    last_name,
    email,
    signup_date::DATE,
    country
FROM read_csv_auto('{raw_uri}', header=true) AS src
WHERE src.customer_id NOT IN (SELECT customer_id FROM customers);

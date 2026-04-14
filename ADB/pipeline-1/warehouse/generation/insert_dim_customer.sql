INSERT INTO
    warehouse.dim_customer (
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state
    )
SELECT DISTINCT
    customers.customer_id,
    customers.customer_unique_id,
    customers.customer_zip_code_prefix,
    customers.customer_city,
    customers.customer_state
FROM
    olist.customers AS customers
WHERE
    customers.customer_unique_id IS NOT NULL
    AND customers.customer_zip_code_prefix IS NOT NULL
    AND customers.customer_city IS NOT NULL
    AND customers.customer_state IS NOT NULL;

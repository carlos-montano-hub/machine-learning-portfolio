DROP TABLE IF EXISTS source_customers;

CREATE TABLE
    source_customers (
        customer_id STRING,
        customer_unique_id STRING,
        customer_zip_code_prefix STRING,
        customer_city STRING,
        customer_state STRING,
        PRIMARY KEY (customer_id) NOT ENFORCED
    )
WITH
    (
        'connector' = 'jdbc',
        'url' = 'jdbc:postgresql://postgres:5432/olist',
        'table-name' = 'public.customers',
        'username' = 'postgres_user',
        'password' = 'postgres_pass'
    );

DROP TABLE IF EXISTS sink_customers;

CREATE TABLE
    sink_customers (
        customer_id VARCHAR(255),
        customer_unique_id VARCHAR(255),
        customer_zip_code_prefix VARCHAR(255),
        customer_city VARCHAR(255),
        customer_state VARCHAR(255),
        PRIMARY KEY (customer_id) NOT ENFORCED
    )
WITH
    (
        'connector' = 'doris',
        'fenodes' = 'doris:8030',
        'benodes' = 'doris:8040',
        'table.identifier' = 'olist.customers',
        'username' = 'root',
        'password' = '',
        'sink.enable-2pc' = 'false',
        'sink.buffer-flush.max-rows' = '10000',
        'sink.buffer-flush.interval' = '5s'
    );

INSERT INTO
    sink_customers
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM
    source_customers;
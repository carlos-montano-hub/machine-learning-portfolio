DROP TABLE IF EXISTS source_sellers;

CREATE TABLE
    source_sellers (
        seller_id STRING,
        seller_zip_code_prefix STRING,
        seller_city STRING,
        seller_state STRING,
        PRIMARY KEY (seller_id) NOT ENFORCED
    )
WITH
    (
        'connector' = 'jdbc',
        'url' = 'jdbc:postgresql://postgres:5432/olist',
        'table-name' = 'public.sellers',
        'username' = 'postgres_user',
        'password' = 'postgres_pass'
    );

DROP TABLE IF EXISTS sink_sellers;

CREATE TABLE
    sink_sellers (
        seller_id VARCHAR(255),
        seller_zip_code_prefix VARCHAR(255),
        seller_city VARCHAR(255),
        seller_state VARCHAR(255),
        PRIMARY KEY (seller_id) NOT ENFORCED
    )
WITH
    (
        'connector' = 'doris',
        'fenodes' = 'doris:8030',
        'benodes' = 'doris:8040',
        'table.identifier' = 'olist.sellers',
        'username' = 'root',
        'password' = '',
        'sink.enable-2pc' = 'false',
        'sink.buffer-flush.max-rows' = '10000',
        'sink.buffer-flush.interval' = '5s'
    );

INSERT INTO
    sink_sellers
SELECT
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM
    source_sellers;
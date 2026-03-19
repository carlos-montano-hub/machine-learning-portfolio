DROP TABLE IF EXISTS source_product_category_name_translation;

CREATE TABLE
    source_product_category_name_translation (
        product_category_name STRING,
        product_category_name_english STRING,
        PRIMARY KEY (product_category_name) NOT ENFORCED
    )
WITH
    (
        'connector' = 'jdbc',
        'url' = 'jdbc:postgresql://postgres:5432/olist',
        'table-name' = 'public.product_category_name_translation',
        'username' = 'postgres_user',
        'password' = 'postgres_pass'
    );

DROP TABLE IF EXISTS sink_product_category_name_translation;

CREATE TABLE
    sink_product_category_name_translation (
        product_category_name VARCHAR(255),
        product_category_name_english VARCHAR(255),
        PRIMARY KEY (product_category_name) NOT ENFORCED
    )
WITH
    (
        'connector' = 'doris',
        'fenodes' = 'doris:8030',
        'benodes' = 'doris:8040',
        'table.identifier' = 'olist.product_category_name_translation',
        'username' = 'root',
        'password' = '',
        'sink.enable-2pc' = 'false',
        'sink.buffer-flush.max-rows' = '10000',
        'sink.buffer-flush.interval' = '5s'
    );

INSERT INTO
    sink_product_category_name_translation
SELECT
    product_category_name,
    product_category_name_english
FROM
    source_product_category_name_translation;
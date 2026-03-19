DROP TABLE IF EXISTS source_products;

CREATE TABLE
    source_products (
        product_id STRING,
        product_category_name STRING,
        product_name_length INT,
        product_description_length INT,
        product_photos_qty INT,
        product_weight_g INT,
        product_length_cm INT,
        product_height_cm INT,
        product_width_cm INT,
        PRIMARY KEY (product_id) NOT ENFORCED
    )
WITH
    (
        'connector' = 'jdbc',
        'url' = 'jdbc:postgresql://postgres:5432/olist',
        'table-name' = 'public.products',
        'username' = 'postgres_user',
        'password' = 'postgres_pass'
    );

DROP TABLE IF EXISTS sink_products;

CREATE TABLE
    sink_products (
        product_id VARCHAR(255),
        product_category_name VARCHAR(255),
        product_name_length INT,
        product_description_length INT,
        product_photos_qty INT,
        product_weight_g INT,
        product_length_cm INT,
        product_height_cm INT,
        product_width_cm INT,
        PRIMARY KEY (product_id) NOT ENFORCED
    )
WITH
    (
        'connector' = 'doris',
        'fenodes' = 'doris:8030',
        'benodes' = 'doris:8040',
        'table.identifier' = 'olist.products',
        'username' = 'root',
        'password' = '',
        'sink.enable-2pc' = 'false',
        'sink.buffer-flush.max-rows' = '10000',
        'sink.buffer-flush.interval' = '5s'
    );

INSERT INTO
    sink_products
SELECT
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM
    source_products;
DROP TABLE IF EXISTS source_order_items;

CREATE TABLE
    source_order_items (
        order_id STRING,
        order_item_id INT,
        product_id STRING,
        seller_id STRING,
        shipping_limit_date TIMESTAMP,
        price DOUBLE,
        freight_value DOUBLE,
        PRIMARY KEY (order_id, order_item_id) NOT ENFORCED
    )
WITH
    (
        'connector' = 'jdbc',
        'url' = 'jdbc:postgresql://postgres:5432/olist',
        'table-name' = 'public.order_items',
        'username' = 'postgres_user',
        'password' = 'postgres_pass'
    );

DROP TABLE IF EXISTS sink_order_items;

CREATE TABLE
    sink_order_items (
        order_id VARCHAR(255),
        order_item_id INT,
        product_id VARCHAR(255),
        seller_id VARCHAR(255),
        shipping_limit_date TIMESTAMP,
        price DOUBLE,
        freight_value DOUBLE,
        PRIMARY KEY (order_id, order_item_id) NOT ENFORCED
    )
WITH
    (
        'connector' = 'doris',
        'fenodes' = 'doris:8030',
        'benodes' = 'doris:8040',
        'table.identifier' = 'olist.order_items',
        'username' = 'root',
        'password' = '',
        'sink.enable-2pc' = 'false',
        'sink.buffer-flush.max-rows' = '10000',
        'sink.buffer-flush.interval' = '5s'
    );

INSERT INTO
    sink_order_items
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
FROM
    source_order_items;
DROP TABLE IF EXISTS source_order_payments;

CREATE TABLE
    source_order_payments (
        order_id STRING,
        payment_sequential INT,
        payment_type STRING,
        payment_installments INT,
        payment_value DOUBLE,
        PRIMARY KEY (order_id, payment_sequential) NOT ENFORCED
    )
WITH
    (
        'connector' = 'jdbc',
        'url' = 'jdbc:postgresql://postgres:5432/olist',
        'table-name' = 'public.order_payments',
        'username' = 'postgres_user',
        'password' = 'postgres_pass'
    );

DROP TABLE IF EXISTS sink_order_payments;

CREATE TABLE
    sink_order_payments (
        order_id VARCHAR(255),
        payment_sequential INT,
        payment_type VARCHAR(255),
        payment_installments INT,
        payment_value DOUBLE,
        PRIMARY KEY (order_id, payment_sequential) NOT ENFORCED
    )
WITH
    (
        'connector' = 'doris',
        'fenodes' = 'doris:8030',
        'benodes' = 'doris:8040',
        'table.identifier' = 'olist.order_payments',
        'username' = 'root',
        'password' = '',
        'sink.enable-2pc' = 'false',
        'sink.buffer-flush.max-rows' = '10000',
        'sink.buffer-flush.interval' = '5s'
    );

INSERT INTO
    sink_order_payments
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM
    source_order_payments;
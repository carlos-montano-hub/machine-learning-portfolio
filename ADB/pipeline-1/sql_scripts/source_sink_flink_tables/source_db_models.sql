-- =============================================
-- Geolocations
-- =============================================
CREATE TABLE
    source_geolocations (
        geolocation_zip_code_prefix STRING,
        geolocation_lat DOUBLE,
        geolocation_lng DOUBLE,
        geolocation_city STRING,
        geolocation_state STRING,
        PRIMARY KEY (geolocation_lat, geolocation_lng) NOT ENFORCED
    )
WITH
    (
        'connector' = 'jdbc',
        'url' = 'jdbc:postgresql://postgres:5432/olist',
        'table-name' = 'public.geolocations',
        'username' = 'postgres_user',
        'password' = 'postgres_pass'
    );

DROP TABLE IF EXISTS sink_geolocations;

CREATE TABLE
    sink_geolocations (
        geolocation_zip_code_prefix VARCHAR(255),
        geolocation_lat DOUBLE,
        geolocation_lng DOUBLE,
        geolocation_city VARCHAR(255),
        geolocation_state VARCHAR(255),
        PRIMARY KEY (geolocation_lat, geolocation_lng) NOT ENFORCED
    )
WITH
    (
        'connector' = 'doris',
        'fenodes' = 'doris:8030',
        'benodes' = 'doris:8040',
        'table.identifier' = 'olist.geolocations',
        'username' = 'root',
        'password' = '',
        'sink.enable-2pc' = 'false',
        'sink.buffer-flush.max-rows' = '10000',
        'sink.buffer-flush.interval' = '5s'
    );

INSERT INTO
    sink_geolocations
SELECT
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
FROM
    source_geolocations;

-- =============================================
-- Customers
-- =============================================
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

-- =============================================
-- Sellers
-- =============================================
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

-- =============================================
-- Product Category Name Translation
-- =============================================
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

-- =============================================
-- Products
-- =============================================
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

-- =============================================
-- Orders
-- =============================================
CREATE TABLE
    source_orders (
        order_id STRING,
        customer_id STRING,
        order_status STRING,
        order_purchase_timestamp TIMESTAMP,
        order_approved_at TIMESTAMP,
        order_delivered_carrier_date TIMESTAMP,
        order_delivered_customer_date TIMESTAMP,
        order_estimated_delivery_date TIMESTAMP,
        PRIMARY KEY (order_id) NOT ENFORCED
    )
WITH
    (
        'connector' = 'jdbc',
        'url' = 'jdbc:postgresql://postgres:5432/olist',
        'table-name' = 'public.orders',
        'username' = 'postgres_user',
        'password' = 'postgres_pass'
    );

DROP TABLE IF EXISTS sink_orders;

CREATE TABLE
    sink_orders (
        order_id VARCHAR(255),
        customer_id VARCHAR(255),
        order_status VARCHAR(255),
        order_purchase_timestamp TIMESTAMP,
        order_approved_at TIMESTAMP,
        order_delivered_carrier_date TIMESTAMP,
        order_delivered_customer_date TIMESTAMP,
        order_estimated_delivery_date TIMESTAMP,
        PRIMARY KEY (order_id) NOT ENFORCED
    )
WITH
    (
        'connector' = 'doris',
        'fenodes' = 'doris:8030',
        'benodes' = 'doris:8040',
        'table.identifier' = 'olist.orders',
        'username' = 'root',
        'password' = '',
        'sink.enable-2pc' = 'false',
        'sink.buffer-flush.max-rows' = '10000',
        'sink.buffer-flush.interval' = '5s'
    );

INSERT INTO
    sink_orders
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM
    source_orders;

-- =============================================
-- Order Items
-- =============================================
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

-- =============================================
-- Order Payments
-- =============================================
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

-- =============================================
-- Order Reviews
-- =============================================
CREATE TABLE
    source_order_reviews (
        review_id STRING,
        order_id STRING,
        review_score INT,
        review_comment_title STRING,
        review_comment_message STRING,
        review_creation_date TIMESTAMP,
        review_answer_timestamp TIMESTAMP,
        PRIMARY KEY (review_id) NOT ENFORCED
    )
WITH
    (
        'connector' = 'jdbc',
        'url' = 'jdbc:postgresql://postgres:5432/olist',
        'table-name' = 'public.order_reviews',
        'username' = 'postgres_user',
        'password' = 'postgres_pass'
    );

DROP TABLE IF EXISTS sink_order_reviews;

CREATE TABLE
    sink_order_reviews (
        review_id VARCHAR(255),
        order_id VARCHAR(255),
        review_score INT,
        review_comment_title VARCHAR(255),
        review_comment_message VARCHAR(255),
        review_creation_date TIMESTAMP,
        review_answer_timestamp TIMESTAMP,
        PRIMARY KEY (review_id) NOT ENFORCED
    )
WITH
    (
        'connector' = 'doris',
        'fenodes' = 'doris:8030',
        'benodes' = 'doris:8040',
        'table.identifier' = 'olist.order_reviews',
        'username' = 'root',
        'password' = '',
        'sink.enable-2pc' = 'false',
        'sink.buffer-flush.max-rows' = '10000',
        'sink.buffer-flush.interval' = '5s'
    );

INSERT INTO
    sink_order_reviews
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM
    source_order_reviews;
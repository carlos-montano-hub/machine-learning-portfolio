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

INSERT INTO
    warehouse.dim_seller (
        seller_id,
        seller_zip_code_prefix,
        seller_city,
        seller_state
    )
SELECT DISTINCT
    sellers.seller_id,
    sellers.seller_zip_code_prefix,
    sellers.seller_city,
    sellers.seller_state
FROM
    olist.sellers AS sellers
WHERE
    sellers.seller_zip_code_prefix IS NOT NULL
    AND sellers.seller_city IS NOT NULL
    AND sellers.seller_state IS NOT NULL;

INSERT INTO
    warehouse.dim_geolocation (
        geolocation_zip_code_prefix,
        geolocation_city,
        geolocation_state,
        geolocation_lat,
        geolocation_lng
    )
SELECT DISTINCT
    geolocations.geolocation_zip_code_prefix,
    geolocations.geolocation_city,
    geolocations.geolocation_state,
    geolocations.geolocation_lat,
    geolocations.geolocation_lng
FROM
    olist.geolocations AS geolocations
WHERE
    geolocations.geolocation_zip_code_prefix IS NOT NULL
    AND geolocations.geolocation_city IS NOT NULL
    AND geolocations.geolocation_state IS NOT NULL;

INSERT INTO
    warehouse.dim_payment_type (payment_type)
SELECT DISTINCT
    order_payments.payment_type
FROM
    olist.order_payments AS order_payments
WHERE
    order_payments.payment_type IS NOT NULL;

INSERT INTO
    warehouse.dim_order_status (order_status)
SELECT DISTINCT
    orders.order_status
FROM
    olist.orders AS orders
WHERE
    orders.order_status IS NOT NULL;
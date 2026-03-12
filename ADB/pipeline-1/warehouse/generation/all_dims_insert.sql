INSERT INTO dim_customer (
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
FROM customers
WHERE
    customers.customer_unique_id IS NOT NULL AND
    customers.customer_zip_code_prefix IS NOT NULL AND
    customers.customer_city IS NOT NULL AND
    customers.customer_state IS NOT NULL
ON CONFLICT (customer_id) DO NOTHING;

INSERT INTO dim_seller (
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
FROM sellers
WHERE
    sellers.seller_zip_code_prefix IS NOT NULL AND
    sellers.seller_city IS NOT NULL AND
    sellers.seller_state IS NOT NULL
ON CONFLICT (seller_id) DO NOTHING;

INSERT INTO dim_geolocation (
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
FROM geolocations
WHERE
    geolocations.geolocation_zip_code_prefix IS NOT NULL AND
    geolocations.geolocation_city IS NOT NULL AND
    geolocations.geolocation_state IS NOT NULL;

INSERT INTO dim_payment_type (payment_type)
SELECT DISTINCT
    order_payments.payment_type
FROM order_payments
WHERE order_payments.payment_type IS NOT NULL
ON CONFLICT (payment_type) DO NOTHING;

INSERT INTO dim_order_status (order_status)
SELECT DISTINCT
    orders.order_status
FROM orders
WHERE orders.order_status IS NOT NULL
ON CONFLICT (order_status) DO NOTHING;


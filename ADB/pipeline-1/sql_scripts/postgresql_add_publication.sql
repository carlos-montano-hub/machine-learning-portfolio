SELECT
    pg_create_logical_replication_slot ('test_slot', 'pgoutput');

ALTER TABLE geolocations REPLICA IDENTITY DEFAULT;

ALTER TABLE customers REPLICA IDENTITY DEFAULT;

ALTER TABLE sellers REPLICA IDENTITY DEFAULT;

ALTER TABLE product_category_name_translation REPLICA IDENTITY DEFAULT;

ALTER TABLE products REPLICA IDENTITY DEFAULT;

ALTER TABLE orders REPLICA IDENTITY DEFAULT;

ALTER TABLE order_items REPLICA IDENTITY DEFAULT;

ALTER TABLE order_payments REPLICA IDENTITY DEFAULT;

ALTER TABLE order_reviews REPLICA IDENTITY DEFAULT;

DROP PUBLICATION IF EXISTS test_publication;

CREATE PUBLICATION test_publication FOR TABLE geolocations,
customers,
sellers,
product_category_name_translation,
products,
orders,
order_items,
order_payments,
order_reviews;
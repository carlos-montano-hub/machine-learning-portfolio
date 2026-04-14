ALTER TABLE public.geolocations REPLICA IDENTITY DEFAULT;

ALTER TABLE public.customers REPLICA IDENTITY DEFAULT;

ALTER TABLE public.sellers REPLICA IDENTITY DEFAULT;

ALTER TABLE public.product_category_name_translation REPLICA IDENTITY DEFAULT;

ALTER TABLE public.products REPLICA IDENTITY DEFAULT;

ALTER TABLE public.orders REPLICA IDENTITY DEFAULT;

ALTER TABLE public.order_items REPLICA IDENTITY DEFAULT;

ALTER TABLE public.order_payments REPLICA IDENTITY DEFAULT;

ALTER TABLE public.order_reviews REPLICA IDENTITY DEFAULT;

ALTER TABLE public.dim_time REPLICA IDENTITY DEFAULT;

-- debezium.publication.autocreate.mode = disabled
DROP PUBLICATION IF EXISTS olist_publication;

CREATE PUBLICATION olist_publication FOR TABLE public.geolocations,
public.customers,
public.sellers,
public.product_category_name_translation,
public.products,
public.orders,
public.order_items,
public.order_payments,
public.order_reviews,
public.dim_time;
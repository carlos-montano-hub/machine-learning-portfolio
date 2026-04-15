SELECT
    f.order_id,
    f.order_item_id,
    f.item_price,
    f.freight_value,
    c.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    s.seller_id,
    s.seller_city,
    s.seller_state,
    p.product_id,
    p.product_english_category_name,
    p.product_category_name,
    p.product_weight_g,
    p.product_volume_cm3,
    p.product_density_g_per_cm3,
    os.order_status,
    t.full_date AS order_date,
    t.year AS order_year,
    t.quarter AS order_quarter,
    t.month AS order_month,
    t.day_name AS order_day_name,
    t.is_weekend AS order_is_weekend
FROM
    warehouse.fact_order_item AS f
    JOIN warehouse.dim_customer AS c ON f.customer_key = c.customer_key
    JOIN warehouse.dim_seller AS s ON f.seller_key = s.seller_key
    JOIN warehouse.dim_product AS p ON f.product_key = p.product_key
    JOIN warehouse.dim_order_status AS os ON f.order_status_key = os.order_status_key
    LEFT JOIN warehouse.dim_time AS t ON f.order_date_key = t.date_id;

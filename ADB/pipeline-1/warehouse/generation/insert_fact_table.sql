INSERT INTO
    warehouse.fact_order_item (
        order_id,
        order_item_id,
        product_key,
        customer_key,
        seller_key,
        order_status_key,
        order_date_key,
        item_price,
        freight_value
    )
SELECT
    order_items.order_id,
    order_items.order_item_id,
    COALESCE(dim_product.product_key, 0),
    COALESCE(dim_customer.customer_key, 0),
    COALESCE(dim_seller.seller_key, 0),
    COALESCE(dim_order_status.order_status_key, 0),
    CAST(
        DATE_FORMAT (orders.order_purchase_timestamp, '%%Y%%m%%d') AS INT
    ),
    order_items.price,
    order_items.freight_value
FROM
    olist.order_items AS order_items
    JOIN olist.orders AS orders ON order_items.order_id = orders.order_id
    JOIN warehouse.dim_customer AS dim_customer ON orders.customer_id = dim_customer.customer_id
    LEFT JOIN warehouse.dim_product AS dim_product ON order_items.product_id = dim_product.product_id
    LEFT JOIN warehouse.dim_seller AS dim_seller ON order_items.seller_id = dim_seller.seller_id
    LEFT JOIN warehouse.dim_order_status AS dim_order_status ON orders.order_status = dim_order_status.order_status;
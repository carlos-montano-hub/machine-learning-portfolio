INSERT INTO
    warehouse.dim_order_status (order_status)
SELECT DISTINCT
    orders.order_status
FROM
    olist.orders AS orders
WHERE
    orders.order_status IS NOT NULL;

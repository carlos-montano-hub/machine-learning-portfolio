INSERT INTO
    warehouse.dim_payment_type (payment_type)
SELECT DISTINCT
    order_payments.payment_type
FROM
    olist.order_payments AS order_payments
WHERE
    order_payments.payment_type IS NOT NULL;

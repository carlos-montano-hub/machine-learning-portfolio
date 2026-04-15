CREATE TABLE
    IF NOT EXISTS olist.order_payments (
        order_id VARCHAR(255) NOT NULL,
        payment_sequential INT NOT NULL,
        payment_type VARCHAR(255) NOT NULL,
        payment_installments INT NOT NULL,
        payment_value DOUBLE NOT NULL
    ) UNIQUE KEY (order_id, payment_sequential) DISTRIBUTED BY HASH (order_id, payment_sequential) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
CREATE TABLE
    IF NOT EXISTS olist.orders (
        order_id VARCHAR(255) NOT NULL,
        customer_id VARCHAR(255) NOT NULL,
        order_status VARCHAR(255) NOT NULL,
        order_purchase_timestamp DATETIME NOT NULL,
        order_approved_at DATETIME NULL,
        order_delivered_carrier_date DATETIME NULL,
        order_delivered_customer_date DATETIME NULL,
        order_estimated_delivery_date DATETIME NULL
    ) UNIQUE KEY (order_id) DISTRIBUTED BY HASH (order_id) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
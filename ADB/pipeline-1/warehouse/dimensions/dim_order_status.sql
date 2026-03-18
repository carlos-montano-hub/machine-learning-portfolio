CREATE TABLE
    IF NOT EXISTS dim_order_status (
        order_status_key INT NOT NULL COMMENT 'Surrogate key',
        order_status VARCHAR(64) NOT NULL
    ) UNIQUE KEY (order_status_key) DISTRIBUTED BY HASH (order_status_key) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
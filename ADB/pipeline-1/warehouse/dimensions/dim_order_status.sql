CREATE TABLE
    IF NOT EXISTS warehouse.dim_order_status (
        order_status VARCHAR(64) NOT NULL COMMENT 'Natural key from source',
        order_status_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key'
    ) UNIQUE KEY (order_status) DISTRIBUTED BY HASH (order_status) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
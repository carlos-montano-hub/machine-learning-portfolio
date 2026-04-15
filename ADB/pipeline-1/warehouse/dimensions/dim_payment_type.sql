CREATE TABLE
    IF NOT EXISTS warehouse.dim_payment_type (
        payment_type VARCHAR(64) NOT NULL COMMENT 'Natural key from source',
        payment_type_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key'
    ) UNIQUE KEY (payment_type) DISTRIBUTED BY HASH (payment_type) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
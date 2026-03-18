CREATE TABLE
    IF NOT EXISTS dim_payment_type (
        payment_type_key INT NOT NULL COMMENT 'Surrogate key',
        payment_type VARCHAR(64) NOT NULL
    ) UNIQUE KEY (payment_type_key) DISTRIBUTED BY HASH (payment_type_key) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
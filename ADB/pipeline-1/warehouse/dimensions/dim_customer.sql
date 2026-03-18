CREATE TABLE
    IF NOT EXISTS dim_customer (
        customer_key INT NOT NULL COMMENT 'Surrogate key',
        customer_id VARCHAR(64) NOT NULL COMMENT 'Natural key from source',
        customer_unique_id VARCHAR(64) NOT NULL,
        customer_zip_code_prefix VARCHAR(16) NOT NULL,
        customer_city VARCHAR(128) NOT NULL,
        customer_state VARCHAR(8) NOT NULL
    ) UNIQUE KEY (customer_key) DISTRIBUTED BY HASH (customer_key) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
CREATE TABLE
    IF NOT EXISTS warehouse.dim_customer (
        customer_id VARCHAR(64) NOT NULL COMMENT 'Natural key from source',
        customer_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
        customer_unique_id VARCHAR(64) NOT NULL,
        customer_zip_code_prefix VARCHAR(16) NOT NULL,
        customer_city VARCHAR(128) NOT NULL,
        customer_state VARCHAR(8) NOT NULL
    ) UNIQUE KEY (customer_id) DISTRIBUTED BY HASH (customer_id) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
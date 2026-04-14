CREATE TABLE
    IF NOT EXISTS warehouse.dim_seller (
        seller_id VARCHAR(64) NOT NULL COMMENT 'Natural key from source',
        seller_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
        seller_zip_code_prefix VARCHAR(16) NOT NULL,
        seller_city VARCHAR(128) NOT NULL,
        seller_state VARCHAR(8) NOT NULL
    ) UNIQUE KEY (seller_id) DISTRIBUTED BY HASH (seller_id) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
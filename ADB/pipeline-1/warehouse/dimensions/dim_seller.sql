CREATE TABLE
    IF NOT EXISTS dim_seller (
        seller_key INT NOT NULL COMMENT 'Surrogate key',
        seller_id VARCHAR(64) NOT NULL COMMENT 'Natural key from source',
        seller_zip_code_prefix VARCHAR(16) NOT NULL,
        seller_city VARCHAR(128) NOT NULL,
        seller_state VARCHAR(8) NOT NULL
    ) UNIQUE KEY (seller_key) DISTRIBUTED BY HASH (seller_key) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
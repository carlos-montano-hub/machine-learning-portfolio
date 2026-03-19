CREATE TABLE
    IF NOT EXISTS olist.sellers (
        seller_id VARCHAR(255) NOT NULL,
        seller_zip_code_prefix VARCHAR(255) NOT NULL,
        seller_city VARCHAR(255) NOT NULL,
        seller_state VARCHAR(255) NOT NULL
    ) UNIQUE KEY (seller_id) DISTRIBUTED BY HASH (seller_id) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
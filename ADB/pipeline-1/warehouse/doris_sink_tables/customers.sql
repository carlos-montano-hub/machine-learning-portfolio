CREATE TABLE
    IF NOT EXISTS olist.customers (
        customer_id VARCHAR(255) NOT NULL,
        customer_unique_id VARCHAR(255) NOT NULL,
        customer_zip_code_prefix VARCHAR(255) NOT NULL,
        customer_city VARCHAR(255) NOT NULL,
        customer_state VARCHAR(255) NOT NULL
    ) UNIQUE KEY (customer_id) DISTRIBUTED BY HASH (customer_id) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
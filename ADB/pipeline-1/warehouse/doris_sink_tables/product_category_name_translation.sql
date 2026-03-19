CREATE TABLE
    IF NOT EXISTS olist.product_category_name_translation (
        product_category_name VARCHAR(255) NOT NULL,
        product_category_name_english VARCHAR(255) NOT NULL
    ) UNIQUE KEY (product_category_name) DISTRIBUTED BY HASH (product_category_name) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
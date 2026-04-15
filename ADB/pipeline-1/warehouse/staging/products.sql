CREATE TABLE
    IF NOT EXISTS olist.products (
        product_id VARCHAR(255) NOT NULL,
        product_category_name VARCHAR(255) NULL,
        product_name_length INT NULL,
        product_description_length INT NULL,
        product_photos_qty INT NULL,
        product_weight_g INT NULL,
        product_length_cm INT NULL,
        product_height_cm INT NULL,
        product_width_cm INT NULL
    ) UNIQUE KEY (product_id) DISTRIBUTED BY HASH (product_id) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
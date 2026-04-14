CREATE TABLE
    IF NOT EXISTS warehouse.dim_product (
        product_id VARCHAR(64) NOT NULL COMMENT 'Natural key from source',
        product_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
        product_english_category_name VARCHAR(256) NULL,
        product_category_name VARCHAR(256) NULL,
        product_weight_g INT NULL,
        product_length_cm INT NULL,
        product_height_cm INT NULL,
        product_width_cm INT NULL,
        product_volume_cm3 INT NULL,
        product_density_g_per_cm3 DOUBLE NULL
    ) UNIQUE KEY (product_id) DISTRIBUTED BY HASH (product_id) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
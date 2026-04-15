CREATE TABLE
    IF NOT EXISTS warehouse.dim_geolocation (
        geolocation_zip_code_prefix VARCHAR(16) NOT NULL COMMENT 'Natural key from source',
        geolocation_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
        geolocation_city VARCHAR(128) NOT NULL,
        geolocation_state VARCHAR(8) NOT NULL,
        geolocation_lat DOUBLE NULL,
        geolocation_lng DOUBLE NULL
    ) UNIQUE KEY (geolocation_zip_code_prefix) DISTRIBUTED BY HASH (geolocation_zip_code_prefix) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
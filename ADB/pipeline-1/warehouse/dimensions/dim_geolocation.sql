CREATE TABLE
    IF NOT EXISTS dim_geolocation (
        geolocation_key INT NOT NULL COMMENT 'Surrogate key',
        geolocation_zip_code_prefix VARCHAR(16) NOT NULL,
        geolocation_city VARCHAR(128) NOT NULL,
        geolocation_state VARCHAR(8) NOT NULL,
        geolocation_lat DOUBLE NULL,
        geolocation_lng DOUBLE NULL
    ) UNIQUE KEY (geolocation_key) DISTRIBUTED BY HASH (geolocation_key) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
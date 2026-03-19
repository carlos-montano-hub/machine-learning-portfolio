CREATE TABLE
    IF NOT EXISTS olist.geolocations (
        geolocation_zip_code_prefix VARCHAR(255) NOT NULL,
        geolocation_lat DECIMAL NOT NULL,
        geolocation_lng DECIMAL NOT NULL,
        geolocation_city VARCHAR(255) NOT NULL,
        geolocation_state VARCHAR(255) NOT NULL
    ) UNIQUE KEY (
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng
    ) DISTRIBUTED BY HASH (geolocation_lat, geolocation_lng) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
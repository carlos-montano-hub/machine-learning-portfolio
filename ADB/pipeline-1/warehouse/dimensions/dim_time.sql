CREATE TABLE
    IF NOT EXISTS dim_time (
        date_id INT NOT NULL COMMENT 'YYYYMMDD format',
        full_date DATE NOT NULL,
        year INT NOT NULL,
        quarter INT NOT NULL,
        month INT NOT NULL,
        day INT NOT NULL,
        day_of_week INT NOT NULL COMMENT 'Monday=1 .. Sunday=7',
        day_name VARCHAR(16) NOT NULL COMMENT 'Monday .. Sunday',
        week_of_year_iso INT NOT NULL,
        is_weekend BOOLEAN NOT NULL
    ) UNIQUE KEY (date_id) DISTRIBUTED BY HASH (date_id) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
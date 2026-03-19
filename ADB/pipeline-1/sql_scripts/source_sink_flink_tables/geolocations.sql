DROP TABLE IF EXISTS source_geolocations;

CREATE TABLE
    source_geolocations (
        geolocation_zip_code_prefix STRING,
        geolocation_lat DOUBLE,
        geolocation_lng DOUBLE,
        geolocation_city STRING,
        geolocation_state STRING,
        PRIMARY KEY (geolocation_lat, geolocation_lng) NOT ENFORCED
    )
WITH
    (
        'connector' = 'jdbc',
        'url' = 'jdbc:postgresql://postgres:5432/olist',
        'table-name' = 'public.geolocations',
        'username' = 'postgres_user',
        'password' = 'postgres_pass'
    );

DROP TABLE IF EXISTS sink_geolocations;

CREATE TABLE
    sink_geolocations (
        geolocation_zip_code_prefix VARCHAR(255),
        geolocation_lat DOUBLE,
        geolocation_lng DOUBLE,
        geolocation_city VARCHAR(255),
        geolocation_state VARCHAR(255),
        PRIMARY KEY (geolocation_lat, geolocation_lng) NOT ENFORCED
    )
WITH
    (
        'connector' = 'doris',
        'fenodes' = 'doris:8030',
        'benodes' = 'doris:8040',
        'table.identifier' = 'olist.geolocations',
        'username' = 'root',
        'password' = '',
        'sink.enable-2pc' = 'false',
        'sink.buffer-flush.max-rows' = '10000',
        'sink.buffer-flush.interval' = '5s'
    );

INSERT INTO
    sink_geolocations
SELECT
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
FROM
    source_geolocations;
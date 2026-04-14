INSERT INTO
    warehouse.dim_geolocation (
        geolocation_zip_code_prefix,
        geolocation_city,
        geolocation_state,
        geolocation_lat,
        geolocation_lng
    )
SELECT DISTINCT
    geolocations.geolocation_zip_code_prefix,
    geolocations.geolocation_city,
    geolocations.geolocation_state,
    geolocations.geolocation_lat,
    geolocations.geolocation_lng
FROM
    olist.geolocations AS geolocations
WHERE
    geolocations.geolocation_zip_code_prefix IS NOT NULL
    AND geolocations.geolocation_city IS NOT NULL
    AND geolocations.geolocation_state IS NOT NULL;

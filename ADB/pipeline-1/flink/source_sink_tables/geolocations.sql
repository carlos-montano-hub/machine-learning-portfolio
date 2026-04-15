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
        'connector' = 'postgres-cdc',
        'hostname' = 'postgres',
        'port' = '5432',
        'username' = 'postgres_user',
        'password' = 'postgres_pass',
        'database-name' = 'olist',
        'schema-name' = 'public',
        'table-name' = 'geolocations',
        'slot.name' = 'geolocations_flink_slot_1',
        'decoding.plugin.name' = 'pgoutput',
        'changelog-mode' = 'upsert',
        'scan.incremental.snapshot.enabled' = 'true',
        'scan.incremental.snapshot.chunk.size' = '2000',
        'scan.snapshot.fetch.size' = '200',
        'debezium.publication.name' = 'olist_publication',
        'debezium.publication.autocreate.mode' = 'disabled'
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
        'username' = 'root',
        'password' = '',
        'sink.enable-2pc' = 'true',
        'sink.max-retries' = '10',
        'sink.properties.group_commit' = 'sync_mode',
        'sink.enable.batch-mode' = 'false',
        'sink.label-prefix' = 'sink_geolocations',
        'table.identifier' = 'olist.geolocations'
    );

SET
    'execution.checkpointing.interval' = '10 s';

SET
    'execution.checkpointing.mode' = 'EXACTLY_ONCE';

SET
    'execution.checkpointing.storage' = 'filesystem';

SET
    'execution.checkpointing.dir' = 'file:///shared/flink-checkpoints';

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
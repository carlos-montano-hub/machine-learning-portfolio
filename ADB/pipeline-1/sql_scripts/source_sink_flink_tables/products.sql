DROP TABLE IF EXISTS source_products;

CREATE TABLE
    source_products (
        product_id STRING,
        product_category_name STRING,
        product_name_length INT,
        product_description_length INT,
        product_photos_qty INT,
        product_weight_g INT,
        product_length_cm INT,
        product_height_cm INT,
        product_width_cm INT,
        PRIMARY KEY (product_id) NOT ENFORCED
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
        'decoding.plugin.name' = 'pgoutput',
        'changelog-mode' = 'upsert',
        'scan.incremental.snapshot.enabled' = 'true',
        'scan.incremental.snapshot.chunk.size' = '2000',
        'scan.snapshot.fetch.size' = '200',
        'debezium.publication.name' = 'olist_publication',
        'debezium.publication.autocreate.mode' = 'disabled',
        'table-name' = 'products',
        'slot.name' = 'products_flink_slot_1'
    );

DROP TABLE IF EXISTS sink_products;

CREATE TABLE
    sink_products (
        product_id VARCHAR(255),
        product_category_name VARCHAR(255),
        product_name_length INT,
        product_description_length INT,
        product_photos_qty INT,
        product_weight_g INT,
        product_length_cm INT,
        product_height_cm INT,
        product_width_cm INT,
        PRIMARY KEY (product_id) NOT ENFORCED
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
        'sink.label-prefix' = 'sink_products',
        'table.identifier' = 'olist.products'
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
    sink_products
SELECT
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM
    source_products;
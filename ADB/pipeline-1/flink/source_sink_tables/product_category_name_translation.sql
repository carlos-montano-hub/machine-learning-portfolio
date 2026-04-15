DROP TABLE IF EXISTS source_product_category_name_translation;

CREATE TABLE
    source_product_category_name_translation (
        product_category_name STRING,
        product_category_name_english STRING,
        PRIMARY KEY (product_category_name) NOT ENFORCED
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
        'table-name' = 'product_category_name_translation',
        'slot.name' = 'product_category_name_translation_flink_slot_1'
    );

DROP TABLE IF EXISTS sink_product_category_name_translation;

CREATE TABLE
    sink_product_category_name_translation (
        product_category_name VARCHAR(255),
        product_category_name_english VARCHAR(255),
        PRIMARY KEY (product_category_name) NOT ENFORCED
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
        'sink.label-prefix' = 'sink_product_category_name_translation',
        'table.identifier' = 'olist.product_category_name_translation'
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
    sink_product_category_name_translation
SELECT
    product_category_name,
    product_category_name_english
FROM
    source_product_category_name_translation;
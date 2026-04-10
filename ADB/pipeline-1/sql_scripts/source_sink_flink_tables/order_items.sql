DROP TABLE IF EXISTS source_order_items;

CREATE TABLE
    source_order_items (
        order_id STRING,
        order_item_id INT,
        product_id STRING,
        seller_id STRING,
        shipping_limit_date TIMESTAMP,
        price DOUBLE,
        freight_value DOUBLE,
        PRIMARY KEY (order_id, order_item_id) NOT ENFORCED
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
        'table-name' = 'order_items',
        'slot.name' = 'order_items_flink_slot_1'
    );

DROP TABLE IF EXISTS sink_order_items;

CREATE TABLE
    sink_order_items (
        order_id VARCHAR(255),
        order_item_id INT,
        product_id VARCHAR(255),
        seller_id VARCHAR(255),
        shipping_limit_date TIMESTAMP,
        price DOUBLE,
        freight_value DOUBLE,
        PRIMARY KEY (order_id, order_item_id) NOT ENFORCED
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
        'sink.label-prefix' = 'sink_order_items',
        'table.identifier' = 'olist.order_items'
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
    sink_order_items
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
FROM
    source_order_items;
DROP TABLE IF EXISTS source_orders;

CREATE TABLE
    source_orders (
        order_id STRING,
        customer_id STRING,
        order_status STRING,
        order_purchase_timestamp TIMESTAMP,
        order_approved_at TIMESTAMP,
        order_delivered_carrier_date TIMESTAMP,
        order_delivered_customer_date TIMESTAMP,
        order_estimated_delivery_date TIMESTAMP,
        PRIMARY KEY (order_id) NOT ENFORCED
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
        'table-name' = 'orders',
        'slot.name' = 'orders_flink_slot_1'
    );

DROP TABLE IF EXISTS sink_orders;

CREATE TABLE
    sink_orders (
        order_id VARCHAR(255),
        customer_id VARCHAR(255),
        order_status VARCHAR(255),
        order_purchase_timestamp TIMESTAMP,
        order_approved_at TIMESTAMP,
        order_delivered_carrier_date TIMESTAMP,
        order_delivered_customer_date TIMESTAMP,
        order_estimated_delivery_date TIMESTAMP,
        PRIMARY KEY (order_id) NOT ENFORCED
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
        'sink.label-prefix' = 'sink_orders',
        'table.identifier' = 'olist.orders'
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
    sink_orders
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM
    source_orders;
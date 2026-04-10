DROP TABLE IF EXISTS source_order_payments;

CREATE TABLE
    source_order_payments (
        order_id STRING,
        payment_sequential INT,
        payment_type STRING,
        payment_installments INT,
        payment_value DOUBLE,
        PRIMARY KEY (order_id, payment_sequential) NOT ENFORCED
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
        'table-name' = 'order_payments',
        'slot.name' = 'order_payments_flink_slot_1'
    );

DROP TABLE IF EXISTS sink_order_payments;

CREATE TABLE
    sink_order_payments (
        order_id VARCHAR(255),
        payment_sequential INT,
        payment_type VARCHAR(255),
        payment_installments INT,
        payment_value DOUBLE,
        PRIMARY KEY (order_id, payment_sequential) NOT ENFORCED
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
        'sink.label-prefix' = 'sink_order_payments',
        'table.identifier' = 'olist.order_payments'
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
    sink_order_payments
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM
    source_order_payments;
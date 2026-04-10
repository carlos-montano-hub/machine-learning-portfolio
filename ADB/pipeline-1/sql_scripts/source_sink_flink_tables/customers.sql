DROP TABLE IF EXISTS source_customers;

CREATE TABLE
    source_customers (
        customer_id STRING,
        customer_unique_id STRING,
        customer_zip_code_prefix STRING,
        customer_city STRING,
        customer_state STRING,
        PRIMARY KEY (customer_id) NOT ENFORCED
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
        'changelog-mode' = 'upsert', --  for tables with unique keys
        'scan.incremental.snapshot.enabled' = 'true',
        'scan.incremental.snapshot.chunk.size' = '2000',
        'scan.snapshot.fetch.size' = '200',
        'debezium.publication.name' = 'olist_publication', -- Publications are the mechanism that postgres uses to expose tables, a publication needs to be created in postgres manually
        'debezium.publication.autocreate.mode' = 'disabled',
        'table-name' = 'customers',
        'slot.name' = 'customers_flink_slot_1' -- WAL slot to write to, saves the point at which the source is reading
    );

DROP TABLE IF EXISTS sink_customers;

CREATE TABLE
    sink_customers (
        customer_id VARCHAR(255),
        customer_unique_id VARCHAR(255),
        customer_zip_code_prefix VARCHAR(255),
        customer_city VARCHAR(255),
        customer_state VARCHAR(255),
        PRIMARY KEY (customer_id) NOT ENFORCED
    )
WITH
    (
        'connector' = 'doris',
        'fenodes' = 'doris:8030',
        'benodes' = 'doris:8040',
        'username' = 'root',
        'password' = '',
        'sink.enable-2pc' = 'true', -- two-phase commit
        'sink.max-retries' = '10',
        'sink.properties.group_commit' = 'sync_mode', -- Passed to Doris, data is visible after the grouped loads commit
        'sink.enable.batch-mode' = 'false', -- streaming mode, checkpoint driven
        'sink.label-prefix' = 'sink_customers', -- Labels for internal transactions, must be unique
        'table.identifier' = 'olist.customers' -- Table to load to
        -- 'sink.buffer-flush.max-rows' = '10000',
        -- 'sink.buffer-flush.interval' = '5s', for batch-mode
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
    sink_customers
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM
    source_customers;
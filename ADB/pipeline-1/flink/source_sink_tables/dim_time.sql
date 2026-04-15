DROP TABLE IF EXISTS source_dim_time;

CREATE TABLE
    source_dim_time (
        date_id INT,
        full_date DATE,
        `year` INT,
        `quarter` INT,
        `month` INT,
        `day` INT,
        day_of_week INT,
        day_name STRING,
        week_of_year_iso INT,
        is_weekend BOOLEAN,
        PRIMARY KEY (date_id) NOT ENFORCED
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
        'table-name' = 'dim_time',
        'slot.name' = 'dim_time_flink_slot_1' -- WAL slot to write to, saves the point at which the source is reading
    );

DROP TABLE IF EXISTS sink_dim_time;

CREATE TABLE
    sink_dim_time (
        date_id INT,
        full_date DATE,
        `year` INT,
        `quarter` INT,
        `month` INT,
        `day` INT,
        day_of_week INT,
        day_name VARCHAR(255),
        week_of_year_iso INT,
        is_weekend BOOLEAN,
        PRIMARY KEY (date_id) NOT ENFORCED
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
        'sink.label-prefix' = 'sink_dim_time', -- Labels for internal transactions, must be unique
        'table.identifier' = 'warehouse.dim_time' -- Table to load to
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
    sink_dim_time
SELECT
    date_id,
    full_date,
    `year`,
    `quarter`,
    `month`,
    `day`,
    day_of_week,
    day_name,
    week_of_year_iso,
    is_weekend
FROM
    source_dim_time;
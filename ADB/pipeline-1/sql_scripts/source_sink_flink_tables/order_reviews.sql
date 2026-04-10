DROP TABLE IF EXISTS source_order_reviews;

CREATE TABLE
    source_order_reviews (
        review_id STRING,
        order_id STRING,
        review_score INT,
        review_comment_title STRING,
        review_comment_message STRING,
        review_creation_date TIMESTAMP,
        review_answer_timestamp TIMESTAMP,
        PRIMARY KEY (review_id) NOT ENFORCED
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
        'table-name' = 'order_reviews',
        'slot.name' = 'order_reviews_flink_slot_1'
    );

DROP TABLE IF EXISTS sink_order_reviews;

CREATE TABLE
    sink_order_reviews (
        review_id VARCHAR(255),
        order_id VARCHAR(255),
        review_score INT,
        review_comment_title VARCHAR(255),
        review_comment_message VARCHAR(255),
        review_creation_date TIMESTAMP,
        review_answer_timestamp TIMESTAMP,
        PRIMARY KEY (review_id) NOT ENFORCED
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
        'sink.label-prefix' = 'sink_order_reviews',
        'table.identifier' = 'olist.order_reviews'
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
    sink_order_reviews
SELECT
    CAST(review_id AS VARCHAR(255)) AS review_id,
    CAST(order_id AS VARCHAR(255)) AS order_id,
    CAST(review_score AS INT) AS review_score,
    CAST(
        REPLACE (
            REPLACE (
                REPLACE (
                    CAST(review_comment_title AS STRING),
                    CHR (9),
                    ' '
                ),
                CHR (10),
                ' '
            ),
            CHR (13),
            ' '
        ) AS VARCHAR(255)
    ) AS review_comment_title,
    CAST(
        REPLACE (
            REPLACE (
                REPLACE (
                    CAST(review_comment_message AS STRING),
                    CHR (9),
                    ' '
                ),
                CHR (10),
                ' '
            ),
            CHR (13),
            ' '
        ) AS VARCHAR(255)
    ) AS review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM
    source_order_reviews;
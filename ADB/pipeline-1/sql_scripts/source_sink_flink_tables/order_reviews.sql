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
        'connector' = 'jdbc',
        'url' = 'jdbc:postgresql://postgres:5432/olist',
        'table-name' = 'public.order_reviews',
        'username' = 'postgres_user',
        'password' = 'postgres_pass'
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
        'table.identifier' = 'olist.order_reviews',
        'username' = 'root',
        'password' = '',
        'sink.enable-2pc' = 'false',
        'sink.buffer-flush.max-rows' = '10000',
        'sink.buffer-flush.interval' = '5s'
    );

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
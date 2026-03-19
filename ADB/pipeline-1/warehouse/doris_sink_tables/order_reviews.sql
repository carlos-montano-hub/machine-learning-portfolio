CREATE TABLE
    IF NOT EXISTS olist.order_reviews (
        review_id VARCHAR(255) NOT NULL,
        order_id VARCHAR(255) NOT NULL,
        review_score INT NOT NULL,
        review_comment_title VARCHAR(255) NULL,
        review_comment_message VARCHAR(65533) NULL,
        review_creation_date DATETIME NOT NULL,
        review_answer_timestamp DATETIME NULL
    ) UNIQUE KEY (review_id) DISTRIBUTED BY HASH (review_id) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
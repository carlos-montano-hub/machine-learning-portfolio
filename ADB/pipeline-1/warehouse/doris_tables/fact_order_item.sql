CREATE TABLE
    IF NOT EXISTS warehouse.fact_order_item (
        order_id VARCHAR(64) NOT NULL COMMENT 'Degenerate dimension – source order id',
        order_item_id INT NOT NULL COMMENT 'Line number within the order',
        order_item_fact_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Surrogate key',
        product_key BIGINT NOT NULL COMMENT 'FK -> dim_product',
        customer_key BIGINT NOT NULL COMMENT 'FK -> dim_customer',
        seller_key BIGINT NOT NULL COMMENT 'FK -> dim_seller',
        order_status_key BIGINT NOT NULL COMMENT 'FK -> dim_order_status',
        order_date_key INT NULL COMMENT 'FK -> dim_time',
        item_price DECIMAL(12, 2) NOT NULL,
        freight_value DECIMAL(12, 2) NOT NULL
    ) UNIQUE KEY (order_id, order_item_id) DISTRIBUTED BY HASH (order_id) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
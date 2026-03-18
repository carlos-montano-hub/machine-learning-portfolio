CREATE TABLE
    IF NOT EXISTS fact_order_item (
        order_item_fact_key BIGINT NOT NULL COMMENT 'Surrogate key',
        order_id VARCHAR(64) NOT NULL COMMENT 'Degenerate dimension – source order id',
        order_item_id INT NOT NULL COMMENT 'Line number within the order',
        product_key INT NOT NULL COMMENT 'FK → dim_product',
        customer_key INT NOT NULL COMMENT 'FK → dim_customer',
        seller_key INT NOT NULL COMMENT 'FK → dim_seller',
        order_status_key INT NOT NULL COMMENT 'FK → dim_order_status',
        item_price DECIMAL(12, 2) NOT NULL,
        freight_value DECIMAL(12, 2) NOT NULL
    ) UNIQUE KEY (order_item_fact_key) DISTRIBUTED BY HASH (order_item_fact_key) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
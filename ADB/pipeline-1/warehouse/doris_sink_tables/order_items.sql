CREATE TABLE
    IF NOT EXISTS olist.order_items (
        order_id VARCHAR(255) NOT NULL,
        order_item_id INT NOT NULL,
        product_id VARCHAR(255) NOT NULL,
        seller_id VARCHAR(255) NOT NULL,
        shipping_limit_date DATETIME NOT NULL,
        price DOUBLE NOT NULL,
        freight_value DOUBLE NOT NULL
    ) UNIQUE KEY (order_id, order_item_id) DISTRIBUTED BY HASH (order_id, order_item_id) BUCKETS AUTO PROPERTIES (
        "replication_allocation" = "tag.location.default: 1"
    );
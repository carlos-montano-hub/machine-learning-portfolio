-- DROP DATABASE IF EXISTS olist;

CREATE DATABASE IF NOT EXISTS olist;
-- DROP DATABASE IF EXISTS warehouse;

CREATE DATABASE IF NOT EXISTS warehouse;

CREATE WORKLOAD GROUP IF NOT EXISTS warehouse_load
PROPERTIES (
  "max_concurrency" = "32",
  "max_queue_size" = "200",
  "queue_timeout" = "10000"
);

GRANT USAGE_PRIV ON WORKLOAD GROUP 'warehouse_load' TO 'flink'@'%';

-- In the session used by the Flink load user:
SET workload_group = 'warehouse_load';
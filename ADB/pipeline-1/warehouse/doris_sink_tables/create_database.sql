DROP DATABASE IF EXISTS olist;

CREATE DATABASE IF NOT EXISTS olist;

CREATE WORKLOAD GROUP IF NOT EXISTS demo_load
PROPERTIES (
  "max_concurrency" = "32",
  "max_queue_size" = "200",
  "queue_timeout" = "10000"
);

GRANT USAGE_PRIV ON WORKLOAD GROUP 'demo_load' TO 'flink'@'%';

-- In the session used by the Flink load user:
SET workload_group = 'demo_load';
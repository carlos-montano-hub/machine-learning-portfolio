
# To run a single table script:
# docker exec -it flink-sql-client bash -lc "cat /opt/flink/sql/setup_flink.sql <(echo '') /opt/flink/sql/source_sink_flink_tables/<table_name>.sql > /tmp/combined.sql && bin/sql-client.sh -f /tmp/combined.sql"
# docker exec -it flink-sql-client bash -lc "cat /opt/flink/sql/setup_flink.sql <(echo '') /opt/flink/sql/source_sink_flink_tables/order_reviews.sql > /tmp/combined.sql && bin/sql-client.sh -f /tmp/combined.sql"

$sqlFiles = docker exec flink-sql-client bash -c "ls /opt/flink/sql/source_sink_flink_tables.sql/*.sql"

foreach ($file in $sqlFiles) {
    $file = $file.Trim()
    Write-Host "Running $file ..."
    docker exec -it flink-sql-client bash -lc "cat /opt/flink/sql/setup_flink.sql <(echo '') $file > /tmp/combined.sql && bin/sql-client.sh -f /tmp/combined.sql"
}

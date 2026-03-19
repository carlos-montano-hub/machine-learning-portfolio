"""
Run all Flink SQL table scripts.
Concatenates setup_flink.sql (JAR loading) with each table file and
executes them via the Flink SQL client inside the Docker container.

To run a single table script:
  python setup_flink.py product_category_name_translation.sql
"""

import subprocess
import sys

CONTAINER = "flink-sql-client"
SETUP_SQL = "/opt/flink/sql/setup_flink.sql"
TABLES_DIR = "/opt/flink/sql/source_sink_flink_tables"


def run_sql_file(file_path: str):
    """Concatenate setup SQL with table file and execute via Flink SQL client."""
    print(f"Running {file_path} ...")
    cmd = (
        f"cat {SETUP_SQL} <(echo '') {file_path} > /tmp/combined.sql "
        f"&& bin/sql-client.sh -f /tmp/combined.sql"
    )
    result = subprocess.run(
        ["docker", "exec", "-it", CONTAINER, "bash", "-lc", cmd],
        check=False,
    )
    if result.returncode != 0:
        print(f"  FAILED (exit code {result.returncode})")
    else:
        print("  OK")
    return result.returncode


def main():
    # If a specific file is passed as argument, run only that one
    if len(sys.argv) > 1:
        for filename in sys.argv[1:]:
            file_path = f"{TABLES_DIR}/{filename}"
            run_sql_file(file_path)
        return

    # Otherwise, run all SQL files in the tables directory
    result = subprocess.run(
        ["docker", "exec", CONTAINER, "bash", "-c", f"ls {TABLES_DIR}/*.sql"],
        capture_output=True,
        text=True,
        check=True,
    )

    sql_files = [f.strip() for f in result.stdout.strip().splitlines() if f.strip()]

    for file_path in sql_files:
        run_sql_file(file_path)

    print("\nDone.")


if __name__ == "__main__":
    main()

"""
Create all Doris tables: database setup, staging, dimensions, and facts.
Connects via MySQL protocol (port 9030) and executes SQL files from
warehouse/setup/, warehouse/staging/, warehouse/dimensions/, and warehouse/facts/.
"""

from pathlib import Path

import pymysql

DORIS_HOST = "localhost"
DORIS_PORT = 9030
DORIS_USER = "root"
DORIS_PASSWORD = ""

PROJECT_ROOT = Path(__file__).resolve().parent.parent
WAREHOUSE_DIR = PROJECT_ROOT / "warehouse"

SQL_DIRS = [
    WAREHOUSE_DIR / "staging",
    WAREHOUSE_DIR / "dimensions",
    WAREHOUSE_DIR / "facts",
]


def main():
    connection = pymysql.connect(
        host=DORIS_HOST,
        port=DORIS_PORT,
        user=DORIS_USER,
        password=DORIS_PASSWORD,
    )

    try:
        cursor = connection.cursor()

        # Run database creation first
        setup_file = WAREHOUSE_DIR / "setup" / "create_database.sql"
        sql = setup_file.read_text(encoding="utf-8").strip()
        print(f"Running {setup_file.name} ...")
        cursor.execute(sql)
        print("  OK")

        # Run all table scripts from each directory
        for sql_dir in SQL_DIRS:
            for filepath in sorted(sql_dir.glob("*.sql")):
                sql = filepath.read_text(encoding="utf-8").strip()
                print(f"Running {sql_dir.name}/{filepath.name} ...")
                cursor.execute(sql)
                print("  OK")

        connection.commit()
        print("\nAll Doris tables created successfully.")
    except Exception as e:
        print(f"\nError: {e}")
        raise
    finally:
        connection.close()


if __name__ == "__main__":
    main()

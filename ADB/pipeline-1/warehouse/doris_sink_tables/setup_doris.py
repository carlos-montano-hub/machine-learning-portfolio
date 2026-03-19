"""
Create all staging tables in Apache Doris.
Connects via MySQL protocol (port 9030) and executes each SQL file
in warehouse/doris_sink_tables/.
"""

from pathlib import Path

import pymysql

DORIS_HOST = "localhost"
DORIS_PORT = 9030
DORIS_USER = "root"
DORIS_PASSWORD = ""

SQL_DIR = Path(__file__).parent  # / "warehouse" / "doris_sink_tables"

# create_database.sql must run first, then the rest in any order
ORDERED_FILES = ["create_database.sql"]


def main():
    connection = pymysql.connect(
        host=DORIS_HOST,
        port=DORIS_PORT,
        user=DORIS_USER,
        password=DORIS_PASSWORD,
    )

    try:
        cursor = connection.cursor()

        # Run ordered files first (database creation)
        for filename in ORDERED_FILES:
            filepath = SQL_DIR / filename
            sql = filepath.read_text(encoding="utf-8").strip()
            print(f"Running {filepath.name} ...")
            cursor.execute(sql)
            print("  OK")

        # Run all remaining table scripts
        for filepath in sorted(SQL_DIR.glob("*.sql")):
            if filepath.name in ORDERED_FILES:
                continue
            sql = filepath.read_text(encoding="utf-8").strip()
            print(f"Running {filepath.name} ...")
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

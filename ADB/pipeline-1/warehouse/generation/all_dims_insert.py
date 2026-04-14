from pathlib import Path

from sqlalchemy import create_engine

database_url = "mysql+pymysql://root:@localhost:9030/warehouse?charset=utf8mb4"

engine = create_engine(
    database_url,
    pool_pre_ping=True,
)

sql_file_paths = [
    Path("warehouse/generation/insert_dim_customer.sql"),
    Path("warehouse/generation/insert_dim_seller.sql"),
    Path("warehouse/generation/insert_dim_geolocation.sql"),
    Path("warehouse/generation/insert_dim_payment_type.sql"),
    Path("warehouse/generation/insert_dim_order_status.sql"),
    Path("warehouse/generation/insert_dim_product.sql"),
    Path("warehouse/generation/insert_fact_table.sql"),
]


def split_sql_statements(sql_text: str) -> list[str]:
    return [statement.strip() for statement in sql_text.split(";") if statement.strip()]


with engine.begin() as connection:
    for sql_file_path in sql_file_paths:
        sql_content = sql_file_path.read_text(encoding="utf-8")
        sql_statements = split_sql_statements(sql_content)
        for sql_statement in sql_statements:
            connection.exec_driver_sql(sql_statement)

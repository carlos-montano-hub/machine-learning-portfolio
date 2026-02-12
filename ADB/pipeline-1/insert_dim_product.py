from pathlib import Path
from sqlalchemy import create_engine, text

database_url = "postgresql+psycopg2://postgres_user:postgres_pass@localhost:5435/olist"

engine = create_engine(database_url)

sql_file_path = Path("insert_dim_product.sql")

with engine.begin() as connection:  # transaction automática
    sql_content = sql_file_path.read_text(encoding="utf-8")
    connection.execute(text(sql_content))

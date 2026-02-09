from sqlalchemy import create_engine

database_url = "postgresql+psycopg2://user:password@localhost:5432/dbname"
engine = create_engine(database_url, pool_pre_ping=True)

from sqlalchemy.orm import (
    declarative_base,
    DeclarativeBase,
    Mapped,
    mapped_column,
    relationship,
)
from sqlalchemy import (
    BigInteger,
    Column,
    Float,
    Integer,
    String,
    ForeignKey,
    DateTime,
    Numeric,
)
from datetime import datetime
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class Customer(Base):
    __tablename__ = "customers"

    customer_id = Column(String, primary_key=True, nullable=False)
    customer_unique_id = Column(String, nullable=False, index=True)
    customer_zip_code_prefix = Column(String, nullable=False)
    customer_city = Column(String, nullable=False)
    customer_state = Column(String, nullable=False)


class Geolocation(Base):
    __tablename__ = "geolocations"

    geolocation_zip_code_prefix = Column(String, primary_key=True, nullable=False)
    geolocation_lat = Column(Float, nullable=False)
    geolocation_lng = Column(Float, nullable=False)
    geolocation_city = Column(String, nullable=False)
    geolocation_state = Column(String, nullable=False)

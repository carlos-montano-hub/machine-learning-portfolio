from sqlalchemy import Integer, String, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from base import Base


class CustomerDimension(Base):
    __tablename__ = "dim_customer"

    customer_key: Mapped[int] = mapped_column(
        Integer, primary_key=True, autoincrement=True
    )
    customer_id: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)

    customer_unique_id: Mapped[str] = mapped_column(String(64), nullable=False)
    customer_zip_code_prefix: Mapped[str] = mapped_column(String(16), nullable=False)
    customer_city: Mapped[str] = mapped_column(String(128), nullable=False)
    customer_state: Mapped[str] = mapped_column(String(8), nullable=False)


class SellerDimension(Base):
    __tablename__ = "dim_seller"

    seller_key: Mapped[int] = mapped_column(
        Integer, primary_key=True, autoincrement=True
    )
    seller_id: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)

    seller_zip_code_prefix: Mapped[str] = mapped_column(String(16), nullable=False)
    seller_city: Mapped[str] = mapped_column(String(128), nullable=False)
    seller_state: Mapped[str] = mapped_column(String(8), nullable=False)


class GeolocationDimension(Base):
    __tablename__ = "dim_geolocation"

    geolocation_key: Mapped[int] = mapped_column(
        Integer, primary_key=True, autoincrement=True
    )

    geolocation_zip_code_prefix: Mapped[str] = mapped_column(String(16), nullable=False)
    geolocation_city: Mapped[str] = mapped_column(String(128), nullable=False)
    geolocation_state: Mapped[str] = mapped_column(String(8), nullable=False)
    geolocation_lat: Mapped[float]
    geolocation_lng: Mapped[float]


class PaymentTypeDimension(Base):
    __tablename__ = "dim_payment_type"

    payment_type_key: Mapped[int] = mapped_column(
        Integer, primary_key=True, autoincrement=True
    )
    payment_type: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)


class OrderStatusDimension(Base):
    __tablename__ = "dim_order_status"

    order_status_key: Mapped[int] = mapped_column(
        Integer, primary_key=True, autoincrement=True
    )
    order_status: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)

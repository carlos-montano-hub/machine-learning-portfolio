from __future__ import annotations

from sqlalchemy import (
    BigInteger,
    ForeignKey,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from base import Base
from dimensions.customer_dimension import CustomerDimension
from dimensions.order_status_dimension import OrderStatusDimension
from dimensions.product_dimension import ProductDimension
from dimensions.seller_dimension import SellerDimension


class OrderItemFact(Base):
    __tablename__ = "fact_order_item"
    __table_args__ = (
        # Asegura repetibilidad en ETL y documenta el grano real del hecho
        UniqueConstraint(
            "order_id", "order_item_id", name="uq_fact_order_item_order_line"
        ),
    )

    order_item_fact_key: Mapped[int] = mapped_column(
        BigInteger, primary_key=True, autoincrement=True
    )

    # Claves degeneradas para drill-through y trazabilidad con la fuente
    order_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    order_item_id: Mapped[int] = mapped_column(Integer, nullable=False)

    # Dimensiones
    product_key: Mapped[int] = mapped_column(
        ForeignKey(ProductDimension.product_id), nullable=False, index=True
    )
    customer_key: Mapped[int] = mapped_column(
        ForeignKey(CustomerDimension.customer_key), nullable=False, index=True
    )
    seller_key: Mapped[int] = mapped_column(
        ForeignKey(SellerDimension.seller_key), nullable=False, index=True
    )
    order_status_key: Mapped[int] = mapped_column(
        ForeignKey(OrderStatusDimension.order_status_key), nullable=False, index=True
    )

    # Medidas (usar Numeric para dinero, evita errores de coma flotante)
    item_price: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    freight_value: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)

from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    BigInteger,
    ForeignKey,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from all_dims_class import CustomerDimension, OrderStatusDimension, SellerDimension
from base import Base


class OrderItemFact(Base):
    __tablename__ = "fact_order_item"
    __table_args__ = (
        # Asegura idempotencia en ETL y documenta el grano real del hecho
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

    # Producto: si no tienes dim_product, esto es degenerado. Si sí tienes, reemplázalo por product_key.
    product_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)

    # Dimensiones
    customer_key: Mapped[int] = mapped_column(
        ForeignKey(CustomerDimension.customer_key), nullable=False, index=True
    )
    seller_key: Mapped[int] = mapped_column(
        ForeignKey(SellerDimension.seller_key), nullable=False, index=True
    )
    order_status_key: Mapped[int] = mapped_column(
        ForeignKey(OrderStatusDimension.order_status_key), nullable=False, index=True
    )

    # Atributo operacional útil (no es “medida”, pero se consulta mucho)
    shipping_limit_timestamp: Mapped[datetime] = mapped_column(
        nullable=False, index=True
    )

    # Medidas (usar Numeric para dinero, evita errores de coma flotante)
    item_price: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    freight_value: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)

    # Relaciones opcionales (solo ergonomía ORM; puedes quitarlas si quieres hechos “puros”)
    customer: Mapped[CustomerDimension] = relationship()
    seller: Mapped[SellerDimension] = relationship()
    order_status: Mapped[OrderStatusDimension] = relationship()

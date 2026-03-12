from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from base import Base


class OrderStatusDimension(Base):
    __tablename__ = "dim_order_status"

    order_status_key: Mapped[int] = mapped_column(
        Integer, primary_key=True, autoincrement=True
    )
    order_status: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)

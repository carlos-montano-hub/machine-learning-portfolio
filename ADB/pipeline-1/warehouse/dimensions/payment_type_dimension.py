from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from base import Base


class PaymentTypeDimension(Base):
    __tablename__ = "dim_payment_type"

    payment_type_key: Mapped[int] = mapped_column(
        Integer, primary_key=True, autoincrement=True
    )
    payment_type: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)

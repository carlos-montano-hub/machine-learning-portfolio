from sqlalchemy import Integer, String
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
